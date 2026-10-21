import { createHmac, timingSafeEqual } from "node:crypto";
import { z } from "zod";
import { ContextRetrievalService } from "../context/retrieval.service";
import type { RetrievedContext } from "../context/retrieval.contracts";

export const contextEnabled = () => process.env.ENABLE_PERSISTENT_CONTEXT === "true";
export function metric(stage: string, started: number, outcome: string, count = 0) {
    console.info(JSON.stringify({ event: "chat_context", stage, durationMs: Math.round(performance.now() - started), outcome, count }));
}
export async function bounded<T>(work: Promise<T>, ms = Number(process.env.CHAT_RETRIEVAL_TIMEOUT_MS ?? 4000)): Promise<T> {
    z.number().int().min(1).max(10000).parse(ms);
    let timer: ReturnType<typeof setTimeout> | undefined;
    try { return await Promise.race([work, new Promise<never>((_, reject) => { timer = setTimeout(() => reject(new Error("Context timeout")), ms); })]); }
    finally { clearTimeout(timer); }
}
const ticketSchema = z.strictObject({ userId: z.uuid(), conversationId: z.string().min(1).max(200), sourceMessageId: z.uuid(), expires: z.number().int() });
function secret() {
    const value = process.env.CONTEXT_BRIDGE_SECRET;
    if (!value || value.length < 32) throw new Error("Context bridge secret is not configured");
    return value;
}
export function issueTicket(userId: string, conversationId: string, sourceMessageId: string) {
    const body = Buffer.from(JSON.stringify(ticketSchema.parse({ userId, conversationId, sourceMessageId, expires: Date.now() + 120000 }))).toString("base64url");
    return `${body}.${createHmac("sha256", secret()).update(body).digest("base64url")}`;
}
export function verifyTicket(value: string) {
    if (value.length > 2000) throw new Error("Invalid ticket");
    const [body, signature, extra] = value.split(".");
    if (!body || !signature || extra) throw new Error("Invalid ticket");
    const expected = createHmac("sha256", secret()).update(body).digest();
    const actual = Buffer.from(signature, "base64url");
    if (actual.length !== expected.length || !timingSafeEqual(actual, expected)) throw new Error("Invalid ticket");
    const parsed = ticketSchema.parse(JSON.parse(Buffer.from(body, "base64url").toString()));
    if (parsed.expires <= Date.now()) throw new Error("Expired ticket");
    return parsed;
}
export type ChatContextEnvelope = { version: 1; ticket: string; sections: RetrievedContext | null };
export async function prepareContext(userId: string, conversationId: string, sourceMessageId: string | undefined, query: string,
    retrieve = (owner: string, input: { conversationId: string; currentMessageId: string; query: string }) => new ContextRetrievalService().retrieve(owner, input)):
    Promise<ChatContextEnvelope | undefined> {
    if (!contextEnabled() || !sourceMessageId) return undefined;
    const started = performance.now();
    try {
        const ticket = issueTicket(userId, conversationId, sourceMessageId);
        try {
            const sections = await bounded(retrieve(userId, { conversationId, currentMessageId: sourceMessageId, query }));
            metric("retrieval", started, sections.semanticStatus, sections.memories.length);
            return { version: 1, ticket, sections: Buffer.byteLength(JSON.stringify(sections)) <= 250000 ? sections : null };
        } catch { metric("retrieval", started, "fallback"); return { version: 1, ticket, sections: null }; }
    } catch { metric("retrieval", started, "configuration_failure"); return undefined; }
}

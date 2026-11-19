import { z } from "zod";
import { factCandidateSchema, memoryCandidateSchema } from "./context.candidates";

export const EXTRACTION_JOBS_TOPIC = "elyrii.context.extraction.jobs.v1";
export const EXTRACTION_RESULTS_TOPIC = "elyrii.context.extraction.results.v1";
export const MAX_ATTEMPTS = 5;
export const RESULT_LIMIT_BYTES = 65536;
export const retryDelay = (attempt: number) => Math.min(300_000, 5000 * 2 ** (attempt - 1));
const identity = {
    version: z.literal(1), jobId: z.uuid(), requestId: z.uuid(), userId: z.uuid(),
    conversationId: z.string().min(1).max(200), sourceMessageId: z.uuid(),
    extractorVersion: z.literal("v1"), attempt: z.number().int().min(1).max(MAX_ATTEMPTS),
};
const text = z.string().min(1).max(4000).refine(s => /\S/.test(s));
const instant = z.iso.datetime({ offset: true });
export const extractionMessageSchema = z.strictObject({
    id: z.uuid(), role: z.literal("user"), content: text, messageAt: instant,
});
export const extractionJobSchema = z.strictObject({ ...identity,
    input: z.strictObject({ source: extractionMessageSchema,
        context: z.array(extractionMessageSchema).max(12), timezone: z.string().min(1).max(100) }),
}).refine(job => job.sourceMessageId === job.input.source.id, "Source ID mismatch");
// The model cannot choose expiry/validity. These strict subsets mirror #222.
const fact = factCandidateSchema.options[0].omit({ validFrom: true, validUntil: true });
const preference = factCandidateSchema.options[1].omit({ validFrom: true, validUntil: true });
const memory = memoryCandidateSchema.omit({ validFrom: true, validUntil: true, expiresAt: true, eventAt: true })
    .extend({ eventAt: instant.nullable() });
export const proposalSchema = z.strictObject({
    candidate: z.discriminatedUnion("kind", [fact, preference, memory]),
    evidence: text, certainty: z.enum(["certain", "uncertain"]),
    category: z.enum(["stable_fact", "stable_preference", "temporary_emotion", "minor_event", "durable_life_event"]),
    temporalExpression: text.nullable(),
}).superRefine((p, ctx) => {
    const kind = { stable_fact: "fact", stable_preference: "preference", temporary_emotion: "memory",
        minor_event: "memory", durable_life_event: "memory" }[p.category];
    if (p.candidate.kind !== kind || (p.candidate.origin === "inferred" && p.certainty !== "uncertain") ||
        (p.candidate.kind === "memory" && p.candidate.retention !== (p.category === "durable_life_event" ? "long_term" : "short_term"))) {
        ctx.addIssue({ code: "custom", message: "Invalid classification or certainty" });
    }
});
export const extractionResultSchema = z.discriminatedUnion("status", [
    z.strictObject({ ...identity, status: z.literal("success"),
        output: z.strictObject({ promptVersion: z.literal("v1"), candidates: z.array(proposalSchema).max(8) }) }),
    z.strictObject({ ...identity, status: z.literal("failure"), error: z.enum(["inference_failed", "invalid_input"]) }),
]);
export type ExtractionJob = z.infer<typeof extractionJobSchema>;
export type ExtractionResult = z.infer<typeof extractionResultSchema>;
export type Proposal = z.infer<typeof proposalSchema>;

export function supportedBySource(p: Proposal, source: { id: string; message: string }) {
    return p.candidate.sourceMessageId === source.id && source.message.includes(p.evidence) &&
        (p.temporalExpression === null || source.message.includes(p.temporalExpression)) &&
        (p.candidate.kind !== "memory" || p.candidate.eventAt === null || p.evidence.includes(p.candidate.eventAt));
}

/** Stable JSON for exact deduplication; never perform semantic retrieval here. */
export function canonical(value: unknown): string {
    if (Array.isArray(value)) return `[${value.map(canonical).join(",")}]`;
    if (value !== null && typeof value === "object") return `{${Object.entries(value).sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0)
        .map(([key, item]) => `${JSON.stringify(key)}:${canonical(item)}`).join(",")}}`;
    return JSON.stringify(value)!;
}

import { afterAll, expect, test } from "bun:test";
import { createHash, randomUUID } from "node:crypto";
import { Pool } from "pg";
import { drizzle } from "drizzle-orm/node-postgres";
import { eq } from "drizzle-orm";
import * as schema from "../config/db/schema";
import ChatRepository from "./chat.repository";
import { ExtractionRepository } from "./extraction.repository";
import { EmbeddingRepository } from "./embedding.repository";
import { SummaryRepository } from "./summary.repository";
import { ContextPolicy } from "../modules/context/context.policy";
import { ContextRetrievalService } from "../modules/context/retrieval.service";
import { RetrievalRepository } from "./retrieval.repository";
import { ContextLifecycleRepository } from "./context-lifecycle.repository";
import { summaryConfig } from "../modules/context/summary.contracts";
import { issueTicket } from "../modules/chat/context-dispatch";
import { createContextRefreshRouter } from "../modules/chat/context-refresh.routes";
import type { EmbeddingModel } from "../modules/context/embedding.contracts";
import type { Proposal } from "../modules/context/extraction.contracts";
const check = process.env.CONTEXT_DB_TEST === "1" ? test : test.skip;
check("extraction → embeddings → summaries → refresh → prompt evaluation fixtures", async () => {
    const pool = new Pool({ host: process.env.DB_HOST, port: Number(process.env.DB_PORT || 5432), user: process.env.DB_USER,
        password: process.env.DB_PASSWORD, database: process.env.DB_NAME });
    const database = drizzle(pool, { schema });
    const owner = randomUUID(), other = randomUUID();
    const previousFlag = process.env.ENABLE_PERSISTENT_CONTEXT, previousSecret = process.env.CONTEXT_BRIDGE_SECRET;
    let now = new Date(Date.now() + 1000);
    const chat = new ChatRepository(database);
    const extraction = new ExtractionRepository(database, new ContextPolicy(() => now));
    const digest = "e".repeat(64);
    const spec: EmbeddingModel = { id: `embeddinggemma-300m@sha256:${digest}:raw-v1:768`, digest, providerModel: "embeddinggemma:300m",
        dimensions: 768, metric: "cosine", preprocessing: "raw-v1" };
    const unit = [1, ...Array(767).fill(0)], orthogonal = [0, 1, ...Array(766).fill(0)];
    const embeddings = new EmbeddingRepository(spec, database, () => now);
    const retrieval = new ContextRetrievalService(new RetrievalRepository(database, () => now), {
        spec, embed: async query => query.includes("graduation") ? unit : orthogonal,
    });
    const lifecycle = new ContextLifecycleRepository(database, () => now);
    const cases: unknown[] = [];
    const add = async (conversationId: string, text: string, candidate: any, category: Proposal["category"]) => {
        const source = await chat.createMessage({ userId: owner, conversationId, message: text, role: "user" });
        const job = (await extraction.claim())!; expect(job.sourceMessageId).toBe(source.id);
        const { input, ...identity } = job;
        expect(await extraction.complete({ ...identity, status: "success", output: { promptVersion: "v1", candidates: [{
            candidate: { ...candidate, origin: "explicit", sourceMessageId: source.id }, evidence: text,
            certainty: "certain", category, temporalExpression: null,
        }] } })).toBe("completed");
        return source;
    };
    try {
        process.env.ENABLE_PERSISTENT_CONTEXT = "true"; process.env.CONTEXT_BRIDGE_SECRET = "rollout-e2e-secret-with-more-than-32-bytes";
        await database.insert(schema.userTable).values([owner, other].map(id => ({ id, firstName: "Fixture", lastName: "User",
            email: `${id}@test.local`, password: "test", age: 30 })));
        await embeddings.register();
        await add("preferences", "I prefer SHORT_REPLIES", { kind: "preference", key: "reply_length", value: "SHORT_REPLIES" }, "stable_preference");
        await add("old-experience", "I had a GRADUATION_PARIS", { kind: "memory", content: "GRADUATION_PARIS", retention: "long_term", eventAt: null }, "durable_life_event");
        await add("monday", "I feel MONDAY_SADNESS", { kind: "memory", content: "MONDAY_SADNESS", retention: "short_term", eventAt: null }, "temporary_emotion");
        let job;
        while ((job = await embeddings.claim())) {
            const { spec: _, content, ...identity } = job;
            expect(await embeddings.complete({ ...identity, status: "success", dimensions: 768, embedding: unit })).toBe("completed");
        }
        await database.insert(schema.userContextFactsTable).values({ userId: other, key: "private", kind: "fact", value: "FOREIGN_SECRET", origin: "explicit" });
        const [oldMemory] = await database.select().from(schema.userMemoriesTable).where(eq(schema.userMemoriesTable.content, "GRADUATION_PARIS"));
        now = new Date(+now + 3 * 86400000);
        // An isolated rolling-summary job covers only the earlier messages.
        await database.update(schema.summaryTasks).set({ status: "idle" });
        await chat.createMessage({ userId: owner, conversationId: "current", role: "user", message: "Earlier topic" });
        await chat.createMessage({ userId: owner, conversationId: "current", role: "ai", message: "Earlier answer" });
        const current = await chat.createMessage({ userId: owner, conversationId: "current", role: "user", message: "CURRENT graduation QUERY" });
        const summaries = new SummaryRepository(database, { ...summaryConfig(), keepRecent: 1 }, () => now);
        const summaryJob = (await summaries.claim())!; expect(summaryJob.conversationId).toBe("current");
        const { messages, policy, priorSummary, priorThroughMessageId, timezone, ...summaryIdentity } = summaryJob;
        expect(await summaries.complete({ ...summaryIdentity, status: "success", summary: "CONTINUITY_MARKER", throughMessageId: messages.at(-1)!.id, outputTokens: 5 })).toBe("completed");
        const router = createContextRefreshRouter(database, retrieval);
        const ticket = issueTicket(owner, "current", current.id);
        const refresh = async () => {
            const response = await router.request("/refresh", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ ticket }) });
            expect(response.status).toBe(200); return await response.json() as any;
        };
        const record = async (name: string, present: string[], absent: string[]) => {
            const started = performance.now(), response = await refresh();
            cases.push({ name, now: now.toISOString(), response, present, absent, retrievalMs: performance.now() - started });
            return response;
        };
        let response = await record("older-recall-and-expiry", ["SHORT_REPLIES", "GRADUATION_PARIS", "CONTINUITY_MARKER"], ["MONDAY_SADNESS", "FOREIGN_SECRET"]);
        expect(response.sections.memories.map((m: any) => m.content)).toEqual(["GRADUATION_PARIS"]);
        expect(await chat.getRecentMessagesForContext(owner, "current", 12, current.id)).not.toContainEqual({ role: "user", message: current.message });
        await database.update(schema.chatMessagesTable).set({ message: "CURRENT unrelated QUERY" }).where(eq(schema.chatMessagesTable.id, current.id));
        await record("unrelated-no-recall", ["SHORT_REPLIES"], ["GRADUATION_PARIS", "MONDAY_SADNESS", "FOREIGN_SECRET"]);
        await database.update(schema.chatMessagesTable).set({ message: "CURRENT graduation QUERY" }).where(eq(schema.chatMessagesTable.id, current.id));
        await lifecycle.correct(owner, "memories", oldMemory!.id, { content: "GRADUATION_LYON" });
        response = await record("correction-before-reembedding", ["SHORT_REPLIES"], ["GRADUATION_PARIS", "GRADUATION_LYON", "MONDAY_SADNESS", "FOREIGN_SECRET"]);
        expect(response.sections.memories).toHaveLength(0);
        const revised = (await embeddings.claim())!; const { spec: _, content, ...identity } = revised;
        await embeddings.complete({ ...identity, status: "success", dimensions: 768, embedding: unit });
        await record("corrected-recall", ["GRADUATION_LYON", "SHORT_REPLIES"], ["GRADUATION_PARIS", "MONDAY_SADNESS", "FOREIGN_SECRET"]);
        await lifecycle.forget(owner, "memories", oldMemory!.id);
        await record("forgotten", ["SHORT_REPLIES"], ["GRADUATION_PARIS", "GRADUATION_LYON", "MONDAY_SADNESS", "FOREIGN_SECRET"]);
        const invalid = await router.request("/refresh", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ ticket: ticket + "x" }) });
        expect(invalid.status).toBe(401);
        expect(await chat.createCurrentResponse({ userId: owner, conversationId: "current", role: "ai", message: "Stale output" }, current.id, "incorrect-hash")).toBeNull();
        await lifecycle.deleteMessages(owner, { messageId: current.id });
        expect(await chat.createCurrentResponse({ userId: owner, conversationId: "current", role: "ai", message: "Deleted source output" }, current.id, createHash("sha256").update(current.message).digest("hex"))).toBeNull();
        expect((await router.request("/refresh", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ ticket }) })).status).toBe(410);
        if (process.env.CONTEXT_EVAL_DIR) await Bun.write(`${process.env.CONTEXT_EVAL_DIR}/lifecycle.json`, JSON.stringify({ cases }, null, 2));
    } finally {
        for (const user of [owner, other]) await database.delete(schema.userTable).where(eq(schema.userTable.id, user));
        await database.delete(schema.embeddingModels).where(eq(schema.embeddingModels.id, spec.id));
        if (previousFlag === undefined) delete process.env.ENABLE_PERSISTENT_CONTEXT; else process.env.ENABLE_PERSISTENT_CONTEXT = previousFlag;
        if (previousSecret === undefined) delete process.env.CONTEXT_BRIDGE_SECRET; else process.env.CONTEXT_BRIDGE_SECRET = previousSecret;
        await pool.end();
    }
});

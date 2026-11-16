import { afterAll, afterEach, beforeEach, describe, expect, test } from "bun:test";
import { randomUUID } from "node:crypto";
import { Pool } from "pg";
import { drizzle } from "drizzle-orm/node-postgres";
import { and, eq } from "drizzle-orm";
import { sign } from "hono/jwt";
import * as schema from "../config/db/schema";
import { ContextLifecycleRepository } from "./context-lifecycle.repository";
import { ContextRepository } from "./context.repository";
import { ContextPolicy } from "../modules/context/context.policy";
import { EmbeddingRepository } from "./embedding.repository";
import { ExtractionRepository } from "./extraction.repository";
import { SummaryRepository } from "./summary.repository";
import { summaryConfig, summaryConfigSchema } from "../modules/context/summary.contracts";
import { createContextRouter } from "../modules/context/lifecycle.routes";
import ChatRepository from "./chat.repository";
import JournalRepository from "./journal.repository";
import { RetrievalRepository } from "./retrieval.repository";
import { retrievalConfigSchema } from "../modules/context/retrieval.contracts";
import type { EmbeddingModel } from "../modules/context/embedding.contracts";
const suite = process.env.CONTEXT_DB_TEST === "1" ? describe : describe.skip;
suite("Context lifecycle and authenticated API", () => {
    const pool = new Pool({ host: process.env.DB_HOST, port: Number(process.env.DB_PORT || 5432), user: process.env.DB_USER,
        password: process.env.DB_PASSWORD, database: process.env.DB_NAME });
    const database = drizzle(pool, { schema });
    let owner: string, other: string, now: Date, repo: ContextLifecycleRepository;
    const digest = "d".repeat(64);
    const spec: EmbeddingModel = { id: `embeddinggemma-300m@sha256:${digest}:raw-v1:768`, digest, providerModel: "embeddinggemma:300m",
        dimensions: 768, metric: "cosine", preprocessing: "raw-v1" };
    const memory = async (sourceMessageId: string | null = null, extra = {}) => (await database.insert(schema.userMemoriesTable).values({
        userId: owner, content: "An old experience", origin: "explicit", retention: "long_term", sourceMessageId, ...extra }).returning())[0]!;
    const source = async (conversationId = "lifecycle") => new ChatRepository(database).createMessage({ userId: owner, role: "user", message: "I graduated in Paris", conversationId });
    beforeEach(async () => {
        owner = randomUUID(); other = randomUUID(); now = new Date(Date.now() + 1000);
        repo = new ContextLifecycleRepository(database, () => now);
        await database.insert(schema.userTable).values([owner, other].map(id => ({ id, firstName: "Test", lastName: "User", email: `${id}@test.local`, password: "test", age: 30 })));
    });
    afterEach(async () => {
        for (const id of [owner, other]) await database.delete(schema.userTable).where(eq(schema.userTable.id, id));
        await database.delete(schema.embeddingModels);
    });
    afterAll(async () => { await pool.end(); });
    test("authenticated pagination, input validation, owner isolation and idempotent deletes", async () => {
        const a = await memory(), b = await memory();
        const router = createContextRouter(repo);
        const oldSecret = process.env.SECRET_KEY; process.env.SECRET_KEY = "lifecycle-test-secret-key-32-bytes";
        try {
            const token = await sign({ userId: owner, email: "test@test.local", exp: Math.floor(Date.now() / 1000) + 60 }, process.env.SECRET_KEY, "HS256");
            const stranger = await sign({ userId: other, email: "other@test.local", exp: Math.floor(Date.now() / 1000) + 60 }, process.env.SECRET_KEY, "HS256");
            const auth = { Authorization: `Bearer ${token}` }, foreign = { Authorization: `Bearer ${stranger}` };
            expect((await router.request("/memories")).status).toBe(401);
            const response = await router.request("/memories?limit=1", { headers: auth });
            expect(response.headers.get("Cache-Control")).toBe("no-store");
            const first = await response.json() as any;
            const second = await (await router.request(`/memories?limit=1&after=${first.nextCursor}`, { headers: auth })).json() as any;
            expect(new Set([...first.items, ...second.items].map(r => r.id)).size).toBe(2);
            expect((await router.request("/memories?limit=101", { headers: auth })).status).toBe(400);
            expect((await (await router.request("/memories", { headers: foreign })).json() as any).items).toHaveLength(0);
            expect((await router.request(`/memories/${a.id}`, { method: "PATCH", headers: { ...foreign, "Content-Type": "application/json" }, body: JSON.stringify({ content: "stolen" }) })).status).toBe(404);
            expect((await router.request(`/memories/${a.id}`, { method: "PATCH", headers: { ...auth, "Content-Type": "application/json" }, body: JSON.stringify({ content: "x", userId: other }) })).status).toBe(400);
            expect((await router.request(`/memories/${a.id}`, { method: "DELETE", headers: foreign })).status).toBe(204);
            expect((await repo.list(owner, "memories", {})).items).toHaveLength(2);
            for (let i = 0; i < 2; i++) expect((await router.request(`/memories/${a.id}`, { method: "DELETE", headers: auth })).status).toBe(204);
            expect((await repo.list(owner, "memories", {})).items.map(r => r.id)).toEqual([b.id]);
        } finally { if (oldSecret === undefined) delete process.env.SECRET_KEY; else process.env.SECRET_KEY = oldSecret; }
    });
    test("correction invalidates old vectors, fences a racing result, and requeues the new revision", async () => {
        const embeddings = new EmbeddingRepository(spec, database, () => now); await embeddings.register();
        const src = await source(), row = await memory(src.id);
        const old = (await embeddings.claim())!;
        const corrected = await repo.correct(owner, "memories", row.id, { content: "Corrected experience" });
        expect(corrected!.origin).toBe("explicit");
        expect((corrected as any).contentRevision).toBe(2);
        const { spec: _, content, ...identity } = old;
        expect(await embeddings.complete({ ...identity, status: "success", dimensions: 768, embedding: [1, ...Array(767).fill(0)] })).toBe("discarded");
        expect((await embeddings.claim())!.content).toBe("Corrected experience");
        expect((await new ChatRepository(database).getHistory(owner))[0]!.message).toBe(src.message);
        expect(await new ChatRepository(database).getRecentMessagesForContext(owner, "lifecycle")).toHaveLength(0);
    });
    test("retained sources, replay and new extractor versions cannot resurrect forgotten context", async () => {
        const src = await source(), row = await memory(src.id);
        const extraction = new ExtractionRepository(database, new ContextPolicy(() => now));
        const old = (await extraction.claim())!; expect(old).not.toBeNull();
        await repo.forget(owner, "memories", row.id);
        expect(await extraction.complete({ ...old, input: undefined, status: "failure", error: "inference_failed" })).toBe("invalid");
        const { input, ...identity } = old;
        expect(await extraction.complete({ ...identity, status: "failure", error: "inference_failed" })).toBe("discarded");
        const [user] = await database.select().from(schema.userTable).where(eq(schema.userTable.id, owner));
        await database.insert(schema.extractionJobs).values({ userId: owner, conversationId: src.conversationId, sourceMessageId: src.id,
            requestId: randomUUID(), extractorVersion: "v2", generation: user!.contextGeneration, timezone: "UTC" });
        expect(await extraction.claim()).toBeNull();
        const embedding = new EmbeddingRepository(spec, database, () => now); await embedding.register();
        await embedding.backfillBatch(); expect(await embedding.claim()).toBeNull();
        await database.update(schema.chatMessagesTable).set({ contextSuppressed: false }).where(eq(schema.chatMessagesTable.id, src.id));
        expect((await database.select().from(schema.chatMessagesTable).where(eq(schema.chatMessagesTable.id, src.id)))[0]!.contextSuppressed).toBe(true);
    });
    test("expiry is immediate at the boundary and bounded cleanup is physical and repeatable", async () => {
        const src = await source(); const expiresAt = new Date(+now + 5000);
        const row = await memory(src.id, { retention: "short_term", expiresAt });
        await database.insert(schema.memoryEmbeddingsTable).values({ memoryId: row.id, model: "test", dimensions: 3, embedding: [1, 0, 0], contentRevision: 1 });
        expect((await repo.list(owner, "memories", {})).items).toHaveLength(1);
        await database.insert(schema.conversationSummariesTable).values({ userId: owner, conversationId: "lifecycle", summary: "Temporary emotion", throughMessageId: src.id });
        now = expiresAt;
        const continuity = await new SummaryRepository(database, undefined, () => now).continuity(owner, "lifecycle");
        expect(continuity.summary).toBeNull(); expect(continuity.messages).toHaveLength(0);
        expect((await repo.list(owner, "memories", {})).items).toHaveLength(0);
        expect(await new ContextRepository(owner, database, new ContextPolicy(() => now)).listEligibleMemories()).toHaveLength(0);
        expect((await Promise.all([repo.cleanup(1), repo.cleanup(1)])).reduce((a, b) => a + b)).toBe(1);
        expect(await repo.cleanup(1)).toBe(0);
        expect(await database.select().from(schema.memoryEmbeddingsTable).where(eq(schema.memoryEmbeddingsTable.memoryId, row.id))).toHaveLength(0);
        expect(await database.select().from(schema.userMemoriesTable).where(eq(schema.userMemoriesTable.id, row.id))).toHaveLength(0);
    });
    for (const boundary of ["expiresAt", "validUntil"] as const) test(`journal ${boundary} cleanup preserves durable recall and explicit forgetting`, async () => {
        const journal = new JournalRepository(database);
        const src = await journal.createEntry({ userId: owner, title: "Mixed context", content: "A temporary mood, a graduation and a preference" });
        const provenance = { sourceKind: "journal" as const, sourceId: src.id, sourceRevision: 1 };
        const expiresAt = new Date(+now + 5000);
        const expired = await memory(null, { ...provenance, retention: boundary === "expiresAt" ? "short_term" : "long_term", [boundary]: expiresAt });
        const durable = await memory(null, { ...provenance, content: "Graduated in Paris" });
        const [preference] = await database.insert(schema.userContextFactsTable).values({ userId: owner, ...provenance,
            key: "reply_length", kind: "preference", value: "short", origin: "explicit" }).returning();
        await new EmbeddingRepository(spec, database, () => now).register();
        const vector = [1, ...Array(767).fill(0)];
        for (const row of [expired, durable]) await database.insert(schema.memoryEmbeddingsTable).values({
            memoryId: row.id, model: spec.id, dimensions: 768, embedding: vector, contentRevision: 1 });
        now = expiresAt;
        expect((await Promise.all([repo.cleanup(1), repo.cleanup(1)])).reduce((a, b) => a + b)).toBe(1);
        expect(await repo.cleanup(1)).toBe(0);
        expect(await database.select().from(schema.userMemoriesTable).where(eq(schema.userMemoriesTable.id, expired.id))).toHaveLength(0);
        expect(await database.select().from(schema.memoryEmbeddingsTable).where(eq(schema.memoryEmbeddingsTable.memoryId, expired.id))).toHaveLength(0);
        expect((await journal.getEntryByIdForUser(src.id, owner))!.contextSuppressed).toBe(false);
        const retrieval = new RetrievalRepository(database, () => now);
        const config = retrievalConfigSchema.parse({ journalRecall: true });
        const ranks = await retrieval.search(owner, spec, vector, config);
        expect(ranks.map(row => row.id)).toEqual([durable.id]);
        const recalled = await retrieval.assemble(owner, { conversationId: "current", query: "graduation" }, spec, ranks, config);
        expect(recalled.memories.map(row => row.id)).toEqual([durable.id]);
        expect(recalled.facts.map(row => row.id)).toEqual([preference!.id]);
        // A later ordinary SQL deletion must still run the source suppression trigger.
        await database.delete(schema.userMemoriesTable).where(eq(schema.userMemoriesTable.id, durable.id));
        expect((await journal.getEntryByIdForUser(src.id, owner))!.contextSuppressed).toBe(true);
        expect((await retrieval.assemble(owner, { conversationId: "current", query: "preference" }, spec, [], config)).facts).toHaveLength(0);
    });
    test("explicitly forgetting an expired journal memory still suppresses the whole source", async () => {
        const journal = new JournalRepository(database);
        const src = await journal.createEntry({ userId: owner, title: "Forget", content: "Temporary and durable context" });
        const provenance = { sourceKind: "journal" as const, sourceId: src.id, sourceRevision: 1 };
        const expiresAt = new Date(+now + 5000);
        const expired = await memory(null, { ...provenance, retention: "short_term", expiresAt });
        await memory(null, provenance);
        now = expiresAt;
        await repo.forget(owner, "memories", expired.id);
        expect((await journal.getEntryByIdForUser(src.id, owner))!.contextSuppressed).toBe(true);
        expect((await repo.list(owner, "memories", {})).items).toHaveLength(0);
    });
    test("non-boundary source deletion fences summary jobs; forget-all excludes retained history from rebuild", async () => {
        const a = await source(), b = await source(), c = await source();
        const summary = new SummaryRepository(database, summaryConfigSchema.parse({ ...summaryConfig(), keepRecent: 1 }), () => now);
        const job = await summary.claim(); expect(job).not.toBeNull();
        await repo.deleteMessages(owner, { messageId: a.id });
        const { messages, priorSummary, priorThroughMessageId, timezone, policy, ...identity } = job!;
        expect(await summary.complete({ ...identity, status: "success", summary: "Old summary", throughMessageId: b.id, outputTokens: 5 })).toBe("discarded");
        await database.insert(schema.conversationSummariesTable).values({ userId: owner, conversationId: "lifecycle", summary: "Retained summary", throughMessageId: c.id });
        await repo.forgetAll(owner);
        expect((await summary.continuity(owner, "lifecycle")).messages).toHaveLength(0);
        const fresh = await source();
        expect((await summary.continuity(owner, "lifecycle")).messages.map(m => m.id)).toEqual([fresh.id]);
        expect(await summary.claim()).toBeNull();
    });
    test("explicit fact corrections stay authoritative across new extraction jobs and deletion", async () => {
        const src = await source();
        const [fact] = await database.insert(schema.userContextFactsTable).values({ userId: owner, key: "city", kind: "fact",
            value: "Paris", origin: "inferred", sourceMessageId: src.id }).returning();
        await repo.correct(owner, "facts", fact!.id, { value: "Lyon" });
        expect((await new ContextRepository(owner, database).listEligibleFacts())[0]!.value).toBe("Lyon");
        await source("new-conversation");
        const extraction = new ExtractionRepository(database, new ContextPolicy(() => now));
        const job = (await extraction.claim())!;
        expect(job).not.toBeNull();
        const { input, ...identity } = job;
        expect(await extraction.complete({ ...identity, status: "success", output: { promptVersion: "v1", candidates: [{
            candidate: { kind: "fact", key: "city", value: "Paris", origin: "explicit", sourceMessageId: job.sourceMessageId },
            evidence: input.source.content, certainty: "certain", category: "stable_fact", temporalExpression: null,
        }] } })).toBe("completed");
        expect((await new ContextRepository(owner, database).listEligibleFacts())[0]!.value).toBe("Lyon");
        await repo.forget(owner, "facts", fact!.id);
        expect((await repo.list(owner, "facts", {})).items).toHaveLength(0);
        expect((await database.select().from(schema.extractionKeys).where(eq(schema.extractionKeys.userId, owner)))[0]!.suppressed).toBe(true);
    });

    test("conversation and account deletion cascade context, queues and markers", async () => {
        const src = await source(), row = await memory(src.id);
        await new EmbeddingRepository(spec, database).register();
        await new EmbeddingRepository(spec, database).backfillBatch();
        await repo.deleteMessages(other, { conversationId: "lifecycle" });
        expect((await repo.list(owner, "memories", {})).items).toHaveLength(1);
        await repo.deleteMessages(owner, { conversationId: "lifecycle" });
        expect((await repo.list(owner, "memories", {})).items).toHaveLength(0);
        await source(); await memory();
        await database.insert(schema.extractionKeys).values({ userId: owner, key: "fact:test", targetId: row.id, sequence: 1n, suppressed: true });
        await database.delete(schema.userTable).where(eq(schema.userTable.id, owner));
        for (const table of [schema.chatMessagesTable, schema.userMemoriesTable, schema.userContextFactsTable, schema.summaryTasks, schema.extractionJobs, schema.extractionKeys, schema.embeddingJobs])
            expect(await database.select().from(table).where(eq(table.userId, owner))).toHaveLength(0);
    });
});

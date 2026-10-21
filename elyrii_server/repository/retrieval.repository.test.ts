import { afterAll, afterEach, beforeEach, describe, expect, test } from "bun:test";
import { randomUUID } from "node:crypto";
import { Pool } from "pg";
import { drizzle } from "drizzle-orm/node-postgres";
import { eq, sql } from "drizzle-orm";
import * as schema from "../config/db/schema";
import { EmbeddingRepository } from "./embedding.repository";
import { RetrievalRepository } from "./retrieval.repository";
import { ContextRetrievalService } from "../modules/context/retrieval.service";
import { retrievalConfigSchema } from "../modules/context/retrieval.contracts";
import type { EmbeddingModel } from "../modules/context/embedding.contracts";

const suite = process.env.CONTEXT_DB_TEST === "1" ? describe : describe.skip;
suite("Three-layer retrieval (PostgreSQL)", () => {
    const pool = new Pool({ host: process.env.DB_HOST, port: Number(process.env.DB_PORT || 5432),
        user: process.env.DB_USER, password: process.env.DB_PASSWORD, database: process.env.DB_NAME });
    const database = drizzle(pool, { schema });
    const digest = "b".repeat(64);
    const spec: EmbeddingModel = { id: `embeddinggemma-300m@sha256:${digest}:raw-v1:768`, digest,
        providerModel: "embeddinggemma:300m", dimensions: 768, metric: "cosine", preprocessing: "raw-v1" };
    const vector = [1, ...Array(767).fill(0)];
    const config = retrievalConfigSchema.parse({ topK: 3, recentLimit: 2 });
    let owner: string, other: string, now: Date, repo: RetrievalRepository;
    const query = { conversationId: "current", query: "Tell me about my graduation" };
    const service = (provider = { spec, embed: async () => vector }, repository = repo) => new ContextRetrievalService(repository, provider, config);
    const memory = async (content: string, similarity = 1, extra: Partial<typeof schema.userMemoriesTable.$inferInsert> = {}, model = spec.id) => {
        const [row] = await database.insert(schema.userMemoriesTable).values({ userId: owner, content, origin: "explicit", retention: "long_term", ...extra }).returning();
        await database.insert(schema.memoryEmbeddingsTable).values({ memoryId: row!.id, model, dimensions: 768, contentRevision: 1,
            embedding: [similarity, Math.sqrt(1 - similarity ** 2), ...Array(766).fill(0)] });
        return row!;
    };
    const message = async (text: string, seconds: number, conversationId = "current", userId = owner) =>
        (await database.insert(schema.chatMessagesTable).values({ userId, conversationId, role: "user", message: text,
            createdAt: new Date(+now - 100000 + seconds * 1000) }).returning())[0]!;
    beforeEach(async () => {
        owner = randomUUID(); other = randomUUID(); now = new Date(Date.now() + 1000);
        repo = new RetrievalRepository(database, () => now);
        await database.insert(schema.userTable).values([owner, other].map(id => ({ id, firstName: "Test", lastName: "User",
            email: `${id}@example.test`, password: "test", age: 30 })));
        await new EmbeddingRepository(spec, database).register();
    });
    afterEach(async () => {
        for (const id of [owner, other]) await database.delete(schema.userTable).where(eq(schema.userTable.id, id));
        await database.delete(schema.embeddingModels);
    });
    afterAll(async () => { await pool.end(); });

    test("recalls older relevant experiences, keeps unrelated preferences, isolates users and conversations", async () => {
        await database.insert(schema.userContextFactsTable).values([
            { userId: owner, key: "drink", kind: "preference", value: "tea", origin: "explicit" },
            { userId: other, key: "secret", kind: "fact", value: "private", origin: "explicit" },
        ]);
        const old = await message("I graduated", 0, "old");
        const relevant = await memory("Graduated years ago", 0.9, { sourceMessageId: old.id, eventAt: new Date("2020-01-01") });
        await memory("Bought a fridge", 0.1);
        await memory("Someone else's graduation", 1, { userId: other });
        await message("private conversation", 1, "other");
        await message("private user", 1, "current", other);
        const prior = await message("recent", 2), current = await message(query.query, 3);
        const context = await service().retrieve(owner, { ...query, currentMessageId: current.id });
        expect(context.facts.map(f => f.value)).toEqual(["tea"]);
        expect(context.continuity.messages.map(m => m.id)).toEqual([prior.id]);
        expect(context.memories.map(m => m.id)).toEqual([relevant.id]);
        expect(context.memories[0]!.sourceMessageId).toBe(old.id);
        expect(context.memories[0]!.eventAt!.getUTCFullYear()).toBe(2020);
        expect(context.semanticStatus).toBe("ok");
    });

    test("filters before top-k and safely handles unrelated mixed-dimension rows under planner changes", async () => {
        const good = await memory("Eligible", 0.8);
        for (const status of ["superseded", "deleted"] as const) {
            const row = await memory(status);
            await database.update(schema.userMemoriesTable).set({ status }).where(eq(schema.userMemoriesTable.id, row.id));
        }
        const expired = await memory("temporary sadness", 1, { retention: "short_term", expiresAt: new Date(+now + 10000) });
        const invalid = await memory("validity ended", 1, { validUntil: new Date(+now + 10000) });
        await memory("not yet valid", 1, { validFrom: new Date(+now + 90000) });
        await memory("wrong model", 1, {}, "old-version");
        const mixed = await memory("mixed dimensions", 1, { userId: other }, "old-version");
        await database.update(schema.memoryEmbeddingsTable).set({ dimensions: 3, embedding: [1, 0, 0] }).where(eq(schema.memoryEmbeddingsTable.memoryId, mixed.id));
        // Legacy zero vectors are not meaningful cosine candidates.
        const zero = await memory("zero norm", 1, {}, "old-version");
        await database.update(schema.memoryEmbeddingsTable).set({ embedding: Array(768).fill(0) }).where(eq(schema.memoryEmbeddingsTable.memoryId, zero.id));
        now = new Date(+now + 20000);
        await database.execute(sql`SET enable_seqscan = off`);
        const result = await new ContextRetrievalService(repo, { spec, embed: async () => vector }, { ...config, topK: 1 }).retrieve(owner, query);
        await database.execute(sql`RESET enable_seqscan`);
        expect(result.memories.map(m => m.id)).toEqual([good.id]);
        expect(result.memories.some(m => m.id === expired.id || m.id === invalid.id)).toBe(false);
        expect(result.semanticStatus).toBe("ok");
    });

    test("excludes legacy wrong-dimension vectors in the selected version and ineligible facts", async () => {
        const legacy = await memory("legacy wrong dimension");
        await database.delete(schema.embeddingModels).where(eq(schema.embeddingModels.id, spec.id));
        await database.update(schema.memoryEmbeddingsTable).set({ dimensions: 3, embedding: [1, 0, 0] })
            .where(eq(schema.memoryEmbeddingsTable.memoryId, legacy.id));
        await new EmbeddingRepository(spec, database).register();
        await database.insert(schema.userContextFactsTable).values([
            { userId: owner, key: "expired", kind: "fact", value: "old", origin: "explicit",
                validFrom: new Date(+now - 20000), validUntil: new Date(+now - 10000) },
            { userId: owner, key: "future", kind: "fact", value: "future", origin: "explicit", validFrom: new Date(+now + 20000) },
            { userId: owner, key: "deleted", kind: "fact", value: "deleted", origin: "explicit", status: "deleted" },
            { userId: owner, key: "superseded", kind: "fact", value: "old", origin: "explicit", status: "superseded" },
        ]);
        const result = await service().retrieve(owner, query);
        expect(result.semanticStatus).toBe("ok"); expect(result.memories).toHaveLength(0); expect(result.facts).toHaveLength(0);
    });

    test("summary coverage and current input never duplicate history, including a summary covering current input", async () => {
        const covered = await message("covered", 1), uncovered = await message("uncovered", 2), current = await message("current", 3);
        await database.insert(schema.conversationSummariesTable).values({ userId: owner, conversationId: "current", summary: "Earlier discussion", throughMessageId: covered.id });
        const foreign = await message("another conversation", 1, "other");
        await database.insert(schema.conversationSummariesTable).values({ userId: owner, conversationId: "other", summary: "Other summary", throughMessageId: foreign.id });
        const privateMessage = await message("another user", 1, "current", other);
        await database.insert(schema.conversationSummariesTable).values({ userId: other, conversationId: "current", summary: "Private summary", throughMessageId: privateMessage.id });
        await memory("covered memory", 1, { sourceMessageId: covered.id });
        await memory("recent memory", 1, { sourceMessageId: uncovered.id });
        await memory("current memory", 1, { sourceMessageId: current.id });
        let result = await service().retrieve(owner, { ...query, currentMessageId: current.id });
        expect(result.continuity.summary!.summary).toBe("Earlier discussion");
        expect(result.continuity.messages.map(m => m.id)).toEqual([uncovered.id]);
        expect(result.memories).toHaveLength(0);
        await database.update(schema.conversationSummariesTable).set({ throughMessageId: current.id, summary: "Includes current" })
            .where(eq(schema.conversationSummariesTable.throughMessageId, covered.id));
        result = await service().retrieve(owner, { ...query, currentMessageId: current.id });
        expect(result.continuity.summary).toBeNull();
        expect(result.continuity.messages.map(m => m.id)).toEqual([covered.id, uncovered.id]);
    });

    test("recent tail is chronological and bounded; invalid current IDs never broaden continuity", async () => {
        await message("old", 1); const a = await message("a", 2), b = await message("b", 3);
        const foreign = await message("foreign", 4, "other");
        const result = await service().retrieve(owner, query);
        expect(result.continuity.messages.map(m => m.id)).toEqual([a.id, b.id]);
        expect(result.continuity.truncated).toBe(true);
        for (const id of [foreign.id, randomUUID()]) {
            const invalid = await service().retrieve(owner, { ...query, currentMessageId: id });
            expect(invalid.continuity.messages).toHaveLength(0);
            expect(invalid.continuity.summary).toBeNull();
        }
    });

    test("deduplicates normalized content and shared provenance before top-k", async () => {
        const source = await message("old event", 0, "old");
        await memory("Graduated   in Paris", 0.9, { sourceMessageId: source.id });
        await memory("graduated in paris", 0.8);
        await memory("Another description of graduation", 0.85, { sourceMessageId: source.id });
        const second = await memory("Other relevant experience", 0.7);
        const result = await service().retrieve(owner, query);
        expect(result.memories).toHaveLength(2);
        expect(result.memories[1]!.id).toBe(second.id);
    });

    test("empty and below-threshold recall produce no semantic memories", async () => {
        expect((await service().retrieve(owner, query)).memories).toEqual([]);
        await memory("unrelated durable event", 0.2);
        expect((await service().retrieve(owner, query)).memories).toEqual([]);
    });

    test("rechecks deletion, correction, supersession and expiry between ranking and final assembly", async () => {
        const deleted = await memory("delete"), edited = await memory("edit"), superseded = await memory("supersede");
        const expiring = await memory("expire", 1, { expiresAt: new Date(+now + 5000) });
        const candidates = await repo.search(owner, spec, vector, { ...config, topK: 10 });
        await database.delete(schema.userMemoriesTable).where(eq(schema.userMemoriesTable.id, deleted.id));
        await database.update(schema.userMemoriesTable).set({ content: "corrected" }).where(eq(schema.userMemoriesTable.id, edited.id));
        await database.update(schema.userMemoriesTable).set({ status: "superseded" }).where(eq(schema.userMemoriesTable.id, superseded.id));
        now = new Date(+now + 6000);
        const context = await repo.assemble(owner, query, spec, candidates, config);
        expect(context.memories).toHaveLength(0);
        expect(candidates.some(c => c.id === expiring.id)).toBe(true);
    });

    test("deletion while query embedding is pending is observed, including fact and history deletion", async () => {
        const source = await message("source", 1);
        await memory("delete while embedding", 1, { sourceMessageId: source.id });
        await database.insert(schema.userContextFactsTable).values({ userId: owner, key: "fact", kind: "fact", value: "value", origin: "explicit", sourceMessageId: source.id });
        const result = await service({ spec, embed: async () => {
            await database.delete(schema.chatMessagesTable).where(eq(schema.chatMessagesTable.id, source.id));
            return vector;
        } }).retrieve(owner, query);
        expect(result.facts).toHaveLength(0); expect(result.continuity.messages).toHaveLength(0); expect(result.memories).toHaveLength(0);
    });

    test("provider timeout and vector errors preserve facts and continuity", async () => {
        await database.insert(schema.userContextFactsTable).values({ userId: owner, key: "preference", kind: "preference", value: "tea", origin: "explicit" });
        await message("recent", 1);
        const slow = new ContextRetrievalService(repo, { spec, embed: () => new Promise(() => {}) }, { ...config, timeoutMs: 5 });
        let result = await slow.retrieve(owner, query);
        expect(result.semanticStatus).toBe("unavailable"); expect(result.facts).toHaveLength(1); expect(result.continuity.messages).toHaveLength(1);
        class BrokenSearch extends RetrievalRepository { override async search(): Promise<never> { throw new Error("lookup failed"); } }
        result = await service(undefined, new BrokenSearch(database)).retrieve(owner, query);
        expect(result.semanticStatus).toBe("unavailable"); expect(result.facts).toHaveLength(1); expect(result.continuity.messages).toHaveLength(1);
    });
});

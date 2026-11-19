import { afterAll, afterEach, beforeEach, describe, expect, test } from "bun:test";
import { randomUUID } from "node:crypto";
import { Pool } from "pg";
import { drizzle } from "drizzle-orm/node-postgres";
import { eq, sql } from "drizzle-orm";
import * as schema from "../config/db/schema";
import { EmbeddingRepository } from "./embedding.repository";
import { ContextRepository } from "./context.repository";
import { ContextPolicy } from "../modules/context/context.policy";
import type { EmbeddingJob, EmbeddingModel } from "../modules/context/embedding.contracts";

const suite = process.env.CONTEXT_DB_TEST === "1" ? describe : describe.skip;
suite("Versioned memory embeddings (PostgreSQL)", () => {
    const pool = new Pool({ host: process.env.DB_HOST, port: Number(process.env.DB_PORT || 5432),
        user: process.env.DB_USER, password: process.env.DB_PASSWORD, database: process.env.DB_NAME });
    const database = drizzle(pool, { schema });
    let owner: string, other: string, repo: EmbeddingRepository, now: Date, spec: EmbeddingModel;
    const specFor = (digest: string): EmbeddingModel => ({ id: `embeddinggemma-300m@sha256:${digest}:raw-v1:768`,
        digest, providerModel: "embeddinggemma:300m", dimensions: 768, metric: "cosine", preprocessing: "raw-v1" });
    const vector = [1, ...Array(767).fill(0)];
    const memory = async (extra: Partial<typeof schema.userMemoriesTable.$inferInsert> = {}) => (await database.insert(schema.userMemoriesTable)
        .values({ userId: owner, content: "J’ai obtenu mon diplôme.", origin: "explicit", retention: "long_term", ...extra }).returning())[0]!;
    const result = (job: EmbeddingJob) => {
        const { spec, content, ...identity } = job;
        return { ...identity, status: "success", dimensions: 768, embedding: vector };
    };
    const claim = async (repository = repo) => { const job = await repository.claim(); expect(job).not.toBeNull(); return job!; };
    beforeEach(async () => {
        owner = randomUUID(); other = randomUUID(); now = new Date(Date.now() + 1000);
        spec = specFor("a".repeat(64)); repo = new EmbeddingRepository(spec, database, () => now);
        await database.insert(schema.userTable).values([owner, other].map(id => ({ id, firstName: "Test", lastName: "User",
            email: `${id}@example.test`, password: "test", age: 30 })));
    });
    afterEach(async () => {
        for (const user of [owner, other]) await database.delete(schema.userTable).where(eq(schema.userTable.id, user));
        await database.delete(schema.embeddingModels);
    });
    afterAll(async () => { await pool.end(); });

    test("new readable memories enqueue automatically and repeated results keep one vector", async () => {
        await repo.register(); const saved = await memory();
        const jobs = await Promise.all([repo.claim(), repo.claim()]); expect(jobs.filter(Boolean)).toHaveLength(1);
        const job = jobs.find(Boolean)!; expect(job.content).toBe(saved.content);
        expect(await repo.complete(result(job))).toBe("completed");
        expect(await repo.complete(result(job))).toBe("discarded");
        expect(await repo.listVectors(owner)).toHaveLength(1);
        expect(await repo.listVectors(other)).toHaveLength(0);
        expect((await database.select().from(schema.userMemoriesTable))[0]!.content).toBe(saved.content);
    });

    test("metadata, finite numbers, dimensions, unit norm, and owner are validated", async () => {
        await repo.register(); await memory(); const job = await claim();
        for (const change of [{ dimensions: 3 }, { embedding: [1, 2, 3] }, { embedding: Array(768).fill(0) },
            { embedding: [NaN, ...vector.slice(1)] }, { embedding: [Infinity, ...vector.slice(1)] }]) {
            expect(await repo.complete({ ...result(job), ...change })).toBe("invalid");
        }
        expect(await repo.complete({ ...result(job), userId: other })).toBe("discarded");
        await expect(database.insert(schema.memoryEmbeddingsTable).values({ memoryId: job.memoryId, model: spec.id,
            dimensions: 3, contentRevision: 1, embedding: [1, 0, 0] }).execute()).rejects.toThrow();
        await expect(database.insert(schema.memoryEmbeddingsTable).values({ memoryId: job.memoryId, model: spec.id,
            dimensions: 768, contentRevision: 9, embedding: vector }).execute()).rejects.toThrow();
        await expect(database.insert(schema.memoryEmbeddingsTable).values({ memoryId: job.memoryId, model: spec.id,
            dimensions: 768, contentRevision: 1, embedding: [Infinity, ...vector.slice(1)] }).execute()).rejects.toThrow();
        expect(await repo.complete(result(job))).toBe("completed");
    });

    test("in-place edits invalidate vectors and fence delayed results, including content ABA", async () => {
        await repo.register(); const saved = await memory(); const old = await claim();
        await repo.complete(result(old));
        await database.update(schema.userMemoriesTable).set({ content: "Graduated in 2025" }).where(eq(schema.userMemoriesTable.id, saved.id));
        expect(await repo.listVectors(owner)).toHaveLength(0);
        const changed = await claim(); expect(changed.contentRevision).toBe(2);
        await database.update(schema.userMemoriesTable).set({ content: saved.content }).where(eq(schema.userMemoriesTable.id, saved.id));
        expect(await repo.complete(result(changed))).toBe("discarded");
        expect(await repo.complete(result(old))).toBe("discarded");
        const latest = await claim(); expect(latest.contentRevision).toBe(3);
        expect(await repo.complete(result(latest))).toBe("completed");
        const context = new ContextRepository(owner, database, new ContextPolicy(() => now));
        await expect(context.putEmbedding(saved.id, { model: spec.id, dimensions: 768, contentRevision: 1, embedding: vector })).rejects.toThrow();
    });

    test("superseded/deleted memories, changed ownership, and source deletion cannot receive delayed vectors", async () => {
        await repo.register(); const saved = await memory(); const old = await claim();
        await database.update(schema.userMemoriesTable).set({ status: "superseded" }).where(eq(schema.userMemoriesTable.id, saved.id));
        expect(await repo.complete(result(old))).toBe("discarded");
        const fresh = await memory(); const foreign = await claim();
        await database.update(schema.userMemoriesTable).set({ userId: other }).where(eq(schema.userMemoriesTable.id, fresh.id));
        expect(await repo.complete(result(foreign))).toBe("discarded");
        const changedOwner = await claim(); expect(changedOwner.userId).toBe(other);
        await database.delete(schema.userMemoriesTable).where(eq(schema.userMemoriesTable.id, fresh.id));
        expect(await repo.complete(result(changedOwner))).toBe("discarded");
        const [source] = await database.insert(schema.chatMessagesTable).values({ userId: owner, role: "user", message: "Graduated" }).returning();
        await memory({ sourceMessageId: source!.id }); const sourced = await claim();
        await database.delete(schema.chatMessagesTable).where(eq(schema.chatMessagesTable.id, source!.id));
        expect(await repo.complete(result(sourced))).toBe("discarded");
    });

    test("deletion racing completion cannot leave an orphaned vector", async () => {
        await repo.register(); const saved = await memory(); const job = await claim();
        await Promise.all([repo.complete(result(job)), database.delete(schema.userMemoriesTable).where(eq(schema.userMemoriesTable.id, saved.id))]);
        expect(await database.select().from(schema.memoryEmbeddingsTable)).toHaveLength(0);
        expect(await database.select().from(schema.embeddingJobs)).toHaveLength(0);
    });

    test("future-valid memories wait, and expired vectors are filtered and pruned", async () => {
        await repo.register();
        await memory({ validFrom: new Date(+now + 10000), expiresAt: new Date(+now + 20000) });
        expect(await repo.claim()).toBeNull();
        now = new Date(+now + 10000); const job = await claim(); await repo.complete(result(job));
        expect(await repo.listVectors(owner)).toHaveLength(1);
        now = new Date(+now + 10000);
        expect(await repo.listVectors(owner)).toHaveLength(0);
        expect(await repo.prune()).toBe(1);
        expect(await database.select().from(schema.memoryEmbeddingsTable)).toHaveLength(0);
        await repo.startBackfill(); await repo.backfillBatch(); expect(await repo.claim()).toBeNull();
    });

    test("different immutable model versions coexist and exact cosine operations use one version", async () => {
        await repo.register();
        const second = new EmbeddingRepository(specFor("b".repeat(64)), database, () => now); await second.register();
        await memory(); const one = await claim(), two = await claim(second);
        await repo.complete(result(one)); await second.complete(result(two));
        expect(await database.select().from(schema.memoryEmbeddingsTable)).toHaveLength(2);
        expect((await repo.listVectors(owner)).map(v => v.model)).toEqual([repo.spec.id]);
        expect((await second.listVectors(owner)).map(v => v.model)).toEqual([second.spec.id]);
        const distances = await database.execute(sql`SELECT embedding <=> ${JSON.stringify(vector)}::vector AS distance
            FROM memory_embeddings WHERE model = ${spec.id}`);
        expect(Number(distances.rows[0]!.distance)).toBeCloseTo(0);
        await expect(database.update(schema.embeddingModels).set({ dimensions: 3 }).where(eq(schema.embeddingModels.id, spec.id)).execute()).rejects.toThrow();
    });

    test("backfill resumes a committed cursor, skips inactive memories, and rebuild fences old jobs", async () => {
        for (let i = 0; i < 5; i++) await memory({ status: i === 4 ? "deleted" : "active" });
        await repo.register(); await repo.backfillBatch(2);
        const [progress] = await database.select().from(schema.embeddingBackfills); expect(progress!.afterId).not.toBeNull();
        const restarted = new EmbeddingRepository(spec, database, () => now); await restarted.register();
        while (await restarted.backfillBatch(2)) { /* resume */ }
        expect(await database.select().from(schema.embeddingJobs)).toHaveLength(4);
        const old = await claim(); await repo.complete(result(old));
        await repo.startBackfill(true); while (await repo.backfillBatch(2)) { /* explicit rebuild */ }
        expect(await repo.listVectors(owner)).toHaveLength(0);
        expect(await repo.complete(result(old))).toBe("discarded");
        const rebuilt = await claim(); expect(rebuilt.jobId).not.toBe(old.jobId);
        expect(await repo.complete(result(rebuilt))).toBe("completed");
    });

    test("registration concurrent with memory writes leaves every eligible memory queued", async () => {
        await Promise.all([repo.register(), ...Array.from({ length: 10 }, () => memory())]);
        while (await repo.backfillBatch(2)) { /* rows predating registration are covered by the cursor */ }
        const saved = await database.select().from(schema.userMemoriesTable);
        const queued = await database.select().from(schema.embeddingJobs);
        expect(queued.map(j => j.memoryId).sort()).toEqual(saved.map(m => m.id).sort());
    });

    test("provider/publish failures and abandoned leases retry at most five times; retry is resumable", async () => {
        await repo.register(); await memory();
        await repo.publishNext(async () => { throw new Error("Kafka down"); });
        expect(await repo.claim()).toBeNull(); now = new Date(+now + 500000);
        const second = await claim(); expect(second.attempt).toBe(2);
        const { spec: ignored, content, ...identity } = second;
        expect(await repo.complete({ ...identity, status: "failure", error: "provider_failed" })).toBe("retry");
        expect(await repo.complete({ ...identity, status: "failure", error: "provider_failed" })).toBe("discarded");
        for (let attempt = 3; attempt <= 5; attempt++) { now = new Date(+now + 500000); expect((await claim()).attempt).toBe(attempt); }
        now = new Date(+now + 500000); expect(await repo.claim()).toBeNull();
        expect(await repo.retryFailed()).toBe(1); const retry = await claim(); expect(retry.attempt).toBe(1);
        expect(await repo.complete(result(second))).toBe("discarded");
        expect(await repo.complete(result(retry))).toBe("completed");
    });

    test("vector write and job completion roll back together after a partial failure", async () => {
        await repo.register(); await memory(); const job = await claim();
        await database.execute(sql`ALTER TABLE memory_embedding_jobs ADD CONSTRAINT embedding_test_fail CHECK (status <> 'completed') NOT VALID`);
        try {
            await expect(repo.complete(result(job))).rejects.toThrow();
            expect(await repo.listVectors(owner)).toHaveLength(0);
        } finally { await database.execute(sql`ALTER TABLE memory_embedding_jobs DROP CONSTRAINT embedding_test_fail`); }
        expect(await repo.complete(result(job))).toBe("completed");
    });
});

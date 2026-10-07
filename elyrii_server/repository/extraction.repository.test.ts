import { afterAll, afterEach, beforeEach, describe, expect, test } from "bun:test";
import { randomUUID } from "node:crypto";
import { Pool } from "pg";
import { drizzle } from "drizzle-orm/node-postgres";
import { eq } from "drizzle-orm";
import * as schema from "../config/db/schema";
import ChatRepository from "./chat.repository";
import { ContextRepository } from "./context.repository";
import { ExtractionRepository } from "./extraction.repository";
import { ContextPolicy } from "../modules/context/context.policy";
import { MAX_ATTEMPTS, retryDelay, type ExtractionJob, type Proposal } from "../modules/context/extraction.contracts";

const suite = process.env.CONTEXT_DB_TEST === "1" ? describe : describe.skip;
suite("Asynchronous extraction (PostgreSQL)", () => {
    const pool = new Pool({ host: process.env.DB_HOST, port: Number(process.env.DB_PORT || 5432),
        user: process.env.DB_USER, password: process.env.DB_PASSWORD, database: process.env.DB_NAME });
    const database = drizzle(pool, { schema });
    const chat = new ChatRepository(database);
    let owner: string, other: string, now: Date, repo: ExtractionRepository;
    const source = (message = "I prefer short replies. I graduated.") => chat.createMessage({ userId: owner, conversationId: "a", role: "user", message });
    const fact = (job: ExtractionJob, value = "short"): Proposal => ({
        candidate: { kind: "preference", key: "reply_length", value, origin: "explicit", sourceMessageId: job.sourceMessageId },
        evidence: job.input.source.content, certainty: "certain", category: "stable_preference", temporalExpression: null,
    });
    const memory = (job: ExtractionJob, retention: "short_term" | "long_term" = "long_term"): Proposal => ({
        candidate: { kind: "memory", content: "The user graduated.", retention, eventAt: null, origin: "explicit", sourceMessageId: job.sourceMessageId },
        evidence: job.input.source.content, certainty: "certain", category: retention === "long_term" ? "durable_life_event" : "minor_event", temporalExpression: null,
    });
    const result = (job: ExtractionJob, candidates: Proposal[] = [fact(job)]) => {
        const { input, ...identity } = job;
        return { ...identity, status: "success", output: { promptVersion: "v1", candidates } };
    };
    const claim = async () => { const job = await repo.claim(); expect(job).not.toBeNull(); return job!; };
    const storedJob = async (id: string) => (await database.select().from(schema.extractionJobs).where(eq(schema.extractionJobs.id, id)))[0]!;
    beforeEach(async () => {
        owner = randomUUID(); other = randomUUID(); now = new Date(Date.now() + 1000);
        repo = new ExtractionRepository(database, new ContextPolicy(() => now));
        await database.insert(schema.userTable).values([owner, other].map(id => ({ id, firstName: "Test", lastName: "User",
            email: `${id}@example.test`, password: "test", age: 30, timezone: "Europe/Paris" })));
    });
    afterEach(async () => {
        for (const id of [owner, other]) await database.delete(schema.userTable).where(eq(schema.userTable.id, id));
    });
    afterAll(async () => { await pool.end(); });

    test("message and outbox are atomic; failed persistence and assistant messages enqueue nothing", async () => {
        await expect(chat.createMessage({ userId: owner, role: "user", message: "Rollback" }, "bad-uuid")).rejects.toThrow();
        expect(await chat.getHistory(owner)).toHaveLength(0);
        await expect(chat.createMessage({ userId: randomUUID(), role: "user", message: "No user" })).rejects.toThrow();
        await chat.createMessage({ userId: owner, role: "ai", message: "Hello" });
        expect(await repo.claim()).toBeNull();
        const saved = await source();
        const job = await claim();
        expect(job.sourceMessageId).toBe(saved.id);
        expect(job.input.timezone).toBe("Europe/Paris");
        expect(job.input.context).toEqual([]);
    });

    test("publish outage and crash after lease recover with backoff and fenced attempts", async () => {
        const saved = await source();
        let failedJob: ExtractionJob | undefined;
        await repo.publishNext(async job => { failedJob = job; throw new Error("Kafka down"); });
        expect((await storedJob(failedJob!.jobId)).status).toBe("retry");
        expect(await repo.claim()).toBeNull();
        now = new Date(+now + retryDelay(1));
        const retry = await claim();
        expect(retry.attempt).toBe(2);
        expect(retry.sourceMessageId).toBe(saved.id);
        // Simulate process death after publishing but before receiving a result.
        now = new Date(+now + 500_000);
        const recovered = await claim();
        expect(recovered.attempt).toBe(3);
        expect(await repo.complete(result(retry))).toBe("discarded");
        expect(await repo.complete(result(recovered))).toBe("completed");
        expect(await repo.complete(result(recovered))).toBe("discarded");
    });

    test("outages exhaust a bounded number of attempts without blocking saved chat", async () => {
        await source();
        let job: ExtractionJob | undefined;
        for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
            job = await claim();
            expect(job.attempt).toBe(attempt);
            now = new Date(+now + 500_000);
        }
        expect(await repo.claim()).toBeNull();
        expect((await storedJob(job!.jobId)).status).toBe("failed");
        expect(await chat.getHistory(owner)).toHaveLength(1);
        await source("Normal chat continues");
        expect(await repo.claim()).not.toBeNull();
    });

    test("replayed failure results do not extend backoff; model errors exhaust retries", async () => {
        await source();
        for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
            const job = await claim();
            const { input, ...identity } = job;
            const failure = { ...identity, status: "failure", error: "inference_failed" };
            expect(await repo.complete(failure)).toBe(attempt === MAX_ATTEMPTS ? "failed" : "retry");
            const due = (await storedJob(job.jobId)).nextAttemptAt;
            now = new Date(+now + 1000);
            expect(await repo.complete(failure)).toBe("discarded");
            expect((await storedJob(job.jobId)).nextAttemptAt).toEqual(due);
            now = new Date(+now + 500_000);
        }
        expect(await repo.claim()).toBeNull();
    });

    test("two dispatchers claim a pending job only once", async () => {
        await source();
        const claims = await Promise.all([repo.claim(), repo.claim()]);
        expect(claims.filter(Boolean)).toHaveLength(1);
    });

    test("replay and repeated candidates do not create duplicate active records", async () => {
        await source(); const job = await claim();
        const payload = result(job, [fact(job), fact(job), memory(job), memory(job)]);
        expect(await repo.complete(payload)).toBe("completed");
        expect(await repo.complete(payload)).toBe("discarded");
        await source(); const next = await claim();
        expect(await repo.complete(result(next, [fact(next), memory(next)]))).toBe("completed");
        expect(await database.select().from(schema.userContextFactsTable)).toHaveLength(1);
        expect(await database.select().from(schema.userMemoriesTable)).toHaveLength(1);
        expect(await database.select().from(schema.extractionKeys)).toHaveLength(2);
    });

    test("out-of-order and concurrent fact corrections deterministically keep the newest source", async () => {
        await source(); const old = await claim();
        await source("I prefer long replies."); const newer = await claim();
        await Promise.all([repo.complete(result(newer, [fact(newer, "long")])), repo.complete(result(old))]);
        const rows = await database.select().from(schema.userContextFactsTable);
        expect(rows.filter(r => r.status === "active").map(r => r.value)).toEqual(["long"]);
        await source("I prefer detailed replies."); const latest = await claim();
        await repo.complete(result(latest, [fact(latest, "detailed")]));
        const all = await database.select().from(schema.userContextFactsTable);
        expect(all.filter(r => r.status === "active").map(r => r.value)).toEqual(["detailed"]);
        expect(all.some(r => r.value === "long" && r.status === "superseded")).toBe(true);
    });

    test("partial reconciliation failure rolls back writes and completion for replay", async () => {
        await source(); const job = await claim();
        const failingPolicy = new ContextPolicy(() => now);
        failingPolicy.memoryTimes = () => { throw new Error("Simulated failure after fact insert"); };
        const failing = new ExtractionRepository(database, failingPolicy);
        const payload = result(job, [fact(job), memory(job)]);
        await expect(failing.complete(payload)).rejects.toThrow();
        expect(await database.select().from(schema.userContextFactsTable)).toHaveLength(0);
        expect(await database.select().from(schema.extractionKeys)).toHaveLength(0);
        expect((await storedJob(job.jobId)).status).toBe("awaiting");
        expect(await repo.complete(payload)).toBe("completed");
    });

    test("foreign identity, metadata, invented sources and expiry are never accepted", async () => {
        await source(); const job = await claim();
        for (const change of [{ userId: other }, { conversationId: "other" }, { requestId: randomUUID() }, { sourceMessageId: randomUUID() }]) {
            expect(await repo.complete({ ...result(job), ...change })).toBe("discarded");
        }
        const invalid = memory(job);
        expect(await repo.complete(result(job, [{ ...invalid, candidate: { ...invalid.candidate, expiresAt: "2099-01-01T00:00:00Z" } } as unknown as Proposal]))).toBe("invalid");
        expect((await storedJob(job.jobId)).status).toBe("awaiting");
        const crossUser = fact(job); crossUser.candidate.sourceMessageId = randomUUID();
        expect(await repo.complete(result(job, [fact(job), crossUser]))).toBe("invalid");
        expect(await database.select().from(schema.userContextFactsTable)).toHaveLength(0);
    });

    test("server enforces short-term retention and accepts a valid empty result", async () => {
        await source(); const job = await claim();
        await repo.complete(result(job, [memory(job, "short_term")]));
        const [row] = await database.select().from(schema.userMemoriesTable);
        expect(+row!.expiresAt! - +now).toBe(48 * 60 * 60 * 1000);
        await source(); const empty = await claim();
        expect(await repo.complete(result(empty, []))).toBe("completed");
    });

    test("uncertain proposals are not silently promoted into authoritative storage", async () => {
        await source(); const job = await claim();
        const tentative = fact(job); tentative.certainty = "uncertain";
        expect(await repo.complete(result(job, [tentative]))).toBe("completed");
        expect(await database.select().from(schema.userContextFactsTable)).toHaveLength(0);
    });

    test("deleted source and user discard delayed results", async () => {
        await source(); const job = await claim();
        await database.delete(schema.chatMessagesTable).where(eq(schema.chatMessagesTable.id, job.sourceMessageId));
        expect(await repo.complete(result(job))).toBe("discarded");
        await source(); const another = await claim();
        await database.delete(schema.userTable).where(eq(schema.userTable.id, owner));
        expect(await repo.complete(result(another))).toBe("discarded");
    });

    test("soft/hard forgetting fences pending results, including empty context", async () => {
        for (const soft of [true, false]) {
            await source(); const initial = await claim();
            await repo.complete(result(initial));
            await source(); const late = await claim();
            if (soft) await database.update(schema.userContextFactsTable).set({ status: "deleted" }).where(eq(schema.userContextFactsTable.userId, owner));
            else await database.delete(schema.userContextFactsTable).where(eq(schema.userContextFactsTable.userId, owner));
            expect(await repo.complete(result(late))).toBe("discarded");
        }
        await source(); const empty = await claim();
        await new ContextRepository(owner, database).forgetAll();
        expect(await repo.complete(result(empty))).toBe("discarded");
        await source(); const fresh = await claim();
        expect(await repo.complete(result(fresh))).toBe("completed");
    });

    test("explicit memory corrections fence pending work and invalidate embeddings", async () => {
        await source(); const job = await claim();
        await repo.complete(result(job, [memory(job)]));
        const context = new ContextRepository(owner, database, new ContextPolicy(() => now));
        const [old] = await context.listEligibleMemories();
        await context.putEmbedding(old!.id, { model: "test", dimensions: 3, embedding: [1, 2, 3] });
        const correction = await source("I graduated in 2025, not 2024."); const pendingJob = await claim();
        await context.correctMemory(old!.id, { kind: "memory", content: "Graduated in 2025", origin: "explicit",
            sourceMessageId: correction.id, retention: "long_term" });
        expect(await repo.complete(result(pendingJob, [memory(pendingJob)]))).toBe("discarded");
        expect(await database.select().from(schema.memoryEmbeddingsTable)).toHaveLength(0);
        expect((await context.getMemory(old!.id))?.status).toBe("superseded");
    });
});

import { afterAll, afterEach, beforeEach, describe, expect, test } from "bun:test";
import { randomUUID } from "node:crypto";
import { Pool } from "pg";
import { drizzle } from "drizzle-orm/node-postgres";
import { and, eq, sql } from "drizzle-orm";
import * as schema from "../config/db/schema";
import { EmbeddingRepository } from "./embedding.repository";
import ChatRepository from "./chat.repository";
import JournalRepository from "./journal.repository";
import { JournalExtractionRepository } from "./journal-extraction.repository";
import { ContextLifecycleRepository } from "./context-lifecycle.repository";
import { ContextRepository } from "./context.repository";
import { ContextPolicy } from "../modules/context/context.policy";
import type { JournalJob } from "../modules/context/journal-extraction.contracts";
const suite = process.env.CONTEXT_DB_TEST === "1" ? describe : describe.skip;
suite("Journal extraction PostgreSQL", () => {
    const pool = new Pool({ host: process.env.DB_HOST, port: Number(process.env.DB_PORT || 5432), user: process.env.DB_USER, password: process.env.DB_PASSWORD, database: process.env.DB_NAME });
    const database = drizzle(pool, { schema });
    const journal = new JournalRepository(database);
    let owner: string, now: Date, repo: JournalExtractionRepository;
    const text = "I graduated yesterday.";
    const proposal = () => ({ candidate: { kind: "memory", origin: "explicit", content: text, retention: "long_term", eventAt: null }, field: "body", evidence: text,
        certainty: "certain", subject: "author", assertion: "affirmed", category: "durable_life_event", temporalExpression: "yesterday" });
    const create = (extra = {}) => journal.createEntry({ userId: owner, title: "Journal", content: text, createdAt: new Date(+now - 10000), ...extra });
    const claim = async () => { await repo.enqueuePage({ userId: owner, backfill: true }); return (await repo.claim())!; };
    const response = (job: JournalJob, proposals = [proposal()]) => { const { input, ...identity } = job; return { ...identity, status: "success", output: { promptVersion: "journal-v1", candidates: proposals } }; };
    beforeEach(async () => {
        owner = randomUUID(); now = new Date(Date.now() + 1000);
        await database.insert(schema.userTable).values({ id: owner, firstName: "Test", lastName: "User", email: `${owner}@test.local`, password: "test", age: 30, timezone: "Europe/Paris" });
        repo = new JournalExtractionRepository(database, new ContextPolicy(() => now));
    });
    afterEach(async () => { await database.delete(schema.userTable).where(eq(schema.userTable.id, owner)); });
    afterAll(async () => { await pool.end(); });
    test("disabled history, explicit bounded backfill and duplicate delivery", async () => {
        await create(); await create();
        expect((await repo.enqueuePage()).scanned).toBe(0);
        const first = await repo.enqueuePage({ userId: owner, backfill: true, limit: 1 });
        expect(first.scanned).toBe(1);
        expect((await repo.enqueuePage({ userId: owner, backfill: true, after: first.cursor!, limit: 1 })).scanned).toBe(1);
        const job = (await repo.claim())!;
        expect(await repo.complete(response(job, [proposal(), proposal()]))).toBe("completed");
        expect(await repo.complete(response(job))).toBe("discarded");
        const rows = await database.select().from(schema.userMemoriesTable).where(eq(schema.userMemoriesTable.userId, owner));
        expect(rows).toHaveLength(1); expect(rows[0]!.evidence).toMatchObject({ quote: text, category: "durable_life_event", certainty: "certain", extractorVersion: "journal-v1" });
        expect((await repo.enqueuePage({ userId: owner, backfill: true })).scanned).toBe(0);
    });
    test("start date excludes deployment history; current events enqueue", async () => {
        await create();
        const future = new JournalExtractionRepository(database, undefined, new Date(+now + 3600000));
        expect((await future.enqueuePage()).scanned).toBe(0);
        const enabled = new JournalExtractionRepository(database, undefined, new Date(+now - 60000));
        expect((await enabled.enqueuePage()).scanned).toBe(1);
    });
    test("whole oversized entry rejected, valid tail retained", async () => {
        await create({ content: "x".repeat(24000) + text });
        expect(await claim()).toBeNull();
        const [failed] = await database.select().from(schema.journalExtractionJobs);
        expect(failed!.status).toBe("failed"); expect(failed!.lastError).toBe("invalid_input");
        await create({ content: "x".repeat(20000) + text });
        const job = await claim(); expect(job.input.source.body.endsWith(text)).toBe(true);
        expect(await repo.complete(response(job))).toBe("completed");
    });
    test("partial invalid evidence fails all candidates; foreign identity cannot complete", async () => {
        await create(); const job = await claim();
        expect(await repo.complete({ ...response(job), userId: randomUUID() })).toBe("discarded");
        expect(await repo.complete(response(job, [proposal(), { ...proposal(), evidence: "invented" }]))).toBe("failed");
        expect(await database.select().from(schema.userMemoriesTable).where(eq(schema.userMemoriesTable.userId, owner))).toHaveLength(0);
    });
    test("uncertain, quoted, negated, and other-person assertions are withheld", async () => {
        await create(); const job = await claim();
        expect(await repo.complete(response(job, [{ ...proposal(), certainty: "uncertain" }, { ...proposal(), subject: "other" }, { ...proposal(), assertion: "quoted" }, { ...proposal(), assertion: "negated" }, { ...proposal(), assertion: "hypothetical" }]))).toBe("completed");
        expect(await database.select().from(schema.userMemoriesTable).where(eq(schema.userMemoriesTable.userId, owner))).toHaveLength(0);
    });
    test("edits, deletion and forget-all fence awaiting results", async () => {
        for (const action of ["edit", "delete", "forget"]) {
            const entry = await create(); const job = await claim();
            if (action === "edit") await journal.updateEntryForUser(entry.id, owner, { content: "Changed" });
            if (action === "delete") await journal.softDeleteEntryForUser(entry.id, owner);
            if (action === "forget") await new ContextRepository(owner, database).forgetAll();
            expect(await repo.complete(response(job))).toBe("discarded");
        }
        expect(await database.select().from(schema.userMemoriesTable).where(eq(schema.userMemoriesTable.userId, owner))).toHaveLength(0);
    });
    test("model and publish failures retry with bounded attempts; stale attempts ignored", async () => {
        await create(); let job = await claim();
        const fail = (j: JournalJob) => { const { input, ...identity } = j; return { ...identity, status: "failure", error: "inference_failed" }; };
        for (let n = 1; n <= 5; n++) {
            expect(job.attempt).toBe(n);
            expect(await repo.complete(fail(job))).toBe(n === 5 ? "failed" : "retry");
            if (n < 5) { now = new Date(+now + 400000); const previous = job; job = (await repo.claim())!; expect(await repo.complete(response(previous))).toBe("discarded"); }
        }
        await create(); await repo.enqueuePage({ userId: owner, backfill: true });
        expect(await repo.publishNext(async () => { throw new Error("Kafka down"); })).toBe(true);
        const rows = await database.select().from(schema.journalExtractionJobs).where(eq(schema.journalExtractionJobs.lastError, "publish_failed"));
        expect(rows).toHaveLength(1); expect(rows[0]!.status).toBe("retry");
    });
    test("old emotions never revive after edits", async () => {
        const entry = await create({ content: "I felt sad yesterday.", createdAt: new Date(+now - 3 * 86400000) }); const job = await claim();
        const sad = { ...proposal(), candidate: { ...proposal().candidate, content: "I felt sad yesterday.", retention: "short_term" }, evidence: "I felt sad yesterday.", category: "temporary_emotion" };
        expect(await repo.complete(response(job, [sad]))).toBe("completed");
        expect(await database.select().from(schema.userMemoriesTable).where(eq(schema.userMemoriesTable.userId, owner))).toHaveLength(0);
        await journal.updateEntryForUser(entry.id, owner, { title: "Edited today" });
        expect(await repo.complete(response(await claim(), [sad]))).toBe("completed");
        expect(await database.select().from(schema.userMemoriesTable).where(eq(schema.userMemoriesTable.userId, owner))).toHaveLength(0);
    });
    test("imported calendar-dated emotions do not become fresh observations", async () => {
        await create({ content: "I felt sad on 2020-01-01." });
        const job = await claim();
        const p = { ...proposal(), category: "temporary_emotion", evidence: "I felt sad on 2020-01-01.", temporalExpression: "2020-01-01",
            candidate: { ...proposal().candidate, content: "I felt sad on 2020-01-01.", retention: "short_term" } };
        expect(await repo.complete(response(job, [p]))).toBe("completed");
        expect(await database.select().from(schema.userMemoriesTable).where(eq(schema.userMemoriesTable.userId, owner))).toHaveLength(0);
    });
    test("chat facts and user corrections survive late journal proposals", async () => {
        const chat = await new ChatRepository(database).createMessage({ userId: owner, conversationId: "a", role: "user", message: "I prefer detailed replies" });
        await new ContextRepository(owner, database).createFact({ kind: "preference", key: "reply_length", value: "detailed", origin: "explicit", sourceMessageId: chat.id });
        const entry = await create({ content: "I prefer short answers.", createdAt: new Date(+now - 30 * 86400000) });
        const job = await claim();
        const pref = { candidate: { kind: "preference", key: "reply_length", value: "short", origin: "explicit" }, field: "body", evidence: "I prefer short answers.", certainty: "certain", subject: "author", assertion: "affirmed", category: "stable_preference", temporalExpression: null };
        const raw = response(job, []);
        expect(await repo.complete({ ...raw, output: { ...raw.output, candidates: [pref] } })).toBe("completed");
        const [fact] = await database.select().from(schema.userContextFactsTable).where(eq(schema.userContextFactsTable.userId, owner));
        expect(fact!.value).toBe("detailed");
        await journal.updateEntryForUser(entry.id, owner, { title: "Another revision" });
        const delayed = await claim();
        await new ContextLifecycleRepository(database).correct(owner, "facts", fact!.id, { value: "user correction" });
        const late = response(delayed, []);
        expect(await repo.complete({ ...late, output: { ...late.output, candidates: [pref] } })).toBe("discarded");
        const [corrected] = await database.select().from(schema.userContextFactsTable).where(eq(schema.userContextFactsTable.id, fact!.id));
        expect(corrected!.value).toBe("user correction"); expect(corrected!.evidence).toBeNull();
    });
    test("extracted memories enter embeddings; an edited revision cannot regain a vector", async () => {
        const digest = "c".repeat(64);
        const embeddings = new EmbeddingRepository({ id: `embeddinggemma-300m@sha256:${digest}:raw-v1:768`, digest,
            providerModel: "embeddinggemma:300m", dimensions: 768, metric: "cosine", preprocessing: "raw-v1" }, database, () => now);
        await embeddings.register();
        try {
            const entry = await create(); expect(await repo.complete(response(await claim()))).toBe("completed");
            const job = (await embeddings.claim())!; expect(job).not.toBeNull();
            const { content, spec, ...identity } = job;
            await journal.updateEntryForUser(entry.id, owner, { content: "Corrected journal" });
            expect(await embeddings.complete({ ...identity, status: "success", dimensions: 768, embedding: [1, ...Array(767).fill(0)] })).toBe("discarded");
            expect(await database.select().from(schema.memoryEmbeddingsTable).where(eq(schema.memoryEmbeddingsTable.memoryId, job.memoryId))).toHaveLength(0);
        } finally { await database.delete(schema.embeddingModels); }
    });
    test("candidate insertion and completion roll back together on storage failure", async () => {
        await create(); const job = await claim();
        await database.execute(sql`ALTER TABLE user_memories ADD CONSTRAINT journal_test_failure CHECK (content <> 'I graduated yesterday.') NOT VALID`);
        try { await expect(repo.complete(response(job))).rejects.toThrow(); }
        finally { await database.execute(sql`ALTER TABLE user_memories DROP CONSTRAINT journal_test_failure`); }
        const [event] = await database.select().from(schema.contextSourceEvents).where(eq(schema.contextSourceEvents.id, job.eventId));
        expect(event!.status).toBe("pending");
        expect(await repo.complete(response(job))).toBe("completed");
    });
});

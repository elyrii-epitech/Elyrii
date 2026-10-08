import { afterAll, afterEach, beforeEach, describe, expect, test } from "bun:test";
import { randomUUID } from "node:crypto";
import { Pool } from "pg";
import { drizzle } from "drizzle-orm/node-postgres";
import { and, eq, sql } from "drizzle-orm";
import * as schema from "../config/db/schema";
import { SummaryRepository } from "./summary.repository";
import { ContextRepository } from "./context.repository";
import { type SummaryJob } from "../modules/context/summary.contracts";

const suite = process.env.CONTEXT_DB_TEST === "1" ? describe : describe.skip;
suite("Rolling summaries (PostgreSQL)", () => {
    const pool = new Pool({ host: process.env.DB_HOST, port: Number(process.env.DB_PORT || 5432),
        user: process.env.DB_USER, password: process.env.DB_PASSWORD, database: process.env.DB_NAME });
    const database = drizzle(pool, { schema });
    let owner: string, other: string, repo: SummaryRepository, now: Date;
    const config = { messageThreshold: 3, tokenThreshold: 100, maxInputTokens: 3000, maxOutputTokens: 512, keepRecent: 2, model: "test-model" };
    const taskWhere = () => and(eq(schema.summaryTasks.userId, owner), eq(schema.summaryTasks.conversationId, "a"));
    const rows = async (n: number, userId = owner, conversationId = "a", start = 1) => {
        const messages = Array.from({ length: n }, (_, i) => ({ id: `${(start + i).toString(16).padStart(8, "0")}-1111-4111-8111-111111111111`,
            userId, conversationId, role: i % 2 ? "ai" : "user", message: `Statement ${start + i}`,
            createdAt: new Date("2030-01-01T00:00:00Z") }));
        if (messages.length) await database.insert(schema.chatMessagesTable).values(messages);
        return messages;
    };
    const claim = async () => { const job = await repo.claim(); expect(job).not.toBeNull(); return job!; };
    const result = (job: SummaryJob, through = job.messages.at(-1)!.id) => ({ version: 1, jobId: job.jobId,
        userId: job.userId, conversationId: job.conversationId, revision: job.revision, attempt: job.attempt,
        model: job.model, status: "success", summary: `Summary through ${through}`, throughMessageId: through, outputTokens: 10 });
    beforeEach(async () => {
        owner = randomUUID(); other = randomUUID(); now = new Date("2031-01-01T00:00:00Z");
        repo = new SummaryRepository(database, config, () => now);
        await database.insert(schema.userTable).values([owner, other].map(id => ({ id, firstName: "Test", lastName: "User",
            email: `${id}@example.test`, password: "test", age: 30, timezone: "Europe/Paris" })));
    });
    afterEach(async () => {
        for (const id of [owner, other]) await database.delete(schema.userTable).where(eq(schema.userTable.id, id));
    });
    afterAll(async () => { await pool.end(); });

    test("empty and recent-only histories create no inference job", async () => {
        expect(await repo.claim()).toBeNull();
        expect((await repo.continuity(owner, "a")).messages).toEqual([]);
        await rows(2);
        expect(await repo.claim()).toBeNull();
        expect((await repo.continuity(owner, "a")).summary).toBeNull();
    });

    test("long conversation coverage is contiguous, ordered on ties, and reconstructable", async () => {
        const saved = await rows(130);
        const covered: string[] = [];
        for (let index = 0; index < 2; index++) {
            const job = await claim();
            expect(job.messages).toHaveLength(64);
            expect(job.messages[0]!.id).toBe(saved[index * 64]!.id);
            if (index) expect(job.priorThroughMessageId).toBe(saved[63]!.id);
            covered.push(...job.messages.map(m => m.id));
            expect(await repo.complete(result(job))).toBe("completed");
        }
        expect(await repo.claim()).toBeNull();
        const continuity = await repo.continuity(owner, "a");
        expect(continuity.summary!.throughMessageId).toBe(saved[127]!.id);
        expect([...covered, ...continuity.messages.map(m => m.id)]).toEqual(saved.map(m => m.id));
        expect(new Set(covered).size).toBe(128);
    });

    test("partial tokenizer-limited prefixes are covered once without omitting the suffix", async () => {
        const saved = await rows(10);
        const first = await claim();
        await repo.complete(result(first, saved[2]!.id));
        const second = await claim();
        expect(second.messages.map(m => m.id)).toEqual(saved.slice(3, 8).map(m => m.id));
        expect(second.priorSummary).toBe(`Summary through ${saved[2]!.id}`);
        await repo.complete(result(second));
        expect((await repo.continuity(owner, "a")).messages.map(m => m.id)).toEqual(saved.slice(8).map(m => m.id));
    });

    test("competing dispatchers and duplicate results cannot overlap or move backwards", async () => {
        await rows(10);
        const claimed = await Promise.all([repo.claim(), repo.claim()]);
        expect(claimed.filter(Boolean)).toHaveLength(1);
        const job = claimed.find(Boolean)!;
        const results = await Promise.all([repo.complete(result(job)), repo.complete(result(job))]);
        expect(results.sort()).toEqual(["completed", "discarded"]);
        expect(await repo.complete(result(job, job.messages[0]!.id))).toBe("discarded");
    });

    test("failure after summary insert rolls back both text and boundary for safe replay", async () => {
        await rows(8); const job = await claim();
        await database.execute(sql`ALTER TABLE conversation_summary_tasks ADD CONSTRAINT summary_test_fail_commit CHECK (status <> 'pending') NOT VALID`);
        try {
            await expect(repo.complete(result(job))).rejects.toThrow();
            expect((await repo.continuity(owner, "a")).summary).toBeNull();
            expect((await database.select().from(schema.summaryTasks).where(taskWhere()))[0]!.status).toBe("awaiting");
        } finally {
            await database.execute(sql`ALTER TABLE conversation_summary_tasks DROP CONSTRAINT summary_test_fail_commit`);
        }
        expect(await repo.complete(result(job))).toBe("completed");
    });

    test("foreign user/conversation messages and result identities are excluded", async () => {
        await rows(6);
        await rows(4, other, "a", 100);
        await rows(4, owner, "b", 200);
        let job = await claim();
        while (job.userId !== owner || job.conversationId !== "a") { await repo.complete(result(job)); job = await claim(); }
        expect(job.messages.map(m => m.content)).toEqual(["Statement 1", "Statement 2", "Statement 3", "Statement 4"]);
        expect(await repo.complete({ ...result(job), userId: other })).toBe("discarded");
        expect(await repo.complete({ ...result(job), conversationId: "b" })).toBe("discarded");
        expect(await repo.complete({ ...result(job), throughMessageId: randomUUID() })).toBe("invalid");
        expect(await repo.complete(result(job))).toBe("completed");
    });

    test("editing or deleting an earlier covered source invalidates reads and rebuilds", async () => {
        const saved = await rows(8);
        const first = await claim(); await repo.complete(result(first));
        await database.update(schema.chatMessagesTable).set({ message: "Corrected user statement" }).where(eq(schema.chatMessagesTable.id, saved[0]!.id));
        expect((await repo.continuity(owner, "a")).summary).toBeNull();
        expect(await new ContextRepository(owner, database).getSummary("a")).toBeNull();
        const rebuild = await claim();
        expect(rebuild.priorSummary).toBeNull(); expect(rebuild.messages[0]!.content).toBe("Corrected user statement");
        await repo.complete(result(rebuild));
        await database.delete(schema.chatMessagesTable).where(eq(schema.chatMessagesTable.id, saved[1]!.id));
        expect((await repo.continuity(owner, "a")).summary).toBeNull();
        const next = await claim(); expect(next.messages.map(m => m.id)).not.toContain(saved[1]!.id);
    });

    test("deleted sources, edited in-flight sources, and deleted users discard stale jobs", async () => {
        const saved = await rows(8);
        const first = await claim();
        await database.delete(schema.chatMessagesTable).where(eq(schema.chatMessagesTable.id, saved[0]!.id));
        expect(await repo.complete(result(first))).toBe("discarded");
        const next = await claim();
        await database.update(schema.chatMessagesTable).set({ message: "Edited while running" }).where(eq(schema.chatMessagesTable.id, saved[1]!.id));
        expect(await repo.complete(result(next))).toBe("discarded");
        const last = await claim();
        await database.delete(schema.userTable).where(eq(schema.userTable.id, owner));
        expect(await repo.complete(result(last))).toBe("discarded");
    });

    test("deleting the boundary schedules rebuilding after the summary FK cascade", async () => {
        await rows(8); const job = await claim(); await repo.complete(result(job));
        await database.delete(schema.chatMessagesTable).where(eq(schema.chatMessagesTable.id, job.messages.at(-1)!.id));
        expect((await repo.continuity(owner, "a")).summary).toBeNull();
        const rebuild = await claim();
        expect(rebuild.priorSummary).toBeNull();
        expect(rebuild.messages.map(m => m.id)).not.toContain(job.messages.at(-1)!.id);
    });

    test("late same-timestamp inserts invalidate a covered prefix, while appends are retained", async () => {
        await rows(8, owner, "a", 10);
        const job = await claim();
        await rows(1, owner, "a", 100);
        expect(await repo.complete(result(job))).toBe("completed");
        const tail = await repo.continuity(owner, "a"); expect(tail.messages).toHaveLength(3);
        await rows(1, owner, "a", 1);
        expect((await repo.continuity(owner, "a")).summary).toBeNull();
        const rebuild = await claim(); expect(rebuild.messages[0]!.content).toBe("Statement 1");
        await rows(1, owner, "a", 2);
        expect(await repo.complete(result(rebuild))).toBe("discarded");
    });

    test("inference failure and expired leases retry safely with a finite bound", async () => {
        await rows(8);
        const first = await claim();
        const failure = { ...result(first), status: "failure", error: "inference_failed" };
        delete (failure as any).summary; delete (failure as any).throughMessageId; delete (failure as any).outputTokens;
        expect(await repo.complete(failure)).toBe("retry");
        expect(await repo.complete(failure)).toBe("discarded");
        expect(await repo.claim()).toBeNull();
        now = new Date(+now + 500000);
        const retry = await claim(); expect(retry.jobId).toBe(first.jobId); expect(retry.messages).toEqual(first.messages);
        expect(await repo.complete(result(first))).toBe("discarded");
        for (let attempt = 3; attempt <= 5; attempt++) {
            now = new Date(+now + 500000); expect((await claim()).attempt).toBe(attempt);
        }
        now = new Date(+now + 500000); expect(await repo.claim()).toBeNull();
        expect((await database.select().from(schema.summaryTasks).where(taskWhere()))[0]!.status).toBe("failed");
        expect((await repo.continuity(owner, "a")).messages).toHaveLength(8);
    });

    test("publish failure and below-threshold skip never advance coverage", async () => {
        await rows(8);
        await repo.publishNext(async () => { throw new Error("Kafka down"); });
        now = new Date(+now + 500000); const job = await claim();
        const { summary, throughMessageId, outputTokens, ...identity } = result(job);
        expect(await repo.complete({ ...identity, status: "skipped" })).toBe("skipped");
        expect((await repo.continuity(owner, "a")).summary).toBeNull();
        expect(await repo.claim()).toBeNull();
        await rows(1, owner, "a", 100);
        expect(await repo.claim()).not.toBeNull();
    });

    test("tail pagination is stable and detects a changed summary revision", async () => {
        const saved = await rows(8);
        const page = await repo.continuity(owner, "a", 3);
        const next = await repo.continuity(owner, "a", 3, page.nextCursor!);
        expect([...page.messages, ...next.messages].map(m => m.id)).toEqual(saved.slice(0, 6).map(m => m.id));
        const job = await claim(); await repo.complete(result(job));
        await expect(repo.continuity(owner, "a", 3, page.nextCursor!)).rejects.toThrow();
    });

    test("pagination detects late inserts in the uncovered tail", async () => {
        await rows(8, owner, "a", 10);
        const page = await repo.continuity(owner, "a", 3);
        await rows(1, owner, "a", 1);
        await expect(repo.continuity(owner, "a", 3, page.nextCursor!)).rejects.toThrow();
    });

    test("forgetting fences pending summaries even before the first summary is saved", async () => {
        await rows(8); const job = await claim();
        await new ContextRepository(owner, database).forgetAll();
        expect(await repo.complete(result(job))).toBe("discarded");
        expect(await repo.claim()).toBeNull();
    });
});

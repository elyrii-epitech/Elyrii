import { afterAll, afterEach, beforeEach, describe, expect, test } from "bun:test";
import { randomUUID } from "node:crypto";
import { Pool } from "pg";
import { drizzle } from "drizzle-orm/node-postgres";
import { eq } from "drizzle-orm";
import * as schema from "../config/db/schema";
import { ContextRepository } from "./context.repository";
import { ContextPolicy } from "../modules/context/context.policy";
import type { FactCandidate, MemoryCandidate } from "../modules/context/context.candidates";

// The Docker runner explicitly opts in and supplies an isolated database.
const suite = process.env.CONTEXT_DB_TEST === "1" ? describe : describe.skip;
suite("Context repository (PostgreSQL)", () => {
    const pool = new Pool({ host: process.env.DB_HOST, port: Number(process.env.DB_PORT || 5432),
        user: process.env.DB_USER, password: process.env.DB_PASSWORD, database: process.env.DB_NAME });
    const database = drizzle(pool, { schema });
    let owner: string, other: string, source: string, foreignSource: string, assistantSource: string;
    let time: Date, repo: ContextRepository, otherRepo: ContextRepository;
    const fact = (extra: Partial<FactCandidate> = {}): FactCandidate => ({ kind: "preference", key: "reply_style",
        value: "short", origin: "explicit", sourceMessageId: source, ...extra });
    const memory = (extra: Partial<MemoryCandidate> = {}): MemoryCandidate => ({ kind: "memory", content: "Graduated",
        retention: "long_term", origin: "explicit", sourceMessageId: source, ...extra });
    const vector = { model: "test-v1", dimensions: 3, embedding: [1, 2, 3] };
    beforeEach(async () => {
        owner = randomUUID(); other = randomUUID(); source = randomUUID(); foreignSource = randomUUID(); assistantSource = randomUUID();
        time = new Date("2030-01-01T00:00:00Z");
        repo = new ContextRepository(owner, database, new ContextPolicy(() => time));
        otherRepo = new ContextRepository(other, database, new ContextPolicy(() => time));
        await database.insert(schema.userTable).values([owner, other].map(id => ({ id, firstName: "Test", lastName: "User",
            email: `${id}@example.test`, password: "test", age: 30 })));
        await database.insert(schema.chatMessagesTable).values([
            { id: source, userId: owner, conversationId: "a", role: "user", message: "Graduated", createdAt: time },
            { id: foreignSource, userId: other, conversationId: "a", role: "user", message: "Private", createdAt: time },
            { id: assistantSource, userId: owner, conversationId: "a", role: "ai", message: "Congrats", createdAt: time },
        ]);
    });
    afterEach(async () => {
        for (const user of [owner, other]) await database.delete(schema.userTable).where(eq(schema.userTable.id, user));
    });
    afterAll(async () => { await pool.end(); });

    test("isolates every context layer and rejects foreign/non-user provenance", async () => {
        const f = await repo.createFact(fact());
        const m = await repo.createMemory(memory());
        await repo.putEmbedding(m.id, vector);
        await repo.putSummary({ conversationId: "a", summary: "Graduated", throughMessageId: source });
        expect(await otherRepo.getFact(f.id)).toBeNull();
        expect(await otherRepo.getMemory(m.id)).toBeNull();
        expect(await otherRepo.listEligibleFacts()).toEqual([]);
        expect(await otherRepo.listEligibleMemories()).toEqual([]);
        expect(await otherRepo.getEmbeddings(m.id)).toEqual([]);
        expect(await otherRepo.getSummary("a")).toBeNull();
        expect(await repo.getSummary("b")).toBeNull();
        for (const badSource of [foreignSource, assistantSource]) {
            await expect(repo.createFact(fact({ key: "bad", sourceMessageId: badSource }))).rejects.toThrow();
            await expect(repo.createMemory(memory({ sourceMessageId: badSource }))).rejects.toThrow();
        }
        await expect(otherRepo.replaceFact(f.id, fact({ sourceMessageId: foreignSource }))).rejects.toThrow();
        await expect(otherRepo.correctMemory(m.id, memory({ sourceMessageId: foreignSource }))).rejects.toThrow();
        await expect(otherRepo.putEmbedding(m.id, vector)).rejects.toThrow();
        await expect(repo.putSummary({ conversationId: "b", summary: "Wrong conversation", throughMessageId: source })).rejects.toThrow();
        await expect(otherRepo.putSummary({ conversationId: "a", summary: "Wrong user", throughMessageId: source })).rejects.toThrow();
        expect((await repo.getEmbeddings(m.id))[0]?.embedding).toEqual([1, 2, 3]);
    });
    test("eligibility uses inclusive start, exclusive validity end and expiry", async () => {
        const start = new Date(+time + 1000).toISOString(), end = new Date(+time + 2000).toISOString();
        const f = await repo.createFact(fact({ validFrom: start, validUntil: end }));
        const m = await repo.createMemory(memory({ validFrom: start, validUntil: end }));
        const durable = await repo.createMemory(memory({ content: "Durable" }));
        const temporary = await repo.createMemory(memory({ retention: "short_term" }));
        const expiringLong = await repo.createMemory(memory({ expiresAt: end }));
        expect((await repo.listEligibleFacts()).length).toBe(0);
        expect((await repo.listEligibleMemories()).map(r => r.id)).not.toContain(m.id);
        time = new Date(start);
        expect((await repo.listEligibleFacts()).map(r => r.id)).toEqual([f.id]);
        expect((await repo.listEligibleMemories()).map(r => r.id)).toContain(m.id);
        await repo.putEmbedding(expiringLong.id, vector);
        time = new Date(end);
        expect(await repo.listEligibleFacts()).toEqual([]);
        expect((await repo.listEligibleMemories()).map(r => r.id)).not.toContain(m.id);
        expect((await repo.listEligibleMemories()).map(r => r.id)).not.toContain(expiringLong.id);
        expect(await repo.getEmbeddings(expiringLong.id)).toEqual([]);
        time = new Date(temporary.expiresAt!);
        expect((await repo.listEligibleMemories()).map(r => r.id)).toEqual([durable.id]);
        await expect(repo.putEmbedding(temporary.id, vector)).rejects.toThrow();
    });
    test("fact replacement preserves history, rolls back failures, and detects stale concurrent writes", async () => {
        const original = await repo.createFact(fact());
        await expect(repo.replaceFact(original.id, fact({ validUntil: time.toISOString() }))).rejects.toThrow();
        expect((await repo.getFact(original.id))?.status).toBe("active");
        const results = await Promise.allSettled([repo.replaceFact(original.id, fact({ value: "long" })),
            repo.replaceFact(original.id, fact({ value: "concise" }))]);
        expect(results.filter(r => r.status === "fulfilled")).toHaveLength(1);
        expect((await repo.getFact(original.id))?.status).toBe("superseded");
        expect(await repo.listEligibleFacts()).toHaveLength(1);
        const creates = await Promise.allSettled([repo.createFact(fact({ key: "new" })), repo.createFact(fact({ key: "new" }))]);
        expect(creates.filter(r => r.status === "fulfilled")).toHaveLength(1);
    });
    test("memory correction removes stale vectors atomically and rejects old jobs", async () => {
        const old = await repo.createMemory(memory());
        await repo.putEmbedding(old.id, vector);
        await expect(repo.correctMemory(old.id, memory({ sourceMessageId: foreignSource }))).rejects.toThrow();
        expect((await repo.getMemory(old.id))?.status).toBe("active");
        expect(await repo.getEmbeddings(old.id)).toHaveLength(1);
        const corrected = await repo.correctMemory(old.id, memory({ content: "Graduating next year" }));
        expect(corrected.id).not.toBe(old.id);
        expect((await repo.getMemory(old.id))?.status).toBe("superseded");
        expect(await database.select().from(schema.memoryEmbeddingsTable).where(eq(schema.memoryEmbeddingsTable.memoryId, old.id))).toEqual([]);
        await expect(repo.putEmbedding(old.id, vector)).rejects.toThrow();
        await expect(repo.correctMemory(old.id, memory())).rejects.toThrow();
        await repo.putEmbedding(corrected.id, vector);
        expect(await repo.getEmbeddings(corrected.id)).toHaveLength(1);
        await expect(repo.putEmbedding(corrected.id, { ...vector, dimensions: 4 })).rejects.toThrow();
    });
    test("correction racing an embedding write cannot leave the old vector", async () => {
        const old = await repo.createMemory(memory());
        const results = await Promise.allSettled([repo.putEmbedding(old.id, vector), repo.correctMemory(old.id, memory({ content: "Corrected" }))]);
        expect(results[1]?.status).toBe("fulfilled");
        expect(await database.select().from(schema.memoryEmbeddingsTable).where(eq(schema.memoryEmbeddingsTable.memoryId, old.id))).toEqual([]);
    });
    test("inactive states are excluded and source deletion removes dependent context", async () => {
        const f = await repo.createFact(fact());
        const m = await repo.createMemory(memory());
        await repo.putEmbedding(m.id, vector);
        await database.update(schema.userContextFactsTable).set({ status: "deleted" }).where(eq(schema.userContextFactsTable.id, f.id));
        await database.update(schema.userMemoriesTable).set({ status: "deleted" }).where(eq(schema.userMemoriesTable.id, m.id));
        expect(await repo.listEligibleFacts()).toEqual([]);
        expect(await repo.listEligibleMemories()).toEqual([]);
        expect(await repo.getEmbeddings(m.id)).toEqual([]);
        await repo.putSummary({ conversationId: "a", summary: "Summary", throughMessageId: source });
        await database.delete(schema.chatMessagesTable).where(eq(schema.chatMessagesTable.id, source));
        expect(await repo.getFact(f.id)).toBeNull();
        expect(await repo.getMemory(m.id)).toBeNull();
        expect(await repo.getSummary("a")).toBeNull();
    });
    test("message ties have stable ordering and summaries remain conversation-scoped", async () => {
        const rows = await repo.getRecentMessages("a");
        expect(rows.map(r => r.id)).toEqual([source, assistantSource].sort());
        expect((await repo.getRecentMessages("a", 1)).map(r => r.id)).toEqual([source, assistantSource].sort().slice(-1));
        expect(await repo.getRecentMessages("b")).toEqual([]);
        await repo.putSummary({ conversationId: "a", summary: "Initial", throughMessageId: source });
        await repo.putSummary({ conversationId: "a", summary: "Updated", throughMessageId: assistantSource });
        expect((await repo.getSummary("a"))?.summary).toBe("Updated");
    });
});

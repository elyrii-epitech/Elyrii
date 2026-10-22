import { afterAll, afterEach, beforeEach, describe, expect, test } from "bun:test";
import { randomUUID } from "node:crypto";
import { Pool } from "pg";
import { drizzle } from "drizzle-orm/node-postgres";
import { and, eq, sql } from "drizzle-orm";
import * as schema from "../config/db/schema";
import JournalRepository from "./journal.repository";
import ChatRepository from "./chat.repository";
import { ContextSourceRepository } from "./context-source.repository";
import { ContextLifecycleRepository } from "./context-lifecycle.repository";
import { ContextRepository } from "./context.repository";
import { ExtractionRepository } from "./extraction.repository";
import { ContextPolicy } from "../modules/context/context.policy";
import { RetrievalRepository } from "./retrieval.repository";
import { retrievalConfigSchema } from "../modules/context/retrieval.contracts";
import { sourceResultSchema, type SourceResult } from "../modules/context/source.contracts";
import { EmbeddingRepository } from "./embedding.repository";

const suite = process.env.CONTEXT_DB_TEST === "1" ? describe : describe.skip;
suite("Journal source foundation (PostgreSQL)", () => {
    const pool = new Pool({ host: process.env.DB_HOST, port: Number(process.env.DB_PORT || 5432), user: process.env.DB_USER,
        password: process.env.DB_PASSWORD, database: process.env.DB_NAME });
    const database = drizzle(pool, { schema });
    const journal = new JournalRepository(database);
    let owner: string, other: string, now: Date, storage: ContextSourceRepository, lifecycle: ContextLifecycleRepository;
    const memory = { kind: "memory" as const, origin: "explicit" as const, content: "Graduated in Paris", retention: "long_term" as const, eventAt: null };
    const fact = { kind: "preference" as const, origin: "explicit" as const, key: "reply_length", value: "brief" };
    const create = (extra = {}) => journal.createEntry({ userId: owner, title: "My entry", content: "Graduated in Paris", createdAt: new Date(+now - 10000), ...extra });
    const result = async (id: string, candidates: SourceResult["candidates"] = [memory, fact]): Promise<SourceResult> => {
        const [entry] = await database.select().from(schema.journalEntriesTable).where(eq(schema.journalEntriesTable.id, id));
        const [event] = await database.select().from(schema.contextSourceEvents).where(and(eq(schema.contextSourceEvents.sourceId, id),
            eq(schema.contextSourceEvents.revision, entry!.contextRevision), sql`"change" IN ('created', 'updated')`));
        return { version: 2, eventId: event!.id, userId: owner, generation: event!.generation,
            source: { kind: "journal", id, revision: entry!.contextRevision }, candidates };
    };
    beforeEach(async () => {
        owner = randomUUID(); other = randomUUID(); now = new Date(Date.now() + 1000);
        storage = new ContextSourceRepository(database, new ContextPolicy(() => now));
        lifecycle = new ContextLifecycleRepository(database, () => now);
        await database.insert(schema.userTable).values([owner, other].map(id => ({ id, firstName: "Test", lastName: "User", email: `${id}@test.local`, password: "test", age: 30 })));
    });
    afterEach(async () => {
        for (const id of [owner, other]) await database.delete(schema.userTable).where(eq(schema.userTable.id, id));
        await database.delete(schema.embeddingModels);
    });
    afterAll(async () => { await pool.end(); });

    test("real owner-scoped version FKs reject missing, foreign, partial and mismatched references", async () => {
        const entry = await create();
        const row = { userId: owner, ...memory, sourceKind: "journal" as const, sourceId: entry.id, sourceRevision: 1 };
        await database.insert(schema.userMemoriesTable).values(row);
        for (const override of [{ userId: other }, { sourceId: randomUUID() }, { sourceRevision: 2 }, { sourceKind: null }, { sourceId: null },
            { sourceMessageId: randomUUID() }]) {
            await expect(database.insert(schema.userMemoriesTable).values({ ...row, ...override }).execute()).rejects.toThrow();
        }
        await expect(database.insert(schema.contextSourceVersions).values({ userId: owner, kind: "journal", sourceId: entry.id,
            journalEntryId: entry.id, revision: 99, sourceCreatedAt: entry.createdAt }).execute()).rejects.toThrow();
        const manual = await database.insert(schema.userMemoriesTable).values({ userId: owner, ...memory }).returning();
        expect(manual[0]!.sourceKind).toBeNull();
    });

    test("create/edit hooks are atomic, context-only, and serialize concurrent no-op updates", async () => {
        const id = randomUUID();
        await expect(database.transaction(async tx => { await tx.insert(schema.journalEntriesTable).values({ id, userId: owner, title: "Rollback" }); throw new Error("rollback"); })).rejects.toThrow();
        expect(await database.select().from(schema.contextSourceEvents).where(eq(schema.contextSourceEvents.sourceId, id))).toHaveLength(0);
        const entry = await create();
        await journal.updateEntryWithRelationsForUser(entry.id, owner, {}, ["personal"]);
        expect(await database.select().from(schema.contextSourceEvents).where(eq(schema.contextSourceEvents.sourceId, entry.id))).toHaveLength(1);
        await Promise.all([journal.updateEntryForUser(entry.id, owner, { title: "Changed" }), journal.updateEntryForUser(entry.id, owner, { title: "Changed" })]);
        expect((await journal.getEntryByIdForUser(entry.id, owner))!.contextRevision).toBe(2);
        await Promise.all([journal.updateEntryForUser(entry.id, owner, { content: "Changed content" }), journal.updateEntryForUser(entry.id, owner, { mood: "happy" })]);
        const current = (await journal.getEntryByIdForUser(entry.id, owner))!;
        expect(current).toMatchObject({ contextRevision: 4, content: "Changed content", mood: "happy" });
        expect(await database.select().from(schema.contextSourceEvents).where(eq(schema.contextSourceEvents.sourceId, entry.id))).toHaveLength(4);
        await expect(journal.updateEntryForUser(entry.id, other, { title: "Foreign" })).rejects.toThrow();
    });

    test("v2 delivery is idempotent and inspection includes typed provenance without journal recall", async () => {
        const entry = await create(); const payload = await result(entry.id);
        expect(await Promise.all([storage.apply(payload), storage.apply(payload)])).toEqual(["completed", "completed"]);
        const inspected = await lifecycle.list(owner, "memories", {});
        expect(inspected.items).toHaveLength(1);
        expect(inspected.items[0]!.source).toEqual(payload.source);
        expect(inspected.items[0]!.sourceMessageId).toBeNull();
        expect((await lifecycle.list(other, "memories", {})).items).toHaveLength(0);
        const retrieved = await new RetrievalRepository(database, () => now).assemble(owner, { conversationId: "a", query: "Hi" }, undefined, [], retrievalConfigSchema.parse({}));
        expect(retrieved.facts).toHaveLength(0); expect(retrieved.memories).toHaveLength(0); expect(retrieved.continuity.summary).toBeNull();
    });

    test("editing and soft deletion invalidate derived rows and reject delayed extraction", async () => {
        const entry = await create(); const old = await result(entry.id);
        expect(await storage.apply(old)).toBe("completed");
        await journal.updateEntryForUser(entry.id, owner, { content: "Corrected event" });
        expect(await new ContextRepository(owner, database, new ContextPolicy(() => now)).listEligibleFacts()).toHaveLength(0);
        expect(await new ContextRepository(owner, database, new ContextPolicy(() => now)).listEligibleMemories()).toHaveLength(0);
        expect(await storage.apply(old)).toBe("discarded");
        const fresh = await result(entry.id);
        expect(await storage.apply(fresh)).toBe("completed");
        await journal.softDeleteEntryForUser(entry.id, owner);
        expect(await storage.apply(fresh)).toBe("discarded");
        expect(await new ContextRepository(owner, database, new ContextPolicy(() => now)).listEligibleMemories()).toHaveLength(0);
        expect(await database.select().from(schema.contextSourceEvents).where(and(eq(schema.contextSourceEvents.sourceId, entry.id), eq(schema.contextSourceEvents.change, "deleted")))).toHaveLength(1);
    });

    test("obsolete embedding results cannot attach after a journal edit", async () => {
        const digest = "9".repeat(64);
        const spec = { id: `embeddinggemma-300m@sha256:${digest}:raw-v1:768`, digest, providerModel: "embeddinggemma:300m" as const,
            dimensions: 768 as const, metric: "cosine" as const, preprocessing: "raw-v1" as const };
        const embeddings = new EmbeddingRepository(spec, database, () => now);
        await embeddings.register();
        const entry = await create(); await storage.apply(await result(entry.id, [memory, { ...memory, content: "Another event" }]));
        const job = (await embeddings.claim())!; expect(job).not.toBeNull();
        const { spec: _, content, ...identity } = job;
        const completed = { ...identity, status: "success", dimensions: 768, embedding: [1, ...Array(767).fill(0)] };
        expect(await embeddings.complete(completed)).toBe("completed");
        const lateJob = (await embeddings.claim())!; expect(lateJob).not.toBeNull();
        const { spec: lateSpec, content: lateContent, ...lateIdentity } = lateJob;
        await journal.updateEntryForUser(entry.id, owner, { title: "Revised title" });
        expect(await database.select().from(schema.memoryEmbeddingsTable).where(eq(schema.memoryEmbeddingsTable.memoryId, job.memoryId))).toHaveLength(0);
        expect(await embeddings.complete({ ...completed, ...lateIdentity })).toBe("discarded");
    });

    test("forgetting retains text but excludes the source through edits and future processing", async () => {
        const entry = await create(); const old = await result(entry.id); await storage.apply(old);
        const [stored] = await database.select().from(schema.userMemoriesTable).where(eq(schema.userMemoriesTable.userId, owner));
        await lifecycle.forget(owner, "memories", stored!.id);
        expect((await journal.getEntryByIdForUser(entry.id, owner))!.contextSuppressed).toBe(true);
        expect(await storage.apply(old)).toBe("discarded");
        await journal.updateEntryForUser(entry.id, owner, { content: "Still retained" });
        expect(await storage.apply(await result(entry.id))).toBe("discarded");
        await database.update(schema.journalEntriesTable).set({ contextSuppressed: false }).where(eq(schema.journalEntriesTable.id, entry.id));
        expect((await journal.getEntryByIdForUser(entry.id, owner))!.contextSuppressed).toBe(true);
        expect(await new ContextRepository(owner, database, new ContextPolicy(() => now)).listEligibleFacts()).toHaveLength(0);
    });

    test("explicit correction and newer facts are never replaced by older journal evidence", async () => {
        const chat = await new ChatRepository(database).createMessage({ userId: owner, conversationId: "a", role: "user", message: "I prefer detailed replies" });
        await new ContextRepository(owner, database, new ContextPolicy(() => now)).createFact({ kind: "preference", key: "reply_length", value: "detailed", origin: "explicit", sourceMessageId: chat.id });
        const old = await create({ createdAt: new Date(+now - 30 * 86400000) });
        await storage.apply(await result(old.id));
        const [current] = await new ContextRepository(owner, database, new ContextPolicy(() => now)).listEligibleFacts(); expect(current!.value).toBe("detailed");
        const another = await create(); await storage.apply(await result(another.id, [{ ...fact, key: "other" }]));
        const [target] = await database.select().from(schema.userContextFactsTable).where(eq(schema.userContextFactsTable.key, "other"));
        await lifecycle.correct(owner, "facts", target!.id, { value: "manual correction" });
        expect((await lifecycle.list(owner, "facts", {})).items.find(f => f.id === target!.id)).toMatchObject({ value: "manual correction", source: { kind: "journal" } });
        expect((await journal.getEntryByIdForUser(another.id, owner))!.contextSuppressed).toBe(true);
    });

    test("delayed emotional evidence expires from source/event time, including after edits", async () => {
        const old = await create({ createdAt: new Date(+now - 48 * 3600000) });
        const emotion = { ...memory, content: "Monday sadness", retention: "short_term" as const };
        expect(await storage.apply(await result(old.id, [emotion]))).toBe("completed");
        expect(await new ContextRepository(owner, database, new ContextPolicy(() => now)).listEligibleMemories()).toHaveLength(0);
        await journal.updateEntryForUser(old.id, owner, { content: "Edited Monday sadness" });
        await storage.apply(await result(old.id, [emotion]));
        expect(await new ContextRepository(owner, database, new ContextPolicy(() => now)).listEligibleMemories()).toHaveLength(0);
        const recent = await create({ createdAt: new Date(+now - 47.5 * 3600000) });
        await storage.apply(await result(recent.id, [emotion]));
        const [active] = await new ContextRepository(owner, database, new ContextPolicy(() => now)).listEligibleMemories();
        expect(+active!.expiresAt! - +now).toBe(30 * 60000);
        now = new Date(+now + 3600000);
        expect(await lifecycle.cleanup()).toBe(1);
        expect((await journal.getEntryByIdForUser(recent.id, owner))!.contextSuppressed).toBe(true);
    });

    test("forget-all fences even empty sources; chat v1 results are fenced by revision", async () => {
        const entry = await create(); const delayed = await result(entry.id);
        await lifecycle.forgetAll(owner); expect(await storage.apply(delayed)).toBe("discarded");
        const chat = await new ChatRepository(database).createMessage({ userId: owner, conversationId: "a", role: "user", message: "Old message" });
        const extraction = new ExtractionRepository(database, new ContextPolicy(() => now));
        const job = (await extraction.claim())!; expect(job).not.toBeNull();
        await database.update(schema.chatMessagesTable).set({ message: "Edited message" }).where(eq(schema.chatMessagesTable.id, chat.id));
        const { input, ...identity } = job;
        expect(await extraction.complete({ ...identity, status: "success", output: { promptVersion: "v1", candidates: [] } })).toBe("discarded");
    });

    test("edit racing a result cannot leave stale active context", async () => {
        const entry = await create(); const delayed = await result(entry.id);
        await Promise.all([storage.apply(delayed), journal.updateEntryForUser(entry.id, owner, { content: "Changed during inference" })]);
        expect(await new ContextRepository(owner, database, new ContextPolicy(() => now)).listEligibleMemories()).toHaveLength(0);
        expect(await storage.apply(delayed)).toBe("discarded");
    });

    test("source event and all derived writes commit atomically", async () => {
        const entry = await create(); const payload = await result(entry.id, [fact, memory]);
        await database.execute(sql`ALTER TABLE user_memories ADD CONSTRAINT source_test_fail CHECK (content <> 'Graduated in Paris') NOT VALID`);
        try { await expect(storage.apply(payload)).rejects.toThrow(); }
        finally { await database.execute(sql`ALTER TABLE user_memories DROP CONSTRAINT source_test_fail`); }
        expect(await database.select().from(schema.userContextFactsTable).where(eq(schema.userContextFactsTable.userId, owner))).toHaveLength(0);
        const [event] = await database.select().from(schema.contextSourceEvents).where(eq(schema.contextSourceEvents.id, payload.eventId));
        expect(event!.status).toBe("pending");
        expect(await storage.apply(payload)).toBe("completed");
    });

    test("strict v2 schema rejects fake conversations and caller-selected lifetimes", () => {
        const payload = { version: 2, eventId: randomUUID(), userId: owner, generation: 0, source: { kind: "journal", id: randomUUID(), revision: 1 }, candidates: [memory] };
        expect(sourceResultSchema.safeParse(payload).success).toBe(true);
        expect(sourceResultSchema.safeParse({ ...payload, conversationId: "invented" }).success).toBe(false);
        expect(sourceResultSchema.safeParse({ ...payload, candidates: [{ ...memory, expiresAt: now.toISOString() }] }).success).toBe(false);
    });
});

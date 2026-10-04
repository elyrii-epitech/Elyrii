import { and, asc, desc, eq } from "drizzle-orm";
import { z } from "zod";
import { db } from "../config/db.config";
import { userTable } from "../config/db/user.table";
import { chatMessagesTable as messages } from "../config/db/chat.table";
import { userContextFactsTable as facts, userMemoriesTable as memories,
    conversationSummariesTable as summaries, memoryEmbeddingsTable as embeddings } from "../config/db/context.table";
import { factCandidateSchema, memoryCandidateSchema, summaryInputSchema, embeddingInputSchema,
    type FactCandidate, type MemoryCandidate, type SummaryInput, type EmbeddingInput } from "../modules/context/context.candidates";
import { ContextPolicy } from "../modules/context/context.policy";

type Database = typeof db;
type Transaction = Parameters<Parameters<Database["transaction"]>[0]>[0];
export class ContextConflictError extends Error {}
export class ContextAccessError extends Error {}
const id = (value: string) => z.uuid().parse(value);
const limitSchema = z.number().int().min(1).max(200);

/** Construct only from authenticated identity or a validated internal job.
 * Candidate payloads cannot supply ownership. Missing and foreign IDs look alike.
 */
export class ContextRepository {
    private readonly userId: string;
    constructor(trustedUserId: string, private readonly database: Database = db,
        private readonly policy = new ContextPolicy()) {
        this.userId = id(trustedUserId);
    }
    private async source(tx: Transaction, messageId: string) {
        const [source] = await tx.select({ id: messages.id }).from(messages).where(and(
            eq(messages.id, messageId), eq(messages.userId, this.userId), eq(messages.role, "user"),
        )).for("key share");
        if (!source) throw new ContextAccessError("Source message is unavailable");
    }
    private async lockUser(tx: Transaction) {
        // Serializes fact writes, including the no-current-fact case.
        const [user] = await tx.select({ id: userTable.id }).from(userTable)
            .where(eq(userTable.id, this.userId)).for("update");
        if (!user) throw new ContextAccessError("Context owner is unavailable");
    }
    async getFact(factId: string) {
        const [row] = await this.database.select().from(facts).where(and(eq(facts.id, id(factId)), eq(facts.userId, this.userId)));
        return row ?? null;
    }
    async listEligibleFacts(limit = 100) {
        return this.database.select().from(facts).where(this.policy.factsEligible(this.userId))
            .orderBy(asc(facts.key), asc(facts.id)).limit(limitSchema.parse(limit));
    }
    async createFact(candidate: FactCandidate) {
        return this.writeFact(candidate);
    }
    async replaceFact(expectedFactId: string, candidate: FactCandidate) {
        return this.writeFact(candidate, id(expectedFactId));
    }
    private async writeFact(candidate: FactCandidate, expectedFactId?: string) {
        const input = factCandidateSchema.parse(candidate);
        return this.database.transaction(async tx => {
            await this.lockUser(tx);
            await this.source(tx, input.sourceMessageId);
            const now = this.policy.now();
            const [current] = await tx.select().from(facts).where(and(eq(facts.userId, this.userId),
                eq(facts.key, input.key), eq(facts.status, "active")));
            if (expectedFactId ? current?.id !== expectedFactId : !!current) {
                throw new ContextConflictError("Active fact changed or already exists");
            }
            if (current) await tx.update(facts).set({ status: "superseded", updatedAt: now })
                .where(and(eq(facts.id, current.id), eq(facts.userId, this.userId)));
            const [row] = await tx.insert(facts).values({ userId: this.userId, key: input.key,
                kind: input.kind, value: input.value, origin: input.origin, sourceMessageId: input.sourceMessageId,
                ...this.policy.validity(input, now), createdAt: now, updatedAt: now }).returning();
            return row!;
        });
    }
    async getMemory(memoryId: string) {
        const [row] = await this.database.select().from(memories)
            .where(and(eq(memories.id, id(memoryId)), eq(memories.userId, this.userId)));
        return row ?? null;
    }
    async listEligibleMemories(limit = 100) {
        return this.database.select().from(memories).where(this.policy.memoriesEligible(this.userId))
            .orderBy(desc(memories.createdAt), desc(memories.id)).limit(limitSchema.parse(limit));
    }
    async createMemory(candidate: MemoryCandidate) {
        return this.writeMemory(candidate);
    }
    async correctMemory(memoryId: string, candidate: MemoryCandidate) {
        return this.writeMemory(candidate, id(memoryId));
    }
    private async writeMemory(candidate: MemoryCandidate, previousId?: string) {
        const input = memoryCandidateSchema.parse(candidate);
        return this.database.transaction(async tx => {
            if (previousId) {
                const [old] = await tx.select().from(memories).where(and(eq(memories.id, previousId),
                    eq(memories.userId, this.userId))).for("update");
                if (!old) throw new ContextAccessError("Memory is unavailable");
                if (old.status !== "active") throw new ContextConflictError("Memory is no longer active");
            }
            await this.source(tx, input.sourceMessageId);
            const now = this.policy.now();
            const times = this.policy.memoryTimes(input, now);
            if (previousId) {
                await tx.update(memories).set({ status: "superseded", updatedAt: now })
                    .where(and(eq(memories.id, previousId), eq(memories.userId, this.userId)));
                // Ownership was checked while holding the parent row lock.
                await tx.delete(embeddings).where(eq(embeddings.memoryId, previousId));
            }
            const [row] = await tx.insert(memories).values({ userId: this.userId, content: input.content,
                retention: input.retention, origin: input.origin, sourceMessageId: input.sourceMessageId,
                ...times, createdAt: now, updatedAt: now }).returning();
            return row!;
        });
    }
    async putSummary(candidate: SummaryInput) {
        const input = summaryInputSchema.parse(candidate);
        return this.database.transaction(async tx => {
            const [source] = await tx.select({ id: messages.id }).from(messages).where(and(
                eq(messages.id, input.throughMessageId), eq(messages.userId, this.userId),
                eq(messages.conversationId, input.conversationId))).for("key share");
            if (!source) throw new ContextAccessError("Summary boundary is unavailable");
            const now = this.policy.now();
            const [row] = await tx.insert(summaries).values({ ...input, userId: this.userId, createdAt: now, updatedAt: now })
                .onConflictDoUpdate({ target: [summaries.userId, summaries.conversationId],
                    set: { summary: input.summary, throughMessageId: input.throughMessageId, updatedAt: now } }).returning();
            return row!;
        });
    }
    async getSummary(conversationId: string) {
        const [row] = await this.database.select().from(summaries).where(and(eq(summaries.userId, this.userId),
            eq(summaries.conversationId, z.string().min(1).parse(conversationId))));
        return row ?? null;
    }
    async getRecentMessages(conversationId: string, limit = 12) {
        const rows = await this.database.select().from(messages).where(and(eq(messages.userId, this.userId),
            eq(messages.conversationId, z.string().min(1).parse(conversationId))))
            .orderBy(desc(messages.createdAt), desc(messages.id)).limit(limitSchema.parse(limit));
        return rows.reverse();
    }
    async putEmbedding(memoryId: string, candidate: EmbeddingInput) {
        const targetId = id(memoryId);
        const input = embeddingInputSchema.parse(candidate);
        return this.database.transaction(async tx => {
            // Same lock as corrections: old jobs cannot reattach a stale vector.
            const [memory] = await tx.select().from(memories).where(and(eq(memories.id, targetId),
                eq(memories.userId, this.userId))).for("update");
            if (!memory) throw new ContextAccessError("Memory is unavailable");
            const now = this.policy.now();
            const [eligible] = await tx.select({ id: memories.id }).from(memories).where(and(
                eq(memories.id, targetId), this.policy.memoriesEligible(this.userId, now)));
            if (!eligible) throw new ContextConflictError("Memory is not eligible for embedding");
            const [row] = await tx.insert(embeddings).values({ ...input, memoryId: targetId, createdAt: now, updatedAt: now })
                .onConflictDoUpdate({ target: [embeddings.memoryId, embeddings.model],
                    set: { ...input, updatedAt: now } }).returning();
            return row!;
        });
    }
    async getEmbeddings(memoryId: string) {
        return this.database.select({ memoryId: embeddings.memoryId, model: embeddings.model,
            dimensions: embeddings.dimensions, embedding: embeddings.embedding,
            createdAt: embeddings.createdAt, updatedAt: embeddings.updatedAt }).from(embeddings)
            .innerJoin(memories, eq(memories.id, embeddings.memoryId))
            .where(and(eq(memories.id, id(memoryId)), this.policy.memoriesEligible(this.userId)))
            .orderBy(asc(embeddings.model));
    }
}

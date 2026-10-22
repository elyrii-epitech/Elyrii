import { and, asc, eq, gt, inArray, isNull, lte, or, sql } from "drizzle-orm";
import { z } from "zod";
import { db } from "../config/db.config";
import { userTable as users } from "../config/db/user.table";
import { chatMessagesTable as messages } from "../config/db/chat.table";
import { userContextFactsTable as facts, userMemoriesTable as memories } from "../config/db/context.table";
import { extractionKeys as keys, extractionJobs as jobs } from "../config/db/extraction.table";
import { ContextRepository, ContextAccessError, ContextConflictError } from "./context.repository";
import { contextPageSchema, correctFactSchema, correctMemorySchema } from "../modules/context/lifecycle.contracts";

type Tx = Parameters<Parameters<typeof db.transaction>[0]>[0];
export class ContextLifecycleRepository {
    constructor(private readonly database: typeof db = db, private readonly clock = () => new Date()) {}
    private async owner(tx: Tx, userId: string) {
        z.uuid().parse(userId);
        const [owner] = await tx.select({ id: users.id }).from(users).where(eq(users.id, userId)).for("update");
        if (!owner) throw new ContextAccessError("Context unavailable");
    }
    async list(userId: string, kind: "facts" | "memories", raw: unknown) {
        z.uuid().parse(userId); const page = contextPageSchema.parse(raw), now = this.clock();
        const table = kind === "facts" ? facts : memories;
        const rows = await this.database.select().from(table).where(and(eq(table.userId, userId),
            page.after ? gt(table.id, page.after) : undefined, page.status ? eq(table.status, page.status) : undefined,
            or(isNull(table.validUntil), gt(table.validUntil, now)),
            kind === "memories" ? or(isNull(memories.expiresAt), gt(memories.expiresAt, now)) : undefined))
            .orderBy(asc(table.id)).limit(page.limit + 1);
        const items = rows.slice(0, page.limit);
        return { items, nextCursor: rows.length > page.limit ? items.at(-1)!.id : null };
    }
    private async suppress(tx: Tx, userId: string, targetId: string, sourceId: string | null, factKey?: string) {
        if (factKey) await tx.insert(keys).values({ userId, key: `fact:${factKey}`, targetId, sequence: 0n, suppressed: true })
            .onConflictDoUpdate({ target: [keys.userId, keys.key], set: { suppressed: true } });
        await tx.update(users).set({ contextGeneration: sql`${users.contextGeneration} + 1` }).where(eq(users.id, userId));
        await tx.update(keys).set({ suppressed: true }).where(and(eq(keys.userId, userId), eq(keys.targetId, targetId)));
        if (sourceId) {
            // Conversation-wide source suppression prevents assistant paraphrases and
            // contextual later messages from reintroducing a forgotten assertion.
            const [source] = await tx.select().from(messages).where(and(eq(messages.userId, userId), eq(messages.id, sourceId)));
            if (source) {
                await tx.update(messages).set({ contextSuppressed: true }).where(and(eq(messages.userId, userId),
                    eq(messages.conversationId, source.conversationId), eq(messages.contextSuppressed, false)));
                await tx.update(jobs).set({ status: "discarded", completedAt: this.clock() }).where(and(eq(jobs.userId, userId),
                    eq(jobs.conversationId, source.conversationId)));
            }
        }
    }
    async correct(userId: string, kind: "facts" | "memories", targetId: string, raw: unknown) {
        z.uuid().parse(targetId);
        const input = kind === "facts" ? correctFactSchema.parse(raw) : correctMemorySchema.parse(raw);
        return this.database.transaction(async tx => {
            await this.owner(tx, userId);
            const table = kind === "facts" ? facts : memories;
            const [row] = await tx.select().from(table).where(and(eq(table.userId, userId), eq(table.id, targetId)));
            if (!row) throw new ContextAccessError("Context unavailable");
            const now = this.clock();
            if (row.status !== "active" || (row.validUntil && row.validUntil <= now) || ("expiresAt" in row && row.expiresAt && row.expiresAt <= now))
                throw new ContextConflictError("Context is no longer active");
            await this.suppress(tx, userId, row.id, row.sourceMessageId, "key" in row ? row.key : undefined);
            if (kind === "facts") {
                const [updated] = await tx.update(facts).set({ value: (input as z.infer<typeof correctFactSchema>).value,
                    origin: "explicit", updatedAt: now }).where(and(eq(facts.id, targetId), eq(facts.userId, userId))).returning();
                return updated;
            }
            const [updated] = await tx.update(memories).set({ content: (input as z.infer<typeof correctMemorySchema>).content,
                origin: "explicit", updatedAt: now }).where(and(eq(memories.id, targetId), eq(memories.userId, userId))).returning();
            return updated;
        });
    }
    async forget(userId: string, kind: "facts" | "memories", targetId: string) {
        z.uuid().parse(targetId);
        return this.database.transaction(async tx => {
            await this.owner(tx, userId);
            const table = kind === "facts" ? facts : memories;
            const [row] = await tx.select().from(table).where(and(eq(table.userId, userId), eq(table.id, targetId)));
            if (!row) return; // Foreign and missing IDs have the same idempotent response.
            await this.suppress(tx, userId, row.id, row.sourceMessageId, "key" in row ? row.key : undefined);
            // A source may have produced several interpretations of the same assertion.
            if (row.sourceMessageId) {
                const related = await tx.select({ id: memories.id }).from(memories).where(and(eq(memories.userId, userId), eq(memories.sourceMessageId, row.sourceMessageId)));
                const relatedFacts = await tx.select({ id: facts.id }).from(facts).where(and(eq(facts.userId, userId), eq(facts.sourceMessageId, row.sourceMessageId)));
                await tx.update(keys).set({ suppressed: true }).where(and(eq(keys.userId, userId), inArray(keys.targetId, [...related, ...relatedFacts].map(r => r.id))));
                await tx.delete(facts).where(and(eq(facts.userId, userId), eq(facts.sourceMessageId, row.sourceMessageId)));
                await tx.delete(memories).where(and(eq(memories.userId, userId), eq(memories.sourceMessageId, row.sourceMessageId)));
            } else await tx.delete(table).where(and(eq(table.userId, userId), eq(table.id, targetId)));
        });
    }
    async forgetAll(userId: string) { return new ContextRepository(userId, this.database).forgetAll(); }
    async deleteMessages(userId: string, input: { messageId: string } | { conversationId: string }) {
        if ("messageId" in input) z.uuid().parse(input.messageId);
        else z.string().min(1).max(200).parse(input.conversationId);
        await this.database.transaction(async tx => {
            await this.owner(tx, userId);
            await tx.delete(messages).where(and(eq(messages.userId, userId), "messageId" in input ?
                eq(messages.id, input.messageId) : eq(messages.conversationId, input.conversationId)));
        });
    }
    /** At most limit expired memory rows per pass; no offsets to skip after deletion. */
    async cleanup(limit = 100) {
        z.number().int().min(1).max(500).parse(limit);
        const now = this.clock();
        const rows = await this.database.select({ id: memories.id, userId: memories.userId }).from(memories)
            .where(or(lte(memories.expiresAt, now), lte(memories.validUntil, now))).orderBy(memories.id).limit(limit);
        let removed = 0;
        for (const candidate of rows) await this.database.transaction(async tx => {
            const [owner] = await tx.select({ id: users.id }).from(users).where(eq(users.id, candidate.userId)).for("update");
            if (!owner) return;
            const [row] = await tx.select().from(memories).where(and(eq(memories.id, candidate.id), eq(memories.userId, owner.id),
                or(lte(memories.expiresAt, this.clock()), lte(memories.validUntil, this.clock()))));
            if (!row) return;
            await this.suppress(tx, owner.id, row.id, row.sourceMessageId);
            await tx.delete(memories).where(and(eq(memories.id, row.id), eq(memories.userId, owner.id)));
            removed++;
        });
        return removed;
    }
}

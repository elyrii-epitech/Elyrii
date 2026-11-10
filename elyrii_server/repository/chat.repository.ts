import { and, desc, eq, ne, lt, or, sql, getTableColumns } from "drizzle-orm";
import { db } from "../config/db.config";
import { chatMessagesTable, deletedChatConversations, type ChatMessageRow, type NewChatMessageRow } from "../config/db/chat.table";
import { userTable } from "../config/db/user.table";
import { extractionJobs } from "../config/db/extraction.table";
import { extractionMessageSchema } from "../modules/context/extraction.contracts";
import { createHash, randomUUID } from "node:crypto";

import { contextSourceEligible } from "../modules/context/source-eligibility";

class ChatRepository {
    constructor(private readonly database: typeof db = db) {}

    async createMessage(data: NewChatMessageRow, requestId: string = randomUUID()): Promise<ChatMessageRow> {
        return this.database.transaction(async tx => {
            // Assign outbox sequence under the same user lock as reconciliation.
            const [owner] = data.role === "user" ? await tx.select().from(userTable)
                .where(eq(userTable.id, data.userId)).for("update") : [];
            if (data.role === "user") {
                const [deleted] = await tx.select().from(deletedChatConversations).where(and(
                    eq(deletedChatConversations.userId, data.userId),
                    eq(deletedChatConversations.conversationId, data.conversationId ?? "default")));
                if (deleted) throw new Error("Conversation deleted");
            }
            if (data.role === "user" && data.id) {
                const [existing] = await tx.select().from(chatMessagesTable).where(eq(chatMessagesTable.id, data.id));
                if (existing) {
                    if (existing.contextSuppressed || existing.userId !== data.userId || existing.conversationId !== data.conversationId ||
                        existing.role !== "user" || existing.message !== data.message) throw new Error("Message identity conflict");
                    return existing;
                }
            }
            const [row] = await tx.insert(chatMessagesTable).values(data).returning();
            if (!row) {
                throw new Error("Failed to persist chat message");
            }
            if (row.role === "user") {
                if (!owner) throw new Error("Message owner is unavailable");
                let timezone = owner.timezone || "UTC";
                try { timezone = new Intl.DateTimeFormat("en", { timeZone: timezone }).resolvedOptions().timeZone; } catch { timezone = "UTC"; }
                const eligible = extractionMessageSchema.safeParse({ id: row.id, role: "user", content: row.message,
                    messageAt: row.createdAt.toISOString() }).success && row.conversationId.length <= 200 && row.conversationId.length > 0;
                await tx.insert(extractionJobs).values({ userId: row.userId, conversationId: row.conversationId,
                    sourceMessageId: row.id, requestId, generation: owner.contextGeneration, timezone,
                    status: eligible ? "pending" : "failed", lastError: eligible ? null : "invalid_input" });
            }
            return row;
        });
    }

    /** Reject responses generated before a source correction/forget/account deletion. */
    async createCurrentResponse(data: NewChatMessageRow, sourceMessageId: string, sourceHash: string): Promise<ChatMessageRow | null> {
        return this.database.transaction(async tx => {
            const [owner] = await tx.select({ id: userTable.id }).from(userTable).where(eq(userTable.id, data.userId)).for("update");
            if (!owner) return null;
            const [source] = await tx.select().from(chatMessagesTable).where(and(eq(chatMessagesTable.id, sourceMessageId),
                eq(chatMessagesTable.userId, data.userId), eq(chatMessagesTable.conversationId, data.conversationId ?? "default"),
                eq(chatMessagesTable.role, "user"), eq(chatMessagesTable.contextSuppressed, false)));
            if (!source || createHash("sha256").update(source.message).digest("hex") !== sourceHash) return null;
            const [saved] = await tx.insert(chatMessagesTable).values({ ...data, role: "ai", replyToId: sourceMessageId })
                .onConflictDoNothing({target: chatMessagesTable.replyToId}).returning();
            return saved ?? (await tx.select().from(chatMessagesTable).where(and(
                eq(chatMessagesTable.userId, data.userId), eq(chatMessagesTable.replyToId, sourceMessageId))))[0] ?? null;
        });
    }

    async getReply(userId: string, sourceMessageId: string) {
        return (await this.database.select().from(chatMessagesTable).where(and(
            eq(chatMessagesTable.userId, userId), eq(chatMessagesTable.replyToId, sourceMessageId))))[0];
    }

    async getConversations(userId: string, limit = 50, before?: {updatedAt: Date; id: string}) {
        const rows = await this.database.execute(sql`
            WITH conversations AS (
                SELECT conversation_id AS id, count(*)::int AS "messageCount",
                    min(created_at) AS created, date_trunc('milliseconds', max(created_at)) AS updated,
                    (array_agg(message ORDER BY created_at, id) FILTER (WHERE role = 'user'))[1] AS first
                FROM chat_messages WHERE user_id = ${userId} GROUP BY conversation_id
            )
            SELECT id, "messageCount", to_char(created, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') AS "createdAt",
                to_char(updated, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') AS "updatedAt", first FROM conversations
            ${before ? sql`WHERE updated < ${before.updatedAt.toISOString()}::timestamp OR
                (updated = ${before.updatedAt.toISOString()}::timestamp AND id > ${before.id})` : sql``}
            ORDER BY updated DESC, id LIMIT ${limit}
        `);
        return rows.rows.map(row => {
            const text = String(row.first ?? "Conversation").trim().replace(/\s+/g, " ");
            return {id: row.id, userId, title: text.length <= 42 ? text : text.slice(0, 42) + "…",
                messageCount: row.messageCount, createdAt: row.createdAt, updatedAt: row.updatedAt};
        });
    }

    async getHistory(userId: string, limit = 50, conversationId?: string, beforeId?: string): Promise<ChatMessageRow[]> {
        const conditions = [eq(chatMessagesTable.userId, userId)];
        if (conversationId) {
            conditions.push(eq(chatMessagesTable.conversationId, conversationId));
        }
        const date = sql`date_trunc('milliseconds', ${chatMessagesTable.createdAt})`;
        if (beforeId) {
            const [cursor] = await this.database.select().from(chatMessagesTable).where(and(
                eq(chatMessagesTable.userId, userId), eq(chatMessagesTable.conversationId, conversationId!),
                eq(chatMessagesTable.id, beforeId)));
            if (!cursor) return [];
            const stamp = sql`${cursor.createdAt.toISOString()}::timestamp`;
            conditions.push(or(lt(date, stamp), and(eq(date, stamp), lt(chatMessagesTable.id, cursor.id)))!);
        }

        // Keep the outer ID explicitly qualified below: Drizzle's single-table
        // projection normalizes interpolated columns, which would resolve an
        // unqualified ID against the inner reply row.
        const rows = await this.database
            .select({...getTableColumns(chatMessagesTable), delivery: sql<string>`CASE WHEN ${chatMessagesTable.role} = 'user' AND NOT EXISTS
                (SELECT 1 FROM chat_messages reply WHERE reply.reply_to_id = "chat_messages"."id")
                THEN 'failed' ELSE 'delivered' END`})
            .from(chatMessagesTable)
            .where(and(...conditions))
            .orderBy(desc(date), desc(chatMessagesTable.id))
            .limit(limit);

        return rows.reverse();
    }

    async getRecentMessagesForContext(userId: string, conversationId: string, limit = 12, currentMessageId?: string): Promise<Array<{ role: string; message: string }>> {
        const rows = await this.database
            .select({
                role: chatMessagesTable.role,
                message: chatMessagesTable.message,
            })
            .from(chatMessagesTable)
            .where(and(
                eq(chatMessagesTable.userId, userId),
                eq(chatMessagesTable.conversationId, conversationId),
                contextSourceEligible(),
                currentMessageId ? ne(chatMessagesTable.id, currentMessageId) : undefined,
            ))
            .orderBy(desc(chatMessagesTable.createdAt), desc(chatMessagesTable.id))
            .limit(limit);
        return rows.reverse();
    }
}

export default ChatRepository;

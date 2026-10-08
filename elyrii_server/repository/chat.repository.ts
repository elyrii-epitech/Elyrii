import { and, desc, eq } from "drizzle-orm";
import { db } from "../config/db.config";
import { chatMessagesTable, type ChatMessageRow, type NewChatMessageRow } from "../config/db/chat.table";
import { userTable } from "../config/db/user.table";
import { extractionJobs } from "../config/db/extraction.table";
import { extractionMessageSchema } from "../modules/context/extraction.contracts";
import { randomUUID } from "node:crypto";

class ChatRepository {
    constructor(private readonly database: typeof db = db) {}

    async createMessage(data: NewChatMessageRow, requestId: string = randomUUID()): Promise<ChatMessageRow> {
        return this.database.transaction(async tx => {
            // Assign outbox sequence under the same user lock as reconciliation.
            const [owner] = data.role === "user" ? await tx.select().from(userTable)
                .where(eq(userTable.id, data.userId)).for("update") : [];
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

    async getHistory(userId: string, limit = 50, conversationId?: string): Promise<ChatMessageRow[]> {
        const conditions = [eq(chatMessagesTable.userId, userId)];
        if (conversationId) {
            conditions.push(eq(chatMessagesTable.conversationId, conversationId));
        }

        const rows = await this.database
            .select()
            .from(chatMessagesTable)
            .where(and(...conditions))
            .orderBy(desc(chatMessagesTable.createdAt), desc(chatMessagesTable.id))
            .limit(limit);

        return rows.reverse();
    }

    async getRecentMessagesForContext(userId: string, conversationId: string, limit = 12): Promise<Array<{ role: string; message: string }>> {
        const rows = await this.database
            .select({
                role: chatMessagesTable.role,
                message: chatMessagesTable.message,
            })
            .from(chatMessagesTable)
            .where(and(
                eq(chatMessagesTable.userId, userId),
                eq(chatMessagesTable.conversationId, conversationId),
            ))
            .orderBy(desc(chatMessagesTable.createdAt), desc(chatMessagesTable.id))
            .limit(limit);
        return rows.reverse();
    }
}

export default ChatRepository;

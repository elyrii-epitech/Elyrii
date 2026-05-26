import { and, desc, eq } from "drizzle-orm";
import { db } from "../config/db.config";
import { chatMessagesTable, type ChatMessageRow, type NewChatMessageRow } from "../config/db/chat.table";

class ChatRepository {
    async createMessage(data: NewChatMessageRow): Promise<ChatMessageRow> {
        const [row] = await db.insert(chatMessagesTable).values(data).returning();
        if (!row) {
            throw new Error("Failed to persist chat message");
        }
        return row;
    }

    async getHistory(userId: string, limit = 50, conversationId?: string): Promise<ChatMessageRow[]> {
        const conditions = [eq(chatMessagesTable.userId, userId)];
        if (conversationId) {
            conditions.push(eq(chatMessagesTable.conversationId, conversationId));
        }

        const rows = await db
            .select()
            .from(chatMessagesTable)
            .where(and(...conditions))
            .orderBy(desc(chatMessagesTable.createdAt))
            .limit(limit);

        return rows.reverse();
    }

    async getRecentMessagesForContext(userId: string, conversationId: string, limit = 12): Promise<Array<{ role: string; message: string }>> {
        const rows = await db
            .select({
                role: chatMessagesTable.role,
                message: chatMessagesTable.message,
            })
            .from(chatMessagesTable)
            .where(and(
                eq(chatMessagesTable.userId, userId),
                eq(chatMessagesTable.conversationId, conversationId),
            ))
            .orderBy(desc(chatMessagesTable.createdAt))
            .limit(limit);
        return rows.reverse();
    }
}

export default ChatRepository;

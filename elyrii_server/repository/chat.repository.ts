import { desc, eq } from "drizzle-orm";
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

    async getHistory(userId: string, limit = 50): Promise<ChatMessageRow[]> {
        const rows = await db
            .select()
            .from(chatMessagesTable)
            .where(eq(chatMessagesTable.userId, userId))
            .orderBy(desc(chatMessagesTable.createdAt))
            .limit(limit);

        return rows.reverse();
    }
}

export default ChatRepository;

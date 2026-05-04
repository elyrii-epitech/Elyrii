import { index, pgTable, text, timestamp, uuid } from "drizzle-orm/pg-core";
import { userTable } from "./user.table";

export const chatMessagesTable = pgTable("chat_messages", {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").references(() => userTable.id, { onDelete: "cascade" }).notNull(),
    conversationId: text("conversation_id").notNull().default("default"),
    role: text("role").notNull(), // user | ai | system
    message: text("message").notNull(),
    createdAt: timestamp("created_at").notNull().defaultNow(),
}, (table) => [
    index("chat_messages_user_id_idx").on(table.userId),
    index("chat_messages_conversation_id_idx").on(table.conversationId),
    index("chat_messages_created_at_idx").on(table.createdAt),
]);

export type ChatMessageRow = typeof chatMessagesTable.$inferSelect;
export type NewChatMessageRow = typeof chatMessagesTable.$inferInsert;

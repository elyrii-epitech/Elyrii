import { sql } from "drizzle-orm";
import { boolean, foreignKey, index, pgTable, text, timestamp, unique, uniqueIndex, uuid } from "drizzle-orm/pg-core";
import { userTable } from "./user.table";

export const chatMessagesTable = pgTable("chat_messages", {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").references(() => userTable.id, { onDelete: "cascade" }).notNull(),
    contextSuppressed: boolean("context_suppressed").notNull().default(false),
    replyToId: uuid("reply_to_id"),
    conversationId: text("conversation_id").notNull().default("default"),
    role: text("role").notNull(), // user | ai | system
    message: text("message").notNull(),
    createdAt: timestamp("created_at").notNull().defaultNow(),
}, (table) => [
    uniqueIndex("chat_messages_reply_to_unique").on(table.replyToId),
    foreignKey({name: "chat_messages_reply_source_fk", columns: [table.userId, table.conversationId, table.replyToId],
        foreignColumns: [table.userId, table.conversationId, table.id]}).onDelete("cascade"),
    index("chat_messages_mobile_page_idx").on(table.userId, table.conversationId, sql`date_trunc('milliseconds', ${table.createdAt})`, table.id),
    // Composite keys keep context provenance within its owning user/conversation.
    unique("chat_messages_user_id_id_unique").on(table.userId, table.id),
    unique("chat_messages_user_conversation_id_unique").on(table.userId, table.conversationId, table.id),
    index("chat_messages_context_history_idx").on(table.userId, table.conversationId, table.createdAt),
    index("chat_messages_user_id_idx").on(table.userId),
    index("chat_messages_conversation_id_idx").on(table.conversationId),
    index("chat_messages_created_at_idx").on(table.createdAt),
]);

export type ChatMessageRow = typeof chatMessagesTable.$inferSelect;
export const deletedChatConversations = pgTable("deleted_chat_conversations", {
    userId: uuid("user_id").notNull().references(() => userTable.id, {onDelete: "cascade"}),
    conversationId: text("conversation_id").notNull(),
    deletedAt: timestamp("deleted_at").notNull().defaultNow(),
}, table => [unique("deleted_chat_conversations_owner_unique").on(table.userId, table.conversationId)]);
export type NewChatMessageRow = typeof chatMessagesTable.$inferInsert;

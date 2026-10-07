import { sql } from "drizzle-orm";
import { bigint, bigserial, check, foreignKey, index, integer, pgTable, primaryKey, text, timestamp, unique, uuid } from "drizzle-orm/pg-core";
import { userTable } from "./user.table";
import { chatMessagesTable } from "./chat.table";

/** Durable outbox and completion record. No copies of private message text. */
export const extractionJobs = pgTable("context_extraction_jobs", {
    id: uuid("id").primaryKey().defaultRandom(),
    sequence: bigserial("sequence", { mode: "bigint" }).notNull(),
    userId: uuid("user_id").notNull().references(() => userTable.id, { onDelete: "cascade" }),
    conversationId: text("conversation_id").notNull(),
    sourceMessageId: uuid("source_message_id").notNull(),
    requestId: uuid("request_id").notNull(),
    extractorVersion: text("extractor_version").notNull().default("v1"),
    generation: integer("generation").notNull(),
    timezone: text("timezone").notNull(),
    status: text("status").notNull().default("pending"),
    attempts: integer("attempts").notNull().default(0),
    nextAttemptAt: timestamp("next_attempt_at", { withTimezone: true }).notNull().defaultNow(),
    lastError: text("last_error"),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
    completedAt: timestamp("completed_at", { withTimezone: true }),
}, table => [
    unique("context_extraction_source_version_unique").on(table.sourceMessageId, table.extractorVersion),
    foreignKey({ columns: [table.userId, table.conversationId, table.sourceMessageId],
        foreignColumns: [chatMessagesTable.userId, chatMessagesTable.conversationId, chatMessagesTable.id] }).onDelete("cascade"),
    index("context_extraction_due_idx").on(table.nextAttemptAt).where(sql`${table.status} IN ('pending', 'retry', 'awaiting')`),
    check("context_extraction_status_check", sql`${table.status} IN ('pending', 'retry', 'awaiting', 'completed', 'failed', 'discarded')`),
    check("context_extraction_attempts_check", sql`${table.attempts} BETWEEN 0 AND 5`),
]);

/** High-water marks survive content deletion, preventing older corrections. */
export const extractionKeys = pgTable("context_extraction_keys", {
    userId: uuid("user_id").notNull().references(() => userTable.id, { onDelete: "cascade" }),
    key: text("key").notNull(),
    sequence: bigint("sequence", { mode: "bigint" }).notNull(),
    targetId: uuid("target_id").notNull(),
}, table => [primaryKey({ columns: [table.userId, table.key] })]);

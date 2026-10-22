import { check, index, integer, jsonb, pgTable, primaryKey, text, timestamp, uuid, boolean } from "drizzle-orm/pg-core";
import { sql } from "drizzle-orm";
import { userTable } from "./user.table";

/** One durable, versioned summary task per conversation. Text stays in messages. */
export const summaryTasks = pgTable("conversation_summary_tasks", {
    userId: uuid("user_id").notNull().references(() => userTable.id, { onDelete: "cascade" }),
    conversationId: text("conversation_id").notNull(),
    revision: integer("revision").notNull().default(0),
    historyVersion: integer("history_version").notNull().default(0),
    dirty: boolean("dirty").notNull().default(true),
    status: text("status").notNull().default("pending"),
    jobId: uuid("job_id"),
    sourceIds: jsonb("source_ids").$type<string[]>(),
    snapshotThroughAt: timestamp("snapshot_through_at"),
    snapshotThroughId: uuid("snapshot_through_id"),
    model: text("model"),
    policy: jsonb("policy").$type<{ messageThreshold: number; tokenThreshold: number; maxInputTokens: number; maxOutputTokens: number }>(),
    attempts: integer("attempts").notNull().default(0),
    nextAttemptAt: timestamp("next_attempt_at", { withTimezone: true }).notNull().defaultNow(),
    lastError: text("last_error"),
}, t => [
    primaryKey({ columns: [t.userId, t.conversationId] }),
    index("conversation_summary_tasks_due_idx").on(t.nextAttemptAt).where(sql`${t.status} IN ('pending','retry','awaiting')`),
    check("conversation_summary_tasks_status_check", sql`${t.status} IN ('pending','retry','awaiting','idle','failed')`),
    check("conversation_summary_tasks_attempts_check", sql`${t.attempts} BETWEEN 0 AND 5`),
]);

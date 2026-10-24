import { sql } from "drizzle-orm";
import { pgTable, uuid, text, integer, timestamp, unique, index, check } from "drizzle-orm/pg-core";
import { contextSourceEvents } from "./context-source.table";
export const journalExtractionJobs = pgTable("journal_extraction_jobs", {
    id: uuid("id").primaryKey().defaultRandom(),
    eventId: uuid("event_id").notNull().references(() => contextSourceEvents.id, { onDelete: "cascade" }),
    extractorVersion: text("extractor_version").notNull().default("journal-v1"),
    timezone: text("timezone"),
    status: text("status").notNull().default("pending"),
    attempts: integer("attempts").notNull().default(0),
    nextAttemptAt: timestamp("next_attempt_at", { withTimezone: true }).notNull().defaultNow(),
    lastError: text("last_error"),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
    completedAt: timestamp("completed_at", { withTimezone: true }),
}, t => [unique("journal_extraction_event_version_unique").on(t.eventId, t.extractorVersion),
    index("journal_extraction_due_idx").on(t.nextAttemptAt).where(sql`${t.status} IN ('pending','retry','awaiting')`),
    check("journal_extraction_status_check", sql`${t.status} IN ('pending','retry','awaiting','completed','failed','discarded')`),
    check("journal_extraction_attempts_check", sql`${t.attempts} BETWEEN 0 AND 5`)]);

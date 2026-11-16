import { sql } from "drizzle-orm";
import { boolean, check, foreignKey, index, integer, pgTable, primaryKey, text, timestamp, unique, uuid } from "drizzle-orm/pg-core";
import { userTable } from "./user.table";
import { chatMessagesTable } from "./chat.table";
import { journalEntriesTable } from "./journal.table";

/** Immutable identities, not copies of source text. Old revisions remain for audit/FKs. */
export const contextSourceVersions = pgTable("context_source_versions", {
    userId: uuid("user_id").notNull().references(() => userTable.id, { onDelete: "cascade" }),
    kind: text("kind").$type<"chat" | "journal">().notNull(),
    sourceId: uuid("source_id").notNull(),
    revision: integer("revision").notNull(),
    chatMessageId: uuid("chat_message_id"),
    journalEntryId: uuid("journal_entry_id"),
    sourceCreatedAt: timestamp("source_created_at", { withTimezone: true }),
    active: boolean("active").notNull().default(true),
    excluded: boolean("excluded").notNull().default(false),
}, t => [
    primaryKey({ columns: [t.userId, t.kind, t.sourceId, t.revision] }),
    foreignKey({ columns: [t.userId, t.chatMessageId], foreignColumns: [chatMessagesTable.userId, chatMessagesTable.id] }).onDelete("cascade"),
    foreignKey({ columns: [t.userId, t.journalEntryId], foreignColumns: [journalEntriesTable.userId, journalEntriesTable.id] }).onDelete("cascade"),
    check("context_source_identity_check", sql`${t.revision} > 0 AND (
        (${t.kind} = 'chat' AND ${t.chatMessageId} = ${t.sourceId} AND ${t.chatMessageId} IS NOT NULL AND ${t.journalEntryId} IS NULL) OR
        (${t.kind} = 'journal' AND ${t.journalEntryId} = ${t.sourceId} AND ${t.journalEntryId} IS NOT NULL AND ${t.chatMessageId} IS NULL))`),
]);

/** Journal lifecycle outbox; #230 will consume eligible create/update events. */
export const contextSourceEvents = pgTable("context_source_events", {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").notNull(),
    kind: text("kind").$type<"chat" | "journal">().notNull(),
    sourceId: uuid("source_id").notNull(),
    revision: integer("revision").notNull(),
    change: text("change").$type<"created" | "updated" | "deleted" | "excluded">().notNull(),
    generation: integer("generation").notNull(),
    status: text("status").notNull().default("pending"),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
}, t => [
    foreignKey({ columns: [t.userId, t.kind, t.sourceId, t.revision],
        foreignColumns: [contextSourceVersions.userId, contextSourceVersions.kind, contextSourceVersions.sourceId, contextSourceVersions.revision] }).onDelete("cascade"),
    unique("context_source_event_identity_unique").on(t.userId, t.kind, t.sourceId, t.revision, t.change),
    check("context_source_event_change_check", sql`${t.change} IN ('created', 'updated', 'deleted', 'excluded')`),
    check("context_source_event_status_check", sql`${t.status} IN ('pending', 'completed', 'discarded')`),
    index("context_source_event_pending_idx").on(t.createdAt).where(sql`${t.status} = 'pending'`),
]);

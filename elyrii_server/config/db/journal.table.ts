import { pgTable, uuid, text, timestamp, index } from "drizzle-orm/pg-core";

export const journalEntriesTable = pgTable("journal_entries", {
    id: uuid("id").primaryKey().defaultRandom().unique().notNull(),
    userId: uuid("user_id").notNull(),
    title: text("title").notNull(),
    content: text("content"),
    mood: text("mood"),
    createdAt: timestamp("created_at").defaultNow(),
    updatedAt: timestamp("updated_at").defaultNow().$onUpdate(() => new Date()),
    deletedAt: timestamp("deleted_at"),
}, (table) => [
  index("journal_entries_user_id_idx").on(table.userId),
]);

export const journalTagsTable = pgTable("journal_tags", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id").notNull(),
  name: text("name").notNull(),
}, (table) => [
  index("journal_tags_user_id_idx").on(table.userId),
]);

export const journalEntryTagsTable = pgTable("journal_entry_tags", {
  entryId: uuid("entry_id").references(() => journalEntriesTable.id).notNull(),
  tagId: uuid("tag_id").references(() => journalTagsTable.id).notNull(),
}, (table) => [
  index("journal_entry_tags_entry_id_idx").on(table.entryId),
  index("journal_entry_tags_tag_id_idx").on(table.tagId),
]);

export const journalMediaTable = pgTable("journal_media", {
  id: uuid("id").primaryKey().defaultRandom(),
  entryId: uuid("entry_id").references(() => journalEntriesTable.id).notNull(),
  url: text("url").notNull(),
  type: text("type"),
  createdAt: timestamp("created_at").defaultNow(),
}, (table) => [
  index("journal_media_entry_id_idx").on(table.entryId),
]);


export type JournalEntry = typeof journalEntriesTable.$inferSelect & { deletedAt?: Date | null };
export type NewJournalEntry = typeof journalEntriesTable.$inferInsert;
export type JournalTag = typeof journalTagsTable.$inferSelect;
export type NewJournalTag = typeof journalTagsTable.$inferInsert;
export type JournalMedia = typeof journalMediaTable.$inferSelect;
export type NewJournalMedia = typeof journalMediaTable.$inferInsert;
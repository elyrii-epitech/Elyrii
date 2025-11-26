import { pgTable, uuid, text, timestamp } from "drizzle-orm/pg-core";

export const journalEntriesTable = pgTable("journal_entries", {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").notNull(),
    title: text("title").notNull(),
    content: text("content"),
    mood: text("mood"),
    createdAt: timestamp("created_at").defaultNow(),
    updatedAt: timestamp("updated_at").defaultNow(),
});

export const journalTagsTable = pgTable("journal_tags", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id").notNull(),
  name: text("name").notNull(),
});

export const journalEntryTagsTable = pgTable("journal_entry_tags", {
  entryId: uuid("entry_id").references(() => journalEntriesTable.id).notNull(),
  tagId: uuid("tag_id").references(() => journalTagsTable.id).notNull(),
});

export const journalMediaTable = pgTable("journal_media", {
  id: uuid("id").primaryKey().defaultRandom(),
  entryId: uuid("entry_id").references(() => journalEntriesTable.id).notNull(),
  url: text("url").notNull(),
  type: text("type"),
  createdAt: timestamp("created_at").defaultNow(),
});


export type JournalEntry = typeof journalEntriesTable.$inferSelect;
export type NewJournalEntry = typeof journalEntriesTable.$inferInsert;
export type JournalTag = typeof journalTagsTable.$inferSelect;
export type NewJournalTag = typeof journalTagsTable.$inferInsert;
export type JournalMedia = typeof journalMediaTable.$inferSelect;
export type NewJournalMedia = typeof journalMediaTable.$inferInsert;
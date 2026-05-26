import { index, integer, pgTable, text, timestamp, uuid } from "drizzle-orm/pg-core";
import { userTable } from "./user.table";

export const meditationSessionsTable = pgTable("meditation_sessions", {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").references(() => userTable.id, { onDelete: "cascade" }).notNull(),
    type: text("type").notNull(),
    durationMinutes: integer("duration_minutes").notNull(),
    status: text("status").notNull().default("STARTED"), // STARTED | COMPLETED | CANCELED
    notes: text("notes"),
    moodBefore: text("mood_before"),
    moodAfter: text("mood_after"),
    startedAt: timestamp("started_at").notNull().defaultNow(),
    endedAt: timestamp("ended_at"),
    createdAt: timestamp("created_at").notNull().defaultNow(),
    updatedAt: timestamp("updated_at").notNull().defaultNow().$onUpdate(() => new Date()),
}, (table) => [
    index("meditation_sessions_user_id_idx").on(table.userId),
    index("meditation_sessions_status_idx").on(table.status),
    index("meditation_sessions_created_at_idx").on(table.createdAt),
]);

export type MeditationSession = typeof meditationSessionsTable.$inferSelect;
export type NewMeditationSession = typeof meditationSessionsTable.$inferInsert;

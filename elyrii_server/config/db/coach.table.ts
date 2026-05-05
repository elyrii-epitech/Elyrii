import { index, jsonb, pgTable, text, timestamp, uuid } from "drizzle-orm/pg-core";
import { userTable } from "./user.table";

export const coachSessionsTable = pgTable("coach_sessions", {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").references(() => userTable.id, { onDelete: "cascade" }).notNull(),
    prompt: text("prompt").notNull(),
    response: text("response").notNull(),
    context: jsonb("context"),
    createdAt: timestamp("created_at").notNull().defaultNow(),
}, (table) => [
    index("coach_sessions_user_id_idx").on(table.userId),
    index("coach_sessions_created_at_idx").on(table.createdAt),
]);

export type CoachSession = typeof coachSessionsTable.$inferSelect;
export type NewCoachSession = typeof coachSessionsTable.$inferInsert;

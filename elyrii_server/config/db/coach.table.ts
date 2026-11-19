import { boolean, index, integer, jsonb, pgTable, text, timestamp, uniqueIndex, uuid } from "drizzle-orm/pg-core";
import {sql} from "drizzle-orm";
import type {CoachPath} from "../../modules/coach/coach.journey-contracts";
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

export const coachJourneysTable = pgTable("coach_journeys", {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").references(() => userTable.id, {onDelete: "cascade"}).notNull(),
    path: jsonb("path").$type<CoachPath>().notNull(),
    status: text("status").notNull().default("active"),
    completedStepCount: integer("completed_step_count").notNull().default(0),
    revision: integer("revision").notNull().default(1),
    isCurrent: boolean("is_current").notNull().default(true),
    startedAt: timestamp("started_at", {withTimezone: true}).notNull(),
    updatedAt: timestamp("updated_at", {withTimezone: true}).notNull(),
    completedAt: timestamp("completed_at", {withTimezone: true}),
}, table => [
    uniqueIndex("coach_journeys_current_user_idx").on(table.userId).where(sql`${table.isCurrent}`),
    index("coach_journeys_user_idx").on(table.userId),
]);
export type CoachJourney = typeof coachJourneysTable.$inferSelect;

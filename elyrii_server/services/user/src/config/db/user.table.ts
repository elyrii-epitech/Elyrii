import { integer, pgTable, text, timestamp, uniqueIndex, uuid, index } from "drizzle-orm/pg-core";

/**
 * Miroir de la table users gérée par le service Auth.
 * Le User service ne fait que lire et modifier, jamais créer ou supprimer.
 */
export const userTable = pgTable("users", {
    id: uuid("id").primaryKey().defaultRandom(),
    lastName: text("last_name").notNull(),
    firstName: text("first_name").notNull(),
    email: text("email").notNull(),
    password: text("password").notNull(),
    age: integer("age").notNull(),
    pfp: text("pfp"),
    createdAt: timestamp("created_at").notNull().defaultNow(),
    updatedAt: timestamp("updated_at").notNull().defaultNow().$onUpdate(() => new Date()),
}, (table) => [
    uniqueIndex("idx_email").on(table.email),
]);

export const moodLogsTable = pgTable("mood_logs", {
    id: uuid("id").primaryKey().defaultRandom().unique(),
    userId: uuid("user_id").references(() => userTable.id, { onDelete: "cascade" }).notNull(),
    moodType: text("mood_type").notNull(),
    createdAt: timestamp("created_at").notNull().defaultNow(),
}, (table) => [
    index("idx_mood_logs_user_id").on(table.userId),
]);

export type User = typeof userTable.$inferSelect;
export type MoodLog = typeof moodLogsTable.$inferSelect;
export type NewMoodLog = typeof moodLogsTable.$inferInsert;

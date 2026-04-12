import { index, integer, pgTable, text, timestamp, uniqueIndex, uuid } from "drizzle-orm/pg-core";

/**
 * Drizzle ORM table definition for users authenticated by the auth service.
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
])

export const moodLogsTable = pgTable("mood_logs", {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").references(() => userTable.id, { onDelete: "cascade" }).notNull(),
    moodType: text("mood_type").notNull(),
    createdAt: timestamp("created_at").notNull().defaultNow(),
}, (table) => [
    index("idx_mood_logs_user_id").on(table.userId),
]);

/**
 * Type representing a user row returned from the database.
 */
export type User = typeof userTable.$inferSelect;
export type MoodLog = typeof moodLogsTable.$inferSelect;
export type NewMoodLog = typeof moodLogsTable.$inferInsert;

/**
 * Type representing the payload required to create a new user row.
 */
export type NewUser = typeof userTable.$inferInsert;

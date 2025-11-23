import { integer, pgTable, text, timestamp, uuid } from "drizzle-orm/pg-core";

/**
 * Drizzle ORM table definition for users authenticated by the auth service.
 */
export const userTable = pgTable("users", {
    id: uuid("id").primaryKey().defaultRandom(),
    lastName: text("last_name").notNull(),
    firstName: text("first_name").notNull(),
    email: text("email").notNull().unique(),
    password: text("password").notNull(),
    age: integer("age").notNull(),
    pfp: text("pfp"),
    createdAt: timestamp("created_at").notNull().defaultNow(),
    updatedAt: timestamp("updated_at").notNull().defaultNow().$onUpdate(() => new Date()),
})

/**
 * Type representing a user row returned from the database.
 */
export type User = typeof userTable.$inferSelect;

/**
 * Type representing the payload required to create a new user row.
 */
export type NewUser = typeof userTable.$inferInsert;

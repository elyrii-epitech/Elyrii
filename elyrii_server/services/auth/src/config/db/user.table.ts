import { integer, pgTable, text, timestamp, uuid } from "drizzle-orm/pg-core";

export const userTable = pgTable("user", {
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

export type User = typeof userTable.$inferSelect;
export type NewUser = typeof userTable.$inferInsert;

import { integer, pgTable, text, timestamp, uniqueIndex, uuid } from "drizzle-orm/pg-core";

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

export type User = typeof userTable.$inferSelect;

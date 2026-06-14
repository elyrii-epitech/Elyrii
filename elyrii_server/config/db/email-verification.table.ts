import { index, pgTable, text, timestamp, uuid } from "drizzle-orm/pg-core";
import { userTable } from "./user.table";

export const emailVerificationTokensTable = pgTable("email_verification_tokens", {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").references(() => userTable.id, { onDelete: "cascade" }).notNull(),
    tokenHash: text("token_hash").notNull(),
    expiresAt: timestamp("expires_at").notNull(),
    createdAt: timestamp("created_at").notNull().defaultNow(),
}, (table) => [
    index("email_verification_tokens_user_id_idx").on(table.userId),
    index("email_verification_tokens_expires_at_idx").on(table.expiresAt),
]);

export type EmailVerificationToken = typeof emailVerificationTokensTable.$inferSelect;
export type NewEmailVerificationToken = typeof emailVerificationTokensTable.$inferInsert;

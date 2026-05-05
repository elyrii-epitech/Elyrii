import { index, pgTable, text, timestamp, uniqueIndex, uuid } from "drizzle-orm/pg-core";
import { userTable } from "./user.table";

export const oauthAccountsTable = pgTable("oauth_accounts", {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").references(() => userTable.id, { onDelete: "cascade" }).notNull(),
    provider: text("provider").notNull(), // google | apple
    providerUserId: text("provider_user_id").notNull(),
    email: text("email"),
    createdAt: timestamp("created_at").notNull().defaultNow(),
    updatedAt: timestamp("updated_at").notNull().defaultNow().$onUpdate(() => new Date()),
}, (table) => [
    uniqueIndex("oauth_accounts_provider_user_uidx").on(table.provider, table.providerUserId),
    index("oauth_accounts_user_id_idx").on(table.userId),
]);

export type OAuthAccount = typeof oauthAccountsTable.$inferSelect;
export type NewOAuthAccount = typeof oauthAccountsTable.$inferInsert;

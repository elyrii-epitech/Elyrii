import { index, pgTable, text, timestamp, uuid } from "drizzle-orm/pg-core";
import { userTable } from "./user.table";

export const tokenTable = pgTable("tokens", {
    id: uuid("id").primaryKey().defaultRandom().notNull(),
    userId: uuid("user_id").references(() => userTable.id, { onDelete: "cascade"}),
    hash_token: text("hash_token").notNull(),
    device: text("device").notNull(),
    created_at: timestamp("created_at").defaultNow().notNull(),
    updated_at: timestamp("updated_at").defaultNow().notNull().$onUpdate(() => new Date()),
})

export const revokedAccessTokensTable = pgTable("revoked_access_tokens", {
    id: uuid("id").primaryKey().defaultRandom().notNull(),
    userId: uuid("user_id").references(() => userTable.id, { onDelete: "cascade" }).notNull(),
    jti: text("jti").notNull(),
    expiresAt: timestamp("expires_at").notNull(),
    createdAt: timestamp("created_at").defaultNow().notNull(),
}, (table) => [
    index("revoked_access_tokens_user_id_idx").on(table.userId),
    index("revoked_access_tokens_jti_idx").on(table.jti),
]);

export type TokenSession = typeof tokenTable.$inferSelect;
export type RevokedAccessToken = typeof revokedAccessTokensTable.$inferSelect;

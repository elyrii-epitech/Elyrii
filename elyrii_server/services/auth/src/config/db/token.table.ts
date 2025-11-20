import { pgTable, text, timestamp, uuid } from "drizzle-orm/pg-core";
import { userTable } from "./user.table";

export const tokenTable = pgTable("tokens", {
    id: uuid("id").primaryKey().defaultRandom().notNull(),
    userId: uuid("user_id").references(() => userTable.id, { onDelete: "cascade"}),
    hash_token: text("hash_token").notNull(),
    created_at: timestamp("created_at").notNull(),
    updated_at: timestamp("updated_at").notNull().$onUpdate(() => new Date()),
})
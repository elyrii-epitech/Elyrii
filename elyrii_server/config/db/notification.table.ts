import { boolean, index, pgTable, text, timestamp, uuid } from "drizzle-orm/pg-core";
import { userTable } from "./user.table";

export const notificationsTable = pgTable("notifications", {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").references(() => userTable.id, { onDelete: "cascade" }).notNull(),
    title: text("title").notNull(),
    body: text("body").notNull(),
    type: text("type").notNull().default("general"),
    isRead: boolean("is_read").notNull().default(false),
    metadata: text("metadata"),
    createdAt: timestamp("created_at").notNull().defaultNow(),
    readAt: timestamp("read_at"),
}, (table) => [
    index("notifications_user_id_idx").on(table.userId),
    index("notifications_is_read_idx").on(table.isRead),
    index("notifications_created_at_idx").on(table.createdAt),
]);

export type Notification = typeof notificationsTable.$inferSelect;
export type NewNotification = typeof notificationsTable.$inferInsert;

import { boolean, index, jsonb, pgTable, text, timestamp, uniqueIndex, uuid } from "drizzle-orm/pg-core";
import { userTable } from "./user.table";

export const userSettingsTable = pgTable("user_settings", {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").references(() => userTable.id, { onDelete: "cascade" }).notNull(),
    themeMode: text("theme_mode").notNull().default("SYSTEM"), // LIGHT | DARK | SYSTEM
    notificationsEnabled: boolean("notifications_enabled").notNull().default(true),
    privacyMode: text("privacy_mode").notNull().default("STANDARD"), // STANDARD | STRICT
    mascotAppearance: text("mascot_appearance").notNull().default("default"),
    mascotPersonality: jsonb("mascot_personality").notNull().default({
        tone: "supportive",
        energy: "balanced",
        humor: "light",
    }),
    createdAt: timestamp("created_at").notNull().defaultNow(),
    updatedAt: timestamp("updated_at").notNull().defaultNow().$onUpdate(() => new Date()),
}, (table) => [
    uniqueIndex("user_settings_user_id_uidx").on(table.userId),
    index("user_settings_theme_mode_idx").on(table.themeMode),
]);

export type UserSettings = typeof userSettingsTable.$inferSelect;
export type NewUserSettings = typeof userSettingsTable.$inferInsert;

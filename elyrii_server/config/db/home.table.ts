import {integer, jsonb, pgTable, text, timestamp, uniqueIndex, uuid} from "drizzle-orm/pg-core";
import {userTable} from "./user.table";
import type {HomeFacts} from "../../modules/user/home.contracts";

export const homeActivitiesTable = pgTable("home_activities", {
    userId: uuid("user_id").primaryKey().references(() => userTable.id, {onDelete: "cascade"}),
    activities: jsonb("activities").$type<HomeFacts>().notNull(),
    revision: integer("revision").notNull().default(1),
    updatedAt: timestamp("updated_at", {withTimezone: true}).notNull().defaultNow(),
});
export const homeCommandsTable = pgTable("home_commands", {
    userId: uuid("user_id").notNull().references(() => userTable.id, {onDelete: "cascade"}),
    requestId: uuid("request_id").notNull(),
    payloadHash: text("payload_hash").notNull(),
    createdAt: timestamp("created_at", {withTimezone: true}).notNull().defaultNow(),
}, table => [uniqueIndex("home_commands_owner_request_uidx").on(table.userId, table.requestId)]);

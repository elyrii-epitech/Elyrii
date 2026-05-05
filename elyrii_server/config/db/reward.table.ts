import { index, integer, jsonb, pgTable, text, timestamp, uniqueIndex, uuid } from "drizzle-orm/pg-core";
import { userTable } from "./user.table";
import { userChallengesTable } from "./quest.table";

export const pointsLedgerTable = pgTable("points_ledger", {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").references(() => userTable.id, { onDelete: "cascade" }).notNull(),
    userChallengeId: uuid("user_challenge_id").references(() => userChallengesTable.id, { onDelete: "set null" }),
    points: integer("points").notNull(),
    reason: text("reason").notNull(),
    metadata: jsonb("metadata"),
    createdAt: timestamp("created_at").notNull().defaultNow(),
}, (table) => [
    index("points_ledger_user_id_idx").on(table.userId),
    uniqueIndex("points_ledger_user_challenge_reason_uidx").on(table.userChallengeId, table.reason),
]);

export type PointsLedgerEntry = typeof pointsLedgerTable.$inferSelect;
export type NewPointsLedgerEntry = typeof pointsLedgerTable.$inferInsert;

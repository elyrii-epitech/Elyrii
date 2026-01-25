import { pgTable, uuid, text, timestamp, jsonb, index } from "drizzle-orm/pg-core";

export const challengesTable = pgTable("challenges", {
    id: uuid("id").primaryKey().defaultRandom(),
    title: text("title").notNull(),
    description: text("description"),
    source: text("source").notNull(), // 'AI' | 'SYSTEM'
    conditions: jsonb("conditions").notNull(),
    aggregator: text("aggregator").notNull().default('ALL'),
    constraints: jsonb("constraints"),
    createdAt: timestamp("created_at").defaultNow(),
    updatedAt: timestamp("updated_at").defaultNow().$onUpdate(() => new Date()),
});

export const userChallengesTable = pgTable("user_challenges", {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").notNull(),
    challengeId: uuid("challenge_id").references(() => challengesTable.id).notNull(),
    status: text("status").notNull().default('PENDING'), // PENDING, ACTIVE, COMPLETED, SKIPPED, EXPIRED, REJECTED
    progress: jsonb("progress"), // Store current progress state
    createdAt: timestamp("created_at").defaultNow(),
    updatedAt: timestamp("updated_at").defaultNow().$onUpdate(() => new Date()),
    completedAt: timestamp("completed_at"),
}, (table) => [
    index("user_challenges_user_id_idx").on(table.userId),
    index("user_challenges_status_idx").on(table.status),
]);

export type Challenge = typeof challengesTable.$inferSelect;
export type NewChallenge = typeof challengesTable.$inferInsert;
export type UserChallenge = typeof userChallengesTable.$inferSelect;
export type NewUserChallenge = typeof userChallengesTable.$inferInsert;

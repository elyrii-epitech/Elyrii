import { boolean, check, integer, pgTable, primaryKey, text, timestamp, uuid, index } from "drizzle-orm/pg-core";
import { sql } from "drizzle-orm";
import { userTable } from "./user.table";
import { userMemoriesTable } from "./context.table";

export const embeddingModels = pgTable("embedding_models", {
    id: text("id").primaryKey(),
    providerModel: text("provider_model").notNull(),
    digest: text("digest").notNull(),
    dimensions: integer("dimensions").notNull(),
    metric: text("metric").notNull(),
    preprocessing: text("preprocessing").notNull(),
    enabled: boolean("enabled").notNull().default(true),
}, t => [check("embedding_models_dimensions_check", sql`${t.dimensions} > 0 AND ${t.dimensions} <= 16000`)]);

export const embeddingJobs = pgTable("memory_embedding_jobs", {
    memoryId: uuid("memory_id").notNull().references(() => userMemoriesTable.id, { onDelete: "cascade" }),
    model: text("model").notNull().references(() => embeddingModels.id, { onDelete: "cascade" }),
    userId: uuid("user_id").notNull().references(() => userTable.id, { onDelete: "cascade" }),
    contentRevision: integer("content_revision").notNull(),
    jobId: uuid("job_id").notNull().defaultRandom(),
    status: text("status").notNull().default("pending"),
    attempts: integer("attempts").notNull().default(0),
    nextAttemptAt: timestamp("next_attempt_at", { withTimezone: true }).notNull().defaultNow(),
    lastError: text("last_error"),
}, t => [primaryKey({ columns: [t.memoryId, t.model] }),
    index("memory_embedding_jobs_due_idx").on(t.nextAttemptAt).where(sql`${t.status} IN ('pending','retry','awaiting')`),
    check("memory_embedding_jobs_status_check", sql`${t.status} IN ('pending','retry','awaiting','completed','failed','discarded')`),
    check("memory_embedding_jobs_attempts_check", sql`${t.attempts} BETWEEN 0 AND 5`)]);

export const embeddingBackfills = pgTable("embedding_backfills", {
    model: text("model").primaryKey().references(() => embeddingModels.id, { onDelete: "cascade" }),
    afterId: uuid("after_id"),
    rebuild: boolean("rebuild").notNull().default(false),
    done: boolean("done").notNull().default(false),
});

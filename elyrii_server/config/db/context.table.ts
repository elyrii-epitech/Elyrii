import { sql } from "drizzle-orm";
import {
    check, customType, foreignKey, index, integer, jsonb, pgEnum, pgTable,
    primaryKey, text, timestamp, uniqueIndex, uuid,
} from "drizzle-orm/pg-core";
import { chatMessagesTable } from "./chat.table";
import { userTable } from "./user.table";

export const contextStatus = pgEnum("context_status", ["active", "superseded", "deleted"]);
export const contextOrigin = pgEnum("context_origin", ["explicit", "inferred"]);
export const contextFactKind = pgEnum("context_fact_kind", ["fact", "preference"]);
export const memoryRetention = pgEnum("memory_retention", ["short_term", "long_term"]);

const createdAt = () => timestamp("created_at", { withTimezone: true }).notNull().defaultNow();
const updatedAt = () => timestamp("updated_at", { withTimezone: true }).notNull().defaultNow().$onUpdate(() => new Date());

// No embedding model has been selected yet. Model-specific dimensions are checked
// per row; a future model-specific migration can add a fixed-size ANN index.
const embeddingVector = customType<{ data: number[]; driverData: string }>({
    dataType: () => "vector",
    toDriver: (value) => JSON.stringify(value),
    fromDriver: (value) => JSON.parse(value),
});

/** Stable facts and preferences, read directly rather than by vector similarity. */
export const userContextFactsTable = pgTable("user_context_facts", {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").notNull().references(() => userTable.id, { onDelete: "cascade" }),
    key: text("key").notNull(),
    kind: contextFactKind("kind").notNull(),
    value: jsonb("value").notNull(),
    origin: contextOrigin("origin").notNull(),
    sourceMessageId: uuid("source_message_id"),
    status: contextStatus("status").notNull().default("active"),
    validFrom: timestamp("valid_from", { withTimezone: true }).notNull().defaultNow(),
    validUntil: timestamp("valid_until", { withTimezone: true }),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
}, (table) => [
    uniqueIndex("user_context_facts_active_key_uidx").on(table.userId, table.key)
        .where(sql`${table.status} = 'active'`),
    index("user_context_facts_user_status_idx").on(table.userId, table.status),
    index("user_context_facts_source_idx").on(table.userId, table.sourceMessageId),
    foreignKey({ name: "user_context_facts_source_fk", columns: [table.userId, table.sourceMessageId],
        foreignColumns: [chatMessagesTable.userId, chatMessagesTable.id] }).onDelete("cascade"),
    check("user_context_facts_key_check", sql`length(btrim(${table.key})) > 0`),
    check("user_context_facts_validity_check", sql`${table.validUntil} IS NULL OR ${table.validUntil} > ${table.validFrom}`),
]);

/** One rolling summary per user/conversation; existing messages remain unchanged. */
export const conversationSummariesTable = pgTable("conversation_summaries", {
    userId: uuid("user_id").notNull().references(() => userTable.id, { onDelete: "cascade" }),
    conversationId: text("conversation_id").notNull(),
    summary: text("summary").notNull(),
    throughMessageId: uuid("through_message_id").notNull(),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
}, (table) => [
    primaryKey({ columns: [table.userId, table.conversationId] }),
    foreignKey({ name: "conversation_summaries_through_message_fk",
        columns: [table.userId, table.conversationId, table.throughMessageId],
        foreignColumns: [chatMessagesTable.userId, chatMessagesTable.conversationId, chatMessagesTable.id],
    }).onDelete("cascade"),
    check("conversation_summaries_content_check", sql`length(btrim(${table.summary})) > 0`),
]);

/** Readable, authoritative memories. Event time, validity and retention differ. */
export const userMemoriesTable = pgTable("user_memories", {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").notNull().references(() => userTable.id, { onDelete: "cascade" }),
    content: text("content").notNull(),
    origin: contextOrigin("origin").notNull(),
    sourceMessageId: uuid("source_message_id"),
    retention: memoryRetention("retention").notNull(),
    status: contextStatus("status").notNull().default("active"),
    eventAt: timestamp("event_at", { withTimezone: true }),
    validFrom: timestamp("valid_from", { withTimezone: true }).notNull().defaultNow(),
    validUntil: timestamp("valid_until", { withTimezone: true }),
    expiresAt: timestamp("expires_at", { withTimezone: true }),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
}, (table) => [
    index("user_memories_user_status_retention_idx").on(table.userId, table.status, table.retention),
    index("user_memories_expiry_idx").on(table.expiresAt).where(sql`${table.expiresAt} IS NOT NULL`),
    index("user_memories_source_idx").on(table.userId, table.sourceMessageId),
    foreignKey({ name: "user_memories_source_fk", columns: [table.userId, table.sourceMessageId],
        foreignColumns: [chatMessagesTable.userId, chatMessagesTable.id] }).onDelete("cascade"),
    check("user_memories_content_check", sql`length(btrim(${table.content})) > 0`),
    check("user_memories_short_term_expiry_check", sql`${table.retention} <> 'short_term' OR ${table.expiresAt} IS NOT NULL`),
    check("user_memories_expiry_check", sql`${table.expiresAt} IS NULL OR ${table.expiresAt} > ${table.createdAt}`),
    check("user_memories_validity_check", sql`${table.validUntil} IS NULL OR ${table.validUntil} > ${table.validFrom}`),
]);

/** Rebuildable vectors, versioned by model identifier; ownership comes from memory. */
export const memoryEmbeddingsTable = pgTable("memory_embeddings", {
    memoryId: uuid("memory_id").notNull().references(() => userMemoriesTable.id, { onDelete: "cascade" }),
    model: text("model").notNull(),
    dimensions: integer("dimensions").notNull(),
    embedding: embeddingVector("embedding").notNull(),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
}, (table) => [
    primaryKey({ columns: [table.memoryId, table.model] }),
    check("memory_embeddings_model_check", sql`length(btrim(${table.model})) > 0`),
    check("memory_embeddings_dimensions_check", sql`${table.dimensions} > 0 AND vector_dims(${table.embedding}) = ${table.dimensions}`),
]);

export type UserContextFact = typeof userContextFactsTable.$inferSelect;
export type NewUserContextFact = typeof userContextFactsTable.$inferInsert;
export type ConversationSummary = typeof conversationSummariesTable.$inferSelect;
export type NewConversationSummary = typeof conversationSummariesTable.$inferInsert;
export type UserMemory = typeof userMemoriesTable.$inferSelect;
export type NewUserMemory = typeof userMemoriesTable.$inferInsert;
export type MemoryEmbedding = typeof memoryEmbeddingsTable.$inferSelect;
export type NewMemoryEmbedding = typeof memoryEmbeddingsTable.$inferInsert;
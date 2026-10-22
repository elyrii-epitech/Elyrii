import { and, eq, sql } from "drizzle-orm";
import { chatMessagesTable as messages } from "../../config/db/chat.table";

/** Source text stays in chat history, but expired context must not leak through a raw tail. */
export function contextSourceEligible(now = new Date()) {
    return and(eq(messages.contextSuppressed, false), sql`NOT EXISTS (
        SELECT 1 FROM user_memories expiring WHERE expiring.source_message_id = ${messages.id}
        AND expiring.user_id = ${messages.userId}
        AND (expiring.expires_at <= ${now} OR expiring.valid_until <= ${now}))`);
}
/** Conservatively withhold a summary until cleanup invalidates its expired sources. */
export function conversationHasExpiredContext(userId: string, conversationId: string, now = new Date()) {
    return sql<boolean>`EXISTS (SELECT 1 FROM user_memories expiring JOIN chat_messages source ON source.id = expiring.source_message_id
        AND source.user_id = expiring.user_id WHERE expiring.user_id = ${userId}::uuid AND source.conversation_id = ${conversationId}
        AND (expiring.expires_at <= ${now} OR expiring.valid_until <= ${now}))`;
}

/** Revision validity is independent from exclusion of future automatic processing. */
export function derivedSourceEligible(table: { userId: import("drizzle-orm/pg-core").AnyPgColumn; sourceKind: import("drizzle-orm/pg-core").AnyPgColumn;
    sourceId: import("drizzle-orm/pg-core").AnyPgColumn; sourceRevision: import("drizzle-orm/pg-core").AnyPgColumn }) {
    return sql`(${table.sourceKind} IS NULL OR EXISTS (SELECT 1 FROM context_source_versions provenance
        WHERE provenance.user_id = ${table.userId} AND provenance.kind = ${table.sourceKind}
        AND provenance.source_id = ${table.sourceId} AND provenance.revision = ${table.sourceRevision} AND provenance.active))`;
}

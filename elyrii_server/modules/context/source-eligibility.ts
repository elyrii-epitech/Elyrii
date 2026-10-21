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

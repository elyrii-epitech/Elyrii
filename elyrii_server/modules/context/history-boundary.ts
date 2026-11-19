import { sql } from "drizzle-orm";
import { chatMessagesTable as messages } from "../../config/db/chat.table";

/** Compare stored tuples without losing PostgreSQL microseconds through a Date. */
export function historyBoundary(boundaryId: string, relation: "after" | "before" | "through") {
    const operator = { after: sql`>`, before: sql`<`, through: sql`<=` }[relation];
    return sql<boolean>`(${messages.createdAt}, ${messages.id}) ${operator} (
        SELECT boundary.created_at, boundary.id FROM chat_messages boundary
        WHERE boundary.id = ${boundaryId}::uuid
            AND boundary.user_id = ${messages.userId}
            AND boundary.conversation_id = ${messages.conversationId}
    )`;
}

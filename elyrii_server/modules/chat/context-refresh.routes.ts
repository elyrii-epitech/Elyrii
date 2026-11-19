import { Hono } from "hono";
import { bodyLimit } from "hono/body-limit";
import { and, eq } from "drizzle-orm";
import { db } from "../../config/db.config";
import { chatMessagesTable as messages } from "../../config/db/chat.table";
import { ContextRetrievalService } from "../context/retrieval.service";
import { bounded, contextEnabled, metric, verifyTicket } from "./context-dispatch";

/** Short-lived, signed capability; caller cannot choose another owner or source. */
export function createContextRefreshRouter(database = db, retrieval = new ContextRetrievalService()) {
    const router = new Hono();
    router.use("*", bodyLimit({ maxSize: 3000 }));
    router.post("/refresh", async c => {
        c.header("Cache-Control", "no-store");
        if (!contextEnabled()) return c.json({ error: "Context disabled" }, 503);
        let identity;
        try { identity = verifyTicket((await c.req.json()).ticket); }
        catch { return c.json({ error: "Context unavailable" }, 401); }
        const started = performance.now();
        try {
            const response = await bounded((async () => {
                const [source] = await database.select().from(messages).where(and(eq(messages.id, identity.sourceMessageId),
                    eq(messages.userId, identity.userId), eq(messages.conversationId, identity.conversationId),
                    eq(messages.role, "user"), eq(messages.contextSuppressed, false)));
                if (!source) return null;
                let sections = null;
                try { sections = await bounded(retrieval.retrieve(identity.userId, { conversationId: identity.conversationId,
                    currentMessageId: source.id, query: source.message }), 3000); } catch { /* Valid source can still receive ordinary chat. */ }
                if (sections && Buffer.byteLength(JSON.stringify(sections)) > 500000) sections = null;
                // Source deletion/correction during embedding must also invalidate the input.
                const [current] = await database.select({ message: messages.message }).from(messages).where(and(eq(messages.id, source.id),
                    eq(messages.userId, identity.userId), eq(messages.conversationId, identity.conversationId), eq(messages.contextSuppressed, false)));
                if (!current || current.message !== source.message) return null;
                return { version: 1, userId: identity.userId, conversationId: identity.conversationId, sourceMessageId: source.id, query: source.message, sections };
            })());
            metric("refresh", started, response ? "ok" : "removed");
            return response ? c.json(response) : c.json({ error: "Source unavailable" }, 410);
        } catch { metric("refresh", started, "failure"); return c.json({ error: "Context unavailable" }, 503); }
    });
    return router;
}

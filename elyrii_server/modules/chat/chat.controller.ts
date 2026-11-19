import { Hono } from "hono";
import { upgradeWebSocket } from "hono/bun";
import { z } from "zod";
import { randomUUID } from "node:crypto";
import { sendMessageToTopic } from "./producer.service";
import { resolveWsIdentity } from "../../utils/ws-auth.utils";
import { authMiddleware } from "../../middleware/auth.middleware";
import ChatRepository from "../../repository/chat.repository";
import { ContextLifecycleRepository } from "../../repository/context-lifecycle.repository";
import type { HonoEnv } from "../../utils/hono.types";
import { bounded, prepareContext } from "./context-dispatch";
import { chatDelivery } from "./chat-delivery";

const router = new Hono<HonoEnv>();
const repository = new ChatRepository();
const conversation = z.string().min(1).max(200);
const pageSchema = z.object({limit: z.coerce.number().int().min(1).max(50).default(50),
    beforeDate: z.iso.datetime().optional(), beforeId: conversation.optional()})
    .refine(p => Boolean(p.beforeDate) === Boolean(p.beforeId));
const inputSchema = z.object({message: z.string().trim().min(1).max(16000),
    conversationId: conversation, requestId: z.uuid(), messageId: z.uuid().optional()});

router.get("/health", c => c.json({message: "Chat service is healthy"}));
router.use("/history", authMiddleware);
router.use("/conversations", authMiddleware);
router.use("/conversations/*", authMiddleware);
router.onError((error, c) => {
    if (error instanceof z.ZodError || error instanceof SyntaxError) return c.json({error: "Invalid chat request"}, 400);
    console.error("[Chat] History operation failed");
    return c.json({error: "Chat unavailable"}, 500);
});
router.get("/conversations", async c => {
    const page = pageSchema.parse(c.req.query());
    c.header("Cache-Control", "no-store");
    return c.json(await repository.getConversations(c.get("user").userId, page.limit,
        page.beforeDate && page.beforeId ? {updatedAt: new Date(page.beforeDate), id: page.beforeId} : undefined));
});
router.delete("/conversations/:id", async c => {
    await new ContextLifecycleRepository().deleteMessages(c.get("user").userId, {conversationId: conversation.parse(c.req.param("id"))});
    return c.body(null, 204);
});
router.get("/history", async c => {
    const query = z.object({limit: z.coerce.number().int().min(1).max(200).default(50),
        conversationId: conversation.optional(), beforeId: z.uuid().optional()}).parse(c.req.query());
    if (query.beforeId && !query.conversationId) return c.json({error: "Conversation required"}, 400);
    c.header("Cache-Control", "no-store");
    return c.json(await repository.getHistory(c.get("user").userId, query.limit, query.conversationId, query.beforeId));
});
router.get("/ws", upgradeWebSocket(async c => {
    const authorization = c.req.header("Authorization");
    const allowInsecure = Bun.env.NODE_ENV !== "production" && Bun.env.ALLOW_INSECURE_WS_USER_ID === "true";
    const identity = await resolveWsIdentity(c.req.url, authorization, allowInsecure);
    if (!identity) return {onOpen: (_, ws) => ws.close(1008, "Unauthorized")};
    const userId = identity.userId;
    return {
        onClose: (_, ws) => chatDelivery.cancelSocket(ws),
        onMessage: async (event, ws) => {
            let input: z.infer<typeof inputSchema>;
            try {
                if (event.data.toString().length > 100000) throw new Error("Oversized frame");
                input = inputSchema.parse(JSON.parse(event.data.toString()));
            } catch {
                ws.close(1003, "Invalid chat message");
                return;
            }
            if (!await resolveWsIdentity(c.req.url, authorization, allowInsecure)) {
                chatDelivery.cancelSocket(ws);
                ws.close(1008, "Unauthorized");
                return;
            }
            const key = randomUUID();
            let registered = false;
            try {
                const persisted = await repository.createMessage({id: input.messageId ?? input.requestId,
                    userId, conversationId: input.conversationId, role: "user", message: input.message}, key);
                const completed = await repository.getReply(userId, persisted.id);
                if (completed) {
                    ws.send(JSON.stringify({type: "reply", requestId: input.requestId, conversationId: input.conversationId,
                        message: completed.message, messageId: completed.id, createdAt: completed.createdAt.toISOString()}));
                    return;
                }
                chatDelivery.register(key, {userId, conversationId: input.conversationId, sourceMessageId: persisted.id,
                    requestId: input.requestId, socket: ws});
                registered = true;
                const context = await prepareContext(userId, input.conversationId, persisted.id, input.message);
                let history: Array<{role: string; message: string}> = [];
                try { history = await bounded(repository.getRecentMessagesForContext(userId, input.conversationId, 12, persisted.id), 1000); }
                catch { console.warn("[Chat] History unavailable; using current input only"); }
                await sendMessageToTopic(userId, input.message, {conversationId: input.conversationId,
                    history, requestId: key, sourceMessageId: persisted.id, context});
            } catch {
                // Persistence and capacity failures occur before registration.
                if (!chatDelivery.finish(key, userId, input.conversationId, "error", "L’envoi a échoué. Tu peux réessayer.") &&
                    !registered && ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify({type: "error", requestId: input.requestId,
                    conversationId: input.conversationId, message: "L’envoi a échoué. Tu peux réessayer."}));
            }
        },
    };
}));
export default router;

import { Hono } from "hono";
import { describeRoute } from "hono-openapi";
import { upgradeWebSocket } from "hono/bun";
import { clientSockets } from "../../main";
import { sendMessageToTopic } from "./producer.service";
import { resolveWsIdentity } from "../../utils/ws-auth.utils";
import { authMiddleware } from "../../middleware/auth.middleware";
import ChatRepository from "../../repository/chat.repository";
import type { HonoEnv } from "../../utils/hono.types";
import { aiResponseTracker } from "./response-tracker.utils";
import { randomUUIDv7 } from "bun";
import { chatResponse } from "./chat-protocol";


const chatRouter = new Hono<HonoEnv>();
const chatRepository = new ChatRepository();

// Only enable userId query auth when explicitly requested for local development.
const allowInsecureWsUserIdFallback =
    Bun.env.ALLOW_INSECURE_WS_USER_ID === "true"
        ? true
        : false;

console.log(`[Chat] Insecure WS userId fallback enabled: ${allowInsecureWsUserIdFallback}`);

chatRouter.get("/health", describeRoute({
    summary: "Health check endpoint for chat",
    description: "Health check endpoint for chat",
    tags: ["Chat"],
    responses: {
        200: {
            description: "Chat service is healthy",
        },
    },
}), (ctx) => {
    return ctx.json({message: "Chat service is healthy"});
})

chatRouter.use("/history", authMiddleware);

chatRouter.get("/history", describeRoute({
    summary: "Get chat history",
    description: "Retrieve persisted chat history for the authenticated user.",
    tags: ["Chat"],
    responses: {
        200: {
            description: "Chat history returned",
        },
    },
}), async (ctx) => {
    const userId = ctx.get("user").userId;
    const limitRaw = ctx.req.query("limit");
    const conversationId = ctx.req.query("conversationId") || undefined;
    const limit = Math.min(Math.max(Number(limitRaw || 50), 1), 200);
    const history = await chatRepository.getHistory(userId, limit, conversationId);
    return ctx.json(history, 200);
});

chatRouter.get("/ws", describeRoute({
    summary: "WebSocket endpoint for chat",
    description: "WebSocket endpoint for chat",
    tags: ["Chat"],
    responses: {
        200: {
            description: "WebSocket connection established",
        },
        400: {
            description: "Invalid request",
        },
    },
}), upgradeWebSocket(async (ctx) => {
    try {
        const parsedUrl = new URL(ctx.req.url, "http://localhost");
        const defaultConversationId = parsedUrl.searchParams.get("conversationId") || "default";
        
        const identity = await resolveWsIdentity(
            ctx.req.url,
            ctx.req.header("Authorization") ?? ctx.req.header("authorization"),
            allowInsecureWsUserIdFallback,
        );

        if (!identity) {
            console.warn(`[Chat] Unauthorized WS connection attempt from ${ctx.req.url}`);
            return {
                onOpen: (_event, ws) => {
                    console.log("[Chat] Closing unauthorized connection");
                    ws.close(1008, "Unauthorized");
                },
            };
        }

        const userId = identity.userId;

        return {
            onOpen: async (event, ws) => {
                console.log(`[Chat] Client connected: ${userId} (auth: ${identity.source})`);
                clientSockets.set(userId, ws);
            },
            onClose: (event, ws) => {
                console.log(`[Chat] Client disconnected: ${userId}`);
                clientSockets.delete(userId);
            },
            onMessage: async (event, ws) => {
                console.log(`[Chat] Message received from ${userId}: ${event.data}`);
                const rawMessage = event.data.toString();
                let message = rawMessage;
                let conversationId = defaultConversationId;
                let clientRequestId: string | undefined;

                try {
                    const parsed = JSON.parse(rawMessage) as { message?: string; conversationId?: string; requestId?: string };
                    if (typeof parsed.message === "string" && parsed.message.trim().length > 0) {
                        message = parsed.message.trim();
                    }
                    if (typeof parsed.conversationId === "string" && parsed.conversationId.trim().length > 0) {
                        conversationId = parsed.conversationId.trim();
                    }
                    if (typeof parsed.requestId === "string" && parsed.requestId.length > 0 && parsed.requestId.length <= 128) {
                        clientRequestId = parsed.requestId;
                    }
                } catch {
                    console.log("[Chat] Parsing failed, using message as plain text");
                }

                try {
                    console.log(`[Chat] Persisting message for ${userId}...`);
                    await chatRepository.createMessage({
                        userId,
                        conversationId,
                        role: "user",
                        message,
                    });
                } catch (error) {
                    console.error("[Chat] Failed to persist user chat message:", error);
                }

                try {
                    console.log(`[Chat] Getting history and sending to Kafka for ${userId}...`);
                    const history = await chatRepository.getRecentMessagesForContext(userId, conversationId, 12);
                    // Server-generated Kafka keys prevent client IDs colliding across users.
                    const requestId = randomUUIDv7();
                    const aiResponse = await aiResponseTracker.request(requestId, () =>
                        sendMessageToTopic(userId, message, { conversationId, history, requestId })
                    );
                    if (ws.readyState === WebSocket.OPEN) {
                        ws.send(chatResponse("reply", aiResponse, conversationId, clientRequestId));
                    }
                } catch (error) {
                    console.error("[Chat] Message dispatch or AI wait failed:", error);
                    try {
                        await chatRepository.createMessage({
                            userId,
                            conversationId,
                            role: "system",
                            message: "Message dispatch failed",
                        });
                    } catch (_err) {
                        // Ignore persistence error
                    }
                    if (ws.readyState === WebSocket.OPEN) {
                        ws.send(chatResponse("error", "Une erreur est survenue lors de l'envoi du message.", conversationId, clientRequestId));
                    }
                }
            },
        }
    } catch (error) {
        console.error("[Chat] Fatal error during WebSocket upgrade:", error);
        return {
            onOpen: (_event, ws) => {
                ws.close(1011, "Internal Server Error during upgrade");
            }
        };
    }
}))

export default chatRouter;

import { Hono } from "hono";
import { describeRoute } from "hono-openapi";
import { upgradeWebSocket } from "hono/bun";
import { clientSockets } from "../../main";
import { sendMessageToTopic } from "./producer.service";
import { resolveWsIdentity } from "../../utils/ws-auth.utils";
import { authMiddleware } from "../../middleware/auth.middleware";
import ChatRepository from "../../repository/chat.repository";
import type { HonoEnv } from "../../utils/hono.types";


const chatRouter = new Hono<HonoEnv>();
const chatRepository = new ChatRepository();
const allowInsecureWsUserIdFallback =
    Bun.env.ALLOW_INSECURE_WS_USER_ID === "true"
        ? true
        : Bun.env.ALLOW_INSECURE_WS_USER_ID === "false"
            ? false
            : Bun.env.NODE_ENV !== "production";

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
    const limit = Math.min(Math.max(Number(limitRaw || 50), 1), 200);
    const history = await chatRepository.getHistory(userId, limit);
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
    const identity = await resolveWsIdentity(
        ctx.req.url,
        ctx.req.header("Authorization") ?? ctx.req.header("authorization"),
        allowInsecureWsUserIdFallback,
    );

    if (!identity) {
        return {
            onOpen: (_event, ws) => {
                ws.close(1008, "Unauthorized");
            },
        };
    }

    const userId = identity.userId;

    return {
        onOpen: async (event, ws) => {
            console.log("Client connected: ", userId, `(auth: ${identity.source})`);
            clientSockets.set(userId, ws);
        },
        onClose: (event, ws) => {
            console.log("Client disconnected: ", userId);
            clientSockets.delete(userId);
        },
        onMessage: async (event, ws) => {
            const message = event.data.toString();
            try {
                await chatRepository.createMessage({
                    userId,
                    role: "user",
                    message,
                });
            } catch (error) {
                console.error("Failed to persist user chat message:", error);
            }
            try {
                await sendMessageToTopic(userId, message);
            } catch (error) {
                try {
                    await chatRepository.createMessage({
                        userId,
                        role: "system",
                        message: "Message dispatch failed",
                    });
                } catch (_err) {
                    // Ignore persistence error
                }
                ws.send(JSON.stringify({ from: "system", error: "Message dispatch failed" }));
            }
            // Optional: somehow store the messages.
        },
    }
}))

export default chatRouter;

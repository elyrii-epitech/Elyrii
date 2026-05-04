import { Hono } from "hono";
import { describeRoute } from "hono-openapi";
import { upgradeWebSocket } from "hono/bun";
import { clientSockets } from "../../main";
import { sendMessageToTopic } from "./producer.service";
import { resolveWsIdentity } from "../../utils/ws-auth.utils";


const chatRouter = new Hono();
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
            onOpen: (_event: unknown, ws: WebSocket) => {
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
                await sendMessageToTopic(userId, message);
            } catch (error) {
                ws.send(JSON.stringify({ from: "system", error: "Message dispatch failed" }));
            }
            // Optional: somehow store the messages.
        },
    }
}))

export default chatRouter;

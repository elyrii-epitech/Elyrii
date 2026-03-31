import { Hono } from "hono";
import { describeRoute } from "hono-openapi";
import { upgradeWebSocket } from "hono/bun";
import { clientSockets } from "../../main";
import { sendMessageToTopic } from "./producer.service";


const chatRouter = new Hono();

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
    const url = new URL(ctx.req.url, `http://${ctx.req.header("host")}`);
    const userId = url.searchParams.get("userId");

    return {
        onOpen: async (event, ws) => {
            console.log("Client connected: ", userId);
            if (!userId) return;
            clientSockets.set(userId, ws);
        },
        onClose: (event, ws) => {
            console.log("Client disconnected: ", userId);
            if (!userId) return;
            clientSockets.delete(userId);
        },
        onMessage: async (event, ws) => {
            const message = event.data.toString();
            if (!userId) return;
            await sendMessageToTopic(userId, message);
            // Optional: somehow store the messages.
        },
    }
}))

export default chatRouter;
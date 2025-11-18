/**
 * @module ChatService
 * Real-time chat service with WebSocket support and Kafka integration
 */

import { Hono } from "hono"
import type { WSContext } from "hono/ws";
import { upgradeWebSocket, websocket } from "hono/bun";
import { swaggerUI } from "@hono/swagger-ui";
import { initKafka } from "./src/service/kafka.service";
import { kafkaService } from "./src/service/kafka.service";
import { describeRoute, openAPIRouteHandler } from "hono-openapi";
import { handleAiResponse } from "./src/service/consumer.service";
import { sendMessageToTopic } from "./src/service/producer.service";

/**
 * Map to store active WebSocket connections indexed by user ID
 * @type {Map<string, WSContext>}
 */
export const clientSockets = new Map<string, WSContext>();

const app = new Hono().basePath("/chat");

app.get("/health", describeRoute({
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

app.get("/ws", describeRoute({
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

app.get("/openapi.json", openAPIRouteHandler(app, {
    documentation: {
        info: {
            title: "Elyrii Chat Service",
            version: "1.0.0",
            description: "API contract for the Elyrii chat microservice."
        },
        servers: [
            {
                url: Bun.env.CHAT_SERVICE_PUBLIC_URL ?? "http://localhost:3002/",
                description: "Current deployment base URL"
            }
        ],
        tags: [
            { name: "Chat", description: "Chat service endpoints" }
        ]
    }
}))

app.get("/swag", swaggerUI({
    url: "/chat/openapi.json",
    title: "Elyrii Chat Service API",
}))

initKafka().catch((err) => console.error("Failed to initialize Kafka: ", err));
handleAiResponse().catch((err) => console.error("Failed to initialize Kafka consumer: ", err));

process.on("SIGINT", async () => {
    console.log("Chat service is shutting down");
    await Promise.all([
        kafkaService.producer.disconnect(),
        kafkaService.consumer.disconnect()
    ]);
    process.exit(0);
});

process.on("SIGTERM", async () => {
    console.log("Chat service is shutting down");
    await Promise.all([
        kafkaService.producer.disconnect(),
        kafkaService.consumer.disconnect()
    ]);
    process.exit(0);
});

Bun.serve({
    port: 3002,
    fetch: app.fetch,
    websocket
})

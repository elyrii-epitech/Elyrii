import { Hono } from "hono"
import type { WSContext } from "hono/ws";
import { upgradeWebSocket, websocket } from "hono/bun";
import { initKafka } from "./src/service/kafka.service";
import { kafkaService } from "./src/service/kafka.service";
import { sendMessageToTopic } from "./src/service/producer.service";
import { handleAiResponse } from "./src/service/consumer.service";

export const clientSockets = new Map<string, WSContext>();

const app = new Hono().basePath("/chat");

app.get("/health", (ctx) => {
    return ctx.json({message: "Chat service is healthy"});
})

app.get("/ws", upgradeWebSocket(async (ctx) => {
    const url = new URL(ctx.req.url, `http://${ctx.req.header("host")}`);
    const userId = url.searchParams.get("userId");

    return {
        onOpen: async (event, ws) => {
            console.log("Client connected");
            if (!userId) return;
            clientSockets.set(userId, ws);
        },
        onClose: (event, ws) => {
            console.log("Client disconnected");
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

initKafka().catch((err) => console.error(err));
handleAiResponse().catch((err) => console.error(err));

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

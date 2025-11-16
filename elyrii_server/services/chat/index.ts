import { Hono } from "hono"
import { chatHistory } from "./src/chat.controller";
import { upgradeWebSocket, websocket } from "hono/bun";
import { kafkaService } from "./src/service/kafka.service";
import run from "./src/utils/test";

const app = new Hono().basePath("/chat");

const wsClients = new Map<string, any>();

app.get("/history", ...chatHistory);
app.get("/health", (ctx) => {
    return ctx.json({message: "Chat service is healthy"});
})
app.get("/test", async (ctx) => {
    await run();
    return ctx.json({message: "Hello"});
})
app.get("/ws", upgradeWebSocket(async (ctx) => {
    return {
        onOpen: async (event, ws) => {
            console.log("Client connected");
            //await kafkaService.producer.connect(); 
            ws.send("Hello");
              
            await kafkaService.producer.send({
                    topic: "elyrii.ai.requests",
                    messages: [{
                        key: "userId",
                        value: JSON.stringify({
                            userID: "userId",
                            message: "Hello nigga",
                            timestamp: new Date().toISOString(),
                        }),
                    },],
            });
            
        },
        onClose: (event, ws) => {
            console.log("Client disconnected");
        },
        onMessage: async (event, ws) => {
            const message = event.data.toString();
            console.log("Client message: ", event.data);
            // add message handling with the ai directly here
            ws.send("Hello " + event.data.toString());
            // After sending back to the user store in the db or in a different process duplicate the message and save it in the db
        },
    }
}))

Bun.serve({
    port: 3002,
    fetch: app.fetch,
    websocket
})

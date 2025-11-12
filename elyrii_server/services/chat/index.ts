import { upgradeWebSocket, websocket } from "hono/bun"
import { Hono } from "hono"
import { chatHistory } from "./src/chat.controller";

const app = new Hono().basePath("/chat");

app.get("/history", ...chatHistory);
app.get("/ws", upgradeWebSocket(async (ctx) => {
    return {
        onOpen: (event, ws) => {
            console.log("Client connected");
            ws.send("Hello");
        },
        onClose: (event, ws) => {
            console.log("Client disconnected");
        },
        onMessage: (event, ws) => {
            console.log("Client message: ", event.data);
            ws.send("Hello " + event.data);
        },
    }
}))

Bun.serve({
    port: 3003,
    fetch: app.fetch,
    websocket
})
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
        onMessage: async (event, ws) => {
            console.log("Client message: ", event.data);
            // add message handling with the ai directly here
            ws.send("Hello " + event.data);
            // After sending back to the user store in the db or in a different process duplicate the message and save it in the db
        },
    }
}))

Bun.serve({
    port: 3003,
    fetch: app.fetch,
    websocket
})
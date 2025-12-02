import { Hono } from "hono";
import { logger } from "hono/logger";
import { upgradeWebSocket } from "hono/bun";
import { proxyRequest } from "./service/gateway.service";

const app = new Hono();

const CHAT_SERVICE_URL = Bun.env.CHAT_SERVICE_URL;
const AUTH_SERVICE_URL = Bun.env.AUTH_SERVICE_URL;

if (!CHAT_SERVICE_URL) {
    throw new Error("CHAT_SERVICE_URL environment variable is required");
}
if (!AUTH_SERVICE_URL) {
    throw new Error("AUTH_SERVICE_URL environment variable is required");
}
console.log("[Gateway] STARTUP: main.ts loaded");

app.use(logger());

app.get("/ping", (c) => c.text("pong"));

app.get(
    "/chat/ws",
    upgradeWebSocket(async (c) => {
        const userId = c.req.query("userId");

        if (!userId) {
            console.error("[Gateway] Error: No userId provided for WebSocket connection");
        }

        // Replace http/https with ws/wss
        const wsServiceUrl = CHAT_SERVICE_URL.replace(/^http/, "ws");
        const targetUrl = `${wsServiceUrl}/chat/ws?userId=${userId}`;

        console.log(`[Gateway] Proxying WebSocket to: ${targetUrl}`);

        // Create a WebSocket connection to the target service
        const targetWs = new WebSocket(targetUrl);

        // Setup target handlers immediately to not miss events
        let clientWs: WebSocket | null = null;

        targetWs.onopen = () => {
            console.log("[Gateway] Connected to target service");
        };

        targetWs.onmessage = (event) => {
            if (clientWs && clientWs.readyState === WebSocket.OPEN) {
                clientWs.send(event.data);
            }
        };

        targetWs.onclose = () => {
            console.log("[Gateway] Target service closed connection");
            if (clientWs && clientWs.readyState === WebSocket.OPEN) {
                clientWs.close();
            }
        };

        targetWs.onerror = (error) => {
            console.error("[Gateway] Target WebSocket error:", error);
            if (clientWs && clientWs.readyState === WebSocket.OPEN) {
                clientWs.close();
            }
        };

        return {
            onOpen: (event, ws) => {
                console.log("[Gateway] Client connected");
                clientWs = ws.raw as WebSocket;
            },
            onMessage: (event, ws) => {
                if (targetWs.readyState === WebSocket.OPEN) {
                    const data = event.data;
                    if (data instanceof Blob) {
                        data.text().then(text => targetWs.send(text));
                    } else {
                        targetWs.send(data);
                    }
                } else {
                    console.warn("[Gateway] Target not ready, dropping message");
                }
            },
            onClose: (event, ws) => {
                console.log("[Gateway] Client disconnected");
                if (targetWs.readyState === WebSocket.OPEN) {
                    targetWs.close();
                }
            },
        };
    })
);

app.all("/chat/*", async (ctx) => {
    return proxyRequest(CHAT_SERVICE_URL, ctx);
});

app.all("/auth/*", async (ctx) => {
    return proxyRequest(AUTH_SERVICE_URL, ctx);
});

export default app;

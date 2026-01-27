import { Hono } from "hono";
import { logger } from "hono/logger";
import { upgradeWebSocket } from "hono/bun";
import { proxyRequest } from "./service/gateway.service";
import { checkEnvVars } from "./utils/utils";

const app = new Hono();

const envVars = checkEnvVars();

if (!envVars) {
    throw new Error("Service URLs are required");
}
const {
    CHAT_SERVICE_URL,
    AUTH_SERVICE_URL,
    JOURNAL_SERVICE_URL,
} = envVars;

app.use(logger());

app.get(
    "/chat/ws",
    upgradeWebSocket((c) => {
        const userId = c.req.query("userId");
        const targetUrl = `${CHAT_SERVICE_URL.replace(/^http/, "ws")}/chat/ws?userId=${userId}`;
        const targetWs = new WebSocket(targetUrl);

        if (!userId) {
            console.error("[Gateway] Error: No userId provided for WebSocket connection");
            return {
                onOpen: (_, ws) => {
                    ws.close(1008, "No userId provided");
                },
            };
        }

        return {
            onOpen: (_, ws) => {
                targetWs.onmessage = (event) => ws.send(event.data);
                targetWs.onclose = () => ws.close();
            },
            onMessage: async (event) => {
                const data = event.data instanceof Blob ? await event.data.text() : event.data;
                if (targetWs.readyState === WebSocket.OPEN) {
                    targetWs.send(data);
                }
            },
            onClose: () => targetWs.close(),
        };
    })
);

app.all("/chat/*", (ctx) => proxyRequest(CHAT_SERVICE_URL, ctx));
app.all("/auth/*", (ctx) => proxyRequest(AUTH_SERVICE_URL, ctx));
app.all("/journal/*", (ctx) => proxyRequest(JOURNAL_SERVICE_URL, ctx));

export default app;

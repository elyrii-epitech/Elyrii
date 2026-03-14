/**
 * Gateway Service Main Application
 *
 * @remarks
 * This service acts as the single entry point for the Elyrii backend.
 * It routes requests to the appropriate microservices:
 * - `/auth/*` -> Auth Service
 * - `/chat/*` -> Chat Service (including WebSocket upgrades)
 * - `/journal/*` -> Journal Service
 * - `/challenge/*` -> Quest Service
 */
import { Hono } from "hono";
import { logger } from "hono/logger";
import { upgradeWebSocket } from "hono/bun";
import { openAPIRouteHandler, describeRoute } from "hono-openapi";
import { swaggerUI } from "@hono/swagger-ui";
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
    USER_SERVICE_URL,
    QUEST_SERVICE_URL,
} = envVars;

app.use(logger());

app.get(
    "/chat/ws",
    describeRoute({
        summary: "Chat WebSocket",
        description: "WebSocket connection for real-time chat. Requires `userId` query parameter.",
        tags: ["Chat"],
        responses: {
            101: { description: "Switching Protocols" },
            1008: { description: "Policy Violation (Missing userId)" }
        }
    }),
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

app.all("/chat/*", describeRoute({
    summary: "Chat Service Proxy",
    description: "Proxies requests to the Chat Service.",
    tags: ["Chat"]
}), (ctx) => proxyRequest(CHAT_SERVICE_URL, ctx));

app.all("/auth/*", describeRoute({
    summary: "Auth Service Proxy",
    description: "Proxies requests to the Auth Service.",
    tags: ["Auth"]
}), (ctx) => proxyRequest(AUTH_SERVICE_URL, ctx));

app.all("/journal/*", describeRoute({
    summary: "Journal Service Proxy",
    description: "Proxies requests to the Journal Service.",
    tags: ["Journal"]
}), (ctx) => proxyRequest(JOURNAL_SERVICE_URL, ctx));

app.all("/user/*", (ctx) => proxyRequest(USER_SERVICE_URL, ctx));

app.all("/challenge/*", describeRoute({
    summary: "Quest Service Proxy",
    description: "Proxies requests to the Quest Service (Challenges).",
    tags: ["Quest"]
}), (ctx) => proxyRequest(QUEST_SERVICE_URL, ctx));

app.get("/openapi.json", openAPIRouteHandler(app, {
    documentation: {
        info: {
            title: "Elyrii API Gateway",
            version: "1.0.0",
            description: "Entry point for Elyrii microservices."
        },
        servers: [
            {
                url: Bun.env.GATEWAY_PUBLIC_URL ?? "http://localhost:3000",
                description: "Gateway Server"
            }
        ]
    }
}));

app.get("/swagger", swaggerUI({
    url: "/openapi.json"
}));

export default app;

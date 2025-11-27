import { Hono } from "hono";
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

app.all("/chat/*", async (ctx) => {
    return proxyRequest(CHAT_SERVICE_URL, ctx);
});

app.all("/auth/*", async (ctx) => {
    return proxyRequest(AUTH_SERVICE_URL, ctx);
});

export default app;

import app from "./main";
import { websocket } from "hono/bun";

Bun.serve({
    port: process.env.PORT || 3000,
    fetch: app.fetch,
    websocket
});

import app from "./main";
import { websocket } from "hono/bun";

Bun.serve({
    port: 3000,
    fetch: app.fetch,
    websocket
});

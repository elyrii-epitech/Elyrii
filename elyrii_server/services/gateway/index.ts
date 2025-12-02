import app from "./src/main";
import { websocket } from "hono/bun";

Bun.serve({
  port: Bun.env.GATEWAY_PORT || 3000,
  fetch: app.fetch,
  websocket
})

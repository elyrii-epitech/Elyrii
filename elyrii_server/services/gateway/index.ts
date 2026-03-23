import { websocket } from "hono/bun";
import app from "./src/main";

Bun.serve({
  port: Bun.env.GATEWAY_PORT || 3000,
  fetch: app.fetch,
  websocket
})

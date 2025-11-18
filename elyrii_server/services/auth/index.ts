import app from "./src/main";

Bun.serve({
    port: Bun.env.AUTH_PORT || 3001,
    fetch: app.fetch
});

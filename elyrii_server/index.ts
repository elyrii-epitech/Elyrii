import app from "./main";

Bun.serve({
    port: 3000,
    fetch: app.fetch,
});

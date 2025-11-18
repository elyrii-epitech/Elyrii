import AuthService from "./src/service/auth.service";

Bun.serve({
    port: Bun.env.AUTH_PORT || 3001,
    fetch: new AuthService().service.fetch
});

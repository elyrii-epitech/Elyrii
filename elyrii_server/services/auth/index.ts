import AuthService from "./src/service"

const authService = new AuthService();

Bun.serve({
    port: 3000,
    fetch: authService.getRouter().fetch
})

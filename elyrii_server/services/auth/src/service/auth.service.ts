import { Hono } from "hono";
import { logger } from "hono/logger";

class AuthService {
    private readonly app = new Hono().basePath("/auth");

    constructor() {
        this.useMiddlewares();
        this.initRoutes();
    }

    useMiddlewares() {}

    initRoutes() {
        this.app.get("/", (c) => c.text("Hello World"));
        this.app.get("/health", (c) => c.text("OK"));
    }

    get service() {
        return this.app;
    }
}

export default AuthService;
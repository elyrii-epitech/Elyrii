import { Hono } from "hono";
import AuthController from "../controller/auth.controller";
/**
 * Service responsible for exposing the Auth HTTP API.
 * Configures the underlying Hono application with routes and middlewares.
 */
class AuthService {
    private readonly app = new Hono().basePath("/auth");
    private readonly controller = new AuthController();

    constructor() {
        this.useMiddlewares();
        this.initRoutes();
    }
    /**
     * Registers middlewares used by the auth service.
     * Extend this method to attach authentication and logging middlewares.
     */
    useMiddlewares() {}

    /**
     * Initializes all HTTP routes handled by the auth service.
     * Maps controller handlers to their corresponding endpoints.
     */
    initRoutes() {
        this.app.get("/health", (c) => c.text("Auth Service Healthy"));

        this.app.post("/login", ...this.controller.login);
        this.app.post("/logout", ...this.controller.logout);
        this.app.post("/register", ...this.controller.register);
    }

    /**
     * Exposes the configured Hono application instance.
     */
    get service() {
        return this.app;
    }
}

export default AuthService;
import { Hono } from "hono";
import { openAPIRouteHandler } from "hono-openapi";
import { swaggerUI } from "@hono/swagger-ui";
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

        this.app.get("/openapi.json", openAPIRouteHandler(this.app, {
            documentation: {
                info: {
                    title: "Elyrii Auth Service",
                    version: "1.0.0",
                    description: "Authentication service API"
                },
                servers: [
                    {
                        url: Bun.env.AUTH_SERVICE_PUBLIC_URL ?? "http://localhost:3001/",
                        description: "Local development server"
                    }
                ]
            }
        }));

        this.app.get("/swagger", swaggerUI({
            url: "/auth/openapi.json"
        }));
    }

    /**
     * Exposes the configured Hono application instance.
     */
    get service() {
        return this.app;
    }
}

export default AuthService;
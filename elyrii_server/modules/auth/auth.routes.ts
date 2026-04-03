import { Hono } from "hono";
import { swaggerUI } from "@hono/swagger-ui";
import AuthController from "./auth.controller";
import { openAPIRouteHandler } from "hono-openapi";

class AuthRoutes {
    private readonly router = new Hono();
    private readonly controller = new AuthController();
    
    constructor() {
        this.initRoutes();
    }
    
    public initRoutes() {
        this.router.get('/health', (ctx) => ctx.text("Auth Service healthy"));
        
        this.router.post('/login', ...this.controller.login);
        this.router.post('/register', ...this.controller.register);
        this.router.post('/logout', ...this.controller.logout);
        this.router.get('/refresh', ...this.controller.refreshToken);
        
        this.router.get("/openapi.json", openAPIRouteHandler(this.router, {
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
        
        this.router.get("/swagger", swaggerUI({
            url: "/auth/openapi.json"
        }));
    }
    
    get Router() {
        return this.router;
    }
}

export default AuthRoutes;

import { Hono } from "hono";
import { bodyLimit } from "hono/body-limit";
import { swaggerUI } from "@hono/swagger-ui";
import PasswordResetController from "./password-reset.controller";
import { resetRateLimit } from "./password-reset.rate-limit";
import AuthController from "./auth.controller";
import { openAPIRouteHandler } from "hono-openapi";

class AuthRoutes {
    private readonly router = new Hono();
    private readonly controller = new AuthController();
    private readonly passwordReset = new PasswordResetController();
    
    constructor() {
        this.initRoutes();
    }
    
    public initRoutes() {
        this.router.get('/health', (ctx) => ctx.text("Auth Service healthy"));
        
        this.router.post('/password-reset/request', bodyLimit({maxSize: 1024}), resetRateLimit(10), ...this.passwordReset.request);
        this.router.post('/password-reset/confirm', bodyLimit({maxSize: 4096}), resetRateLimit(30), ...this.passwordReset.confirm);
        this.router.post('/login', ...this.controller.login);
        this.router.post('/register', ...this.controller.register);
        this.router.post('/oauth/google', ...this.controller.googleOAuth);
        this.router.post('/oauth/apple', ...this.controller.appleOAuth);
        this.router.post('/verify-email', ...this.controller.verifyEmail);
        this.router.post('/resend-verification', ...this.controller.resendVerification);
        this.router.post('/logout', ...this.controller.logout);
        this.router.get('/refresh', ...this.controller.refreshToken);
        this.router.post('/refresh', ...this.controller.refreshTokenPost);
        
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

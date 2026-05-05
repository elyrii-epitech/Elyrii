import { Hono } from "hono";
import { swaggerUI } from "@hono/swagger-ui";
import { rateLimiter } from "hono-rate-limiter";
import AuthController from "./auth.controller";
import { openAPIRouteHandler } from "hono-openapi";

import { getConnInfo } from 'hono/bun';

const authRateLimiter = rateLimiter({
    windowMs: 15 * 60 * 1000, // 15 minutes
    limit: 10, // Limit each IP to 10 requests per `window` (here, per 15 minutes).
    standardHeaders: "draft-6", // draft-6: `RateLimit-*` headers; draft-7: combined `RateLimit` header
    keyGenerator: (c) => {
        const xForwardedFor = c.req.header("x-forwarded-for");
        if (xForwardedFor) {
            return xForwardedFor.split(',')[0].trim();
        }

        // Use Hono's getConnInfo helper to extract the remote address
        const connInfo = getConnInfo(c);
        if (connInfo.remote.address) {
            return connInfo.remote.address;
        }

        // Fallback to a static string if IP is completely unresolvable, limiting unknown traffic globally
        return 'unknown-ip';
    },
});

class AuthRoutes {
    private readonly router = new Hono();
    private readonly controller = new AuthController();
    
    constructor() {
        this.initRoutes();
    }
    
    public initRoutes() {
        this.router.get('/health', (ctx) => ctx.text("Auth Service healthy"));
        
        this.router.post('/login', authRateLimiter, ...this.controller.login);
        this.router.post('/register', authRateLimiter, ...this.controller.register);
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

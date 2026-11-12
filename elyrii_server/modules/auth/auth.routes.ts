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
        this.router.post('/register', bodyLimit({maxSize: 8192}), resetRateLimit(10), ...this.controller.register);
        this.router.post('/oauth/google', ...this.controller.googleOAuth);
        this.router.post('/oauth/apple', ...this.controller.appleOAuth);
        this.router.post('/verify-email', bodyLimit({maxSize: 1024}), resetRateLimit(30), ...this.controller.verifyEmail);
        this.router.post('/resend-verification', bodyLimit({maxSize: 1024}), resetRateLimit(10), ...this.controller.resendVerification);
        this.router.get('/verify-email', c => {
            c.header('Cache-Control', 'no-store');
            c.header('Referrer-Policy', 'no-referrer');
            const nonce = crypto.randomUUID();
            c.header('Content-Security-Policy', `default-src 'none'; script-src 'nonce-${nonce}'; connect-src 'self'; style-src 'unsafe-inline'; base-uri 'none'; frame-ancestors 'none'`);
            return c.html(`<!doctype html><html lang="fr"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Activation Elyrii</title><style>body{font:18px system-ui;max-width:32rem;margin:15vh auto;padding:24px;background:#fafafa;color:#242426}h1{font-size:28px}</style><h1>Elyrii</h1><p id="status" role="status">Confirmation de ton adresse…</p><script nonce="${nonce}">
            const token = location.hash.slice(1); history.replaceState(null, '', location.pathname);
            (async () => { try {
                if (!token) throw new Error();
                const response = await fetch(location.pathname, {method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({token})});
                if (!response.ok) throw new Error();
                document.getElementById('status').textContent = 'Adresse confirmée. Tu peux revenir dans Elyrii et te connecter.';
            } catch { document.getElementById('status').textContent = 'Ce lien est invalide ou expiré. Demande un nouveau lien depuis Elyrii.'; } })();
            </script></html>`);
        });
        this.router.post('/logout', bodyLimit({ maxSize: 8192 }), ...this.controller.logout);
        this.router.get('/refresh', ...this.controller.refreshToken);
        this.router.post('/refresh', bodyLimit({ maxSize: 8192 }), ...this.controller.refreshTokenPost);
        
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

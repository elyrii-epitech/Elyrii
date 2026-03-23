import { getSignedCookie } from "hono/cookie";
import { createMiddleware } from "hono/factory";
import { JwtUtils } from "../utils/jwt.utils";

export const authMiddleware = createMiddleware(async (ctx, next) => {
    let token;
    const jwtUtils = new JwtUtils();

    if (Bun.env.ACCESS_JWT_SIGN_KEY) {
        token = await getSignedCookie(ctx, Bun.env.ACCESS_JWT_SIGN_KEY, "access_token");
    }
    
    if (!token) {
        const authHeader = ctx.req.header("Authorization");
        if (authHeader && authHeader.startsWith("Bearer ")) {
            token = authHeader.split(" ")[1];
        }
    }
    
    if (!token) {
        return ctx.json({ error: "No token provided" }, 401);
    }
    
    const decodedToken = await jwtUtils.verifyAccessToken(token);
    if (!decodedToken) {
        return ctx.json({ error: "Invalid or expired token" }, 401);
    }
    
    ctx.set('user', decodedToken);

    await next();
});

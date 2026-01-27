import { getSignedCookie } from "hono/cookie";
import { createMiddleware } from "hono/factory";
import { JwtUtils } from "../utils/jwt.utils";

export const authMiddleware = createMiddleware(async (ctx, next) => {
    let token;
    const jwtUtils = new JwtUtils();

    if (!Bun.env.ACCESS_JWT_SIGN_KEY) {
        throw new Error("COOKIE_SECRET environment variable is not set");
    }
    
    token = await getSignedCookie(ctx, Bun.env.ACCESS_JWT_SIGN_KEY, "access_token");
    
    if (!token) {
        const authHeader = ctx.req.header("Authorization");
        if (authHeader && authHeader.startsWith("Bearer ")) {
            token = authHeader.split(" ")[1];
        }
    }
    
    if (!token) {
        throw new Error("No token provided");
    }
    
    // Implement token verification logic
    const decodedToken = await jwtUtils.verifyAccessToken(token);
    if (!decodedToken) {
        throw new Error("Invalid token");
    }
    
    ctx.set('user', decodedToken);

    await next();
});

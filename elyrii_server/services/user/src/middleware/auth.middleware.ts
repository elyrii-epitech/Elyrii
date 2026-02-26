import { createMiddleware } from "hono/factory";
import { JwtUtils } from "../utils/jwt.utils";

export const authMiddleware = createMiddleware(async (ctx, next) => {
    const authHeader = ctx.req.header("Authorization");

    if (!authHeader || !authHeader.startsWith("Bearer ")) {
        return ctx.json({ error: "No token provided" }, 401);
    }

    const token = authHeader.split(" ")[1];
    const jwtUtils = new JwtUtils();

    const decodedToken = await jwtUtils.verifyAccessToken(token);
    if (!decodedToken) {
        return ctx.json({ error: "Invalid or expired token" }, 401);
    }

    ctx.set("user", decodedToken);
    await next();
});

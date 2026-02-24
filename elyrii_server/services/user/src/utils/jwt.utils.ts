import { verify } from "hono/jwt";

export type TokenPayload = {
    userId: string;
    email: string;
};

export class JwtUtils {
    async verifyAccessToken(token: string): Promise<TokenPayload | null> {
        if (!Bun.env.SECRET_KEY) {
            throw new Error("SECRET_KEY environment variable is not defined");
        }
        try {
            return await verify(token, Bun.env.SECRET_KEY, "HS256") as TokenPayload;
        } catch (error) {
            console.error("Error verifying access token:", error);
            return null;
        }
    }
}

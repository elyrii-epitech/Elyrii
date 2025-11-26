import { sign, verify } from "hono/jwt";

export type TokenPayload = {
    userId: string;
    email: string;
};

export class JwtUtils {
    private static readonly ACCESS_TOKEN_EXP = 60 * 15;
    private static readonly REFRESH_TOKEN_EXP = 60 * 60 * 24 * 30;

    static async generateAccessToken(payload: TokenPayload): Promise<string> {
        if (!Bun.env.SECRET_KEY) {
            throw new Error("SECRET_KEY environment variable is not defined");
        }
        try {
            return await sign({
                ...payload,
                exp: Math.floor(Date.now() / 1000) + this.ACCESS_TOKEN_EXP,
                iat: Math.floor(Date.now() / 1000)
            }, Bun.env.SECRET_KEY, "HS256");
        } catch (error) {
            console.error("Error generating access token:", error);
            throw error;
        }
    }

    static async generateRefreshToken(payload: TokenPayload): Promise<string> {
        if (!Bun.env.REFRESH_SECRET_KEY) {
            throw new Error("REFRESH_SECRET_KEY environment variable is not defined");
        }
        try {
            return await sign({
                ...payload,
                exp: Math.floor(Date.now() / 1000) + this.REFRESH_TOKEN_EXP,
                iat: Math.floor(Date.now() / 1000)
            }, Bun.env.REFRESH_SECRET_KEY, "HS256");
        } catch (error) {
            console.error("Error generating refresh token:", error);
            throw error;
        }
    }

    static async verifyAccessToken(token: string): Promise<TokenPayload | null> {
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

    static async verifyRefreshToken(token: string): Promise<TokenPayload | null> {
        if (!Bun.env.REFRESH_SECRET_KEY) {
            throw new Error("REFRESH_SECRET_KEY environment variable is not defined");
        }
        try {
            return await verify(token, Bun.env.REFRESH_SECRET_KEY, "HS256") as TokenPayload;
        } catch (error) {
            console.error("Error verifying refresh token:", error);
            return null;
        }
    }
}
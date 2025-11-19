import { sign, verify } from "hono/jwt";

export type tokenPayload = {
    userId: string;
    email: string;
};

export const ACCESS_TOKEN_EXP = 60 * 15;

export const generateToken = async (payload: tokenPayload): Promise<string> => {
    try {
        const token = await sign({
            ...payload,
            exp: Math.floor(Date.now() / 1000) + ACCESS_TOKEN_EXP,
            iat: Math.floor(Date.now() / 1000)
        }, Bun.env.SECRET_KEY as string, "HS256");
        return token;
    } catch (error) {
        console.error("Error generating token:", error);
        throw error;
    }
};

export const verifyToken = async (token: string): Promise<tokenPayload | null> => {
    try {
        const payload = await verify(token, Bun.env.SECRET_KEY as string, "HS256");
        return payload as tokenPayload;
    } catch (error) {
        console.error("Error verifying token:", error);
        return null;
    }
};
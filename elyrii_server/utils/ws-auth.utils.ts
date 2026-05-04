import { JwtUtils, type TokenPayload } from "./jwt.utils";

type WsIdentity = {
    userId: string;
    payload?: TokenPayload;
    source: "token" | "query";
}

export function extractBearerToken(authorizationHeader?: string): string | null {
    if (!authorizationHeader) return null;
    if (!authorizationHeader.startsWith("Bearer ")) return null;
    const token = authorizationHeader.slice("Bearer ".length).trim();
    return token.length > 0 ? token : null;
}

export async function resolveWsIdentity(
    requestUrl: string,
    authorizationHeader?: string,
    allowInsecureUserIdFallback = process.env.NODE_ENV !== "production",
): Promise<WsIdentity | null> {
    const parsedUrl = new URL(requestUrl, "http://localhost");
    const token = extractBearerToken(authorizationHeader) || parsedUrl.searchParams.get("token");
    if (token) {
        const payload = await JwtUtils.verifyAccessToken(token);
        if (payload?.userId) {
            return { userId: payload.userId, payload, source: "token" };
        }
    }

    if (!allowInsecureUserIdFallback) {
        return null;
    }

    const userId = parsedUrl.searchParams.get("userId");
    if (!userId) {
        return null;
    }
    return { userId, source: "query" };
}

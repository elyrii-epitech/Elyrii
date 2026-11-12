import { JwtUtils, type TokenPayload } from "./jwt.utils";
import TokenRepository from "../repository/token.repository";

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
    validateSession?: (payload: TokenPayload) => Promise<boolean>,
): Promise<WsIdentity | null> {
    const tokenRepository = new TokenRepository();
    const parsedUrl = new URL(requestUrl, "http://localhost");
    const token = extractBearerToken(authorizationHeader);
    if (token) {
        const payload = await JwtUtils.verifyAccessToken(token);
        if (payload?.userId) {
            try {
                const valid = validateSession
                    ? await validateSession(payload)
                    : await tokenRepository.userExists(payload.userId) &&
                      (!payload.jti || !await tokenRepository.isAccessTokenRevoked(payload.jti));
                if (!valid) return null;
            } catch {
                return null;
            }
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

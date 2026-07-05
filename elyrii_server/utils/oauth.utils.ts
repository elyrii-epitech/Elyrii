export type OAuthProvider = "google" | "apple";

export type OAuthProfile = {
    provider: OAuthProvider;
    providerUserId: string;
    email: string;
    emailVerified: boolean;
    firstName?: string;
    lastName?: string;
};

type JwtHeader = {
    alg?: string;
    kid?: string;
};

type AppleJwk = {
    kty: "RSA";
    kid: string;
    use: "sig";
    alg: "RS256";
    n: string;
    e: string;
};

let appleJwksCache: { keys: AppleJwk[]; fetchedAt: number } | null = null;

function base64UrlToBytes(value: string): Uint8Array {
    const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
    const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
    const bin = Buffer.from(padded, "base64");
    return new Uint8Array(bin);
}

function decodeJwtPart<T>(part: string): T | null {
    try {
        const decoded = Buffer.from(base64UrlToBytes(part)).toString("utf8");
        return JSON.parse(decoded) as T;
    } catch {
        return null;
    }
}

function toString(value: unknown): string | undefined {
    return typeof value === "string" && value.trim().length > 0 ? value.trim() : undefined;
}

function isAppleIssuer(iss?: string): boolean {
    return Boolean(iss && (iss === "https://appleid.apple.com" || iss === "appleid.apple.com"));
}

function isGoogleIssuer(iss?: string): boolean {
    if (!iss) {
        return false;
    }

    if (iss === "https://accounts.google.com" || iss === "accounts.google.com") {
        return true;
    }

    try {
        const parsed = new URL(iss);
        return parsed.hostname === "accounts.google.com";
    } catch {
        return false;
    }
}

async function getAppleJwks(): Promise<AppleJwk[]> {
    const now = Date.now();
    if (appleJwksCache && now - appleJwksCache.fetchedAt < 1000 * 60 * 60) {
        return appleJwksCache.keys;
    }

    const response = await fetch("https://appleid.apple.com/auth/keys");
    if (!response.ok) {
        throw new Error("Unable to fetch Apple JWKS");
    }

    const payload = await response.json() as { keys?: AppleJwk[] };
    if (!payload.keys || payload.keys.length === 0) {
        throw new Error("Invalid Apple JWKS payload");
    }

    appleJwksCache = {
        keys: payload.keys,
        fetchedAt: now,
    };
    return payload.keys;
}

async function verifyAppleIdTokenSignature(idToken: string): Promise<Record<string, unknown>> {
    const parts = idToken.split(".");
    if (parts.length !== 3) {
        throw new Error("Invalid Apple identity token format");
    }

    const [encodedHeader, encodedPayload, encodedSignature] = parts;
    if (!encodedHeader || !encodedPayload || !encodedSignature) {
        throw new Error("Invalid Apple identity token payload");
    }

    const header = decodeJwtPart<JwtHeader>(encodedHeader);
    if (!header?.kid || header.alg !== "RS256") {
        throw new Error("Invalid Apple identity token header");
    }

    const jwks = await getAppleJwks();
    const jwk = jwks.find((k) => k.kid === header.kid);
    if (!jwk) {
        throw new Error("Apple signing key not found");
    }

    const data = new TextEncoder().encode(`${encodedHeader}.${encodedPayload}`);
    const signature = base64UrlToBytes(encodedSignature);
    const cryptoKey = await crypto.subtle.importKey(
        "jwk",
        jwk as any,
        { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
        false,
        ["verify"],
    );

    const valid = await crypto.subtle.verify(
        { name: "RSASSA-PKCS1-v1_5" },
        cryptoKey,
        signature,
        data,
    );
    if (!valid) {
        throw new Error("Invalid Apple identity token signature");
    }

    const payload = decodeJwtPart<Record<string, unknown>>(encodedPayload);
    if (!payload) {
        throw new Error("Invalid Apple identity token body");
    }
    return payload;
}

export async function verifyGoogleOAuth(input: {
    idToken?: string;
    accessToken?: string;
    email?: string;
    firstName?: string;
    lastName?: string;
    providerUserId?: string;
}): Promise<OAuthProfile> {
    if (input.idToken) {
        const url = `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(input.idToken)}`;
        const response = await fetch(url);
        if (response.ok) {
            const data = await response.json() as Record<string, unknown>;
            const sub = toString(data.sub);
            const email = toString(data.email);
            const iss = toString(data.iss);
            const aud = toString(data.aud);
            const exp = Number(data.exp ?? 0);
            const nowInSeconds = Math.floor(Date.now() / 1000);

            if (!sub || !email || !iss || !isGoogleIssuer(iss)) {
                throw new Error("Invalid Google token payload");
            }
            if (!Number.isFinite(exp) || exp <= nowInSeconds) {
                throw new Error("Google token expired");
            }

            const expectedAud = Bun.env.GOOGLE_CLIENT_ID?.trim();
            if (expectedAud && aud !== expectedAud) {
                throw new Error("Google token audience mismatch");
            }

            return {
                provider: "google",
                providerUserId: sub,
                email,
                emailVerified: data.email_verified === "true" || data.email_verified === true,
                firstName: toString(data.given_name) ?? input.firstName,
                lastName: toString(data.family_name) ?? input.lastName,
            };
        }
    }

    if (input.accessToken) {
        const response = await fetch("https://www.googleapis.com/oauth2/v3/userinfo", {
            headers: {
                Authorization: `Bearer ${input.accessToken}`,
            },
        });

        if (response.ok) {
            const data = await response.json() as Record<string, unknown>;
            const sub = toString(data.sub);
            const email = toString(data.email);
            if (!sub || !email) {
                throw new Error("Invalid Google userinfo payload");
            }

            return {
                provider: "google",
                providerUserId: sub,
                email,
                emailVerified: data.email_verified === true,
                firstName: toString(data.given_name) ?? input.firstName,
                lastName: toString(data.family_name) ?? input.lastName,
            };
        }
    }

    throw new Error("Unable to verify Google OAuth identity");
}

export async function verifyAppleOAuth(input: {
    idToken?: string;
    email?: string;
    firstName?: string;
    lastName?: string;
    providerUserId?: string;
}): Promise<OAuthProfile> {
    if (!input.idToken) {
        throw new Error("Apple idToken is required");
    }

    const payload = await verifyAppleIdTokenSignature(input.idToken);
    const sub = toString(payload.sub);
    const email = toString(payload.email) ?? input.email;
    const iss = toString(payload.iss);
    const aud = toString(payload.aud);
    const exp = Number(payload.exp ?? 0);
    const nowInSeconds = Math.floor(Date.now() / 1000);

    if (!sub || !email || !isAppleIssuer(iss)) {
        throw new Error("Invalid Apple identity token");
    }
    if (!Number.isFinite(exp) || exp <= nowInSeconds) {
        throw new Error("Apple token expired");
    }

    const expectedAud = Bun.env.APPLE_CLIENT_ID?.trim();
    if (expectedAud && aud !== expectedAud) {
        throw new Error("Apple token audience mismatch");
    }

    return {
        provider: "apple",
        providerUserId: sub,
        email,
        emailVerified: payload.email_verified === true || payload.email_verified === "true",
        firstName: input.firstName,
        lastName: input.lastName,
    };
}

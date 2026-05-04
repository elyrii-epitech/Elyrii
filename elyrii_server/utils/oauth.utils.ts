export type OAuthProvider = "google" | "apple";

export type OAuthProfile = {
    provider: OAuthProvider;
    providerUserId: string;
    email: string;
    emailVerified: boolean;
    firstName?: string;
    lastName?: string;
};

function decodeJwtPayload(token: string): Record<string, unknown> | null {
    const parts = token.split(".");
    if (parts.length < 2) return null;

    try {
        const payload = parts[1]!;
        const normalized = payload.replace(/-/g, "+").replace(/_/g, "/");
        const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
        const decoded = Buffer.from(padded, "base64").toString("utf8");
        return JSON.parse(decoded) as Record<string, unknown>;
    } catch {
        return null;
    }
}

function toString(value: unknown): string | undefined {
    return typeof value === "string" && value.trim().length > 0 ? value.trim() : undefined;
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
            if (!sub || !email || !iss || !iss.includes("accounts.google.com")) {
                throw new Error("Invalid Google token payload");
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

    if (input.providerUserId && input.email) {
        return {
            provider: "google",
            providerUserId: input.providerUserId,
            email: input.email,
            emailVerified: true,
            firstName: input.firstName,
            lastName: input.lastName,
        };
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
    if (input.idToken) {
        const payload = decodeJwtPayload(input.idToken);
        const sub = toString(payload?.sub);
        const email = toString(payload?.email) ?? input.email;
        const iss = toString(payload?.iss);

        if (!sub || !email || !iss || !iss.includes("appleid.apple.com")) {
            throw new Error("Invalid Apple identity token");
        }

        return {
            provider: "apple",
            providerUserId: sub,
            email,
            emailVerified: payload?.email_verified === true || payload?.email_verified === "true",
            firstName: input.firstName,
            lastName: input.lastName,
        };
    }

    if (input.providerUserId && input.email) {
        return {
            provider: "apple",
            providerUserId: input.providerUserId,
            email: input.email,
            emailVerified: true,
            firstName: input.firstName,
            lastName: input.lastName,
        };
    }

    throw new Error("Unable to verify Apple OAuth identity");
}

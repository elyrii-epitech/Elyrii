import { beforeEach, describe, expect, test } from "bun:test";
import { JwtUtils } from "./jwt.utils";
import { extractBearerToken, resolveWsIdentity } from "./ws-auth.utils";

describe("extractBearerToken", () => {
    test("returns token for valid Bearer header", () => {
        expect(extractBearerToken("Bearer abc.def")).toBe("abc.def");
    });

    test("returns null when header is missing or malformed", () => {
        expect(extractBearerToken()).toBeNull();
        expect(extractBearerToken("Basic abc")).toBeNull();
        expect(extractBearerToken("Bearer   ")).toBeNull();
    });
});

describe("resolveWsIdentity", () => {
    beforeEach(() => {
        Bun.env.SECRET_KEY = "test-secret";
    });

    test("resolves identity from Authorization bearer token", async () => {
        const token = await JwtUtils.generateAccessToken({
            userId: "user-1",
            email: "user1@example.com",
        });

        const identity = await resolveWsIdentity("/chat/ws", `Bearer ${token}`, false);
        expect(identity).not.toBeNull();
        expect(identity?.userId).toBe("user-1");
        expect(identity?.source).toBe("token");
    });

    test("resolves identity from query token", async () => {
        const token = await JwtUtils.generateAccessToken({
            userId: "user-2",
            email: "user2@example.com",
        });

        const identity = await resolveWsIdentity(`/chat/ws?token=${token}`, undefined, false);
        expect(identity).not.toBeNull();
        expect(identity?.userId).toBe("user-2");
        expect(identity?.source).toBe("token");
    });

    test("uses userId query fallback when enabled", async () => {
        const identity = await resolveWsIdentity("/chat/ws?userId=legacy-user", undefined, true);
        expect(identity).toEqual({ userId: "legacy-user", source: "query" });
    });

    test("rejects userId query fallback when disabled", async () => {
        const identity = await resolveWsIdentity("/chat/ws?userId=legacy-user", undefined, false);
        expect(identity).toBeNull();
    });
});

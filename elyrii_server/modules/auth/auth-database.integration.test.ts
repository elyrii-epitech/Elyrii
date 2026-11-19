import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { Hono } from "hono";
import { eq } from "drizzle-orm";
import { randomBytes } from "node:crypto";
import { db } from "../../config/db.config";
import { passwordResetTable, userTable } from "../../config/db/schema";
import AuthController from "./auth.controller";
import { resetHash } from "./password-reset.service";

const connected = Bun.env.AUTH_PROFILE_MOOD_INTEGRATION === "1" ? describe : describe.skip;
connected("activation and recovery against disposable PostgreSQL", () => {
    const email = `activation-${crypto.randomUUID()}@example.test`;
    const password = "Secret123";
    const deliveries: string[] = [];
    let userId: string;
    const previousVerification = Bun.env.REQUIRE_EMAIL_VERIFICATION;
    const controller = new AuthController({
        available: () => true,
        send: async (_email, token) => { deliveries.push(token); },
    });
    const app = new Hono();
    app.post("/register", ...controller.register);
    app.post("/login", ...controller.login);
    app.post("/verify", ...controller.verifyEmail);
    app.post("/resend", ...controller.resendVerification);
    const send = (path: string, body: unknown) => app.request(path, {
        method: "POST", headers: {"Content-Type": "application/json"}, body: JSON.stringify(body),
    });

    beforeAll(() => {
        if (Bun.env.DB_HOST !== "127.0.0.1" ||
            Bun.env.DB_NAME !== "elyrii_frontend_test" ||
            Bun.env.NODE_ENV !== "test") throw new Error("Disposable local database required");
        Bun.env.REQUIRE_EMAIL_VERIFICATION = "true";
    });
    afterAll(async () => {
        if (previousVerification === undefined) delete Bun.env.REQUIRE_EMAIL_VERIFICATION;
        else Bun.env.REQUIRE_EMAIL_VERIFICATION = previousVerification;
        if (userId) await db.delete(userTable).where(eq(userTable.id, userId));
    });

    test("verification is delivered, one-use, and required before login", async () => {
        const registered = await send("/register", {email, password, firstName: "Activation", lastName: "Fixture"});
        expect(registered.status).toBe(201);
        const body = await registered.json() as any;
        expect(body.emailVerificationRequired).toBe(true);
        expect(body.token).toBeUndefined();
        expect(body.verificationToken).toBeUndefined();
        expect(deliveries).toHaveLength(1);
        const [user] = await db.select().from(userTable).where(eq(userTable.email, email));
        userId = user!.id;
        expect((await send("/login", {email, password})).status).toBe(403);
        const verified = await send("/verify", {token: deliveries[0]});
        expect(verified.status).toBe(200);
        expect((await verified.json() as any).refreshToken).toBeString();
        expect((await send("/verify", {token: deliveries[0]})).status).toBe(400);
        expect((await send("/login", {email, password})).status).toBe(200);
    });

    test("the actual recovery route consumes its migration table and revokes refresh credentials", async () => {
        const original = await send("/login", {email, password});
        const session = await original.json() as any;
        const code = randomBytes(32).toString("base64url");
        await db.insert(passwordResetTable).values({
            userId, tokenHash: resetHash(code), expiresAt: new Date(Date.now() + 60000),
        });
        const base = Bun.env.MOBILE_TEST_API_URL ?? "http://127.0.0.1:3188";
        const request = (path: string, body: unknown) => fetch(base + path, {
            method: "POST", headers: {"Content-Type": "application/json"}, body: JSON.stringify(body),
        });
        const newPassword = "RecoveredSecret123";
        expect((await request("/auth/password-reset/confirm", {code, password: newPassword})).status).toBe(200);
        expect((await request("/auth/password-reset/confirm", {code, password: newPassword})).status).toBe(400);
        expect((await request("/auth/refresh", {refreshToken: session.refreshToken})).status).toBe(401);
        expect((await send("/login", {email, password})).status).toBe(401);
        expect((await send("/login", {email, password: newPassword})).status).toBe(200);
    });
});

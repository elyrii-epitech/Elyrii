import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { db } from "../../config/db.config";
import { userTable } from "../../config/db/user.table";
import { eq } from "drizzle-orm";

const connected = Bun.env.AUTH_PROFILE_MOOD_INTEGRATION === "1" ? describe : describe.skip;
connected("native auth, profile and mood through the running API", () => {
    const base = Bun.env.MOBILE_TEST_API_URL ?? "http://127.0.0.1:3188";
    const password = "Secret123";
    const accounts: Array<{id: string; email: string; token: string; refreshToken: string}> = [];

    async function request(path: string, token?: string, body?: unknown, method = body === undefined ? "GET" : "POST") {
        return fetch(base + path, {
            method,
            headers: {
                ...(token ? {Authorization: `Bearer ${token}`} : {}),
                ...(body !== undefined ? {"Content-Type": "application/json"} : {}),
            },
            ...(body !== undefined ? {body: JSON.stringify(body)} : {}),
        });
    }
    async function json(path: string, token?: string, body?: unknown, method?: string): Promise<any> {
        const response = await request(path, token, body, method);
        const value = await response.json();
        expect(response.ok, `${path}: ${response.status} ${JSON.stringify(value)}`).toBe(true);
        return value;
    }

    beforeAll(async () => {
        if (new URL(base).hostname !== "127.0.0.1" ||
            Bun.env.DB_NAME !== "elyrii_frontend_test" ||
            Bun.env.DB_HOST !== "127.0.0.1" ||
            Bun.env.NODE_ENV !== "test") {
            throw new Error("Only the disposable local integration database is allowed");
        }
        for (let index = 0; index < 2; index++) {
            const email = `integration-${crypto.randomUUID()}@example.test`;
            const session = await json("/auth/register", undefined, {
                firstName: "Camille", lastName: "Camille", email, password,
            });
            const id = JSON.parse(Buffer.from(session.token.split(".")[1], "base64url").toString()).userId;
            expect(session.refreshToken).toBeString();
            accounts.push({id, email, ...session});
        }
    });
    afterAll(async () => {
        for (const account of accounts) {
            await db.delete(userTable).where(eq(userTable.id, account.id));
        }
    });

    test("signup accepts exactly the new frontend's password rules", async () => {
        const body = {firstName: "Fixture", lastName: "Fixture", email: "invalid@example.test"};
        for (const invalid of ["Short1", "lowercase1", "NoDigitsHere"]) {
            expect((await request("/auth/register", undefined, {...body, password: invalid})).status).toBe(400);
        }
        expect((await request("/auth/login", undefined, {
            email: accounts[0]!.email, password: "WrongSecret123",
        })).status).toBe(401);
        expect((await request("/user/me")).status).toBe(401);
    });

    test("parallel first-launch profile, settings and dashboard reads all succeed", async () => {
        const {token} = accounts[0]!;
        const results = await Promise.all(Array.from({length: 12}, (_, i) =>
            request(["/user/me", "/user/settings", "/user/dashboard?range=30d"][i % 3]!, token)));
        for (const result of results) expect(result.status, await result.text()).toBe(200);
        expect((await json("/user/settings", token)).userId).toBe(accounts[0]!.id);
    });

    test("profile fields persist through a new login without crossing accounts", async () => {
        const account = accounts[0]!;
        const body = {
            firstName: "Camille connecté", lastName: "Fixture", age: 25,
            bio: "Local integration fixture", pronouns: "iel",
            wellnessGoal: "calm", timezone: "Europe/Paris", pfp: null,
        };
        expect(await json("/user/me", account.token, body, "PUT")).toMatchObject(body);
        const next = await json("/auth/login", undefined, {email: account.email, password});
        expect(await json("/user/me", next.token)).toMatchObject(body);
        const other = await json("/user/me", accounts[1]!.token);
        expect(other.id).toBe(accounts[1]!.id);
        expect(other.bio).toBeNull();
        expect(other.password).toBeUndefined();
    });

    test("all five moods persist, update the dashboard and remain account scoped", async () => {
        const account = accounts[0]!;
        for (const moodType of ["verySad", "sad", "neutral", "happy", "veryHappy"]) {
            const result = await json("/user/mood", account.token, {moodType});
            expect(result).toMatchObject({userId: account.id, moodType});
        }
        expect((await request("/user/mood", account.token, {moodType: "invented"})).status).toBe(400);
        const next = await json("/auth/login", undefined, {email: account.email, password});
        expect((await json("/user/mood/latest", next.token)).moodType).toBe("veryHappy");
        const dashboard = await json("/user/dashboard?range=30d", next.token);
        expect(dashboard.latestMood).toBe("veryHappy");
        expect(dashboard.stats.moodLogsCount).toBe(5);
        expect(dashboard.stats.activityTimeline.some((day: any) => day.moodLogs === 5)).toBe(true);
        expect((await json("/user/dashboard?range=30d", accounts[1]!.token)).latestMood).toBeNull();
    });

    test("refresh rotates atomically, rejects replay, and logout revokes the session", async () => {
        const account = accounts[0]!;
        const session = await json("/auth/login", undefined, {email: account.email, password});
        const results = await Promise.all([
            request("/auth/refresh", undefined, {refreshToken: session.refreshToken}),
            request("/auth/refresh", undefined, {refreshToken: session.refreshToken}),
        ]);
        expect(results.map(response => response.status).sort()).toEqual([200, 401]);
        const rotated = await results.find(response => response.status === 200)!.json() as any;
        expect(rotated.refreshToken).not.toBe(session.refreshToken);
        expect((await request("/auth/refresh", undefined, {refreshToken: session.refreshToken})).status).toBe(401);
        await json("/auth/logout", rotated.token, {refreshToken: rotated.refreshToken});
        expect((await request("/auth/refresh", undefined, {refreshToken: rotated.refreshToken})).status).toBe(401);
        expect((await request("/user/me", rotated.token)).status).toBe(401);
    });

    test("a deleted account cannot keep using its old access token", async () => {
        const account = accounts[1]!;
        await db.delete(userTable).where(eq(userTable.id, account.id));
        expect((await request("/user/me", account.token)).status).toBe(401);
        expect((await request("/user/mood", account.token, {moodType: "happy"})).status).toBe(401);
    });
});

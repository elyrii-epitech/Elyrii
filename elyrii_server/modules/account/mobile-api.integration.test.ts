import { afterAll, beforeAll, describe, expect, test } from "bun:test";

const connected = Bun.env.MOBILE_API_INTEGRATION === "1" ? describe : describe.skip;
connected("mobile requests against the running API and disposable PostgreSQL", () => {
    const base = Bun.env.MOBILE_TEST_API_URL ?? "http://127.0.0.1:3188";
    const password = "Local fixture password 2026!";
    const accounts: Array<{ token: string; id: string; refreshToken: string }> = [];
    async function request(path: string, token?: string, body?: unknown, method = body === undefined ? "GET" : "POST") {
        return fetch(base + path, {
            method, headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}), ...(body !== undefined ? { "Content-Type": "application/json" } : {}) },
            ...(body === undefined ? {} : { body: JSON.stringify(body) }),
        });
    }
    async function json(path: string, token?: string, body?: unknown, method?: string): Promise<any> {
        const response = await request(path, token, body, method);
        const data = await response.json();
        expect(response.ok, `${path}: ${response.status} ${JSON.stringify(data)}`).toBe(true);
        return data;
    }
    beforeAll(async () => {
        const url = new URL(base);
        if (Bun.env.DB_NAME !== "elyrii_frontend_test" || Bun.env.NODE_ENV === "production" || url.hostname !== "127.0.0.1") {
            throw new Error("Connected tests require the local disposable elyrii_frontend_test database");
        }
        for (let i = 0; i < 2; i++) {
            const session = await json("/auth/register", undefined, { email: `mobile-${crypto.randomUUID()}@example.test`, password, firstName: "Mobile", lastName: "Fixture", age: 24 });
            expect(session.token).toBeString();
            const payload = JSON.parse(Buffer.from(session.token.split(".")[1], "base64url").toString());
            accounts.push({ token: session.token, id: payload.userId, refreshToken: session.refreshToken });
        }
    });
    afterAll(async () => {
        for (const account of accounts) await request("/user/account", account.token, { password }, "DELETE");
    });
    test("parallel first-launch requests create one settings record", async () => {
        const { token } = accounts[0]!;
        const results = await Promise.all(Array.from({ length: 16 }, (_, i) => request(i % 3 === 0 ? "/user/me" : i % 3 === 1 ? "/user/settings" : "/user/dashboard?range=30d", token)));
        for (const response of results) expect(response.status, await response.text()).toBe(200);
        const settings = await json("/user/settings", token);
        expect(settings.userId).toBe(accounts[0]!.id);
    });
    test("profile, settings and mascot edits round-trip the mobile payloads", async () => {
        const { token } = accounts[0]!;
        expect((await json("/user/me", token, { firstName: "Aperçu", pfp: null, bio: "Fixture", pronouns: "iel", wellnessGoal: "calm", timezone: "Europe/Paris" }, "PUT")).firstName).toBe("Aperçu");
        const settings = await json("/user/settings", token, { themeMode: "DARK", privacyMode: "STRICT", hapticsEnabled: false, language: "fr" }, "PUT");
        expect(settings.themeMode).toBe("DARK");
        expect((await json("/user/settings", token)).hapticsEnabled).toBe(false);
        await json("/user/mascot", token, { appearance: "nature", themeId: "nature", equippedCosmetics: ["custom1"], personality: { equippedCosmetics: ["custom1"], customization: { colors: { body: "#ABCDEF" }, finish: "satin" } } }, "PUT");
        const mascot = await json("/user/mascot", token);
        expect(mascot.personality.customization.colors.body).toBe("#ABCDEF");
        expect(mascot.personality.equippedCosmetics).toEqual(["custom1"]);
        expect((await json("/user/mascot", accounts[1]!.token)).personality.customization).toBeUndefined();
    });
    test("journal saves, retries, pagination, media and owner isolation match the app", async () => {
        const { token } = accounts[0]!;
        const body = { title: "Mobile note", content: "A real persisted fixture", mood: "happy", tags: null, clientRequestId: crypto.randomUUID() };
        const entry = (await json("/journal", token, body)).body;
        expect((await json("/journal", token, body)).body.id).toBe(entry.id);
        expect((await request(`/journal/${entry.id}`, accounts[1]!.token)).status).toBe(404);
        const page = await json("/journal?limit=100&order=desc", token);
        expect(page.entries.some((item: any) => item.id === entry.id)).toBe(true);
        expect((await json(`/journal/${entry.id}`, token, { content: "Edited" }, "PUT")).body.content).toBe("Edited");
        const media = await json(`/journal/${entry.id}/media`, token, { url: "https://example.test/fixture.png", type: "image" });
        expect((await json(`/journal/${entry.id}/media`, token))[0].id).toBe(media.id);
        await json(`/journal/${entry.id}/media/${media.id}`, token, undefined, "DELETE");
        await json(`/journal/${entry.id}`, token, undefined, "DELETE");
        expect((await request(`/journal/${entry.id}`, token)).status).toBe(404);
    });
    test("accepted and rejected proposals include their template for the mobile cards", async () => {
        const { token } = accounts[0]!;
        for (const action of ["accept", "reject"]) {
            const created = await json("/challenge/proposals", token, { title: `Fixture ${action}`, conditions: [{ type: "mood_count", target: 5 }], constraints: {} });
            const proposal = created.userChallenge;
            const response = await json(`/challenge/proposals/${proposal.id}/${action}`, token, {});
            expect(response.challenge?.title).toBe(`Fixture ${action}`);
            expect(response.userId).toBe(accounts[0]!.id);
            expect((await request(`/challenge/proposals/${proposal.id}/${action}`, accounts[1]!.token, {})).status).toBe(404);
        }
    });
    test("meditation and coach sessions feed the dashboard and remain private", async () => {
        const { token } = accounts[0]!;
        const catalog = await json("/meditation/catalog", token);
        expect(catalog.some((program: any) => program.id === "coherence")).toBe(true);
        const session = await json("/meditation/sessions/start", token, { type: "coherence", durationMinutes: 5 });
        const completed = await json(`/meditation/sessions/${session.id}/complete`, token, { endedAt: new Date().toISOString(), moodAfter: "calm" });
        expect(completed.status).toBe("COMPLETED");
        expect((await json("/meditation/sessions", accounts[1]!.token))).toEqual([]);
        const coach = await json("/coach/sessions", token, { prompt: "Je cherche une routine calme", context: { source: "mobile" } });
        expect(coach.response).toBeString();
        await json("/user/mood", token, { moodType: "happy" });
        const dashboard = await json("/user/dashboard?range=30d", token);
        expect(dashboard.latestMood).toBe("happy");
        expect(dashboard.stats.meditationSessionsCount).toBe(1);
        expect(dashboard.stats.coachSessionsCount).toBe(1);
        expect(dashboard.stats.streak).toBeGreaterThanOrEqual(1);
    });
    test("export, reporting and authentication failures use the mobile routes", async () => {
        const { token } = accounts[0]!;
        expect((await request("/user/me")).status).toBe(401);
        await json("/user/ai-reports", token, { messageId: crypto.randomUUID(), conversationId: crypto.randomUUID(), reason: "OTHER", content: "Selected fixture reply" });
        const exported = await json("/user/export", token);
        expect(exported.profile.id).toBe(accounts[0]!.id);
        expect(exported.profile.password).toBeUndefined();
        expect(exported.reports).toHaveLength(1);
    });
    test("native refresh tokens rotate once, reject replay and revoke on logout", async () => {
        const session = await json("/auth/register", undefined, { email: `refresh-${crypto.randomUUID()}@example.test`, password, firstName: "Session", lastName: "Fixture" });
        const id = JSON.parse(Buffer.from(session.token.split('.')[1], 'base64url').toString()).userId;
        accounts.push({token: session.token, id, refreshToken: session.refreshToken});
        expect(session.refreshToken).toBeString();
        const updated = await json("/auth/refresh", undefined, {refreshToken: session.refreshToken});
        expect(updated.refreshToken).not.toBe(session.refreshToken);
        expect((await request("/auth/refresh", undefined, {refreshToken: session.refreshToken})).status).toBe(401);
        const concurrent = await Promise.all([request("/auth/refresh", undefined, {refreshToken: updated.refreshToken}), request("/auth/refresh", undefined, {refreshToken: updated.refreshToken})]);
        expect(concurrent.map(r => r.status).sort()).toEqual([200, 401]);
        const latest = await concurrent.find(r => r.status === 200)!.json() as any;
        await json("/auth/logout", latest.token, {refreshToken: latest.refreshToken});
        expect((await request("/auth/refresh", undefined, {refreshToken: latest.refreshToken})).status).toBe(401);
        expect((await request("/user/me", latest.token)).status).toBe(401);
    });
    test("account deletion removes legacy journal relations and prevents using the old token", async () => {
        const session = await json("/auth/register", undefined, { email: `deletion-${crypto.randomUUID()}@example.test`, password, firstName: "Deletion", lastName: "Fixture" });
        const entry = (await json("/journal", session.token, {title: "Delete with my account", content: "Private fixture", tags: ["private"]})).body;
        await json(`/journal/${entry.id}/media`, session.token, {url: 'https://example.test/private.png'});
        await json("/challenge/proposals", session.token, {title: "Owned challenge", conditions: [], constraints: {}});
        await json("/user/account", session.token, {password}, "DELETE");
        expect((await request("/user/me", session.token)).status).toBe(401);
        expect((await request("/journal", session.token, {title: "Must not recreate orphan data"})).status).toBe(401);
    });
});

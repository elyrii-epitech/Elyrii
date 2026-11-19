import {afterAll, beforeAll, describe, expect, test} from "bun:test";
import {eq} from "drizzle-orm";
import {db} from "../../config/db.config";
import {meditationSessionsTable} from "../../config/db/meditation.table";
import AuthRepository from "../../repository/auth.repository";
import UserRepository from "../../repository/user.repository";

const connected = Bun.env.MEDITATION_INTEGRATION === "1" ? describe : describe.skip;
connected("new frontend meditation against disposable PostgreSQL and HTTP", () => {
    const base = Bun.env.MOBILE_TEST_API_URL!;
    const accounts: Array<{id: string; token: string}> = [];
    const password = "MeditationFixture123";
    const nativeIds = ["coherence", "facile", "carree", "relaxation478", "diaphragmatique", "ujjayi",
        "expirationLongue", "mindful-breathing", "body-scan", "sound-awareness", "loving-kindness", "self-compassion"];

    async function request(path: string, body?: unknown, owner = 0, method = body === undefined ? "GET" : "POST") {
        return fetch(base + path, {method, headers: {Authorization: `Bearer ${accounts[owner]!.token}`,
            ...(body !== undefined ? {"Content-Type": "application/json"} : {})},
            ...(body !== undefined ? {body: JSON.stringify(body)} : {})});
    }
    async function json(path: string, body?: unknown, owner = 0): Promise<any> {
        const response = await request(path, body, owner), value = await response.json();
        expect(response.ok, `${path}: ${response.status} ${JSON.stringify(value)}`).toBe(true);
        return value;
    }
    const start = (type = "coherence", durationMinutes = 7) => json("/meditation/sessions/start", {type, durationMinutes});
    beforeAll(async () => {
        if (new URL(base).hostname !== "127.0.0.1" || Bun.env.DB_NAME !== "elyrii_frontend_test" || Bun.env.NODE_ENV !== "test") {
            throw new Error("Local disposable fixture required");
        }
        for (let i = 0; i < 2; i++) {
            const email = `meditation-${crypto.randomUUID()}@example.test`;
            const user = await new AuthRepository().createUser({email, password, firstName: "Meditation", lastName: "Fixture", age: 25, emailVerified: true});
            const response = await fetch(base + "/auth/login", {method: "POST", headers: {"Content-Type": "application/json"}, body: JSON.stringify({email, password})});
            expect(response.status).toBe(200);
            const session = await response.json() as any;
            accounts.push({id: user!.id, token: session.token});
        }
    });
    afterAll(async () => {
        for (const account of accounts) await new UserRepository().deleteUserAccount(account.id);
    });

    test("authenticated catalogue contains every shipped practice and retains legacy programs", async () => {
        expect((await fetch(base + "/meditation/catalog")).status).toBe(401);
        expect((await fetch(base + "/meditation/sessions")).status).toBe(401);
        const catalog = await json("/meditation/catalog");
        expect(catalog.map((p: any) => p.id)).toContainAllValues([...nativeIds, "breathing-5m", "body-scan-10m", "grounding-15m"]);
        expect(catalog.filter((p: any) => p.guidance).every((p: any) => p.minDurationMinutes === 1 && p.maxDurationMinutes === 1439 && p.audioUrl === "")).toBe(true);
    });

    test("all native IDs accept chosen durations including dashboard and controller boundaries", async () => {
        for (const type of nativeIds) {
            const session = await start(type);
            expect(session).toMatchObject({type, durationMinutes: 7, status: "STARTED", userId: accounts[0]!.id});
            expect(Math.abs(Date.now() - Date.parse(session.startedAt))).toBeLessThan(5000);
            await json(`/meditation/sessions/${session.id}/cancel`, {});
        }
        for (const duration of [1, 2, 3, 5, 10, 15, 1439]) {
            const session = await start("coherence", duration);
            await json(`/meditation/sessions/${session.id}/cancel`, {});
        }
        expect(await start("breathing-5m", 5)).toMatchObject({type: "breathing-5m", durationMinutes: 5});
    });

    test("invalid programs, durations, moods, IDs and list limits fail as client errors", async () => {
        for (const body of [
            {type: "unknown", durationMinutes: 5}, {type: "breathing-5m", durationMinutes: 7},
            ...[0, -1, 1.5, 1440].map(durationMinutes => ({type: "coherence", durationMinutes})),
            {type: "coherence", durationMinutes: 5, moodBefore: "invalid"},
            {type: "coherence", durationMinutes: 5, clientSessionId: "invalid"},
        ]) expect((await request("/meditation/sessions/start", body)).status).toBe(400);
        for (const limit of ["NaN", "0", "101", "1.5"]) expect((await request("/meditation/sessions?limit=" + limit)).status).toBe(400);
        expect((await request("/meditation/sessions/invalid/complete", {})).status).toBe(400);
        const session = await start();
        for (const body of [{moodAfter: "invalid"}, {notes: "x".repeat(5001)}, {endedAt: "2020-01-01T00:00:00Z"}, {endedAt: "2099-01-01T00:00:00Z"}]) {
            expect((await request(`/meditation/sessions/${session.id}/complete`, body)).status).toBe(400);
        }
    });

    test("concurrent starts and lost acknowledgements reuse one owned session", async () => {
        const clientSessionId = crypto.randomUUID(), body = {clientSessionId, type: "body-scan", durationMinutes: 10};
        const rows = await Promise.all(Array.from({length: 6}, () => json("/meditation/sessions/start", body)));
        expect(new Set(rows.map(r => r.id))).toEqual(new Set([clientSessionId]));
        expect(await db.select().from(meditationSessionsTable).where(eq(meditationSessionsTable.id, clientSessionId))).toHaveLength(1);
        expect((await request("/meditation/sessions/start", {...body, durationMinutes: 5})).status).toBe(409);
        expect((await request("/meditation/sessions/start", body, 1)).status).toBe(409);
    });

    test("completion retries preserve time, optional mood and notes and count activity once", async () => {
        const before = await json("/user/stats?range=30d"), session = await start();
        const first = await json(`/meditation/sessions/${session.id}/complete`, {notes: "Fixture note", moodBefore: "neutral"});
        const withMood = await json(`/meditation/sessions/${session.id}/complete`, {moodAfter: "happy"});
        const replay = await json(`/meditation/sessions/${session.id}/complete`, {});
        expect(replay).toMatchObject({status: "COMPLETED", endedAt: first.endedAt, notes: "Fixture note", moodBefore: "neutral", moodAfter: "happy"});
        expect(withMood.endedAt).toBe(first.endedAt);
        expect((await request(`/meditation/sessions/${session.id}/cancel`, {})).status).toBe(409);
        expect((await json("/user/stats?range=30d")).meditationSessionsCount).toBe(before.meditationSessionsCount + 1);
        const list = await request("/meditation/sessions?limit=100");
        expect(list.headers.get("Cache-Control")).toBe("no-store");
        expect((await list.json() as any[]).filter(row => row.id === session.id)).toHaveLength(1);
    });

    test("cancel retries preserve interruption and concurrent terminal commands have one winner", async () => {
        const session = await start(), first = await json(`/meditation/sessions/${session.id}/cancel`, {});
        expect(await json(`/meditation/sessions/${session.id}/cancel`, {})).toMatchObject({status: "CANCELED", endedAt: first.endedAt});
        expect((await request(`/meditation/sessions/${session.id}/complete`, {})).status).toBe(409);
        const racing = await start();
        const responses = await Promise.all([request(`/meditation/sessions/${racing.id}/complete`, {}), request(`/meditation/sessions/${racing.id}/cancel`, {})]);
        expect(responses.map(r => r.status).sort()).toEqual([200, 409]);
    });

    test("history and terminal commands stay account scoped and deletion removes sessions", async () => {
        const session = await start();
        expect(await json("/meditation/sessions", undefined, 1)).toBeEmpty();
        for (const command of ["complete", "cancel"]) {
            expect((await request(`/meditation/sessions/${session.id}/${command}`, {}, 1)).status).toBe(404);
        }
        const other = await json("/meditation/sessions/start", {type: "facile", durationMinutes: 3}, 1);
        expect((await json("/meditation/sessions?limit=100")).some((row: any) => row.id === other.id)).toBe(false);
        expect((await request("/user/account", {password}, 1, "DELETE")).status).toBe(200);
        expect(await db.select().from(meditationSessionsTable).where(eq(meditationSessionsTable.userId, accounts[1]!.id))).toBeEmpty();
        expect((await json("/meditation/sessions?limit=100")).some((row: any) => row.id === session.id)).toBe(true);
    });
});

import {afterAll, beforeAll, describe, expect, test} from "bun:test";
import {and, eq} from "drizzle-orm";
import {db} from "../../config/db.config";
import {coachJourneysTable} from "../../config/db/coach.table";
import AuthRepository from "../../repository/auth.repository";
import UserRepository from "../../repository/user.repository";
import {COACH_CATALOG} from "./coach.catalog";

const connected = Bun.env.COACH_INTEGRATION === "1" ? describe : describe.skip;
connected("new Coach programs through disposable PostgreSQL and HTTP", () => {
    const base = Bun.env.MOBILE_TEST_API_URL!;
    const accounts: Array<{id: string; token: string}> = [];
    const password = "CoachFixture123";
    let current: any;
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
    const expected = (e: any) => ({enrollmentId: e.enrollmentId, revision: e.revision});
    const choose = (index: number, id: string | null = null) => ({pathId: COACH_CATALOG[index]!.pathId,
        contentVersion: COACH_CATALOG[index]!.contentVersion, expectedEnrollmentId: id});
    const step = (e: any, index: number) => `/coach/journey/steps/${e.path.steps[index].stepId}/complete`;
    beforeAll(async () => {
        if (new URL(base).hostname !== "127.0.0.1" || Bun.env.DB_NAME !== "elyrii_frontend_test" || Bun.env.NODE_ENV !== "test") throw new Error("Local disposable fixture required");
        for (let i = 0; i < 3; i++) {
            const email = `coach-${crypto.randomUUID()}@example.test`;
            const user = await new AuthRepository().createUser({email, password, firstName: "Coach", lastName: "Fixture", age: 25, emailVerified: true});
            const response = await fetch(base + "/auth/login", {method: "POST", headers: {"Content-Type": "application/json"}, body: JSON.stringify({email, password})});
            expect(response.status).toBe(200);
            accounts.push({id: user!.id, token: (await response.json() as any).token});
        }
    });
    afterAll(async () => { for (const account of accounts) await new UserRepository().deleteUserAccount(account.id); });

    test("catalogue and owner documents require authentication and preserve all editorial content", async () => {
        expect((await fetch(base + "/coach/catalog")).status).toBe(401);
        expect((await fetch(base + "/coach/journey")).status).toBe(401);
        expect(await json("/coach/catalog")).toEqual(COACH_CATALOG);
        const response = await request("/coach/journey");
        expect(response.headers.get("Cache-Control")).toBe("no-store");
        expect(await response.json()).toEqual({schemaVersion: 1, owner: accounts[0]!.id, current: null});
        expect((await request("/coach/journey/choose", {...choose(0), contentVersion: 99})).status).toBe(400);
        expect((await request("/coach/journey/pause", {enrollmentId: "bad", revision: -1})).status).toBe(400);
    });

    test("concurrent choices return one enrollment and repeated starts preserve progress", async () => {
        const results = await Promise.all(Array.from({length: 6}, () => json("/coach/journey/choose", choose(0))));
        expect(results.filter(r => r.changed)).toHaveLength(1);
        expect(new Set(results.map(r => r.current.enrollmentId)).size).toBe(1);
        current = results[0].current;
        expect(current).toMatchObject({status: "active", completedStepCount: 0, revision: 1, path: COACH_CATALOG[0]});
        expect(await db.select().from(coachJourneysTable).where(eq(coachJourneysTable.userId, accounts[0]!.id))).toHaveLength(1);
    });

    test("only the current step advances, retries are idempotent and pause/resume require current revisions", async () => {
        expect((await request(step(current, 1), expected(current))).status).toBe(400);
        const initial = current;
        current = (await json(step(current, 0), expected(current))).current;
        expect(current.completedStepCount).toBe(1);
        expect((await json(step(initial, 0), expected(initial))).changed).toBe(false);
        current = (await json("/coach/journey/pause", expected(current))).current;
        expect((await json("/coach/journey/pause", expected(current))).changed).toBe(false);
        expect((await request(step(current, 1), expected(current))).status).toBe(409);
        expect((await request("/coach/journey/resume", expected(initial))).status).toBe(409);
        current = (await json("/coach/journey/resume", expected(current))).current;
        const attempts = await Promise.all(Array.from({length: 5}, () => json(step(current, 1), expected(current))));
        expect(attempts.filter(r => r.changed)).toHaveLength(1);
        current = attempts[0].current;
        expect(current.completedStepCount).toBe(2);
        current = (await json(step(current, 2), expected(current))).current;
        expect(current.status).toBe("completed");
        expect(current.completedAt).toBeString();
        expect((await json(step(current, 2), expected(current))).current).toEqual(current);
        expect((await request("/coach/journey/pause", expected(current))).status).toBe(409);
        expect((await json("/coach/journey/choose", choose(0))).current).toEqual(current);
    });

    test("switching archives the previous enrollment and rejects stale or foreign actions", async () => {
        const previous = current;
        current = (await json("/coach/journey/choose", choose(1, previous.enrollmentId))).current;
        expect(current.enrollmentId).not.toBe(previous.enrollmentId);
        expect((await request(step(previous, 0), expected(previous))).status).toBe(404);
        expect((await request("/coach/journey/choose", choose(2))).status).toBe(409);
        expect((await request("/coach/journey/pause", expected(current), 2)).status).toBe(404);
        expect((await json("/coach/journey", undefined, 2)).current).toBeNull();
        const rows = await db.select().from(coachJourneysTable).where(eq(coachJourneysTable.userId, accounts[0]!.id));
        expect(rows).toHaveLength(2);
        expect(rows.filter(r => r.isCurrent)).toHaveLength(1);
        expect(rows.find(r => r.id === previous.enrollmentId)?.status).toBe("completed");
    });

    test("legacy migration preserves frozen progress once and cannot overwrite server state", async () => {
        const path = structuredClone(COACH_CATALOG[0]!);
        path.contentVersion = 1;
        path.title = "Ancien programme conservé";
        const local = {enrollmentId: crypto.randomUUID(), path, status: "paused", completedStepCount: 1, revision: 4,
            startedAt: "2026-10-01T10:00:00.000Z", updatedAt: "2026-10-02T10:00:00.000Z", completedAt: null};
        const imported = await json("/coach/journey/import", local, 1);
        expect(imported.current).toMatchObject(local);
        expect(imported.changed).toBe(true);
        expect((await json("/coach/journey/import", local, 1)).changed).toBe(false);
        const picked = await json("/coach/journey/choose", choose(2, local.enrollmentId), 1);
        expect((await json("/coach/journey/import", local, 1)).current.enrollmentId).toBe(picked.current.enrollmentId);
        expect((await request("/coach/journey/import", {...local, status: "completed"}, 2)).status).toBe(400);
        expect((await request("/coach/journey/import", {...local, path: {...COACH_CATALOG[0], title: "Tampered"}}, 2)).status).toBe(400);
    });

    test("linked meditation and journal activity does not pre-complete coach steps", async () => {
        const before = (await json("/coach/journey")).current;
        const meditation = await json("/meditation/sessions/start", {type: "mindful-breathing", durationMinutes: 3});
        await json(`/meditation/sessions/${meditation.id}/complete`, {});
        await json("/journal", {title: "Coach fixture", content: "Une note privée pour le programme.", clientRequestId: crypto.randomUUID()});
        expect((await json("/coach/journey")).current).toEqual(before);
        expect((await json(step(current, 0), expected(current))).current.completedStepCount).toBe(1);
    });

    test("legacy coach responses remain available and account deletion cascades enrollments", async () => {
        const response = await json("/coach/sessions", {prompt: "Je veux garder une petite routine"}, 2);
        expect(response.userId).toBe(accounts[2]!.id);
        expect(response.response).toBeString();
        expect((await request("/user/account", {password}, 1, "DELETE")).status).toBe(200);
        expect(await db.select().from(coachJourneysTable).where(eq(coachJourneysTable.userId, accounts[1]!.id))).toBeEmpty();
        expect(await db.select().from(coachJourneysTable).where(and(eq(coachJourneysTable.userId, accounts[0]!.id), eq(coachJourneysTable.isCurrent, true)))).toHaveLength(1);
    });
});

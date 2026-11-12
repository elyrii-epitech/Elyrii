import {afterAll, beforeAll, describe, expect, test} from "bun:test";
import {and, eq, inArray, sql} from "drizzle-orm";
import {db} from "../../config/db.config";
import {challengesTable, userChallengesTable} from "../../config/db/quest.table";
import {pointsLedgerTable} from "../../config/db/reward.table";
import {notificationsTable} from "../../config/db/notification.table";
import AuthRepository from "../../repository/auth.repository";
import UserRepository from "../../repository/user.repository";
import QuestRepository from "../../repository/quest.repository";
const connected = Bun.env.CHALLENGES_INTEGRATION === "1" ? describe : describe.skip;
connected("new frontend challenges against disposable PostgreSQL and HTTP", () => {
    const base = Bun.env.MOBILE_TEST_API_URL!;
    const accounts: Array<{id: string; token: string}> = [], templates: string[] = [];
    let moodTemplate: string, moodAssignment: string;
    async function request(path: string, owner = 0, body?: unknown, method = body === undefined ? "GET" : "POST") {
        return fetch(base + path, {method, headers: {
            Authorization: `Bearer ${accounts[owner]!.token}`,
            ...(body !== undefined ? {"Content-Type": "application/json"} : {}),
        }, ...(body !== undefined ? {body: JSON.stringify(body)} : {})});
    }
    async function json(path: string, owner = 0, body?: unknown, method?: string): Promise<any> {
        const response = await request(path, owner, body, method), value = await response.json();
        expect(response.ok, `${path}: ${response.status} ${JSON.stringify(value)}`).toBe(true);
        return value;
    }
    async function template(type: string, target: number, points = 77) {
        const row = await new QuestRepository().createChallengeTemplate({title: "Fixture " + crypto.randomUUID(),
            source: "SYSTEM", conditions: [{type, target, period: "all_time"}], aggregator: "ALL", rewardPoints: points});
        templates.push(row.id); return row.id;
    }
    async function ledger(id: string) {
        return db.select().from(pointsLedgerTable).where(eq(pointsLedgerTable.userChallengeId, id));
    }
    beforeAll(async () => {
        if (new URL(base).hostname !== "127.0.0.1" || Bun.env.DB_NAME !== "elyrii_frontend_test" || Bun.env.NODE_ENV !== "test") throw new Error("Local disposable fixture required");
        for (let i = 0; i < 2; i++) {
            const email = `challenge-${crypto.randomUUID()}@example.test`, password = "ChallengeSecret123";
            const user = await new AuthRepository().createUser({email, password, firstName: "Challenge", lastName: "Fixture", age: 25, emailVerified: true});
            const session = await fetch(base + "/auth/login", {method: "POST", headers: {"Content-Type": "application/json"},
                body: JSON.stringify({email, password})}).then(r => r.json()) as any;
            accounts.push({id: user!.id, token: session.token});
        }
    });
    afterAll(async () => {
        for (const account of accounts) await new UserRepository().deleteUserAccount(account.id);
        if (templates.length) await db.delete(challengesTable).where(inArray(challengesTable.id, templates));
    });
    test("catalogue and pages match the new frontend and require authentication", async () => {
        expect((await fetch(base + "/challenge/active")).status).toBe(401);
        const available = await json("/challenge/available?pageSize=100");
        expect(available.items.length).toBeGreaterThanOrEqual(12);
        expect(available.items.every((row: any) => row.source === "SYSTEM" && Array.isArray(row.conditions))).toBe(true);
        expect(Array.isArray(await json("/challenge/available"))).toBe(true);
        for (const query of ["pageSize=101", "pageSize=0", "pageSize=10&cursorId=" + crypto.randomUUID(), "pageSize=10&cursorId=invalid&cursorDate=invalid"]) {
            expect((await request("/challenge/completed?" + query)).status).toBe(400);
        }
    });
    test("concurrent starts and lost-ack retries create a single owned assignment", async () => {
        moodTemplate = await template("mood_count", 3);
        const attempts = await Promise.all(Array.from({length: 4}, () => request("/challenge/available/" + moodTemplate + "/start", 0, {})));
        expect(attempts.map(r => r.status).sort()).toEqual([200, 200, 200, 201]);
        const results = await Promise.all(attempts.map(r => r.json())) as any[];
        moodAssignment = results[0].userChallenge.id;
        expect(new Set(results.map(r => r.userChallenge.id)).size).toBe(1);
        expect(results[0].userChallenge.challenge.id).toBe(moodTemplate);
        expect(results[0].userChallenge.progress.condition_0.current).toBe(0);
        expect(await db.select().from(userChallengesTable).where(and(eq(userChallengesTable.userId, accounts[0]!.id), eq(userChallengesTable.challengeId, moodTemplate)))).toHaveLength(1);
    });
    test("real mood writes update progress, completion, one reward and one notification", async () => {
        await json("/user/mood", 0, {moodType: "happy"});
        await json("/user/mood", 0, {moodType: "neutral"});
        const active = (await json("/challenge/active")).find((row: any) => row.id === moodAssignment);
        expect(active.progress.condition_0).toMatchObject({current: 2, target: 3, completed: false});
        await json("/user/mood", 0, {moodType: "sad"});
        await Promise.all(Array.from({length: 6}, () => json("/challenge/completed")));
        const completed = (await json("/challenge/completed")).find((row: any) => row.id === moodAssignment);
        expect(completed).toMatchObject({status: "COMPLETED", challenge: {id: moodTemplate, rewardPoints: 77}});
        expect(completed.completedAt).toBeString();
        expect(await ledger(moodAssignment)).toHaveLength(1);
        expect((await ledger(moodAssignment))[0]!.points).toBe(77);
        const notifications = await db.select().from(notificationsTable).where(eq(notificationsTable.userId, accounts[0]!.id));
        expect(notifications.filter(row => JSON.parse(row.metadata ?? "{}").userChallengeId === moodAssignment)).toHaveLength(1);
        expect((await json("/challenge/available/" + moodTemplate + "/start", 0, {})).userChallenge.id).toBe(moodAssignment);
        expect(await ledger(moodAssignment)).toHaveLength(1);
        expect(await json("/challenge/completed", 1)).toBeEmpty();
    });
    test("journal saves count committed notes once and complete a journal challenge", async () => {
        const id = await template("journal_count", 2, 33);
        const started = await json("/challenge/available/" + id + "/start", 0, {});
        const clientRequestId = crypto.randomUUID();
        await Promise.all(Array.from({length: 3}, () => json("/journal", 0, {title: "Note fixture", content: "Une première note", clientRequestId})));
        const current = (await json("/challenge/active")).find((row: any) => row.challengeId === id);
        expect(current.progress.condition_0.current).toBe(1);
        await json("/journal", 0, {title: "Deuxième note", content: "Un autre moment"});
        const completed = (await json("/challenge/completed")).find((row: any) => row.challengeId === id);
        expect(completed.status).toBe("COMPLETED");
        expect(await ledger(started.userChallenge.id)).toHaveLength(1);
    });
    test("proposals retain template details, validate conditions and remain account scoped", async () => {
        const make = async () => {
            const result = await json("/challenge/proposals", 0, {title: "Une proposition privée", description: "Fixture uniquement",
                conditions: [{type: "mood_count", target: 20}], aggregator: "ALL"});
            templates.push(result.template.id); return result;
        };
        const first = await make(), second = await make();
        expect((await request("/challenge/available/" + first.template.id + "/start", 1, {})).status).toBe(404);
        for (const action of ["accept", "reject"]) {
            expect((await request("/challenge/proposals/" + first.userChallenge.id + "/" + action, 1, {})).status).toBe(404);
        }
        const accepted = await Promise.all(Array.from({length: 3}, () => json("/challenge/proposals/" + first.userChallenge.id + "/accept", 0, {})));
        expect(accepted.every(row => row.status === "ACTIVE" && row.challenge.title === "Une proposition privée")).toBe(true);
        expect(accepted[0].progress.condition_0).toMatchObject({current: 3, target: 20});
        for (let i = 0; i < 2; i++) expect((await json("/challenge/proposals/" + second.userChallenge.id + "/reject", 0, {})).status).toBe("REJECTED");
        expect((await request("/challenge/proposals/" + second.userChallenge.id + "/accept", 0, {})).status).toBe(409);
        expect((await json("/challenge/proposals")).some((row: any) => row.id === second.userChallenge.id)).toBe(false);
        for (const conditions of [[], [{type: "invented", target: 1}], [{type: "mood_count", target: 0}]]) {
            expect((await request("/challenge/proposals", 0, {title: "Invalid fixture", conditions})).status).toBe(400);
        }
    });
    test("all completed history is reachable across timestamp ties and milliseconds", async () => {
        const id = await template("mood_count", 1);
        await db.insert(userChallengesTable).values(Array.from({length: 125}, () => ({
            userId: accounts[0]!.id, challengeId: id, status: "COMPLETED", progress: {},
            createdAt: new Date("2026-01-10T12:00:00.123Z"), completedAt: new Date("2026-01-10T12:00:00.123Z"),
        })));
        await db.execute(sql`UPDATE user_challenges SET created_at = created_at + ((get_byte(decode(replace(id::text, '-', ''), 'hex'), 15) % 9) * interval '1 microsecond') WHERE challenge_id = ${id}`);
        const rows: any[] = [];
        let cursor: any;
        do {
            const query = new URLSearchParams({pageSize: "37"});
            if (cursor) {query.set("cursorDate", cursor.createdAt); query.set("cursorId", cursor.id);}
            const page = await json("/challenge/completed?" + query);
            expect(page.items.length).toBeLessThanOrEqual(37);
            rows.push(...page.items); cursor = page.nextCursor;
        } while (cursor);
        expect(rows.filter(row => row.challengeId === id)).toHaveLength(125);
        expect(new Set(rows.map(row => row.id)).size).toBe(rows.length);
        expect((await json("/challenge/completed?pageSize=100", 1)).items).toBeEmpty();
    });
    test("competing activity writes cannot regress completion or grant points twice", async () => {
        const id = await template("journal_count", 5);
        const started = await json("/challenge/available/" + id + "/start", 0, {});
        await Promise.all(Array.from({length: 3}, (_, i) => json("/journal", 0, {title: "Concurrent " + i, content: "Fixture de concurrence"})));
        const completed = (await json("/challenge/completed")).find((row: any) => row.challengeId === id);
        expect(completed.status).toBe("COMPLETED");
        await Promise.all(Array.from({length: 4}, () => json("/challenge/active")));
        expect((await json("/challenge/completed")).some((row: any) => row.id === completed.id)).toBe(true);
        expect(await ledger(started.userChallenge.id)).toHaveLength(1);
    });
    test("account deletion removes private proposal templates and rewards while retaining shared and system challenges", async () => {
        const make = async () => {
            const result = await json("/challenge/proposals", 0, {title: "Private deletion fixture",
                conditions: [{type: "mood_count", target: 99}], aggregator: "ALL"});
            templates.push(result.template.id); return result.template.id as string;
        };
        const privateId = await make(), sharedId = await make();
        await new QuestRepository().assignChallengeToUser({userId: accounts[1]!.id, challengeId: sharedId, status: "PENDING"});
        await json("/user/account", 0, {password: "ChallengeSecret123"}, "DELETE");
        expect(await db.select().from(challengesTable).where(eq(challengesTable.id, privateId))).toBeEmpty();
        expect(await db.select().from(challengesTable).where(eq(challengesTable.id, sharedId))).toHaveLength(1);
        expect(await db.select().from(challengesTable).where(eq(challengesTable.id, moodTemplate))).toHaveLength(1);
        expect(await db.select().from(pointsLedgerTable).where(eq(pointsLedgerTable.userId, accounts[0]!.id))).toBeEmpty();
        expect(await db.select().from(notificationsTable).where(eq(notificationsTable.userId, accounts[0]!.id))).toBeEmpty();
    });
});

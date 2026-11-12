import {afterAll, beforeAll, describe, expect, test} from "bun:test";
import {eq} from "drizzle-orm";
import {db} from "../../config/db.config";
import {homeActivitiesTable, homeCommandsTable} from "../../config/db/home.table";
import {journalEntriesTable} from "../../config/db/journal.table";
import {challengesTable, userChallengesTable} from "../../config/db/quest.table";
import AuthRepository from "../../repository/auth.repository";
import UserRepository from "../../repository/user.repository";

const connected = Bun.env.HOME_INTEGRATION === "1" ? describe : describe.skip;
connected("Home extras through authenticated HTTP and disposable PostgreSQL", () => {
    const base = Bun.env.MOBILE_TEST_API_URL!;
    const accounts: Array<{id: string; token: string}> = [];
    const password = "HomeFixture123";
    const today = new Date().toISOString().slice(0, 10);
    let ownedEntry: string, foreignEntry: string, template: string;
    async function request(path: string, body?: unknown, owner = 0, method = body === undefined ? "GET" : "POST") {
        return fetch(base + path, {method, headers: {Authorization: `Bearer ${accounts[owner]!.token}`,
            ...(body !== undefined ? {"Content-Type": "application/json"} : {})},
            ...(body !== undefined ? {body: JSON.stringify(body)} : {})});
    }
    async function json(path: string, body?: unknown, owner = 0, method?: string): Promise<any> {
        const response = await request(path, body, owner, method), value = await response.json();
        expect(response.ok, `${path}: ${response.status} ${JSON.stringify(value)}`).toBe(true);
        return value;
    }
    const command = (command: unknown, owner = 0, requestId = crypto.randomUUID()) => json("/user/home/commands", {requestId, command}, owner);
    beforeAll(async () => {
        if (new URL(base).hostname !== "127.0.0.1" || Bun.env.DB_NAME !== "elyrii_frontend_test" || Bun.env.NODE_ENV !== "test") throw new Error("Local disposable fixture required");
        for (let i = 0; i < 2; i++) {
            const email = `home-${crypto.randomUUID()}@example.test`;
            const user = await new AuthRepository().createUser({email, password, firstName: "Home", lastName: "Fixture", age: 25, emailVerified: true});
            const login = await fetch(base + "/auth/login", {method: "POST", headers: {"Content-Type": "application/json"}, body: JSON.stringify({email, password})});
            expect(login.status).toBe(200);
            accounts.push({id: user!.id, token: (await login.json() as any).token});
        }
        const notes = await db.insert(journalEntriesTable).values([{userId: accounts[0]!.id, title: "Owned Home fixture"}, {userId: accounts[1]!.id, title: "FOREIGN_PRIVATE_NOTE"}]).returning();
        ownedEntry = notes[0]!.id; foreignEntry = notes[1]!.id;
        const [created] = await db.insert(challengesTable).values({title: "Home unlock fixture", source: "SYSTEM", conditions: []}).returning();
        template = created!.id;
    });
    afterAll(async () => {
        for (const account of accounts) await new UserRepository().deleteUserAccount(account.id);
        if (template) await db.delete(challengesTable).where(eq(challengesTable.id, template));
    });
    test("authentication, defaults and canonical civil-date validation", async () => {
        expect((await fetch(base + "/user/home")).status).toBe(401);
        const response = await request("/user/home");
        expect(response.headers.get("Cache-Control")).toBe("no-store");
        expect(await response.json()).toMatchObject({schemaVersion: 1, owner: accounts[0]!.id, revision: 0, activities: {decor: "arches", ritualDays: {}}});
        for (const command of [{kind: "ritual", day: "2026-02-30", ritual: "walk", done: true}, {kind: "decor", decor: "volcano"}, {kind: "question", day: today, count: 0}]) {
            expect((await request("/user/home/commands", {requestId: crypto.randomUUID(), command})).status).toBe(400);
        }
        expect((await request("/user/home/import", {owner: accounts[1]!.id, activities: {}})).status).toBe(403);
    });
    test("one-time local import retains owned history and cannot overwrite a later device", async () => {
        const input = {owner: accounts[0]!.id, activities: {decor: "hills", ritualDays: {[today]: {walk: new Date().toISOString()}}, threadAnswers: {[ownedEntry]: {reply: "ratherGood", answeredAt: new Date().toISOString()}, [foreignEntry]: {reply: "notGreat", answeredAt: new Date().toISOString()}}, addedRituals: ["water"]}};
        const imported = await json("/user/home/import", input);
        expect(imported.activities.decor).toBe("hills");
        expect(Object.keys(imported.activities.threadAnswers)).toEqual([ownedEntry]);
        await command({kind: "ritual", day: today, ritual: "walk", done: false});
        const repeated = await json("/user/home/import", input);
        expect(repeated.activities.ritualDays[today].walk).toBeUndefined();
        expect(repeated.revision).toBeGreaterThan(imported.revision);
    });
    test("two devices merge unrelated changes and duplicate deliveries execute once", async () => {
        const id = crypto.randomUUID(), input = {kind: "socialIdea", day: today};
        await Promise.all([command({kind: "ritual", day: today, ritual: "gratitude", done: true}), command({kind: "addRitual", ritual: "music"}), command(input, 0, id), command(input, 0, id)]);
        const result = await json("/user/home"), week = Object.values(result.activities.socialWeeks)[0] as any;
        expect(week.ideaIndex).toBe(1);
        expect(result.activities.ritualDays[today].gratitude).toBeString();
        expect(result.activities.addedRituals).toEqual(expect.arrayContaining(["water", "music"]));
        expect((await request("/user/home/commands", {requestId: id, command: {kind: "socialComplete", day: today}})).status).toBe(409);
        const first = await command({kind: "socialComplete", day: today});
        const again = await command({kind: "socialComplete", day: today});
        expect(again.activities.socialWeeks).toEqual(first.activities.socialWeeks);
        expect((await json("/user/home", undefined, 1)).activities.ritualDays).toEqual({});
    });
    test("journal follow-ups are owned, keep their first answer and locked scenes use server rewards", async () => {
        expect((await request("/user/home/commands", {requestId: crypto.randomUUID(), command: {kind: "thread", entryId: foreignEntry, reply: "notGreat"}})).status).toBe(404);
        const answer = await command({kind: "thread", entryId: ownedEntry, reply: "notGreat"});
        expect(answer.activities.threadAnswers[ownedEntry].reply).toBe("ratherGood");
        expect((await request("/user/home/commands", {requestId: crypto.randomUUID(), command: {kind: "decor", decor: "clearing"}})).status).toBe(403);
        await db.insert(userChallengesTable).values(Array.from({length: 10}, () => ({userId: accounts[0]!.id, challengeId: template, status: "COMPLETED"})));
        expect((await command({kind: "decor", decor: "clearing"})).activities.decor).toBe("clearing");
        const question = await command({kind: "question", day: today, count: 3});
        expect(question.activities.journalQuestion).toEqual({day: today, index: (Math.floor(Date.parse(today) / 86400000) + 1) % 3});
    });
    test("Home data is exported and account deletion cascades documents and receipts", async () => {
        const exported = await json("/user/export");
        expect(exported.home.userId).toBe(accounts[0]!.id);
        expect(exported.home.activities.decor).toBe("clearing");
        expect((await json("/user/export", undefined, 1)).home).toBeNull();
        await json("/user/account", {password}, 0, "DELETE");
        expect((await request("/user/home")).status).toBe(401);
        expect(await db.select().from(homeActivitiesTable).where(eq(homeActivitiesTable.userId, accounts[0]!.id))).toHaveLength(0);
        expect(await db.select().from(homeCommandsTable).where(eq(homeCommandsTable.userId, accounts[0]!.id))).toHaveLength(0);
        expect((await request("/user/home", undefined, 1)).status).toBe(200);
    });
});

import {afterAll, beforeAll, describe, expect, test} from "bun:test";
import {eq, sql} from "drizzle-orm";
import {db} from "../../config/db.config";
import {userSettingsTable} from "../../config/db/settings.table";
import {journalEntriesTable, journalTagsTable, journalEntryTagsTable, journalMediaTable} from "../../config/db/journal.table";
import {meditationSessionsTable} from "../../config/db/meditation.table";
import {notificationsTable} from "../../config/db/notification.table";
import {pointsLedgerTable} from "../../config/db/reward.table";
import {COACH_CATALOG} from "../coach/coach.catalog";
import AuthRepository from "../../repository/auth.repository";
import UserRepository from "../../repository/user.repository";

const connected = Bun.env.SETTINGS_INTEGRATION === "1" ? describe : describe.skip;
connected("Settings with disposable PostgreSQL and authenticated HTTP", () => {
    const base = Bun.env.MOBILE_TEST_API_URL!;
    const accounts: Array<{id: string; token: string}> = [];
    const password = "SettingsFixture123";
    async function request(path: string, body?: unknown, owner = 0, method = body === undefined ? "GET" : "PUT") {
        return fetch(base + path, {method, headers: {Authorization: `Bearer ${accounts[owner]!.token}`,
            ...(body !== undefined ? {"Content-Type": "application/json"} : {})},
            ...(body !== undefined ? {body: JSON.stringify(body)} : {})});
    }
    async function json(path: string, body?: unknown, owner = 0, method?: string): Promise<any> {
        const response = await request(path, body, owner, method), value = await response.json();
        expect(response.ok, `${path}: ${response.status} ${JSON.stringify(value)}`).toBe(true);
        return value;
    }
    beforeAll(async () => {
        if (new URL(base).hostname !== "127.0.0.1" || Bun.env.DB_NAME !== "elyrii_frontend_test" || Bun.env.NODE_ENV !== "test") throw new Error("Local disposable fixture required");
        for (let i = 0; i < 2; i++) {
            const email = `settings-${crypto.randomUUID()}@example.test`;
            const user = await new AuthRepository().createUser({email, password, firstName: "Settings", lastName: "Fixture", age: 25, emailVerified: true});
            const response = await fetch(base + "/auth/login", {method: "POST", headers: {"Content-Type": "application/json"}, body: JSON.stringify({email, password})});
            expect(response.status).toBe(200);
            accounts.push({id: user!.id, token: (await response.json() as any).token});
        }
    });
    afterAll(async () => { for (const account of accounts) await new UserRepository().deleteUserAccount(account.id); });

    test("preferences and exports require authentication; concurrent reads create one defaults row", async () => {
        for (const path of ["/user/settings", "/user/export"]) expect((await fetch(base + path)).status).toBe(401);
        const defaults = await Promise.all(Array.from({length: 5}, () => json("/user/settings")));
        expect(new Set(defaults.map(s => s.id)).size).toBe(1);
        expect(defaults[0]).toMatchObject({userId: accounts[0]!.id, themeMode: "SYSTEM", hapticsEnabled: true, language: "fr"});
        expect(await db.select().from(userSettingsTable).where(eq(userSettingsTable.userId, accounts[0]!.id))).toHaveLength(1);
        expect((await request("/user/settings")).headers.get("Cache-Control")).toBe("no-store");
    });

    test("partial and concurrent changes preserve other preferences and reject invalid values", async () => {
        await json("/user/settings", {language: "en", privacyMode: "STRICT", notificationsEnabled: false});
        await Promise.all([json("/user/settings", {themeMode: "DARK"}), json("/user/settings", {hapticsEnabled: false})]);
        expect(await json("/user/settings")).toMatchObject({themeMode: "DARK", hapticsEnabled: false, language: "en", privacyMode: "STRICT", notificationsEnabled: false});
        for (const value of [{themeMode: "blue"}, {hapticsEnabled: "false"}, {privacyMode: "public"}, {language: ""}]) {
            expect((await request("/user/settings", value)).status).toBe(400);
        }
        const saved = await request("/user/settings", {userId: accounts[1]!.id, themeMode: "LIGHT"});
        expect(saved.headers.get("Cache-Control")).toBe("no-store");
        expect((await saved.json() as any).userId).toBe(accounts[0]!.id);
        expect(await json("/user/settings", undefined, 1)).toMatchObject({themeMode: "SYSTEM", hapticsEnabled: true});
    });

    test("export includes complete owned history, archived Coach and attachments but excludes credentials and other owners", async () => {
        const owner = accounts[0]!.id, other = accounts[1]!.id;
        const entries = await db.insert(journalEntriesTable).values(Array.from({length: 125}, (_, i) => ({userId: owner, title: `Owned note ${i}`, content: "Fixture journal"}))).returning();
        const [deleted] = await db.insert(journalEntriesTable).values({userId: owner, title: "Deleted fixture", deletedAt: new Date()}).returning();
        const [foreign] = await db.insert(journalEntriesTable).values({userId: other, title: "FOREIGN_PRIVATE_DATA"}).returning();
        const tags = await db.insert(journalTagsTable).values([{userId: owner, name: "Owned tag"}, {userId: other, name: "FOREIGN_PRIVATE_TAG"}]).returning();
        await db.insert(journalEntryTagsTable).values([{entryId: entries[0]!.id, tagId: tags[0]!.id}, {entryId: entries[0]!.id, tagId: tags[1]!.id}]);
        await db.insert(journalMediaTable).values([{entryId: entries[0]!.id, url: "https://example.test/owned.png", type: "image"}, {entryId: deleted!.id, url: "https://example.test/deleted.png"}, {entryId: foreign!.id, url: "https://example.test/FOREIGN_PRIVATE_DATA.png"}]);
        // Baseline chat columns also work in the mobile-only migration fixture.
        await db.execute(sql`INSERT INTO chat_messages (user_id, role, message, conversation_id) VALUES (${owner}, 'user', 'Owned chat', ${crypto.randomUUID()}), (${other}, 'user', 'FOREIGN_PRIVATE_DATA', ${crypto.randomUUID()})`);
        await json("/user/mood", {moodType: "happy"}, 0, "POST");
        await db.insert(meditationSessionsTable).values({userId: owner, type: "facile", durationMinutes: 3, status: "COMPLETED"});
        await db.insert(notificationsTable).values({userId: owner, title: "Fixture notification", body: "Owned notification"});
        await db.insert(pointsLedgerTable).values({userId: owner, points: 50, reason: "fixture"});
        const first = (await json("/coach/journey/choose", {pathId: COACH_CATALOG[0]!.pathId, contentVersion: COACH_CATALOG[0]!.contentVersion, expectedEnrollmentId: null}, 0, "POST")).current;
        await json("/coach/journey/choose", {pathId: COACH_CATALOG[1]!.pathId, contentVersion: COACH_CATALOG[1]!.contentVersion, expectedEnrollmentId: first.enrollmentId}, 0, "POST");
        const response = await request("/user/export"), value = await response.json() as any;
        expect(response.status).toBe(200);
        expect(response.headers.get("Cache-Control")).toBe("no-store");
        expect(value.schemaVersion).toBe(1);
        expect(value.profile.id).toBe(owner);
        expect(value.profile.password).toBeUndefined();
        expect(value.profile.contextGeneration).toBeUndefined();
        expect(value.settings).toMatchObject({themeMode: "LIGHT", hapticsEnabled: false});
        expect(value.journal.entries).toHaveLength(125);
        expect(value.journal.tags).toHaveLength(1);
        expect(value.journal.entryTags).toEqual([{entryId: entries[0]!.id, tagId: tags[0]!.id}]);
        expect(value.journal.media).toHaveLength(1);
        expect(value.messages.map((m: any) => m.message)).toEqual(["Owned chat"]);
        expect(value.moods).toHaveLength(1);
        expect(value.meditationSessions).toHaveLength(1);
        expect(value.coachJourneys).toHaveLength(2);
        expect(value.coachJourneys.filter((j: any) => j.isCurrent)).toHaveLength(1);
        expect(value.notifications).toHaveLength(1);
        expect(value.points).toHaveLength(1);
        expect(JSON.stringify(value)).not.toContain("FOREIGN_PRIVATE");
        expect(JSON.stringify(value)).not.toContain(password);
        expect(value).not.toHaveProperty("refreshTokens");
        expect((await json("/user/export", undefined, 1)).journal.entries).toHaveLength(1);
    });

    test("password-protected deletion removes preferences and export access without affecting another account", async () => {
        expect((await request("/user/account", {password: "wrong-password"}, 0, "DELETE")).status).toBe(401);
        expect((await request("/user/export")).status).toBe(200);
        await json("/user/account", {password}, 0, "DELETE");
        expect((await request("/user/settings")).status).toBe(401);
        expect((await request("/user/export")).status).toBe(401);
        expect(await db.select().from(userSettingsTable).where(eq(userSettingsTable.userId, accounts[0]!.id))).toHaveLength(0);
        expect(await db.select().from(journalEntriesTable).where(eq(journalEntriesTable.userId, accounts[0]!.id))).toHaveLength(0);
        expect((await json("/user/export", undefined, 1)).profile.id).toBe(accounts[1]!.id);
    });
});

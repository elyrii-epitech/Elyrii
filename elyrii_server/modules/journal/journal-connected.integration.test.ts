import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { eq, sql } from "drizzle-orm";
import { db } from "../../config/db.config";
import { journalEntriesTable, journalTagsTable, journalEntryTagsTable, journalMediaTable } from "../../config/db/journal.table";
import AuthRepository from "../../repository/auth.repository";
import UserRepository from "../../repository/user.repository";

const connected = Bun.env.JOURNAL_INTEGRATION === "1" ? describe : describe.skip;
connected("journal through the running local API", () => {
    const base = Bun.env.MOBILE_TEST_API_URL ?? "http://127.0.0.1:3188";
    const password = "JournalSecret123";
    const accounts: Array<{id: string; token: string}> = [];
    const requestId = crypto.randomUUID();
    let entryId: string;
    async function request(path: string, token?: string, body?: unknown, method = body === undefined ? "GET" : "POST") {
        return fetch(base + path, {method, headers: {
            ...(token ? {Authorization: `Bearer ${token}`} : {}),
            ...(body !== undefined ? {"Content-Type": "application/json"} : {}),
        }, ...(body !== undefined ? {body: JSON.stringify(body)} : {})});
    }
    async function json(path: string, token: string, body?: unknown, method?: string): Promise<any> {
        const response = await request(path, token, body, method);
        const result = await response.json();
        expect(response.ok, `${path}: ${response.status} ${JSON.stringify(result)}`).toBe(true);
        return result;
    }
    beforeAll(async () => {
        if (new URL(base).hostname !== "127.0.0.1" || Bun.env.DB_NAME !== "elyrii_frontend_test" ||
            Bun.env.DB_HOST !== "127.0.0.1" || Bun.env.NODE_ENV !== "test") throw new Error("Disposable local database required");
        for (let i = 0; i < 2; i++) {
            const email = `journal-${crypto.randomUUID()}@example.test`;
            const user = await new AuthRepository().createUser({email, password, firstName: "Journal", lastName: "Fixture", age: 25, emailVerified: true});
            const session = await json("/auth/login", "", {email, password});
            accounts.push({id: user!.id, token: session.token});
        }
    });
    afterAll(async () => {
        for (const account of accounts) await new UserRepository().deleteUserAccount(account.id);
    });
    test("retrying a committed create is duplicate safe and keeps the original content", async () => {
        const payload = {title: "Ma note", content: "Texte privé", mood: "happy", tags: ["Calme"], clientRequestId: requestId};
        const results = await Promise.all(Array.from({length: 4}, () => json("/journal", accounts[0]!.token, payload)));
        entryId = results[0].body.id;
        expect(new Set(results.map(r => r.body.id)).size).toBe(1);
        expect(results.every(r => r.body.wasCreated === undefined)).toBe(true);
        const replay = await json("/journal", accounts[0]!.token, {...payload, mood: "sad", content: "New revision"});
        expect(replay.body).toMatchObject({id: entryId, mood: "happy", content: "Texte privé"});
        expect((await db.select().from(journalEntryTagsTable).where(eq(journalEntryTagsTable.entryId, entryId))).length).toBe(1);
        const other = await json("/journal", accounts[1]!.token, payload);
        expect(other.body.id).not.toBe(entryId);
    });
    test("read, edit and delete are owner scoped", async () => {
        for (const method of ["GET", "PUT", "DELETE"]) {
            const response = await request(`/journal/${entryId}`, accounts[1]!.token, method === "PUT" ? {content: "Intrusion"} : undefined, method);
            expect(response.status).toBe(404);
        }
        expect((await request("/journal?limit=100")).status).toBe(401);
        const updated = await json(`/journal/${entryId}`, accounts[0]!.token, {title: "Modifiée", content: "Ma nouvelle note", mood: "neutral"}, "PUT");
        expect(updated.body).toMatchObject({title: "Modifiée", content: "Ma nouvelle note", mood: "neutral"});
        expect(await json(`/journal/${entryId}`, accounts[0]!.token)).toMatchObject(updated.body);
    });
    test("bounded cursor pages cover timestamp ties and microseconds in both directions", async () => {
        await db.insert(journalEntriesTable).values(Array.from({length: 125}, (_, i) => ({
            userId: accounts[0]!.id, title: `Fixture ${i}`, createdAt: new Date("2026-09-18T12:00:00.123Z"),
        })));
        // PostgreSQL precision exceeds the JSON cursor. Every row must still appear once.
        await db.execute(sql`UPDATE journal_entries SET created_at = created_at + ((get_byte(decode(replace(id::text, '-', ''), 'hex'), 15) % 9) * interval '1 microsecond') WHERE user_id = ${accounts[0]!.id} AND title LIKE 'Fixture %'`);
        for (const order of ["asc", "desc"]) {
            const ids: string[] = [];
            let cursor: any = null;
            do {
                const query = new URLSearchParams({limit: "17", order});
                if (cursor) {query.set("cursorDate", cursor.createdAt); query.set("cursorId", cursor.id);}
                const page = await json("/journal?" + query, accounts[0]!.token);
                expect(page.totalCount).toBe(126);
                expect(page.entries.length).toBeLessThanOrEqual(17);
                ids.push(...page.entries.map((e: any) => e.id));
                cursor = page.nextCursor;
            } while (cursor);
            expect(ids.length).toBe(126);
            expect(new Set(ids).size).toBe(126);
        }
        const filtered = await json("/journal?limit=100&startDate=2026-09-18T00:00:00Z&endDate=2026-09-19T00:00:00Z", accounts[0]!.token);
        expect(filtered.totalCount).toBe(125);
        expect(filtered.entries.length).toBe(100);
        expect(Array.isArray(await json("/journal", accounts[0]!.token))).toBe(true);
        for (const query of ["limit=101", "limit=0", "limit=2&cursorId=" + entryId, "limit=2&cursorDate=invalid&cursorId=" + entryId, "limit=2&order=bad", "limit=2&startDate=2026-10-20&endDate=2026-10-01"]) {
            expect((await request("/journal?" + query, accounts[0]!.token)).status).toBe(400);
        }
    });
    test("deletion hides the note and an old retry cannot resurrect it", async () => {
        await json(`/journal/${entryId}`, accounts[0]!.token, undefined, "DELETE");
        expect((await request(`/journal/${entryId}`, accounts[0]!.token)).status).toBe(404);
        expect((await request("/journal", accounts[0]!.token, {title: "Replay", clientRequestId: requestId})).status).toBe(409);
        expect((await json("/journal?limit=100", accounts[0]!.token)).totalCount).toBe(125);
    });
    test("account deletion removes journal relations without touching another account", async () => {
        const account = accounts[1]!;
        const page = await json("/journal?limit=100", account.token);
        const id = page.entries[0].id;
        await json(`/journal/${id}/media`, account.token, {url: "https://example.test/fixture.jpg", type: "image"});
        await json("/user/account", account.token, {password}, "DELETE");
        expect(await db.select().from(journalEntriesTable).where(eq(journalEntriesTable.userId, account.id))).toBeEmpty();
        expect(await db.select().from(journalTagsTable).where(eq(journalTagsTable.userId, account.id))).toBeEmpty();
        expect(await db.select().from(journalMediaTable).where(eq(journalMediaTable.entryId, id))).toBeEmpty();
        expect(await db.select().from(journalEntryTagsTable).where(eq(journalEntryTagsTable.entryId, id))).toBeEmpty();
        expect((await json("/journal?limit=100", accounts[0]!.token)).totalCount).toBe(125);
    });
});

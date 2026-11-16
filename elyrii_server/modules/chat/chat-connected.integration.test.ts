import {afterAll, beforeAll, describe, expect, test} from "bun:test";
import {eq} from "drizzle-orm";
import {db} from "../../config/db.config";
import {chatMessagesTable} from "../../config/db/chat.table";
import AuthRepository from "../../repository/auth.repository";
import UserRepository from "../../repository/user.repository";

const connected = Bun.env.CHAT_INTEGRATION === "1" ? describe : describe.skip;
connected("chat over real HTTP, WebSocket, Kafka and PostgreSQL", () => {
    const base = Bun.env.MOBILE_TEST_API_URL!;
    const accounts: Array<{id: string; token: string}> = [];
    const sockets: WebSocket[] = [];
    const conversationId = crypto.randomUUID(), messageId = crypto.randomUUID();
    async function json(path: string, token: string, method = "GET") {
        const response = await fetch(base + path, {method, headers: {Authorization: `Bearer ${token}`}});
        expect(response.ok, `${path}: ${response.status}`).toBe(true);
        return response.status === 204 ? null : await response.json() as any;
    }
    async function open(token?: string, claimedUser?: string) {
        const socket = new WebSocket(base.replace("http", "ws") + "/chat/ws" + (claimedUser ? "?userId=" + claimedUser : ""),
            {headers: token ? {Authorization: `Bearer ${token}`} : {}});
        const frames: any[] = [];
        socket.addEventListener("message", event => frames.push(JSON.parse(String(event.data))));
        sockets.push(socket);
        await new Promise<void>((resolve, reject) => {
            socket.addEventListener("open", () => resolve(), {once: true});
            socket.addEventListener("error", reject, {once: true});
        });
        return {socket, frames};
    }
    async function until(condition: () => boolean) {
        const start = Date.now();
        while (!condition()) {
            if (Date.now() - start > 10000) throw new Error("Timed out waiting for local chat");
            await Bun.sleep(10);
        }
    }
    beforeAll(async () => {
        if (new URL(base).hostname !== "127.0.0.1" || Bun.env.DB_NAME !== "elyrii_frontend_test" || Bun.env.NODE_ENV !== "test") throw new Error("Local fixture required");
        for (let i = 0; i < 2; i++) {
            const email = `chat-${crypto.randomUUID()}@example.test`;
            const user = await new AuthRepository().createUser({email, password: "ChatSecret123", firstName: "Chat", lastName: "Fixture", age: 25, emailVerified: true});
            const session = await fetch(base + "/auth/login", {method: "POST", headers: {"Content-Type": "application/json"},
                body: JSON.stringify({email, password: "ChatSecret123"})}).then(r => r.json()) as any;
            accounts.push({id: user!.id, token: session.token});
        }
    });
    afterAll(async () => {
        for (const socket of sockets) socket.close();
        for (const account of accounts) await new UserRepository().deleteUserAccount(account.id);
    });
    test("unauthenticated sockets close and cannot select an owner through the URL", async () => {
        const {socket} = await open(undefined, accounts[0]!.id);
        await until(() => socket.readyState === WebSocket.CLOSED);
        expect(socket.readyState).toBe(WebSocket.CLOSED);
        expect((await fetch(base + "/chat/history")).status).toBe(401);
    });
    test("correlated replies persist before acknowledgement and retries do not duplicate either message", async () => {
        const first = await open(accounts[0]!.token);
        const otherSocket = await open(accounts[0]!.token);
        const requestId = crypto.randomUUID();
        first.socket.send(JSON.stringify({message: "J’ai besoin d’une pause.", requestId, messageId, conversationId}));
        await until(() => first.frames.length === 1);
        expect(first.frames[0]).toMatchObject({type: "reply", requestId, conversationId});
        expect(first.frames[0].messageId).toBeString();
        expect(otherSocket.frames).toBeEmpty();
        const retryId = crypto.randomUUID();
        otherSocket.socket.send(JSON.stringify({message: "J’ai besoin d’une pause.", requestId: retryId, messageId, conversationId}));
        await until(() => otherSocket.frames.length === 1);
        expect(otherSocket.frames[0]).toMatchObject({requestId: retryId, messageId: first.frames[0].messageId});
        const history = await json("/chat/history?conversationId=" + conversationId, accounts[0]!.token);
        expect(history).toHaveLength(2);
        expect(history.every((row: any) => row.delivery === "delivered")).toBe(true);
        expect(history[0].id).toBe(messageId);
        expect(history[1].id).toBe(first.frames[0].messageId);
        expect((await json("/chat/conversations", accounts[0]!.token))[0]).toMatchObject({id: conversationId, messageCount: 2});
        expect(await json("/chat/history?conversationId=" + conversationId, accounts[1]!.token)).toBeEmpty();
        expect(await json("/chat/conversations", accounts[1]!.token)).toBeEmpty();
    });
    test("simultaneous conversations can finish out of order without crossing sockets or IDs", async () => {
        const a = await open(accounts[0]!.token), b = await open(accounts[0]!.token);
        const requests = ["[slow] A", "B"].map(message => ({message, messageId: crypto.randomUUID(),
            requestId: crypto.randomUUID(), conversationId: crypto.randomUUID()}));
        a.socket.send(JSON.stringify(requests[0])); b.socket.send(JSON.stringify(requests[1]));
        await until(() => b.frames.length === 1);
        expect(b.frames[0].conversationId).toBe(requests[1]!.conversationId);
        expect(a.frames).toBeEmpty();
        await until(() => a.frames.length === 1);
        expect(a.frames[0].conversationId).toBe(requests[0]!.conversationId);
        a.socket.close();
        const next = {...requests[1]!, message: "Toujours connecté", messageId: crypto.randomUUID(), requestId: crypto.randomUUID()};
        b.socket.send(JSON.stringify(next));
        await until(() => b.frames.length === 2);
        expect(b.frames[1].requestId).toBe(next.requestId);
    });
    test("history and conversation pages are bounded and account scoped, including timestamp ties", async () => {
        const id = crypto.randomUUID();
        await db.insert(chatMessagesTable).values(Array.from({length: 125}, (_, i) => ({
            userId: accounts[0]!.id, conversationId: id, role: "user", message: `Fixture ${i}`, createdAt: new Date("2026-09-18T12:00:00.123Z"),
        })));
        const all: string[] = [];
        let before: string | undefined;
        do {
            const page = await json("/chat/history?limit=50&conversationId=" + id + (before ? "&beforeId=" + before : ""), accounts[0]!.token);
            expect(page.length).toBeLessThanOrEqual(50);
            expect(page.every((row: any) => row.delivery === "failed")).toBe(true);
            all.push(...page.map((m: any) => m.id));
            before = page.length === 50 ? page[0].id : undefined;
        } while (before);
        expect(new Set(all).size).toBe(125);
        expect(all.length).toBe(125);
        const foreign = await json("/chat/history?limit=50&conversationId=" + id + "&beforeId=" + messageId, accounts[1]!.token);
        expect(foreign).toBeEmpty();
        expect((await fetch(base + "/chat/conversations?limit=51", {headers: {Authorization: `Bearer ${accounts[0]!.token}`}})).status).toBe(400);
    });
    test("deleting a conversation fences pending replies and retries, preserving other owners", async () => {
        const peer = await open(accounts[0]!.token);
        const input = {message: "[slow] À supprimer", requestId: crypto.randomUUID(), messageId: crypto.randomUUID(), conversationId: crypto.randomUUID()};
        peer.socket.send(JSON.stringify(input));
        for (let i = 0; i < 100; i++) {
            if ((await json("/chat/history?conversationId=" + input.conversationId, accounts[0]!.token)).length) break;
            await Bun.sleep(10);
        }
        await json("/chat/conversations/" + input.conversationId, accounts[0]!.token, "DELETE");
        await until(() => peer.frames.length === 1);
        expect(peer.frames[0].type).toBe("error");
        expect(await json("/chat/history?conversationId=" + input.conversationId, accounts[0]!.token)).toBeEmpty();
        peer.socket.send(JSON.stringify({...input, requestId: crypto.randomUUID()}));
        await until(() => peer.frames.length === 2);
        expect(peer.frames[1].type).toBe("error");
        await json("/chat/conversations/" + conversationId, accounts[1]!.token, "DELETE");
        expect(await json("/chat/history?conversationId=" + conversationId, accounts[0]!.token)).toHaveLength(2);
    });
    test("conversation metadata pages cover tied timestamps without duplicates", async () => {
        await db.insert(chatMessagesTable).values(Array.from({length: 60}, () => ({
            userId: accounts[0]!.id, conversationId: crypto.randomUUID(), role: "user",
            message: "Une conversation", createdAt: new Date("2026-09-19T12:00:00.123Z"),
        })));
        const ids: string[] = [];
        let cursor: any;
        do {
            const query = new URLSearchParams({limit: "17"});
            if (cursor) {query.set("beforeDate", cursor.updatedAt); query.set("beforeId", cursor.id);}
            const page = await json("/chat/conversations?" + query, accounts[0]!.token);
            expect(page.length).toBeLessThanOrEqual(17);
            expect(page.every((row: any) => row.userId === accounts[0]!.id)).toBe(true);
            ids.push(...page.map((row: any) => row.id));
            cursor = page.length === 17 ? page.at(-1) : undefined;
        } while (cursor);
        expect(ids.length).toBe(64);
        expect(new Set(ids).size).toBe(64);
    });
    test("logout revokes an already open socket before it can persist another message", async () => {
        const peer = await open(accounts[1]!.token);
        const response = await fetch(base + "/auth/logout", {method: "POST",
            headers: {Authorization: `Bearer ${accounts[1]!.token}`, "Content-Type": "application/json"}, body: "{}"});
        expect(response.ok).toBe(true);
        peer.socket.send(JSON.stringify({message: "Must be rejected", conversationId: crypto.randomUUID(),
            messageId: crypto.randomUUID(), requestId: crypto.randomUUID()}));
        await until(() => peer.socket.readyState === WebSocket.CLOSED);
        expect(await db.select().from(chatMessagesTable).where(eq(chatMessagesTable.userId, accounts[1]!.id))).toBeEmpty();
    });
});

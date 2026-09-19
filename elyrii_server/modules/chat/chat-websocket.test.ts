import { expect, mock, spyOn, test } from "bun:test";
import { Hono } from "hono";
import { websocket } from "hono/bun";

// Exercise the real controller, producer and consumer without external DB/Kafka.
const published: Array<{ key: string; value: string }> = [];
const persisted: Array<Record<string, unknown>> = [];
let consume: (event: { message: { value: Buffer } }) => Promise<void>;
let rejectNext = false;
mock.module("../../main", () => ({ clientSockets: new Map() }));
mock.module("../../repository/chat.repository", () => ({
    default: class {
        async createMessage(message: Record<string, unknown>) { persisted.push(message); }
        async getRecentMessagesForContext() { return []; }
    },
}));
mock.module("./chat.service", () => ({ kafkaService: {
    producer: { async send(batch: { messages: Array<{ key: string; value: string }> }) {
        if (rejectNext) { rejectNext = false; throw new Error("Test dispatch failure"); }
        published.push(...batch.messages);
    } },
    consumer: {
        async subscribe() {},
        async run(options: { eachMessage: typeof consume }) { consume = options.eachMessage; },
    },
} }));

test("real WebSocket pipeline correlates reordered replies, suppresses duplicates, and supports legacy clients", async () => {
    const previous = Bun.env.ALLOW_INSECURE_WS_USER_ID;
    Bun.env.ALLOW_INSECURE_WS_USER_ID = "true";
    const { default: chatRouter } = await import("./chat.controller");
    const { handleAiResponse } = await import("./consumer.service");
    const { aiResponseTracker } = await import("./response-tracker.utils");
    if (previous === undefined) delete Bun.env.ALLOW_INSECURE_WS_USER_ID;
    else Bun.env.ALLOW_INSECURE_WS_USER_ID = previous;
    await handleAiResponse();
    const app = new Hono().route("/chat", chatRouter);
    const server = Bun.serve({ hostname: "127.0.0.1", port: 0, fetch: app.fetch, websocket });
    const client = new WebSocket(`ws://127.0.0.1:${server.port}/chat/ws?userId=qa-user`);
    const received: string[] = [];
    client.addEventListener("message", event => received.push(String(event.data)));
    async function until(condition: () => boolean) {
        const deadline = Date.now() + 2000;
        while (!condition()) {
            if (Date.now() >= deadline) throw new Error("Pipeline did not reach expected state");
            await Bun.sleep(5);
        }
    }
    async function reply(index: number, text: string) {
        const request = published[index]!;
        const payload = JSON.parse(request.value);
        await consume({ message: { value: Buffer.from(JSON.stringify({
            userId: payload.userId, conversationId: payload.conversationId,
            requestId: request.key, response: text,
        })) } });
    }
    try {
        await until(() => client.readyState === WebSocket.OPEN);
        client.send(JSON.stringify({ requestId: "client-a", conversationId: "session-a", message: "Question A" }));
        client.send(JSON.stringify({ requestId: "client-b", conversationId: "session-b", message: "Question B" }));
        await until(() => published.length === 2);
        expect(published[0]!.key).not.toBe("client-a");
        await reply(1, "Answer B");
        await reply(0, "Answer A");
        await until(() => received.length === 2);
        expect(received.map(value => JSON.parse(value))).toEqual([
            { type: "reply", requestId: "client-b", conversationId: "session-b", message: "Answer B" },
            { type: "reply", requestId: "client-a", conversationId: "session-a", message: "Answer A" },
        ]);
        await reply(0, "Duplicate A");
        rejectNext = true;
        client.send(JSON.stringify({ requestId: "client-c", conversationId: "session-c", message: "Fails" }));
        await until(() => received.length >= 3);
        expect(JSON.parse(received[2]!)).toMatchObject({ type: "error", requestId: "client-c", conversationId: "session-c" });
        client.send("Legacy question");
        await until(() => published.length === 3);
        await reply(2, "Legacy answer");
        await until(() => received.length >= 4);
        expect(received).toHaveLength(4);
        expect(received[3]).toBe("Legacy answer");
        expect(persisted.some(message => message.role === "ai" && message.message === "Answer B")).toBe(true);

        // Shorten only the test timeout; exercise the production error path.
        const request = aiResponseTracker.request.bind(aiResponseTracker);
        const shortTimeout = spyOn(aiResponseTracker, "request").mockImplementation(
            (id, dispatch) => request(id, dispatch, 100)
        );
        try {
            client.send(JSON.stringify({ requestId: "client-d", conversationId: "session-d", message: "Slow AI" }));
            await until(() => received.length >= 5);
            expect(JSON.parse(received[4]!)).toMatchObject({ type: "error", requestId: "client-d" });
            client.send(JSON.stringify({ requestId: "client-e", conversationId: "session-e", message: "New request" }));
            await until(() => published.length === 5);
            await reply(3, "Late D after timeout");
            await reply(4, "Answer E");
            await until(() => received.length >= 6);
            expect(received).toHaveLength(6);
            expect(JSON.parse(received[5]!)).toEqual({
                type: "reply", requestId: "client-e", conversationId: "session-e", message: "Answer E",
            });
        } finally {
            shortTimeout.mockRestore();
        }
    } finally {
        client.close();
        server.stop(true);
    }
});

import { expect, test } from "bun:test";
import { ResponseTracker } from "./response-tracker.utils";
import { chatResponse } from "./chat-protocol";

test("new clients receive IDs on both success and failure; old clients receive text", () => {
    for (const type of ["reply", "error"] as const) {
        expect(JSON.parse(chatResponse(type, "result", "session-a", "request-a")))
            .toEqual({ type, message: "result", conversationId: "session-a", requestId: "request-a" });
        expect(chatResponse(type, "result", "default")).toBe("result");
    }
});

test("registers before dispatch and handles an immediate AI response", async () => {
    const tracker = new ResponseTracker();
    const answer = await tracker.request("a", async () => {
        tracker.resolveResponse("a", "fast reply");
    });
    expect(answer).toBe("fast reply");
    expect(tracker.listenerCount("a")).toBe(0);
});

test("out-of-order replies resolve only their matching request", async () => {
    const tracker = new ResponseTracker();
    const a = tracker.request("a", async () => {});
    const b = tracker.request("b", async () => {});
    tracker.resolveResponse("b", "B");
    tracker.resolveResponse("a", "A");
    expect(await b).toBe("B");
    expect(await a).toBe("A");
});

test("timeout is terminal; a late result cannot satisfy another request", async () => {
    const tracker = new ResponseTracker();
    await expect(tracker.request("a", async () => {}, 5)).rejects.toThrow("Timeout");
    expect(tracker.listenerCount("a")).toBe(0);
    const b = tracker.request("b", async () => {});
    tracker.resolveResponse("a", "late A");
    expect(tracker.listenerCount("b")).toBe(1);
    tracker.resolveResponse("b", "B");
    expect(await b).toBe("B");
});

test("dispatch failure removes its listener and timer", async () => {
    const tracker = new ResponseTracker();
    await expect(tracker.request("a", async () => { throw new Error("Kafka offline"); }))
        .rejects.toThrow("Kafka offline");
    expect(tracker.listenerCount("a")).toBe(0);
});

import {describe, expect, test} from "bun:test";
import type {WSContext} from "hono/ws";
import {ChatDelivery} from "./chat-delivery";

function peer() {
    const frames: any[] = [];
    const socket = {readyState: WebSocket.OPEN, send: (frame: string) => frames.push(JSON.parse(frame))} as unknown as WSContext;
    return {socket, frames};
}
describe("originating chat delivery", () => {
    test("ownership, conversation and source must match; terminal results cannot be repeated", () => {
        const delivery = new ChatDelivery(), a = peer(), b = peer();
        delivery.register("server-key", {userId: "a", conversationId: "one", sourceMessageId: "source", requestId: "client-key", socket: a.socket});
        expect(delivery.finish("server-key", "b", "one", "reply", "foreign")).toBe(false);
        expect(delivery.finish("server-key", "a", "two", "reply", "wrong conversation")).toBe(false);
        expect(delivery.finish("server-key", "a", "one", "reply", "wrong source", undefined, undefined, "another")).toBe(false);
        expect(delivery.finish("server-key", "a", "one", "reply", "correct", "saved", new Date(0), "source")).toBe(true);
        expect(delivery.finish("server-key", "a", "one", "reply", "duplicate")).toBe(false);
        expect(a.frames).toEqual([{type: "reply", message: "correct", requestId: "client-key", conversationId: "one", messageId: "saved", createdAt: new Date(0).toISOString()}]);
        expect(b.frames).toBeEmpty();
    });
    test("closing one socket cancels only its own pending replies", () => {
        const delivery = new ChatDelivery(), a = peer(), b = peer();
        for (const [key, socket] of [["a", a.socket], ["b", b.socket]] as const) {
            delivery.register(key, {userId: "owner", conversationId: key, sourceMessageId: key, requestId: key, socket});
        }
        delivery.cancelSocket(a.socket);
        expect(delivery.finish("a", "owner", "a", "reply", "late")).toBe(false);
        expect(delivery.finish("b", "owner", "b", "reply", "current")).toBe(true);
        expect(a.frames).toBeEmpty();
        expect(b.frames).toHaveLength(1);
    });
    test("a deadline produces one correlated failure and releases the request", async () => {
        const delivery = new ChatDelivery(10), a = peer();
        delivery.register("key", {userId: "owner", conversationId: "one", sourceMessageId: "source", requestId: "client", socket: a.socket});
        await Bun.sleep(30);
        expect(a.frames).toHaveLength(1);
        expect(a.frames[0]).toMatchObject({type: "error", requestId: "client", conversationId: "one"});
        expect(delivery.finish("key", "owner", "one", "reply", "late")).toBe(false);
    });
});

import { expect, test } from "bun:test";
import { randomUUID } from "node:crypto";
import { bounded, issueTicket, prepareContext, verifyTicket } from "./context-dispatch";

test("rollout defaults off; signed tickets bind identity and reject tampering; retrieval fallback is bounded", async () => {
    const previous = process.env.ENABLE_PERSISTENT_CONTEXT, secret = process.env.CONTEXT_BRIDGE_SECRET;
    const user = randomUUID(), source = randomUUID();
    try {
        delete process.env.ENABLE_PERSISTENT_CONTEXT;
        expect(await prepareContext(user, "a", source, "hello", async () => { throw new Error("must not retrieve"); })).toBeUndefined();
        process.env.ENABLE_PERSISTENT_CONTEXT = "true";
        process.env.CONTEXT_BRIDGE_SECRET = "rollout-test-secret-32-characters-long";
        const ticket = issueTicket(user, "a", source);
        expect(verifyTicket(ticket).userId).toBe(user);
        expect(() => verifyTicket(ticket + "changed")).toThrow();
        expect(() => verifyTicket(issueTicket(user, "b", source).replace(/.$/, "!"))).toThrow();
        const result = await prepareContext(user, "a", source, "hello", async () => { throw new Error("provider down"); });
        expect(result!.sections).toBeNull(); expect(verifyTicket(result!.ticket).sourceMessageId).toBe(source);
        await expect(bounded(new Promise(() => {}), 5)).rejects.toThrow("Context timeout");
    } finally {
        if (previous === undefined) delete process.env.ENABLE_PERSISTENT_CONTEXT; else process.env.ENABLE_PERSISTENT_CONTEXT = previous;
        if (secret === undefined) delete process.env.CONTEXT_BRIDGE_SECRET; else process.env.CONTEXT_BRIDGE_SECRET = secret;
    }
});

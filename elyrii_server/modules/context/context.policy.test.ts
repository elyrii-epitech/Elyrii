import { describe, expect, test } from "bun:test";
import { ContextPolicy } from "./context.policy";
import { contextCandidateSchema, memoryCandidateSchema } from "./context.candidates";

const now = new Date("2030-01-01T00:00:00Z");
const base = { kind: "memory" as const, content: "Sad today", origin: "explicit" as const,
    sourceMessageId: "10000000-0000-4000-8000-000000000001", retention: "short_term" as const };
describe("Context contracts and retention", () => {
    test("defaults short retention without confusing event time and validity", () => {
        const policy = new ContextPolicy(() => now);
        const times = policy.memoryTimes(memoryCandidateSchema.parse({ ...base,
            eventAt: "2029-12-01T12:00:00+02:00", validUntil: "2030-01-01T12:00:00Z" }), now);
        expect(times.eventAt?.toISOString()).toBe("2029-12-01T10:00:00.000Z");
        expect(times.expiresAt?.toISOString()).toBe("2030-01-03T00:00:00.000Z");
        expect(times.validUntil?.toISOString()).toBe("2030-01-01T12:00:00.000Z");
        expect(policy.memoryTimes(memoryCandidateSchema.parse({ ...base, retention: "long_term" }), now).expiresAt).toBeNull();
    });
    test("configurable inclusive bounds reject invalid retention instead of silently extending it", () => {
        const policy = new ContextPolicy(() => now, { minMs: 1000, defaultMs: 2000, maxMs: 3000 });
        for (const ms of [1000, 3000]) expect(policy.memoryTimes(memoryCandidateSchema.parse({ ...base,
            expiresAt: new Date(+now + ms).toISOString() }), now).expiresAt?.getTime()).toBe(+now + ms);
        for (const ms of [999, 3001, -1]) expect(() => policy.memoryTimes(memoryCandidateSchema.parse({ ...base,
            expiresAt: new Date(+now + ms).toISOString() }), now)).toThrow();
        expect(() => new ContextPolicy(() => now, { minMs: 3000, defaultMs: 2000, maxMs: 1000 })).toThrow();
        expect(() => policy.memoryTimes(memoryCandidateSchema.parse({ ...base, retention: "long_term",
            expiresAt: now.toISOString() }), now)).toThrow();
        expect(() => policy.validity({ validUntil: now }, now)).toThrow();
    });
    test("rejects ownership injection, statuses, blank content and ambiguous times", () => {
        for (const extra of [{ userId: base.sourceMessageId }, { status: "active" },
            { content: " " }, { validFrom: "2030-01-01T00:00:00" }, { sourceMessageId: "invalid" }]) {
            expect(contextCandidateSchema.safeParse({ ...base, ...extra }).success).toBe(false);
        }
        expect(contextCandidateSchema.safeParse({ kind: "preference", key: "style", value: null,
            origin: "explicit", sourceMessageId: base.sourceMessageId }).success).toBe(false);
        expect(() => new ContextPolicy(() => new Date(NaN)).now()).toThrow();
    });
});

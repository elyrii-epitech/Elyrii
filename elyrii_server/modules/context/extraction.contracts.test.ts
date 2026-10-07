import { expect, test } from "bun:test";
import { canonical, extractionResultSchema, retryDelay, supportedBySource } from "./extraction.contracts";
import fixtures from "../../../elyrii_ai/test/fixtures/extraction_v1.json";

test("all #222 fixtures pass the server's strict proposal contract", () => {
    for (const fixture of fixtures) {
        const result = extractionResultSchema.parse({ version: 1,
            jobId: "22222222-2222-4222-8222-222222222222", requestId: "33333333-3333-4333-8333-333333333333",
            userId: "44444444-4444-4444-8444-444444444444", conversationId: "a",
            sourceMessageId: fixture.request.source.id, extractorVersion: "v1", attempt: 1, status: "success", output: fixture.output });
        if (result.status !== "success") throw new Error("Expected success");
        for (const proposal of result.output.candidates) {
            expect(supportedBySource(proposal, { id: fixture.request.source.id, message: fixture.request.source.content })).toBe(true);
        }
    }
});

test("canonical values and backoff are deterministic and bounded", () => {
    expect(canonical({ b: 2, a: [1, { z: false }] })).toBe(canonical({ a: [1, { z: false }], b: 2 }));
    expect(retryDelay(1)).toBe(5000);
    expect(retryDelay(5)).toBe(80000);
    expect(retryDelay(20)).toBe(300000);
});

import { expect, test } from "bun:test";
import { QueryEmbeddingProvider } from "./query-embedding";
import type { EmbeddingModel } from "./embedding.contracts";
const digest = "c".repeat(64);
const spec: EmbeddingModel = { id: `embeddinggemma-300m@sha256:${digest}:raw-v1:768`, digest,
    providerModel: "embeddinggemma:300m", dimensions: 768, metric: "cosine", preprocessing: "raw-v1" };
const vector = [2, ...Array(767).fill(0)];
const response = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status });
function provider(transform: (path: string, body: any, call: number) => Response = (_, body) => response(body)) {
    const calls: { path: string; body: any }[] = [];
    const request = (async (url: URL, init: RequestInit) => {
        const path = url.pathname;
        calls.push({ path, body: init.body ? JSON.parse(String(init.body)) : null });
        return transform(path, path === "/api/tags" ? { models: [{ name: spec.providerModel, digest }] } :
            { model: spec.providerModel, embeddings: [vector] }, calls.length);
    }) as unknown as typeof fetch;
    return { adapter: new QueryEmbeddingProvider(spec, "http://provider.test", request), calls };
}
test("query embedding matches raw-v1 memory encoding, checks digest twice and normalizes", async () => {
    const { adapter, calls } = provider();
    const result = await adapter.embed("  Bonjour café  ", new AbortController().signal);
    expect(result).toEqual([1, ...Array(767).fill(0)]);
    expect(calls.map(c => c.path)).toEqual(["/api/tags", "/api/embed", "/api/tags"]);
    expect(calls[1]!.body).toEqual({ model: spec.providerModel, input: "  Bonjour café  ", truncate: false,
        dimensions: 768, options: { num_ctx: 2048 } });
});
test("rejects artifact changes before and after embedding", async () => {
    for (const failingCall of [1, 3]) {
        const { adapter } = provider((path, body, call) => response(call === failingCall ? { models: [] } : body));
        await expect(adapter.embed("query", new AbortController().signal)).rejects.toThrow();
    }
});
test("rejects invalid dimensions, zero norms, nonnumeric values and malformed provider bodies", async () => {
    for (const bad of [[1, 0, 0], Array(768).fill(0), ["1", ...vector.slice(1)], [true, ...vector.slice(1)], [null, ...vector.slice(1)]]) {
        const { adapter } = provider((path, body) => response(path === "/api/embed" ? { ...body, embeddings: [bad] } : body));
        await expect(adapter.embed("query", new AbortController().signal)).rejects.toThrow();
    }
    for (const bad of [new Response("x".repeat(256001)), new Response("not JSON"), response({}, 503), response({}, 400)]) {
        const { adapter } = provider(() => bad);
        await expect(adapter.embed("query", new AbortController().signal)).rejects.toThrow();
    }
});
test("rejects blank or oversized inputs without contacting provider", async () => {
    const { adapter, calls } = provider();
    for (const input of [" ", "a".repeat(10001)]) await expect(adapter.embed(input, new AbortController().signal)).rejects.toThrow();
    expect(calls).toHaveLength(0);
});

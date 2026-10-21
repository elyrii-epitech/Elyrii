import { embeddingModelSchema, type EmbeddingModel } from "./embedding.contracts";

/** Same raw-v1 contract as the asynchronous memory worker. No text truncation. */
export class QueryEmbeddingProvider {
    readonly spec: EmbeddingModel;
    constructor(spec: EmbeddingModel, private readonly baseUrl = process.env.EMBEDDING_AI_BASE_URL || process.env.AI_BASE_URL || "http://localhost:11434",
        private readonly request: typeof fetch = fetch) {
        this.spec = embeddingModelSchema.parse(spec);
    }
    async embed(content: string, signal: AbortSignal): Promise<number[]> {
        if (!content.trim() || content.length > 10000 || Buffer.byteLength(content) > 40000) throw new Error("Invalid embedding input");
        const json = async (path: string, body?: unknown): Promise<any> => {
            const response = await this.request(new URL(path, this.baseUrl), { method: body ? "POST" : "GET", signal,
                headers: body ? { "Content-Type": "application/json" } : undefined, body: body ? JSON.stringify(body) : undefined });
            if (!response.ok || !response.body) { await response.body?.cancel(); throw new Error("Embedding provider failed"); }
            const reader = response.body.getReader();
            const chunks: Uint8Array[] = []; let bytes = 0;
            try {
                while (true) {
                    const part = await reader.read();
                    if (part.done) break;
                    bytes += part.value.byteLength;
                    if (bytes > 256000) throw new Error("Oversized embedding response");
                    chunks.push(part.value);
                }
                return JSON.parse(Buffer.concat(chunks).toString("utf8"));
            } finally { await reader.cancel(); reader.releaseLock(); }
        };
        const verify = async () => {
            const listing = await json("/api/tags");
            const matches = Array.isArray(listing?.models) ? listing.models.filter((m: any) => m?.name === this.spec.providerModel) : [];
            if (matches.length !== 1 || String(matches[0].digest).replace(/^sha256:/, "") !== this.spec.digest) throw new Error("Embedding artifact mismatch");
        };
        await verify();
        const result = await json("/api/embed", { model: this.spec.providerModel, input: content, truncate: false,
            dimensions: this.spec.dimensions, options: { num_ctx: 2048 } });
        if (result?.model !== this.spec.providerModel || !Array.isArray(result.embeddings) || result.embeddings.length !== 1) throw new Error("Embedding model mismatch");
        const vector = result.embeddings[0];
        if (!Array.isArray(vector) || vector.length !== this.spec.dimensions || vector.some(v => typeof v !== "number" || !Number.isFinite(v))) throw new Error("Invalid embedding vector");
        const norm = Math.hypot(...vector);
        if (!Number.isFinite(norm) || norm === 0) throw new Error("Invalid embedding norm");
        await verify();
        return vector.map(v => v / norm);
    }
}

import { z } from "zod";
import { RetrievalRepository } from "../../repository/retrieval.repository";
import { embeddingConfig, embeddingModelSchema, type EmbeddingModel } from "./embedding.contracts";
import { QueryEmbeddingProvider } from "./query-embedding";
import { retrievalConfig, retrievalConfigSchema, retrievalRequestSchema, type RankedMemory, type RetrievedContext,
    type RetrievalConfig, type RetrievalRequest } from "./retrieval.contracts";

export interface QueryEmbedder { readonly spec: EmbeddingModel; embed(content: string, signal: AbortSignal): Promise<number[]> }

/** Internal API: userId must come from authenticated server identity, never request JSON. */
export class ContextRetrievalService {
    private readonly config: RetrievalConfig;
    constructor(private readonly repository = new RetrievalRepository(), private readonly provider?: QueryEmbedder,
        config: RetrievalConfig = retrievalConfig()) {
        this.config = retrievalConfigSchema.parse(config);
    }
    async retrieve(userId: string, input: RetrievalRequest): Promise<RetrievedContext> {
        z.uuid().parse(userId);
        const request = retrievalRequestSchema.parse(input);
        let ranked: RankedMemory[] = [], spec: EmbeddingModel | undefined, semanticStatus: RetrievedContext["semanticStatus"] = "ok";
        try {
            const provider = this.provider ?? new QueryEmbeddingProvider(embeddingConfig());
            spec = embeddingModelSchema.parse(provider.spec);
            const controller = new AbortController();
            let timer: ReturnType<typeof setTimeout> | undefined;
            try {
                const vector = await Promise.race([provider.embed(request.query, controller.signal), new Promise<never>((_, reject) => {
                    timer = setTimeout(() => { controller.abort(); reject(new Error("Query embedding timed out")); }, this.config.timeoutMs);
                })]);
                if (vector.length !== spec.dimensions || vector.some(v => typeof v !== "number" || !Number.isFinite(v)) ||
                    Math.abs(Math.hypot(...vector) - 1) > 0.001) throw new Error("Invalid query vector");
                ranked = await this.repository.search(userId, spec, vector, this.config);
            } finally { clearTimeout(timer); controller.abort(); }
        } catch { semanticStatus = "unavailable"; ranked = []; }
        try {
            return { ...await this.repository.assemble(userId, request, spec, ranked, this.config), semanticStatus };
        } catch (error) {
            if (!ranked.length) throw error;
            // A failed vector lookup must not remove directly loaded facts and continuity.
            return { ...await this.repository.assemble(userId, request, undefined, [], this.config), semanticStatus: "unavailable" };
        }
    }
}

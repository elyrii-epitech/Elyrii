import { z } from "zod";

export const EMBEDDING_JOBS_TOPIC = "elyrii.context.embeddings.jobs.v1";
export const EMBEDDING_RESULTS_TOPIC = "elyrii.context.embeddings.results.v1";
export const embeddingModelSchema = z.strictObject({
    id: z.string().min(1).max(200), providerModel: z.literal("embeddinggemma:300m"),
    digest: z.string().regex(/^[0-9a-f]{64}$/), dimensions: z.literal(768),
    metric: z.literal("cosine"), preprocessing: z.literal("raw-v1"),
}).refine(m => m.id === `embeddinggemma-300m@sha256:${m.digest}:raw-v1:768`, "Model ID must encode the artifact and encoding policy");
export type EmbeddingModel = z.infer<typeof embeddingModelSchema>;
export function embeddingConfig(): EmbeddingModel {
    const digest = process.env.EMBEDDING_MODEL_DIGEST || "";
    return embeddingModelSchema.parse({ id: `embeddinggemma-300m@sha256:${digest}:raw-v1:768`,
        providerModel: "embeddinggemma:300m", digest, dimensions: 768, metric: "cosine", preprocessing: "raw-v1" });
}
const identity = { version: z.literal(1), jobId: z.uuid(), memoryId: z.uuid(), userId: z.uuid(),
    model: z.string().min(1).max(200), contentRevision: z.number().int().positive(), attempt: z.number().int().min(1).max(5) };
export const embeddingJobSchema = z.strictObject({ ...identity, spec: embeddingModelSchema,
    content: z.string().min(1).max(10000) }).refine(j => j.model === j.spec.id, "Model mismatch");
export const embeddingResultSchema = z.discriminatedUnion("status", [
    z.strictObject({ ...identity, status: z.literal("success"), dimensions: z.literal(768),
        embedding: z.array(z.number().finite().min(-1).max(1)).length(768) }).refine(r => {
        const norm = Math.hypot(...r.embedding); return Math.abs(norm - 1) < 0.001;
    }, "Expected a nonzero unit vector"),
    z.strictObject({ ...identity, status: z.literal("failure"), error: z.enum(["provider_failed", "invalid_input", "model_mismatch"]) }),
]);
export type EmbeddingJob = z.infer<typeof embeddingJobSchema>;

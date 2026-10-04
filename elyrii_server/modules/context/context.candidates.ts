import { z } from "zod";

// Wire DTOs accept explicit timezone offsets, never machine-local dates.
const instant = z.iso.datetime({ offset: true }).transform(value => new Date(value));
const provenance = {
    origin: z.enum(["explicit", "inferred"]),
    sourceMessageId: z.uuid(),
    validFrom: instant.optional(),
    validUntil: instant.nullable().optional(),
};
const factFields = {
    ...provenance,
    key: z.string().trim().min(1).max(200),
    value: z.json().refine(value => value !== null, "A fact value cannot be null"),
};
export const factCandidateSchema = z.discriminatedUnion("kind", [
    z.strictObject({ ...factFields, kind: z.literal("fact") }),
    z.strictObject({ ...factFields, kind: z.literal("preference") }),
]);
export const memoryCandidateSchema = z.strictObject({
    ...provenance,
    kind: z.literal("memory"),
    content: z.string().trim().min(1).max(10000),
    retention: z.enum(["short_term", "long_term"]),
    eventAt: instant.nullable().optional(),
    expiresAt: instant.nullable().optional(),
});
export const contextCandidateSchema = z.union([factCandidateSchema, memoryCandidateSchema]);
export type FactCandidate = z.input<typeof factCandidateSchema>;
export type MemoryCandidate = z.input<typeof memoryCandidateSchema>;
export type ContextCandidate = z.input<typeof contextCandidateSchema>;
export type ParsedMemoryCandidate = z.output<typeof memoryCandidateSchema>;

export const summaryInputSchema = z.strictObject({
    conversationId: z.string().trim().min(1).max(200),
    summary: z.string().trim().min(1).max(20000),
    throughMessageId: z.uuid(),
});
export type SummaryInput = z.input<typeof summaryInputSchema>;
export const embeddingInputSchema = z.strictObject({
    model: z.string().trim().min(1).max(200),
    dimensions: z.number().int().min(1).max(16000),
    embedding: z.array(z.number().finite()).min(1).max(16000),
}).refine(value => value.embedding.length === value.dimensions, "Embedding dimension mismatch");
export type EmbeddingInput = z.input<typeof embeddingInputSchema>;

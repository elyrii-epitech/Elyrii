import { z } from "zod";

/** Owner comes from the authenticated envelope, never from a candidate's source. */
export const sourceReferenceSchema = z.strictObject({
    kind: z.enum(["chat", "journal"]), id: z.uuid(), revision: z.number().int().positive(),
});
export type SourceReference = z.infer<typeof sourceReferenceSchema>;
const instant = z.iso.datetime({ offset: true });
export const sourceEvidenceSchema = z.strictObject({
    field: z.enum(["title", "body", "mood"]), quote: z.string().min(1).max(4000),
    certainty: z.literal("certain"), category: z.enum(["stable_fact", "stable_preference", "temporary_emotion", "minor_event", "durable_life_event"]),
    temporalExpression: z.string().max(4000).nullable(), eventDate: z.iso.date().nullable(),
    timezone: z.string().nullable(), referenceAt: instant, extractorVersion: z.literal("journal-v1"),
});
const fact = z.strictObject({ kind: z.enum(["fact", "preference"]), key: z.string().trim().min(1).max(200),
    value: z.json().refine(v => v !== null), origin: z.enum(["explicit", "inferred"]), evidence: sourceEvidenceSchema.optional() });
const memory = z.strictObject({ kind: z.literal("memory"), content: z.string().trim().min(1).max(10000),
    origin: z.enum(["explicit", "inferred"]), retention: z.enum(["short_term", "long_term"]), eventAt: instant.nullable(), evidence: sourceEvidenceSchema.optional() });
// Foundation-only v2 DTO: no invented journal conversation, no model-chosen validity/expiry.
// #230 supplies inference/evidence validation before handing these candidates to storage.
export const sourceResultSchema = z.strictObject({
    version: z.literal(2), eventId: z.uuid(), userId: z.uuid(), generation: z.number().int().nonnegative(),
    source: sourceReferenceSchema,
    candidates: z.array(z.discriminatedUnion("kind", [fact, memory])).max(8),
});
export type SourceResult = z.infer<typeof sourceResultSchema>;
export function sourceReference(row: { sourceKind: "chat" | "journal" | null; sourceId: string | null; sourceRevision: number | null }): SourceReference | null {
    return row.sourceKind && row.sourceId && row.sourceRevision ? { kind: row.sourceKind, id: row.sourceId, revision: row.sourceRevision } : null;
}

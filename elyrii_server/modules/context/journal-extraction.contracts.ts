import { z } from "zod";
import { sourceResultSchema } from "./source.contracts";
export const JOURNAL_JOBS_TOPIC = "elyrii.context.journal.jobs.v1";
export const JOURNAL_RESULTS_TOPIC = "elyrii.context.journal.results.v1";
export const JOURNAL_MAX_BYTES = 24000;
const instant = z.iso.datetime({ offset: true });
const timezone = z.string().max(100).refine(s => { try { new Intl.DateTimeFormat("en", { timeZone: s }); return true; } catch { return false; } }).nullable();
export const journalInputSchema = z.strictObject({
    source: z.strictObject({ kind: z.literal("journal"), id: z.uuid(), revision: z.number().int().positive(),
        title: z.string().max(24000), body: z.string().max(24000), mood: z.string().max(1000).nullable(), createdAt: instant }),
    timezone,
}).refine(v => Buffer.byteLength(JSON.stringify(v)) <= JOURNAL_MAX_BYTES, "whole_entry_too_large");
export const journalProposalSchema = z.strictObject({
    candidate: z.discriminatedUnion("kind", [sourceResultSchema.shape.candidates.element.options[0].omit({ evidence: true }), sourceResultSchema.shape.candidates.element.options[1].omit({ evidence: true })]),
    field: z.enum(["title", "body", "mood"]), evidence: z.string().min(1).max(4000),
    certainty: z.enum(["certain", "uncertain"]), subject: z.enum(["author", "other", "unknown"]),
    assertion: z.enum(["affirmed", "negated", "quoted", "hypothetical"]),
    category: z.enum(["stable_fact", "stable_preference", "temporary_emotion", "minor_event", "durable_life_event"]),
    temporalExpression: z.string().min(1).max(4000).nullable(),
}).superRefine((p, ctx) => {
    const kind = { stable_fact: "fact", stable_preference: "preference", temporary_emotion: "memory", minor_event: "memory", durable_life_event: "memory" }[p.category];
    if (p.candidate.kind !== kind || (p.candidate.origin === "inferred" && p.certainty !== "uncertain") ||
        (p.candidate.kind === "memory" && p.candidate.retention !== (p.category === "durable_life_event" ? "long_term" : "short_term")))
        ctx.addIssue({ code: "custom", message: "Invalid classification" });
});
export const journalOutputSchema = z.strictObject({ promptVersion: z.literal("journal-v1"), candidates: z.array(journalProposalSchema).max(8) });
const identity = { version: z.literal(2), jobId: z.uuid(), eventId: z.uuid(), userId: z.uuid(), generation: z.number().int().nonnegative(),
    source: z.strictObject({ kind: z.literal("journal"), id: z.uuid(), revision: z.number().int().positive() }),
    extractorVersion: z.literal("journal-v1"), attempt: z.number().int().min(1).max(5) };
export const journalJobSchema = z.strictObject({ ...identity, input: journalInputSchema }).refine(j => j.source.id === j.input.source.id && j.source.revision === j.input.source.revision);
export const journalResultSchema = z.discriminatedUnion("status", [
    z.strictObject({ ...identity, status: z.literal("success"), output: journalOutputSchema }),
    z.strictObject({ ...identity, status: z.literal("failure"), error: z.enum(["inference_failed", "invalid_input"]) }),
]);
export type JournalJob = z.infer<typeof journalJobSchema>;
export type JournalProposal = z.infer<typeof journalProposalSchema>;
export type JournalInput = z.infer<typeof journalInputSchema>;
export function supportedJournalProposal(p: JournalProposal, input: JournalInput) {
    const text = input.source[p.field];
    return text !== null && text.includes(p.evidence) && (p.temporalExpression === null || p.evidence.includes(p.temporalExpression)) &&
        (p.candidate.kind !== "memory" || p.candidate.eventAt === null || p.evidence.includes(p.candidate.eventAt)) &&
        (p.field !== "mood" || p.category === "temporary_emotion");
}
export function eligibleJournalProposal(p: JournalProposal) {
    return p.certainty === "certain" && p.candidate.origin === "explicit" && p.subject === "author" && p.assertion === "affirmed";
}
/** Calendar dates retain day precision; never manufacture midnight as an event instant. */
export function journalEventDate(expression: string | null, createdAt: string, timezone: string | null): string | null {
    if (!expression) return null;
    if (/^\d{4}-\d{2}-\d{2}$/.test(expression)) {
        const d = new Date(expression); return Number.isFinite(+d) && d.toISOString().slice(0, 10) === expression ? expression : null;
    }
    if (!timezone) return null;
    const offset = ({ today: 0, yesterday: -1, tomorrow: 1, "aujourd'hui": 0, "aujourd’hui": 0, hier: -1, demain: 1 } as Record<string, number>)[expression.toLowerCase().trim()];
    if (offset === undefined) return null;
    const parts = new Intl.DateTimeFormat("en-US", { timeZone: timezone, year: "numeric", month: "2-digit", day: "2-digit" }).formatToParts(new Date(createdAt));
    const part = (type: string) => Number(parts.find(p => p.type === type)!.value);
    return new Date(Date.UTC(part("year"), part("month") - 1, part("day") + offset)).toISOString().slice(0, 10);
}

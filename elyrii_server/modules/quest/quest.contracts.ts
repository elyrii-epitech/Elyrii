import {z} from "zod";
import type {ChallengeProgress} from "./quest.types";

export const conditionSchema = z.object({
    type: z.enum(["mood_count", "mood_streak", "mood_variety", "journal_count", "journal_streak", "journal_min_words", "mood_and_journal_same_day"]),
    target: z.number().int().min(1).max(1000000),
    period: z.enum(["day", "week", "month", "all_time"]).optional(),
    filter: z.object({moodTypes: z.array(z.enum(["verySad", "sad", "neutral", "happy", "veryHappy"])).min(1).max(5).optional()}).optional(),
});
export const conditionsSchema = z.array(conditionSchema).min(1).max(20);
export const proposalSchema = z.object({
    title: z.string().trim().min(1).max(200),
    description: z.string().max(4000).optional(),
    conditions: conditionsSchema, aggregator: z.enum(["ALL", "ANY"]).default("ALL"),
    constraints: z.unknown().optional(),
});
export const challengePageSchema = z.object({
    pageSize: z.coerce.number().int().min(1).max(100),
    cursorDate: z.iso.datetime().optional(), cursorId: z.uuid().optional(),
}).refine(p => Boolean(p.cursorDate) === Boolean(p.cursorId));
export class QuestRequestError extends Error {
    constructor(message: string, readonly status: 404 | 409 | 422) { super(message); }
}
export function initialProgress(raw: unknown): ChallengeProgress {
    const parsed = conditionsSchema.safeParse(raw);
    if (!parsed.success) throw new QuestRequestError("Invalid challenge conditions", 422);
    return Object.fromEntries(parsed.data.map((condition, i) => [`condition_${i}`, {
        current: 0, target: condition.target, completed: false, updatedAt: new Date().toISOString(),
    }]));
}

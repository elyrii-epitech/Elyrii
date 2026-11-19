import {z} from "zod";

export const rituals = ["breathe", "gratitude", "walk", "reachOut", "water", "music"] as const;
const ritual = z.enum(rituals);
export const civilDay = z.string().regex(/^\d{4}-\d{2}-\d{2}$/).refine(value => {
    const date = new Date(value + "T00:00:00.000Z");
    return Number.isFinite(date.getTime()) && date.toISOString().slice(0, 10) === value;
}, "Invalid civil day");
const timestamp = z.string().datetime({offset: true});
const decor = z.enum(["arches", "hills", "waves", "clearing"]);
const question = z.object({day: civilDay, index: z.number().int().min(0).max(999)}).strict();
const socialWeek = z.object({ideaIndex: z.number().int().min(0).max(1000000), completedAt: z.record(civilDay, timestamp)}).strict();
export const homeFactsSchema = z.object({
    ritualDays: z.record(civilDay, z.record(z.string().refine(value => rituals.some(r => r === value)), timestamp)).default({}),
    socialWeeks: z.record(civilDay, socialWeek).default({}),
    threadAnswers: z.record(z.string().uuid(), z.object({reply: z.enum(["ratherGood", "notGreat"]), answeredAt: timestamp}).strict()).default({}),
    decor: decor.default("arches"), addedRituals: z.array(ritual).max(6).default([]),
    journalQuestion: question.nullable().default(null),
}).strict().superRefine((value, ctx) => {
    if (Object.keys(value.ritualDays).length > 380 || Object.keys(value.socialWeeks).length > 60 || Object.keys(value.threadAnswers).length > 50) {
        ctx.addIssue({code: z.ZodIssueCode.custom, message: "Home history exceeds retention"});
    }
    for (const [monday, week] of Object.entries(value.socialWeeks)) {
        const start = new Date(monday + "T00:00:00Z");
        if (start.getUTCDay() !== 1 || Object.keys(week.completedAt).some(day => day < monday || Date.parse(day) >= start.getTime() + 7 * 86400000)) {
            ctx.addIssue({code: z.ZodIssueCode.custom, message: "Invalid social week"});
        }
    }
});
export type HomeFacts = z.infer<typeof homeFactsSchema>;
export const emptyHome = (): HomeFacts => homeFactsSchema.parse({});
export const importHomeSchema = z.object({owner: z.string().uuid(), activities: homeFactsSchema}).strict();
export const homeCommandSchema = z.object({requestId: z.string().uuid(), command: z.discriminatedUnion("kind", [
    z.object({kind: z.literal("ritual"), day: civilDay, ritual, done: z.boolean()}).strict(),
    z.object({kind: z.literal("addRitual"), ritual}).strict(),
    z.object({kind: z.literal("socialComplete"), day: civilDay}).strict(),
    z.object({kind: z.literal("socialIdea"), day: civilDay}).strict(),
    z.object({kind: z.literal("thread"), entryId: z.string().uuid(), reply: z.enum(["ratherGood", "notGreat"])}).strict(),
    z.object({kind: z.literal("decor"), decor}).strict(),
    z.object({kind: z.literal("question"), day: civilDay, count: z.number().int().min(1).max(1000)}).strict(),
])}).strict();
export type HomeCommand = z.infer<typeof homeCommandSchema>;
export class HomeError extends Error {
    constructor(message: string, readonly status: 400 | 403 | 404 | 409) { super(message); }
}

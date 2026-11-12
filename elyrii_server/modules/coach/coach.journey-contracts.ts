import {z} from "zod";

const text = z.string().min(1).max(4000);
const id = z.string().min(1).max(100);
const minutes = z.number().int().min(1).max(1439);
export const coachPathSchema = z.object({
    pathId: id, title: text, description: text, contentVersion: z.number().int().min(1),
    topic: z.enum(["connection", "calm", "sleep"]),
    steps: z.array(z.object({stepId: id, title: text, instructions: text, durationMinutes: minutes,
        action: z.discriminatedUnion("kind", [
            z.object({kind: z.literal("none")}),
            z.object({kind: z.literal("journal"), prompt: text}),
            z.object({kind: z.literal("meditation"), programId: id, durationMinutes: minutes}),
        ]),
    })).min(1).max(30),
}).refine(p => new Set(p.steps.map(s => s.stepId)).size === p.steps.length);
export const coachEnrollmentSchema = z.object({
    enrollmentId: z.uuid(), path: coachPathSchema,
    status: z.enum(["active", "paused", "completed"]),
    completedStepCount: z.number().int().min(0).max(30),
    revision: z.number().int().min(1).max(1000000000),
    startedAt: z.iso.datetime(), updatedAt: z.iso.datetime(), completedAt: z.iso.datetime().nullable(),
}).refine(e => e.completedStepCount <= e.path.steps.length &&
    (e.status === "completed") === (e.completedStepCount === e.path.steps.length) &&
    (e.status === "completed") === (e.completedAt !== null) &&
    Date.parse(e.updatedAt) >= Date.parse(e.startedAt) &&
    (!e.completedAt || (Date.parse(e.completedAt) >= Date.parse(e.startedAt) && Date.parse(e.completedAt) <= Date.parse(e.updatedAt))));
export const chooseCoachSchema = z.object({pathId: id, contentVersion: z.number().int().min(1),
    expectedEnrollmentId: z.uuid().nullable()});
export const coachCommandSchema = z.object({enrollmentId: z.uuid(), revision: z.number().int().min(1)});
export class CoachJourneyError extends Error {
    constructor(message: string, readonly status: 400 | 404 | 409) { super(message); }
}
export type CoachPath = z.infer<typeof coachPathSchema>;
export type CoachEnrollment = z.infer<typeof coachEnrollmentSchema>;

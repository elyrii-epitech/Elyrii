import {z} from "zod";

export const meditationMoodSchema = z.enum(["verySad", "sad", "neutral", "happy", "veryHappy"]);
export const startMeditationSchema = z.object({
    clientSessionId: z.uuid().optional(),
    type: z.string().min(1).max(80),
    durationMinutes: z.number().int().min(1).max(1439),
    moodBefore: meditationMoodSchema.optional(),
});
export const completeMeditationSchema = z.object({
    notes: z.string().max(5000).optional(),
    moodBefore: meditationMoodSchema.optional(),
    moodAfter: meditationMoodSchema.optional(),
    endedAt: z.iso.datetime().optional(),
});
export class MeditationRequestError extends Error {
    constructor(message: string, readonly status: 400 | 404 | 409) { super(message); }
}

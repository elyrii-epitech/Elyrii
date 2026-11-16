import { z } from "zod";

export const moodValues = ["verySad", "sad", "neutral", "happy", "veryHappy"] as const;
export const moodConfigSchema = z.strictObject({
    enabled: z.boolean().default(false),
    freshnessHours: z.number().int().min(1).max(168).default(48),
});
export const moodConfig = () => moodConfigSchema.parse({
    enabled: process.env.ENABLE_PERSISTENT_CONTEXT === "true" && process.env.ENABLE_MOOD_CONTEXT === "true",
    freshnessHours: Number(process.env.MOOD_CONTEXT_FRESHNESS_HOURS ?? 48),
});
export const moodObservationSchema = z.strictObject({
    source: z.literal("mood_logs"),
    logId: z.uuid(),
    userId: z.uuid(),
    mood: z.enum(moodValues),
    observedAt: z.iso.datetime(),
    freshUntil: z.iso.datetime(),
    timezone: z.string().max(100),
});
export type MoodObservation = z.infer<typeof moodObservationSchema>;

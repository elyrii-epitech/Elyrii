import { z } from "zod";
import { getMeditationProgramById, MIN_MEDITATION_DURATION, MAX_MEDITATION_DURATION } from "./meditation.catalog";

export const startMeditationSchema = z.object({
    type: z.string().min(1).refine((id) => getMeditationProgramById(id) !== undefined, "Unknown meditation program type"),
    durationMinutes: z.number().int().min(MIN_MEDITATION_DURATION).max(MAX_MEDITATION_DURATION),
    moodBefore: z.string().optional(),
});

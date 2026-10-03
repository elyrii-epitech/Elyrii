import { describe, expect, test } from "bun:test";
import { getMeditationProgramById, MAX_MEDITATION_DURATION, MIN_MEDITATION_DURATION, MEDITATION_PROGRAMS } from "./meditation.catalog";
import { startMeditationSchema } from "./meditation.validation";
import { readFileSync } from "node:fs";

describe("meditation session preparation", () => {
    test("the server accepts every identifier offered by the Flutter catalogue", () => {
        const phases = readFileSync(new URL("../../../elyrii_app/lib/features/meditation/domain/models/breath_phase.dart", import.meta.url), "utf8");
        const guided = readFileSync(new URL("../../../elyrii_app/lib/features/meditation/domain/models/meditation_exercises.dart", import.meta.url), "utf8");
        const breathingIds = [...phases.matchAll(/^  (\w+)\(/gm)].map((match) => match[1]);
        const guidedIds = [...guided.matchAll(/id: '([^']+)'/g)].map((match) => match[1]);
        expect(MEDITATION_PROGRAMS.map((p) => p.id).sort()).toEqual([...breathingIds, ...guidedIds].sort());
    });
    test("all native exercises accept a duration chosen by the user", () => {
        for (const program of MEDITATION_PROGRAMS) {
            for (const durationMinutes of [1, 7, 23, 45, 59, 60, 61, 180, 181, 777, 1439]) {
                expect(startMeditationSchema.safeParse({ type: program.id, durationMinutes }).success).toBe(true);
            }
        }
    });
    test("every minute in the hours-and-minutes picker is accepted without presets", () => {
        for (let durationMinutes = 1; durationMinutes <= 1439; durationMinutes++) {
            expect(startMeditationSchema.safeParse({ type: "coherence", durationMinutes }).success).toBe(true);
        }
    });
    test("the catalogue publishes the same one-minute to 23h59 bounds as validation", () => {
        expect(MIN_MEDITATION_DURATION).toBe(1);
        expect(MAX_MEDITATION_DURATION).toBe(1439);
        for (const program of MEDITATION_PROGRAMS) {
            expect(program.minDurationMinutes).toBe(1);
            expect(program.maxDurationMinutes).toBe(1439);
        }
    });
    test("old program identifiers continue to work with custom durations", () => {
        for (const type of ["breathing-5m", "body-scan-10m", "grounding-15m"]) {
            expect(getMeditationProgramById(type)).toBeDefined();
            for (const durationMinutes of [7, 61, 1439]) {
                expect(startMeditationSchema.safeParse({ type, durationMinutes }).success).toBe(true);
            }
        }
    });
    test("invalid durations and unknown practices are rejected", () => {
        for (const durationMinutes of [0, -1, 1440, 86400, 2.5, "7", null, undefined, Number.NaN, Number.POSITIVE_INFINITY]) {
            expect(startMeditationSchema.safeParse({ type: "coherence", durationMinutes }).success).toBe(false);
        }
        expect(startMeditationSchema.safeParse({ type: "unknown", durationMinutes: 5 }).success).toBe(false);
    });
});

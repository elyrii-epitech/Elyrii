export type MeditationProgram = {
    id: string;
    title: string;
    description: string;
    durationMinutes: number;
    audioUrl: string;
    tags: string[];
};

export const MEDITATION_PROGRAMS: MeditationProgram[] = [
    {
        id: "breathing-5m",
        title: "Respiration apaisante",
        description: "Une session courte pour calmer le rythme mental.",
        durationMinutes: 5,
        audioUrl: "https://cdn.elyrii.app/audio/meditation/breathing-5m.mp3",
        tags: ["stress", "quick", "focus"],
    },
    {
        id: "body-scan-10m",
        title: "Body scan",
        description: "Balayage corporel progressif pour relâcher les tensions.",
        durationMinutes: 10,
        audioUrl: "https://cdn.elyrii.app/audio/meditation/body-scan-10m.mp3",
        tags: ["relax", "sleep", "awareness"],
    },
    {
        id: "grounding-15m",
        title: "Ancrage émotionnel",
        description: "Pratique guidée pour revenir au présent.",
        durationMinutes: 15,
        audioUrl: "https://cdn.elyrii.app/audio/meditation/grounding-15m.mp3",
        tags: ["anxiety", "grounding"],
    },
];

export function getMeditationProgramById(id: string): MeditationProgram | undefined {
    return MEDITATION_PROGRAMS.find((program) => program.id === id);
}

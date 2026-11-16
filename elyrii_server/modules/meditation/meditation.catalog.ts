export type MeditationProgram = {
    id: string;
    title: string;
    description: string;
    durationMinutes: number;
    audioUrl: string;
    tags: string[];
    guidance?: "breathing" | "written";
    minDurationMinutes?: number;
    maxDurationMinutes?: number;
};

// IDs shipped by the Flutter library and dashboard/journey entry points.
// Guidance stays on-device; these practices require no audio URL.
const nativePractices: Array<[string, string, "breathing" | "written"]> = [
    ["coherence", "Cohérence cardiaque", "breathing"],
    ["facile", "Découverte", "breathing"],
    ["carree", "Respiration carrée", "breathing"],
    ["relaxation478", "Relaxation 4-7-8", "breathing"],
    ["diaphragmatique", "Respiration ventrale", "breathing"],
    ["ujjayi", "Respiration Ujjayi", "breathing"],
    ["expirationLongue", "Expiration longue", "breathing"],
    ["mindful-breathing", "Souffle conscient", "written"],
    ["body-scan", "Scan corporel", "written"],
    ["sound-awareness", "Écoute attentive", "written"],
    ["loving-kindness", "Bienveillance", "written"],
    ["self-compassion", "Pause bienveillante", "written"],
];

export const MEDITATION_PROGRAMS: MeditationProgram[] = [
    ...nativePractices.map(([id, title, guidance]) => ({
        id, title, description: "Pratique guidée dans Elyrii.",
        durationMinutes: 5, audioUrl: "", tags: [guidance], guidance,
        minDurationMinutes: 1, maxDurationMinutes: 1439,
    })),
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

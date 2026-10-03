export type MeditationProgram = {
    id: string;
    title: string;
    description: string;
    durationMinutes: number;
    audioUrl: string;
    tags: string[];
    minDurationMinutes: number;
    maxDurationMinutes: number;
    guidanceMode: "breathing" | "written";
};

export const MIN_MEDITATION_DURATION = 1;
export const MAX_MEDITATION_DURATION = 180;

// durationMinutes is a suggested starting point, not an enforced duration.
function program(id: string, title: string, description: string, guidanceMode: "breathing" | "written", tags: string[], durationMinutes = 5): MeditationProgram {
    return { id, title, description, guidanceMode, tags, durationMinutes,
        minDurationMinutes: MIN_MEDITATION_DURATION,
        maxDurationMinutes: MAX_MEDITATION_DURATION,
        // Guidance is provided by the app; there is no recorded audio asset.
        audioUrl: "",
    };
}

export const MEDITATION_PROGRAMS: MeditationProgram[] = [
    program("facile", "Découverte", "Un repère de souffle doux 3–3, sans rétention.", "breathing", ["breathing", "beginner"]),
    program("coherence", "Équilibre", "Un rythme de six respirations par minute.", "breathing", ["breathing", "regular"]),
    program("expirationLongue", "Ralentir", "Un repère 4–6 pour laisser de la place à l’expiration.", "breathing", ["breathing", "slow"]),
    program("diaphragmatique", "Ventre détendu", "Observer les mouvements du ventre, sans rétention.", "breathing", ["breathing", "body"]),
    program("carree", "Focus", "Quatre phases de même durée.", "breathing", ["breathing", "focus"]),
    program("relaxation478", "Pause 4–7–8", "Quatre cycles, puis retour au souffle naturel.", "breathing", ["breathing", "rest"]),
    program("ujjayi", "Souffle océan", "Un souffle doux et sonore, inspiré du yoga.", "breathing", ["breathing", "yoga"]),
    program("mindful-breathing", "Souffle conscient", "Observer le souffle naturel sans le contrôler.", "written", ["mindfulness", "attention"]),
    program("body-scan", "Scan corporel", "Parcourir les sensations dans le corps.", "written", ["body", "awareness"], 10),
    program("sound-awareness", "Écoute des sons", "Accueillir les sons comme point d’attention.", "written", ["mindfulness", "present"]),
    program("loving-kindness", "Bienveillance", "S’adresser des souhaits bienveillants.", "written", ["kindness"]),
    program("self-compassion", "Auto-compassion", "Reconnaître ce que l’on vit et s’offrir du soutien.", "written", ["kindness", "self-compassion"]),
];

const LEGACY_PROGRAM_IDS: Record<string, string> = {
    "breathing-5m": "coherence",
    "body-scan-10m": "body-scan",
    "grounding-15m": "sound-awareness",
};

export function getMeditationProgramById(id: string): MeditationProgram | undefined {
    const canonicalId = Object.hasOwn(LEGACY_PROGRAM_IDS, id) ? LEGACY_PROGRAM_IDS[id] : id;
    return MEDITATION_PROGRAMS.find((program) => program.id === canonicalId);
}

export type ConditionType =
    | 'mood_count'               // Enregistrer X humeurs sur une période
    | 'mood_streak'              // Enregistrer son humeur X jours consécutifs
    | 'mood_variety'             // Enregistrer X types d'humeurs différents
    | 'journal_count'            // Écrire X entrées de journal sur une période
    | 'journal_streak'           // Écrire dans son journal X jours consécutifs
    | 'journal_min_words'        // Écrire une entrée avec au moins X mots
    | 'mood_and_journal_same_day'; // Enregistrer humeur ET journal le même jour, X fois

export type ChallengePeriod = 'day' | 'week' | 'month' | 'all_time';

export interface ChallengeCondition {
    type: ConditionType;
    target: number;
    period?: ChallengePeriod;
    filter?: {
        moodTypes?: string[];
    };
}

export interface ConditionProgress {
    current: number;
    target: number;
    completed: boolean;
    updatedAt: string;
}

/** Map de la progression par index de condition : "condition_0", "condition_1", etc. */
export type ChallengeProgress = Record<string, ConditionProgress>;

export type TriggerEvent = 'mood_logged' | 'journal_created';

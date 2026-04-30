import { db } from "./config/db.config";
import { challengesTable } from "./config/db/quest.table";
import { eq, sql } from "drizzle-orm";
import type { ChallengeCondition } from "./modules/quest/quest.types";

/**
 * 12 défis SYSTEM organisés en 4 niveaux psychologiques :
 * 1. Découverte  — premiers pas, aucune pression
 * 2. Régularité  — formation d'habitudes (règle des 21 jours)
 * 3. Profondeur  — introspection et conscience émotionnelle (CBT)
 * 4. Résilience  — engagement à long terme
 */
const SYSTEM_CHALLENGES: Array<{
    title: string;
    description: string;
    conditions: ChallengeCondition[];
    aggregator: 'ALL' | 'ANY';
}> = [
    // ─── Niveau 1 : Découverte ───────────────────────────────────────────────
    {
        title: "Premier pas",
        description: "Enregistre ton humeur pour la première fois. Prendre conscience de son état émotionnel est la première étape vers le bien-être.",
        conditions: [
            { type: 'mood_count', target: 1, period: 'all_time' },
        ],
        aggregator: 'ALL',
    },
    {
        title: "Première page",
        description: "Écris ta première entrée dans ton journal. Mettre des mots sur ses pensées libère l'esprit.",
        conditions: [
            { type: 'journal_count', target: 1, period: 'all_time' },
        ],
        aggregator: 'ALL',
    },

    // ─── Niveau 2 : Régularité ───────────────────────────────────────────────
    {
        title: "3 jours d'affilée",
        description: "Enregistre ton humeur 3 jours de suite. La régularité est la clé de l'auto-connaissance.",
        conditions: [
            { type: 'mood_streak', target: 3 },
        ],
        aggregator: 'ALL',
    },
    {
        title: "Semaine de pleine conscience",
        description: "Enregistre ton humeur 7 fois cette semaine. Observer ses émotions régulièrement renforce la résilience émotionnelle.",
        conditions: [
            { type: 'mood_count', target: 7, period: 'week' },
        ],
        aggregator: 'ALL',
    },
    {
        title: "Journaliste en herbe",
        description: "Écris 3 entrées dans ton journal cette semaine. L'écriture régulière clarifie les pensées et réduit l'anxiété.",
        conditions: [
            { type: 'journal_count', target: 3, period: 'week' },
        ],
        aggregator: 'ALL',
    },
    {
        title: "Journal quotidien",
        description: "Écris dans ton journal 3 jours consécutifs. Écrire chaque jour ancre la pratique dans ta routine.",
        conditions: [
            { type: 'journal_streak', target: 3 },
        ],
        aggregator: 'ALL',
    },

    // ─── Niveau 3 : Profondeur ───────────────────────────────────────────────
    {
        title: "Explorateur d'émotions",
        description: "Enregistre 5 types d'humeurs différents. Nommer ses émotions avec précision — labeling émotionnel — réduit leur intensité.",
        conditions: [
            { type: 'mood_variety', target: 5, period: 'all_time' },
        ],
        aggregator: 'ALL',
    },
    {
        title: "Réflexion profonde",
        description: "Écris une entrée de journal d'au moins 100 mots. La rédaction longue favorise l'insight et la résolution de problèmes.",
        conditions: [
            { type: 'journal_min_words', target: 100 },
        ],
        aggregator: 'ALL',
    },
    {
        title: "Corps et âme",
        description: "Enregistre ton humeur ET écris dans ton journal le même jour, 3 fois ce mois-ci. Combiner les deux pratiques amplifie leurs bénéfices.",
        conditions: [
            { type: 'mood_and_journal_same_day', target: 3, period: 'month' },
        ],
        aggregator: 'ALL',
    },

    // ─── Niveau 4 : Résilience ───────────────────────────────────────────────
    {
        title: "Semaine complète",
        description: "Enregistre ton humeur 7 jours consécutifs. Une semaine sans interruption marque l'ancrage d'une nouvelle habitude.",
        conditions: [
            { type: 'mood_streak', target: 7 },
        ],
        aggregator: 'ALL',
    },
    {
        title: "Mois du bien-être",
        description: "Enregistre ton humeur 20 fois ce mois-ci. La constance sur un mois entier transforme l'acte en réflexe.",
        conditions: [
            { type: 'mood_count', target: 20, period: 'month' },
        ],
        aggregator: 'ALL',
    },
    {
        title: "Auteur engagé",
        description: "Écris 10 entrées dans ton journal. Dix pages de ta vie, dix occasions de mieux te comprendre.",
        conditions: [
            { type: 'journal_count', target: 10, period: 'all_time' },
        ],
        aggregator: 'ALL',
    },
];

export async function seedChallenges(): Promise<void> {
    const [result] = await db
        .select({ count: sql<number>`count(*)` })
        .from(challengesTable)
        .where(eq(challengesTable.source, 'SYSTEM'));

    const existing = Number(result?.count ?? 0);
    if (existing >= SYSTEM_CHALLENGES.length) {
        console.log(`[seed] ${existing} défis SYSTEM déjà présents — skip`);
        return;
    }

    console.log(`[seed] Insertion de ${SYSTEM_CHALLENGES.length} défis SYSTEM...`);
    await db.insert(challengesTable).values(
        SYSTEM_CHALLENGES.map(c => ({
            title: c.title,
            description: c.description,
            source: 'SYSTEM' as const,
            conditions: c.conditions,
            aggregator: c.aggregator,
            constraints: null,
        }))
    );
    console.log(`[seed] Défis SYSTEM insérés.`);
}

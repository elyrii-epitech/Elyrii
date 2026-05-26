import UserRepository from "../../repository/user.repository";
import QuestRepository from "../../repository/quest.repository";

class CoachLogic {
    private readonly userRepository = new UserRepository();
    private readonly questRepository = new QuestRepository();

    async generateResponse(userId: string, prompt: string): Promise<{ response: string; context: Record<string, unknown> }> {
        const [stats, latestMood, activeChallenges] = await Promise.all([
            this.userRepository.getStats(userId, 30),
            this.userRepository.getLatestMood(userId),
            this.questRepository.getUserChallenges(userId, "ACTIVE"),
        ]);

        const focusArea = this.extractFocusArea(prompt, latestMood?.moodType);
        const challengeHint = activeChallenges[0]?.challenge?.title
            ? `Tu peux aussi avancer sur ton défi actif: "${activeChallenges[0].challenge.title}".`
            : "Si tu veux, démarre un petit défi pour garder l'élan.";

        const response = [
            "Merci pour ce partage.",
            latestMood?.moodType
                ? `Dernier ressenti enregistré: ${latestMood.moodType}.`
                : "Je n'ai pas encore de mood récent enregistré.",
            `Tu as actuellement une série de ${stats.streak} jour(s), ${stats.totalPoints} points cumulés et ${stats.activeChallengesCount} défi(s) actif(s).`,
            "Petit objectif concret pour aujourd'hui: prends 10 minutes pour une action simple et faisable, puis note ton ressenti.",
            `Focus suggéré selon ton message: ${focusArea}.`,
            challengeHint,
        ].join(" ");

        return {
            response,
            context: {
                streak: stats.streak,
                totalPoints: stats.totalPoints,
                activeChallengesCount: stats.activeChallengesCount,
                completedChallengesCount: stats.completedChallengesCount,
                latestMood: latestMood?.moodType ?? null,
                promptLength: prompt.length,
                focusArea,
            },
        };
    }

    private extractFocusArea(prompt: string, latestMood?: string): string {
        const normalized = prompt.toLowerCase();
        if (normalized.includes("stress") || normalized.includes("anx")) return "respiration guidée";
        if (normalized.includes("fatigu") || normalized.includes("épuis")) return "récupération et sommeil";
        if (normalized.includes("motivation") || normalized.includes("procrast")) return "micro-objectifs";
        if (normalized.includes("triste") || normalized.includes("seul")) return "connexion sociale douce";
        if (latestMood?.toLowerCase().includes("angry") || latestMood?.toLowerCase().includes("col")) return "régulation émotionnelle";
        if (latestMood?.toLowerCase().includes("sad") || latestMood?.toLowerCase().includes("trist")) return "auto-compassion";
        return "ancrage et routine";
    }
}

export default CoachLogic;

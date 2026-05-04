import UserRepository from "../../repository/user.repository";

class CoachLogic {
    private readonly userRepository = new UserRepository();

    async generateResponse(userId: string, prompt: string): Promise<{ response: string; context: Record<string, unknown> }> {
        const stats = await this.userRepository.getStats(userId);

        const response = [
            "Merci pour ce partage.",
            `Tu as actuellement une série de ${stats.streak} jour(s) et ${stats.totalPoints} points cumulés.`,
            "Petit objectif concret pour aujourd'hui : prends 10 minutes pour une action simple et faisable, puis note ton ressenti.",
            `Focus suggéré selon ton message: ${this.extractFocusArea(prompt)}.`,
        ].join(" ");

        return {
            response,
            context: {
                streak: stats.streak,
                totalPoints: stats.totalPoints,
                activeChallengesCount: stats.activeChallengesCount,
                promptLength: prompt.length,
            },
        };
    }

    private extractFocusArea(prompt: string): string {
        const normalized = prompt.toLowerCase();
        if (normalized.includes("stress") || normalized.includes("anx")) return "respiration guidée";
        if (normalized.includes("fatigu") || normalized.includes("épuis")) return "récupération et sommeil";
        if (normalized.includes("motivation") || normalized.includes("procrast")) return "micro-objectifs";
        if (normalized.includes("triste") || normalized.includes("seul")) return "connexion sociale douce";
        return "ancrage et routine";
    }
}

export default CoachLogic;

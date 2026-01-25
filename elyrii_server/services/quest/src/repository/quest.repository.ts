import { db } from "../config/db.config";
import { challengesTable, userChallengesTable, type Challenge, type NewChallenge, type UserChallenge, type NewUserChallenge } from "../config/db/quest.table";
import { eq, and, isNull } from "drizzle-orm";

class QuestRepository {
    
    // Challenge Templates
    async createChallengeTemplate(data: NewChallenge): Promise<Challenge> {
        const [challenge] = await db.insert(challengesTable).values(data).returning();
        if (!challenge) throw new Error("Failed to create challenge template");
        return challenge;
    }

    async getChallengeTemplateById(id: string): Promise<Challenge | null> {
        const [challenge] = await db.select().from(challengesTable).where(eq(challengesTable.id, id));
        return challenge || null;
    }

    // User Challenges
    async assignChallengeToUser(data: NewUserChallenge): Promise<UserChallenge> {
        const [userChallenge] = await db.insert(userChallengesTable).values(data).returning();
        if (!userChallenge) throw new Error("Failed to assign challenge to user");
        return userChallenge;
    }

    async getUserChallenges(userId: string, status?: string): Promise<(UserChallenge & { challenge: Challenge })[]> {
        // Simple join to get challenge details
        const query = db.select({
            userChallenge: userChallengesTable,
            challenge: challengesTable
        })
        .from(userChallengesTable)
        .innerJoin(challengesTable, eq(userChallengesTable.challengeId, challengesTable.id))
        .where(
            and(
                eq(userChallengesTable.userId, userId),
                status ? eq(userChallengesTable.status, status) : undefined
            )
        );

        const results = await query;
        return results.map(r => ({ ...r.userChallenge, challenge: r.challenge }));
    }

    async updateUserChallengeStatus(id: string, status: string, progress?: any): Promise<UserChallenge> {
        const updateData: Partial<UserChallenge> = { status };
        if (progress) updateData.progress = progress;
        if (status === 'COMPLETED') updateData.completedAt = new Date();

        const [updated] = await db.update(userChallengesTable)
            .set(updateData)
            .where(eq(userChallengesTable.id, id))
            .returning();
        
        if (!updated) throw new Error("Failed to update user challenge");
        return updated;
    }
}

export default QuestRepository;

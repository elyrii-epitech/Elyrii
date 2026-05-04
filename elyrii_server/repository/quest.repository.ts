import { db } from "../config/db.config";
import { challengesTable, userChallengesTable, type Challenge, type NewChallenge, type UserChallenge, type NewUserChallenge } from "../config/db/quest.table";
import { eq, and, notInArray, sql } from "drizzle-orm";

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

    async getUserChallengeByIdForUser(id: string, userId: string): Promise<UserChallenge | null> {
        const [userChallenge] = await db
            .select()
            .from(userChallengesTable)
            .where(and(
                eq(userChallengesTable.id, id),
                eq(userChallengesTable.userId, userId),
            ))
            .limit(1);
        return userChallenge || null;
    }

    async getUserChallengeAssignment(userId: string, challengeId: string): Promise<UserChallenge | null> {
        const [assignment] = await db
            .select()
            .from(userChallengesTable)
            .where(and(
                eq(userChallengesTable.userId, userId),
                eq(userChallengesTable.challengeId, challengeId),
            ))
            .limit(1);
        return assignment || null;
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

    async updateUserChallengeStatusForUser(id: string, userId: string, status: string, progress?: any): Promise<UserChallenge> {
        const updateData: Partial<UserChallenge> = { status };
        if (progress) updateData.progress = progress;
        if (status === 'COMPLETED') updateData.completedAt = new Date();

        const [updated] = await db
            .update(userChallengesTable)
            .set(updateData)
            .where(and(
                eq(userChallengesTable.id, id),
                eq(userChallengesTable.userId, userId),
            ))
            .returning();

        if (!updated) throw new Error("Failed to update user challenge");
        return updated;
    }

    /**
     * Retourne les défis SYSTEM que l'utilisateur n'a pas encore commencé ou rejeté.
     * Exclut les défis déjà en ACTIVE, COMPLETED, ou REJECTED pour cet utilisateur.
     */
    async getAvailableChallenges(userId: string): Promise<Challenge[]> {
        // Récupérer les challenge_id déjà assignés à l'utilisateur (hors PENDING — les PENDING sont des propositions IA)
        const existing = await db
            .select({ challengeId: userChallengesTable.challengeId })
            .from(userChallengesTable)
            .where(and(
                eq(userChallengesTable.userId, userId),
                // Exclure seulement ACTIVE et COMPLETED (l'utilisateur peut réessayer les REJECTED)
                sql`${userChallengesTable.status} IN ('ACTIVE', 'COMPLETED')`,
            ));

        const excludedIds = existing.map(e => e.challengeId);

        const query = db
            .select()
            .from(challengesTable)
            .where(
                excludedIds.length > 0
                    ? and(
                        eq(challengesTable.source, 'SYSTEM'),
                        notInArray(challengesTable.id, excludedIds),
                    )
                    : eq(challengesTable.source, 'SYSTEM'),
            );

        return query;
    }

    async getSystemChallengeCount(): Promise<number> {
        const [result] = await db
            .select({ count: sql<number>`count(*)` })
            .from(challengesTable)
            .where(eq(challengesTable.source, 'SYSTEM'));
        return Number(result?.count ?? 0);
    }
}

export default QuestRepository;

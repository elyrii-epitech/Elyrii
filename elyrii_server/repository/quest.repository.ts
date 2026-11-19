import { db } from "../config/db.config";
import { challengesTable, userChallengesTable, type Challenge, type NewChallenge, type UserChallenge, type NewUserChallenge } from "../config/db/quest.table";
import { eq, and, notInArray, sql, lt, or, desc } from "drizzle-orm";
import {userTable} from "../config/db/user.table";
import {pointsLedgerTable} from "../config/db/reward.table";
import {notificationsTable} from "../config/db/notification.table";
import {initialProgress, QuestRequestError, type proposalSchema} from "../modules/quest/quest.contracts";
import type {z} from "zod";
import type {ChallengeProgress} from "../modules/quest/quest.types";

class QuestRepository {
    async getUserChallengePage(userId: string, status: string | undefined, limit: number, cursor?: {date: Date; id: string}) {
        const date = sql`coalesce(date_trunc('milliseconds', ${userChallengesTable.createdAt}), timestamp 'epoch')`;
        const rows = await db.select({userChallenge: userChallengesTable, challenge: challengesTable})
            .from(userChallengesTable).innerJoin(challengesTable, eq(challengesTable.id, userChallengesTable.challengeId))
            .where(and(eq(userChallengesTable.userId, userId), status ? eq(userChallengesTable.status, status) : undefined,
                cursor ? or(lt(date, sql`${cursor.date.toISOString()}::timestamp`),
                    and(eq(date, sql`${cursor.date.toISOString()}::timestamp`), lt(userChallengesTable.id, cursor.id))) : undefined))
            .orderBy(desc(date), desc(userChallengesTable.id)).limit(limit + 1);
        const items = rows.slice(0, limit).map(r => ({...r.userChallenge, challenge: r.challenge}));
        const last = items.at(-1);
        return {items, nextCursor: rows.length > limit && last ? {createdAt: (last.createdAt ?? new Date(0)).toISOString(), id: last.id} : null};
    }

    async getAvailablePage(userId: string, limit: number, cursor?: {date: Date; id: string}) {
        const date = sql`coalesce(date_trunc('milliseconds', ${challengesTable.createdAt}), timestamp 'epoch')`;
        const rows = await db.select().from(challengesTable).where(and(eq(challengesTable.source, "SYSTEM"),
            sql`NOT EXISTS (SELECT 1 FROM user_challenges assigned WHERE assigned.user_id = ${userId}
                AND assigned.challenge_id = "challenges"."id" AND assigned.status IN ('ACTIVE','COMPLETED'))`,
            cursor ? or(lt(date, sql`${cursor.date.toISOString()}::timestamp`),
                and(eq(date, sql`${cursor.date.toISOString()}::timestamp`), lt(challengesTable.id, cursor.id))) : undefined))
            .orderBy(desc(date), desc(challengesTable.id)).limit(limit + 1);
        const items = rows.slice(0, limit), last = items.at(-1);
        return {items, nextCursor: rows.length > limit && last ? {createdAt: (last.createdAt ?? new Date(0)).toISOString(), id: last.id} : null};
    }

    async startSystemChallenge(userId: string, challengeId: string) {
        return db.transaction(async tx => {
            const [owner] = await tx.select({id: userTable.id}).from(userTable).where(eq(userTable.id, userId)).for("update");
            if (!owner) throw new QuestRequestError("Account not found", 404);
            const [challenge] = await tx.select().from(challengesTable).where(and(
                eq(challengesTable.id, challengeId), eq(challengesTable.source, "SYSTEM")));
            if (!challenge) throw new QuestRequestError("Challenge not found", 404);
            const progress = initialProgress(challenge.conditions);
            const [existing] = await tx.select().from(userChallengesTable).where(and(
                eq(userChallengesTable.userId, userId), eq(userChallengesTable.challengeId, challengeId)))
                .orderBy(sql`CASE WHEN ${userChallengesTable.status} = 'COMPLETED' THEN 0 ELSE 1 END`).limit(1);
            if (existing && (existing.status === "ACTIVE" || existing.status === "COMPLETED")) return {assignment: existing, created: false};
            if (existing) return {assignment: (await tx.update(userChallengesTable).set({status: "ACTIVE", progress, completedAt: null, rewardGrantedAt: null})
                .where(eq(userChallengesTable.id, existing.id)).returning())[0]!, created: false};
            return {assignment: (await tx.insert(userChallengesTable).values({userId, challengeId, status: "ACTIVE", progress}).returning())[0]!, created: true};
        });
    }

    async transitionProposal(userId: string, id: string, status: "ACTIVE" | "REJECTED") {
        return db.transaction(async tx => {
            await tx.select({id: userTable.id}).from(userTable).where(eq(userTable.id, userId)).for("update");
            const [row] = await tx.select({assignment: userChallengesTable, challenge: challengesTable}).from(userChallengesTable)
                .innerJoin(challengesTable, eq(challengesTable.id, userChallengesTable.challengeId))
                .where(and(eq(userChallengesTable.id, id), eq(userChallengesTable.userId, userId)));
            if (!row) throw new QuestRequestError("Challenge not found", 404);
            if (row.assignment.status === status || (status === "ACTIVE" && row.assignment.status === "COMPLETED")) return row.assignment;
            if (row.assignment.status !== "PENDING") throw new QuestRequestError("Challenge is no longer pending", 409);
            return (await tx.update(userChallengesTable).set({status,
                ...(status === "ACTIVE" ? {progress: initialProgress(row.challenge.conditions), completedAt: null} : {})})
                .where(eq(userChallengesTable.id, id)).returning())[0]!;
        });
    }

    async getJoinedAssignment(userId: string, id: string) {
        const [row] = await db.select({assignment: userChallengesTable, challenge: challengesTable}).from(userChallengesTable)
            .innerJoin(challengesTable, eq(challengesTable.id, userChallengesTable.challengeId))
            .where(and(eq(userChallengesTable.userId, userId), eq(userChallengesTable.id, id)));
        if (!row) throw new QuestRequestError("Challenge not found", 404);
        return {...row.assignment, challenge: row.challenge};
    }

    async createProposal(userId: string, input: z.infer<typeof proposalSchema>) {
        return db.transaction(async tx => {
            const [owner] = await tx.select({id: userTable.id}).from(userTable).where(eq(userTable.id, userId)).for("update");
            if (!owner) throw new QuestRequestError("Account not found", 404);
            const [template] = await tx.insert(challengesTable).values({...input, source: "AI", constraints: input.constraints ?? null}).returning();
            const [assignment] = await tx.insert(userChallengesTable).values({userId, challengeId: template!.id, status: "PENDING", progress: {}}).returning();
            return {template: template!, userChallenge: assignment!};
        });
    }

    /** Progress, terminal state, points and the completion notification commit together. */
    async applyProgress(assignment: UserChallenge, challenge: Challenge, progress: ChallengeProgress, complete: boolean) {
        return db.transaction(async tx => {
            const [owner] = await tx.select({id: userTable.id}).from(userTable).where(eq(userTable.id, assignment.userId)).for("update");
            if (!owner) return false;
            const [current] = await tx.select().from(userChallengesTable).where(and(
                eq(userChallengesTable.id, assignment.id), eq(userChallengesTable.userId, assignment.userId))).for("update");
            if (!current || current.status !== "ACTIVE" || JSON.stringify(current.progress ?? {}) !== JSON.stringify(assignment.progress ?? {})) return false;
            const now = new Date();
            await tx.update(userChallengesTable).set({progress, status: complete ? "COMPLETED" : "ACTIVE",
                ...(complete ? {completedAt: now, rewardGrantedAt: now} : {})})
                .where(eq(userChallengesTable.id, assignment.id));
            if (!complete) return false;
            const inserted = await tx.insert(pointsLedgerTable).values({userId: assignment.userId, userChallengeId: assignment.id,
                points: challenge.rewardPoints, reason: "challenge_completion",
                metadata: {challengeId: challenge.id, challengeTitle: challenge.title}})
                .onConflictDoNothing().returning({id: pointsLedgerTable.id});
            if (!inserted.length) return false;
            await tx.insert(notificationsTable).values({userId: assignment.userId, type: "challenge_completed", title: "Défi complété",
                body: `Bravo ! Tu as complété "${challenge.title}" et gagné ${challenge.rewardPoints} points.`,
                metadata: JSON.stringify({challengeId: challenge.id, userChallengeId: assignment.id, rewardPoints: challenge.rewardPoints})});
            return true;
        });
    }
    
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
        if (status === 'ACTIVE') {
            updateData.completedAt = null;
            updateData.rewardGrantedAt = null;
        }

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
        if (status === 'ACTIVE') {
            updateData.completedAt = null;
            updateData.rewardGrantedAt = null;
        }

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

    async markRewardGranted(userChallengeId: string): Promise<void> {
        await db
            .update(userChallengesTable)
            .set({ rewardGrantedAt: new Date() })
            .where(eq(userChallengesTable.id, userChallengeId));
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

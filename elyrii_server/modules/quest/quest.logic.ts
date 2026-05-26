import { db } from "../../config/db.config";
import { moodLogsTable } from "../../config/db/user.table";
import { journalEntriesTable } from "../../config/db/journal.table";
import {
    challengesTable,
    userChallengesTable,
} from "../../config/db/quest.table";
import { eq, and, isNull, desc, gte, sql } from "drizzle-orm";
import type {
    ChallengeCondition,
    ChallengeProgress,
    ConditionProgress,
    TriggerEvent,
} from "./quest.types";
import RewardRepository from "../../repository/reward.repository";
import QuestRepository from "../../repository/quest.repository";
import NotificationRepository from "../../repository/notification.repository";
import UserRepository from "../../repository/user.repository";
import { sendQuestEvent } from "./producer.service";

class QuestLogic {
    private readonly rewardRepository = new RewardRepository();
    private readonly questRepository = new QuestRepository();
    private readonly notificationRepository = new NotificationRepository();
    private readonly userRepository = new UserRepository();

    /**
     * Point d'entrée principal : appelé après chaque action utilisateur.
     * Évalue la progression de tous les défis ACTIVE et les complète si besoin.
     */
    async checkAndUpdateProgress(
        userId: string,
        event: TriggerEvent,
    ): Promise<void> {
        const activeChallenges = await db
            .select({
                userChallenge: userChallengesTable,
                challenge: challengesTable,
            })
            .from(userChallengesTable)
            .innerJoin(
                challengesTable,
                eq(userChallengesTable.challengeId, challengesTable.id),
            )
            .where(
                and(
                    eq(userChallengesTable.userId, userId),
                    eq(userChallengesTable.status, "ACTIVE"),
                ),
            );

        for (const { userChallenge, challenge } of activeChallenges) {
            const conditions = challenge.conditions as ChallengeCondition[];
            const currentProgress =
                (userChallenge.progress as ChallengeProgress) ?? {};
            const newProgress: ChallengeProgress = { ...currentProgress };
            let changed = false;

            for (let i = 0; i < conditions.length; i++) {
                const condition = conditions[i];
                if (!condition || !this.isRelevantToEvent(condition, event))
                    continue;

                const current = await this.evaluateCondition(userId, condition);
                const completed = current >= condition.target;
                const key = `condition_${i}`;
                const prev = newProgress[key];

                if (
                    !prev ||
                    prev.current !== current ||
                    prev.completed !== completed
                ) {
                    newProgress[key] = {
                        current,
                        target: condition.target,
                        completed,
                        updatedAt: new Date().toISOString(),
                    };
                    changed = true;
                }
            }

            if (!changed) continue;

            // Vérifier si le défi est complété
            const results = conditions.map(
                (_, i) => newProgress[`condition_${i}`]?.completed ?? false,
            );
            const isComplete =
                challenge.aggregator === "ALL"
                    ? results.every(Boolean)
                    : results.some(Boolean);

            const newStatus = isComplete ? "COMPLETED" : "ACTIVE";
            const updateData: Record<string, unknown> = {
                progress: newProgress,
                status: newStatus,
            };
            if (isComplete) {
                updateData.completedAt = new Date();
                // Update user streak when a challenge is completed
                this.userRepository.updateUserStreak(userId).catch((err) => {
                    console.error(
                        `Failed to update streak for user ${userId}:`,
                        err,
                    );
                });
            }

            const [updatedUserChallenge] = await db
                .update(userChallengesTable)
                .set(updateData)
                .where(eq(userChallengesTable.id, userChallenge.id))
                .returning();

            if (
                isComplete &&
                updatedUserChallenge &&
                !updatedUserChallenge.rewardGrantedAt
            ) {
                const granted =
                    await this.rewardRepository.grantChallengeCompletionPoints(
                        userId,
                        userChallenge.id,
                        challenge.rewardPoints ?? 50,
                        {
                            challengeId: challenge.id,
                            challengeTitle: challenge.title,
                        },
                    );

                if (granted) {
                    await this.questRepository.markRewardGranted(
                        userChallenge.id,
                    );
                    await this.notificationRepository.createNotification({
                        userId,
                        type: "challenge_completed",
                        title: "Défi complété",
                        body: `Bravo ! Tu as complété "${challenge.title}" et gagné ${challenge.rewardPoints ?? 50} points.`,
                        metadata: JSON.stringify({
                            challengeId: challenge.id,
                            userChallengeId: userChallenge.id,
                            rewardPoints: challenge.rewardPoints ?? 50,
                        }),
                    });
                    sendQuestEvent("challenge_completed", {
                        userId,
                        challengeId: challenge.id,
                        userChallengeId: userChallenge.id,
                        rewardPoints: challenge.rewardPoints ?? 50,
                    }).catch(() => {});
                }
            }
        }
    }

    // ─── Routing ─────────────────────────────────────────────────────────────

    private isRelevantToEvent(
        condition: ChallengeCondition,
        event: TriggerEvent,
    ): boolean {
        const moodTypes = ["mood_count", "mood_streak", "mood_variety"];
        const journalTypes = [
            "journal_count",
            "journal_streak",
            "journal_min_words",
        ];
        const bothTypes = ["mood_and_journal_same_day"];

        if (event === "mood_logged")
            return (
                moodTypes.includes(condition.type) ||
                bothTypes.includes(condition.type)
            );
        if (event === "journal_created")
            return (
                journalTypes.includes(condition.type) ||
                bothTypes.includes(condition.type)
            );
        return false;
    }

    private async evaluateCondition(
        userId: string,
        condition: ChallengeCondition,
    ): Promise<number> {
        switch (condition.type) {
            case "mood_count":
                return this.countMoods(userId, condition);
            case "mood_streak":
                return this.calcMoodStreak(userId);
            case "mood_variety":
                return this.countMoodVariety(userId, condition);
            case "journal_count":
                return this.countJournalEntries(userId, condition);
            case "journal_streak":
                return this.calcJournalStreak(userId);
            case "journal_min_words":
                return this.getLatestEntryWordCount(userId);
            case "mood_and_journal_same_day":
                return this.countMoodAndJournalSameDay(userId, condition);
            default:
                return 0;
        }
    }

    // ─── Helpers de période ──────────────────────────────────────────────────

    private getPeriodStart(period?: string): Date | undefined {
        if (!period || period === "all_time") return undefined;
        const now = new Date();
        if (period === "day") {
            const d = new Date(now);
            d.setHours(0, 0, 0, 0);
            return d;
        }
        if (period === "week") {
            const d = new Date(now);
            d.setDate(d.getDate() - 7);
            return d;
        }
        if (period === "month") {
            const d = new Date(now);
            d.setDate(d.getDate() - 30);
            return d;
        }
        return undefined;
    }

    // ─── Évaluateurs de conditions ───────────────────────────────────────────

    private async countMoods(
        userId: string,
        condition: ChallengeCondition,
    ): Promise<number> {
        const periodStart = this.getPeriodStart(condition.period);
        const filters: ReturnType<typeof eq>[] = [
            eq(moodLogsTable.userId, userId),
        ];
        if (periodStart)
            filters.push(gte(moodLogsTable.createdAt, periodStart) as any);

        if (condition.filter?.moodTypes?.length) {
            const logs = await db
                .select({ moodType: moodLogsTable.moodType })
                .from(moodLogsTable)
                .where(and(...filters));
            return logs.filter((l) =>
                condition.filter!.moodTypes!.includes(l.moodType),
            ).length;
        }

        const [result] = await db
            .select({ count: sql<number>`count(*)` })
            .from(moodLogsTable)
            .where(and(...filters));
        return Number(result?.count ?? 0);
    }

    private async calcMoodStreak(userId: string): Promise<number> {
        const logs = await db
            .select({ createdAt: moodLogsTable.createdAt })
            .from(moodLogsTable)
            .where(eq(moodLogsTable.userId, userId))
            .orderBy(desc(moodLogsTable.createdAt));

        return this.consecutiveDayStreak(logs.map((l) => l.createdAt));
    }

    private async countMoodVariety(
        userId: string,
        condition: ChallengeCondition,
    ): Promise<number> {
        const periodStart = this.getPeriodStart(condition.period);
        const filters: ReturnType<typeof eq>[] = [
            eq(moodLogsTable.userId, userId),
        ];
        if (periodStart)
            filters.push(gte(moodLogsTable.createdAt, periodStart) as any);

        const logs = await db
            .select({ moodType: moodLogsTable.moodType })
            .from(moodLogsTable)
            .where(and(...filters));

        return new Set(logs.map((l) => l.moodType)).size;
    }

    private async countJournalEntries(
        userId: string,
        condition: ChallengeCondition,
    ): Promise<number> {
        const periodStart = this.getPeriodStart(condition.period);
        const filters: ReturnType<typeof eq>[] = [
            eq(journalEntriesTable.userId, userId),
            isNull(journalEntriesTable.deletedAt) as any,
        ];
        if (periodStart)
            filters.push(
                gte(journalEntriesTable.createdAt, periodStart) as any,
            );

        const [result] = await db
            .select({ count: sql<number>`count(*)` })
            .from(journalEntriesTable)
            .where(and(...filters));
        return Number(result?.count ?? 0);
    }

    private async calcJournalStreak(userId: string): Promise<number> {
        const entries = await db
            .select({ createdAt: journalEntriesTable.createdAt })
            .from(journalEntriesTable)
            .where(
                and(
                    eq(journalEntriesTable.userId, userId),
                    isNull(journalEntriesTable.deletedAt),
                ),
            )
            .orderBy(desc(journalEntriesTable.createdAt));

        return this.consecutiveDayStreak(entries.map((e) => e.createdAt));
    }

    private async getLatestEntryWordCount(userId: string): Promise<number> {
        const [latest] = await db
            .select({ content: journalEntriesTable.content })
            .from(journalEntriesTable)
            .where(
                and(
                    eq(journalEntriesTable.userId, userId),
                    isNull(journalEntriesTable.deletedAt),
                ),
            )
            .orderBy(desc(journalEntriesTable.createdAt))
            .limit(1);

        if (!latest?.content) return 0;
        return latest.content.trim().split(/\s+/).filter(Boolean).length;
    }

    private async countMoodAndJournalSameDay(
        userId: string,
        condition: ChallengeCondition,
    ): Promise<number> {
        const periodStart = this.getPeriodStart(condition.period);

        const moodFilters: ReturnType<typeof eq>[] = [
            eq(moodLogsTable.userId, userId),
        ];
        if (periodStart)
            moodFilters.push(gte(moodLogsTable.createdAt, periodStart) as any);

        const journalFilters: ReturnType<typeof eq>[] = [
            eq(journalEntriesTable.userId, userId),
            isNull(journalEntriesTable.deletedAt) as any,
        ];
        if (periodStart)
            journalFilters.push(
                gte(journalEntriesTable.createdAt, periodStart) as any,
            );

        const [moods, journals] = await Promise.all([
            db
                .select({ createdAt: moodLogsTable.createdAt })
                .from(moodLogsTable)
                .where(and(...moodFilters)),
            db
                .select({ createdAt: journalEntriesTable.createdAt })
                .from(journalEntriesTable)
                .where(and(...journalFilters)),
        ]);

        const moodDays = new Set(
            moods.map((m) => new Date(m.createdAt!).toDateString()),
        );
        const journalDays = new Set(
            journals.map((j) => new Date(j.createdAt!).toDateString()),
        );

        let count = 0;
        for (const day of moodDays) {
            if (journalDays.has(day)) count++;
        }
        return count;
    }

    // ─── Streak helper ───────────────────────────────────────────────────────

    private consecutiveDayStreak(dates: (Date | string | null)[]): number {
        if (dates.length === 0) return 0;

        const today = new Date();
        today.setHours(0, 0, 0, 0);

        const firstDate = new Date(dates[0]!);
        firstDate.setHours(0, 0, 0, 0);

        const diffFromToday = Math.floor(
            (today.getTime() - firstDate.getTime()) / (1000 * 60 * 60 * 24),
        );
        if (diffFromToday > 1) return 0; // Streak cassé

        let streak = 1;
        let lastDate = firstDate;

        for (let i = 1; i < dates.length; i++) {
            const current = new Date(dates[i]!);
            current.setHours(0, 0, 0, 0);

            const dayDiff = Math.floor(
                (lastDate.getTime() - current.getTime()) /
                    (1000 * 60 * 60 * 24),
            );
            if (dayDiff === 1) {
                streak++;
                lastDate = current;
            } else if (dayDiff === 0) {
                continue; // Même jour, on ignore les doublons
            } else {
                break;
            }
        }

        return streak;
    }
}

export default QuestLogic;

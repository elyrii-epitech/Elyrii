import { desc, eq, and, isNull, sql } from "drizzle-orm";
import { db } from "../config/db.config";
import { moodLogsTable, userTable } from "../config/db/user.table";
import { journalEntriesTable } from "../config/db/journal.table";
import { userChallengesTable } from "../config/db/quest.table";
import type { UpdateProfileType } from "../utils/zod.valid";
import {
    userSettingsTable,
    type UserSettings,
} from "../config/db/settings.table";
import { pointsLedgerTable } from "../config/db/reward.table";
import { meditationSessionsTable } from "../config/db/meditation.table";
import { coachSessionsTable } from "../config/db/coach.table";

class UserRepository {
    async getUserById(userId: string) {
        const user = (
            await db
                .select({
                    id: userTable.id,
                    firstName: userTable.firstName,
                    lastName: userTable.lastName,
                    email: userTable.email,
                    emailVerified: userTable.emailVerified,
                    age: userTable.age,
                    pfp: userTable.pfp,
                    createdAt: userTable.createdAt,
                    updatedAt: userTable.updatedAt,
                })
                .from(userTable)
                .where(eq(userTable.id, userId))
        )[0];

        if (!user) {
            return null;
        }

        const settings = await this.getOrCreateUserSettings(userId);
        return {
            ...user,
            settings,
        };
    }

    async updateUser(userId: string, data: UpdateProfileType) {
        return (
            await db
                .update(userTable)
                .set(data)
                .where(eq(userTable.id, userId))
                .returning({
                    id: userTable.id,
                    firstName: userTable.firstName,
                    lastName: userTable.lastName,
                    email: userTable.email,
                    emailVerified: userTable.emailVerified,
                    age: userTable.age,
                    pfp: userTable.pfp,
                    createdAt: userTable.createdAt,
                    updatedAt: userTable.updatedAt,
                })
        )[0];
    }

    async updateUserStreak(userId: string) {
        const user = (
            await db
                .select({
                    currentStreak: userTable.currentStreak,
                    highestStreak: userTable.highestStreak,
                    lastActivityDate: userTable.lastActivityDate,
                })
                .from(userTable)
                .where(eq(userTable.id, userId))
        )[0];

        if (!user) return;

        const now = new Date();
        const today = new Date(
            now.getFullYear(),
            now.getMonth(),
            now.getDate(),
        );

        let lastActivity = user.lastActivityDate
            ? new Date(user.lastActivityDate)
            : null;
        if (lastActivity) {
            lastActivity = new Date(
                lastActivity.getFullYear(),
                lastActivity.getMonth(),
                lastActivity.getDate(),
            );
        }

        let newStreak = user.currentStreak;
        let newHighest = user.highestStreak;

        if (!lastActivity) {
            // Premier streak
            newStreak = 1;
        } else {
            const diffTime = today.getTime() - lastActivity.getTime();
            const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24));

            if (diffDays === 1) {
                // Consécutif
                newStreak += 1;
            } else if (diffDays > 1) {
                // Cassé
                newStreak = 1;
            } else if (diffDays === 0) {
                // Déjà fait aujourd'hui
                return;
            }
        }

        if (newStreak > newHighest) {
            newHighest = newStreak;
        }

        await db
            .update(userTable)
            .set({
                currentStreak: newStreak,
                highestStreak: newHighest,
                lastActivityDate: now,
            })
            .where(eq(userTable.id, userId));
    }

    async logMood(userId: string, moodType: string) {
        const [log] = await db
            .insert(moodLogsTable)
            .values({ userId, moodType })
            .returning();

        await this.updateUserStreak(userId);
        return log;
    }

    async touchActivity(userId: string) {
        await this.updateUserStreak(userId);
    }

    async getLatestMood(userId: string) {
        return (
            await db
                .select()
                .from(moodLogsTable)
                .where(eq(moodLogsTable.userId, userId))
                .orderBy(desc(moodLogsTable.createdAt))
                .limit(1)
        )[0];
    }

    async getStats(userId: string, days = 7) {
        const safeDays =
            Number.isFinite(days) && days > 0 ? Math.min(days, 365) : 7;

        const [
            moodLogs,
            journalEntries,
            userChallenges,
            meditations,
            coachSessions,
            userRecord,
        ] = await Promise.all([
            db
                .select({ d: moodLogsTable.createdAt })
                .from(moodLogsTable)
                .where(eq(moodLogsTable.userId, userId)),
            db
                .select({ d: journalEntriesTable.createdAt })
                .from(journalEntriesTable)
                .where(
                    and(
                        eq(journalEntriesTable.userId, userId),
                        isNull(journalEntriesTable.deletedAt),
                    ),
                ),
            db
                .select({
                    c: userChallengesTable.createdAt,
                    u: userChallengesTable.updatedAt,
                    comp: userChallengesTable.completedAt,
                    s: userChallengesTable.status,
                })
                .from(userChallengesTable)
                .where(eq(userChallengesTable.userId, userId)),
            db
                .select({ d: meditationSessionsTable.createdAt })
                .from(meditationSessionsTable)
                .where(
                    and(
                        eq(meditationSessionsTable.userId, userId),
                        eq(meditationSessionsTable.status, "COMPLETED"),
                    ),
                ),
            db
                .select({ d: coachSessionsTable.createdAt })
                .from(coachSessionsTable)
                .where(eq(coachSessionsTable.userId, userId)),
            db
                .select({ currentStreak: userTable.currentStreak })
                .from(userTable)
                .where(eq(userTable.id, userId))
                .limit(1),
        ]);

        const streak = userRecord?.[0]?.currentStreak ?? 0;

        // Fetch other counts
        const [journalCount] = await db
            .select({ count: sql<number>`count(*)` })
            .from(journalEntriesTable)
            .where(
                and(
                    eq(journalEntriesTable.userId, userId),
                    isNull(journalEntriesTable.deletedAt),
                ),
            );

        const [challengeCount] = await db
            .select({ count: sql<number>`count(*)` })
            .from(userChallengesTable)
            .where(
                and(
                    eq(userChallengesTable.userId, userId),
                    eq(userChallengesTable.status, "ACTIVE"),
                ),
            );

        const [completedChallengeCount] = await db
            .select({ count: sql<number>`count(*)` })
            .from(userChallengesTable)
            .where(
                and(
                    eq(userChallengesTable.userId, userId),
                    eq(userChallengesTable.status, "COMPLETED"),
                ),
            );

        const [pointsResult] = await db
            .select({
                points: sql<number>`coalesce(sum(${pointsLedgerTable.points}), 0)`,
            })
            .from(pointsLedgerTable)
            .where(eq(pointsLedgerTable.userId, userId));

        const [meditationCount] = await db
            .select({ count: sql<number>`count(*)` })
            .from(meditationSessionsTable)
            .where(
                and(
                    eq(meditationSessionsTable.userId, userId),
                    eq(meditationSessionsTable.status, "COMPLETED"),
                ),
            );

        const [coachCount] = await db
            .select({ count: sql<number>`count(*)` })
            .from(coachSessionsTable)
            .where(eq(coachSessionsTable.userId, userId));

        const moodTrend = await db
            .select({
                day: sql<string>`to_char(date_trunc('day', ${moodLogsTable.createdAt}), 'YYYY-MM-DD')`,
                count: sql<number>`count(*)`,
            })
            .from(moodLogsTable)
            .where(
                and(
                    eq(moodLogsTable.userId, userId),
                    sql`${moodLogsTable.createdAt} >= now() - (${safeDays} * interval '1 day')`,
                ),
            )
            .groupBy(sql`date_trunc('day', ${moodLogsTable.createdAt})`)
            .orderBy(sql`date_trunc('day', ${moodLogsTable.createdAt}) asc`);

        const moodDistribution = await db
            .select({
                moodType: moodLogsTable.moodType,
                count: sql<number>`count(*)`,
            })
            .from(moodLogsTable)
            .where(
                and(
                    eq(moodLogsTable.userId, userId),
                    sql`${moodLogsTable.createdAt} >= now() - (${safeDays} * interval '1 day')`,
                ),
            )
            .groupBy(moodLogsTable.moodType)
            .orderBy(sql`count(*) desc`);

        const journalTrend = await db
            .select({
                day: sql<string>`to_char(date_trunc('day', ${journalEntriesTable.createdAt}), 'YYYY-MM-DD')`,
                count: sql<number>`count(*)`,
            })
            .from(journalEntriesTable)
            .where(
                and(
                    eq(journalEntriesTable.userId, userId),
                    isNull(journalEntriesTable.deletedAt),
                    sql`${journalEntriesTable.createdAt} >= now() - (${safeDays} * interval '1 day')`,
                ),
            )
            .groupBy(sql`date_trunc('day', ${journalEntriesTable.createdAt})`)
            .orderBy(
                sql`date_trunc('day', ${journalEntriesTable.createdAt}) asc`,
            );

        const timelineMap = new Map<
            string,
            { moodLogs: number; journalEntries: number }
        >();
        for (const row of moodTrend) {
            timelineMap.set(row.day, {
                moodLogs: Number(row.count ?? 0),
                journalEntries: 0,
            });
        }
        for (const row of journalTrend) {
            const existing = timelineMap.get(row.day);
            timelineMap.set(row.day, {
                moodLogs: existing?.moodLogs ?? 0,
                journalEntries: Number(row.count ?? 0),
            });
        }

        const activityTimeline = Array.from(timelineMap.entries())
            .sort((a, b) => a[0].localeCompare(b[0]))
            .map(([day, counts]) => ({
                day,
                moodLogs: counts.moodLogs,
                journalEntries: counts.journalEntries,
            }));

        const latestMood = await this.getLatestMood(userId);
        const settings = await this.getOrCreateUserSettings(userId);

        return {
            rangeDays: safeDays,
            streak,
            moodLogsCount: moodLogs.length,
            journalEntriesCount: Number(journalCount?.count ?? 0),
            activeChallengesCount: Number(challengeCount?.count ?? 0),
            completedChallengesCount: Number(
                completedChallengeCount?.count ?? 0,
            ),
            totalPoints: Number(pointsResult?.points ?? 0),
            meditationSessionsCount: Number(meditationCount?.count ?? 0),
            coachSessionsCount: Number(coachCount?.count ?? 0),
            latestMood: latestMood?.moodType ?? null,
            moodTrend7Days: moodTrend,
            moodDistribution,
            activityTimeline,
            settings,
        };
    }

    async getOrCreateUserSettings(userId: string): Promise<UserSettings> {
        const [existing] = await db
            .select()
            .from(userSettingsTable)
            .where(eq(userSettingsTable.userId, userId))
            .limit(1);
        if (existing) {
            return existing;
        }

        const [created] = await db
            .insert(userSettingsTable)
            .values({ userId })
            .returning();
        if (!created) {
            throw new Error("Failed to create user settings");
        }
        return created;
    }

    async updateUserSettings(
        userId: string,
        data: Partial<UserSettings>,
    ): Promise<UserSettings> {
        await this.getOrCreateUserSettings(userId);

        const [updated] = await db
            .update(userSettingsTable)
            .set(data)
            .where(eq(userSettingsTable.userId, userId))
            .returning();

        if (!updated) {
            throw new Error("Failed to update user settings");
        }
        return updated;
    }

    async deleteUserAccount(userId: string): Promise<boolean> {
        const [deleted] = await db
            .delete(userTable)
            .where(eq(userTable.id, userId))
            .returning({ id: userTable.id });

        return Boolean(deleted);
    }
}

export default UserRepository;

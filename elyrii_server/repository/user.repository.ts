import { desc, eq, and, isNull, sql } from "drizzle-orm";
import { db } from "../config/db.config";
import { moodLogsTable, userTable } from "../config/db/user.table";
import { journalEntriesTable } from "../config/db/journal.table";
import { userChallengesTable } from "../config/db/quest.table";
import type { UpdateProfileType } from "../utils/zod.valid";
import { userSettingsTable, type UserSettings } from "../config/db/settings.table";
import { pointsLedgerTable } from "../config/db/reward.table";
import { meditationSessionsTable } from "../config/db/meditation.table";
import { coachSessionsTable } from "../config/db/coach.table";

class UserRepository {
    async getUserById(userId: string) {
        const user = (await db
            .select({
                id: userTable.id,
                firstName: userTable.firstName,
                lastName: userTable.lastName,
                email: userTable.email,
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
        return (await db
            .update(userTable)
            .set(data)
            .where(eq(userTable.id, userId))
            .returning({
                id: userTable.id,
                firstName: userTable.firstName,
                lastName: userTable.lastName,
                email: userTable.email,
                age: userTable.age,
                pfp: userTable.pfp,
                createdAt: userTable.createdAt,
                updatedAt: userTable.updatedAt,
            })
        )[0];
    }

    async logMood(userId: string, moodType: string) {
        return (await db
            .insert(moodLogsTable)
            .values({ userId, moodType })
            .returning()
        )[0];
    }

    async getLatestMood(userId: string) {
        return (await db
            .select()
            .from(moodLogsTable)
            .where(eq(moodLogsTable.userId, userId))
            .orderBy(desc(moodLogsTable.createdAt))
            .limit(1)
        )[0];
    }

    async getStats(userId: string) {
        // Calculate streak from mood logs
        const logs = await db
            .select({ createdAt: moodLogsTable.createdAt })
            .from(moodLogsTable)
            .where(eq(moodLogsTable.userId, userId))
            .orderBy(desc(moodLogsTable.createdAt));

        let streak = 0;
        if (logs.length > 0 && logs[0]?.createdAt) {
            const today = new Date();
            today.setHours(0, 0, 0, 0);
            
            let lastDate = new Date(logs[0].createdAt);
            lastDate.setHours(0, 0, 0, 0);

            // Check if last log is today or yesterday to continue streak
            const diffDays = Math.floor((today.getTime() - lastDate.getTime()) / (1000 * 60 * 60 * 24));
            
            if (diffDays <= 1) {
                streak = 1;

                for (let i = 1; i < logs.length; i++) {
                    const createdAt = logs[i]?.createdAt;
                    if (!createdAt) continue;
                    const currentDate = new Date(createdAt);
                    currentDate.setHours(0, 0, 0, 0);
                    
                    const dayDiff = Math.floor((lastDate.getTime() - currentDate.getTime()) / (1000 * 60 * 60 * 24));
                    
                    if (dayDiff === 1) {
                        streak++;
                        lastDate = currentDate;
                    } else if (dayDiff > 1) {
                        break;
                    }
                }
            }
        }

        // Fetch other counts
        const [journalCount] = await db
            .select({ count: sql<number>`count(*)` })
            .from(journalEntriesTable)
            .where(and(eq(journalEntriesTable.userId, userId), isNull(journalEntriesTable.deletedAt)));

        const [challengeCount] = await db
            .select({ count: sql<number>`count(*)` })
            .from(userChallengesTable)
            .where(and(eq(userChallengesTable.userId, userId), eq(userChallengesTable.status, 'ACTIVE')));

        const [completedChallengeCount] = await db
            .select({ count: sql<number>`count(*)` })
            .from(userChallengesTable)
            .where(and(eq(userChallengesTable.userId, userId), eq(userChallengesTable.status, 'COMPLETED')));

        const [pointsResult] = await db
            .select({ points: sql<number>`coalesce(sum(${pointsLedgerTable.points}), 0)` })
            .from(pointsLedgerTable)
            .where(eq(pointsLedgerTable.userId, userId));

        const [meditationCount] = await db
            .select({ count: sql<number>`count(*)` })
            .from(meditationSessionsTable)
            .where(and(
                eq(meditationSessionsTable.userId, userId),
                eq(meditationSessionsTable.status, "COMPLETED"),
            ));

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
            .where(and(
                eq(moodLogsTable.userId, userId),
                sql`${moodLogsTable.createdAt} >= now() - interval '7 days'`,
            ))
            .groupBy(sql`date_trunc('day', ${moodLogsTable.createdAt})`)
            .orderBy(sql`date_trunc('day', ${moodLogsTable.createdAt}) asc`);

        const settings = await this.getOrCreateUserSettings(userId);

        return {
            streak,
            moodLogsCount: logs.length,
            journalEntriesCount: Number(journalCount?.count ?? 0),
            activeChallengesCount: Number(challengeCount?.count ?? 0),
            completedChallengesCount: Number(completedChallengeCount?.count ?? 0),
            totalPoints: Number(pointsResult?.points ?? 0),
            meditationSessionsCount: Number(meditationCount?.count ?? 0),
            coachSessionsCount: Number(coachCount?.count ?? 0),
            moodTrend7Days: moodTrend,
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

    async updateUserSettings(userId: string, data: Partial<UserSettings>): Promise<UserSettings> {
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
}

export default UserRepository;

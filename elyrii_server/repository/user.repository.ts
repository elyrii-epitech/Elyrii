import { desc, eq, and, isNull, sql } from "drizzle-orm";
import { db } from "../config/db.config";
import { moodLogsTable, userTable } from "../config/db/user.table";
import { journalEntriesTable } from "../config/db/journal.table";
import { userChallengesTable } from "../config/db/quest.table";
import type { UpdateProfileType } from "../utils/zod.valid";

class UserRepository {
    async getUserById(userId: string) {
        return (await db
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
    }

    async updateUser(userId: string, data: UpdateProfileType) {
        return (await db
            .update(userTable)
            .set(data)
            .where(eq(userTable.id, userId))
            .returning()
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
        if (logs.length > 0) {
            const today = new Date();
            today.setHours(0, 0, 0, 0);
            
            let lastDate = new Date(logs[0].createdAt);
            lastDate.setHours(0, 0, 0, 0);

            // Check if last log is today or yesterday to continue streak
            const diffDays = Math.floor((today.getTime() - lastDate.getTime()) / (1000 * 60 * 60 * 24));
            
            if (diffDays <= 1) {
                streak = 1;

                for (let i = 1; i < logs.length; i++) {
                    const currentDate = new Date(logs[i].createdAt);
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

        return {
            streak,
            moodLogsCount: logs.length,
            journalEntriesCount: Number(journalCount.count),
            activeChallengesCount: Number(challengeCount.count)
        };
    }
}

export default UserRepository;

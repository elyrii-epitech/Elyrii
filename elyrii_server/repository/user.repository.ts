import { desc, eq } from "drizzle-orm";
import { db } from "../config/db.config";
import { moodLogsTable, userTable } from "../config/db/user.table";
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
}

export default UserRepository;

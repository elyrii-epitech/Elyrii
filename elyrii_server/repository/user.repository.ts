import { eq } from "drizzle-orm";
import { db } from "../config/db.config";
import { userTable } from "../config/db/user.table";
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
}

export default UserRepository;

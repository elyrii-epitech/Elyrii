import { eq } from "drizzle-orm";
import { db } from "../config/db.config";
import { userTable } from "../config/db/user.table";

class AuthRepository {
    async getUserById(userId: string) {
        return (await db.select({
            id: userTable.id,
            password: userTable.password
        }).from(userTable).where(eq(userTable.id, userId)))[0];
    }

    async getUserByEmail(email: string) {
        return (await db.select({
            id: userTable.id, password: userTable.password
        }).from(userTable).where(eq(userTable.email, email)))[0];
    }
}

export default AuthRepository;

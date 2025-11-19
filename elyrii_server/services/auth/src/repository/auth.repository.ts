import { eq } from "drizzle-orm";
import { db } from "../config/db.config";
import { userTable } from "../config/db/user.table";
 
type AuthUserCredentials = {
    readonly id: string;
    readonly password: string;
};

/**
 * Repository responsible for retrieving user authentication data.
 */
class AuthRepository {
    /**
     * Retrieves user credentials by unique user identifier.
     * @param userId - Unique user identifier.
     * @returns Promise resolving to user credentials or undefined when no user is found.
     */
    async getUserById(userId: string): Promise<AuthUserCredentials | undefined> {
        return (await db.select({
            id: userTable.id,
            password: userTable.password
        }).from(userTable).where(eq(userTable.id, userId)))[0];
    }

    /**
     * Retrieves user credentials by email address.
     * @param email - User email address.
     * @returns Promise resolving to user credentials or undefined when no user is found.
     */
    async getUserByEmail(email: string): Promise<AuthUserCredentials | undefined> {
        return (await db.select({
            id: userTable.id, password: userTable.password
        }).from(userTable).where(eq(userTable.email, email)))[0];
    }
}

export default AuthRepository;

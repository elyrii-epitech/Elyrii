import { eq } from "drizzle-orm";
import { db } from "../config/db.config";
import { userTable, type NewUser, type User } from "../config/db/user.table";

type AuthUserReturn = {
    readonly id: string;
    readonly email: string;
}

class AuthRepository {
    public async findUserByEmail(email: string): Promise<User | undefined> {
        const result = await db.select().from(userTable).where(eq(userTable.email, email)).limit(1);
        return result[0];
    }
    
    public async getUserById(id: string): Promise<User | undefined> {
        return await db.query.userTable.findFirst({
            where: eq(userTable.id, id),
        });
    }
    
    public async createUser(user: NewUser): Promise<User | undefined> {
        let hashedPass: string;
        
        try {
            hashedPass = await Bun.password.hash(user.password);
            if (!hashedPass) throw new Error('Failed to hash password');
            
            const newUser = await db.insert(userTable).values({
                ...user,
                password: hashedPass
            }).returning();
            
            return newUser[0];
        } catch (error) {
            throw new Error(error instanceof Error ? error.message : String(error));
        }
    }
}

export default AuthRepository;

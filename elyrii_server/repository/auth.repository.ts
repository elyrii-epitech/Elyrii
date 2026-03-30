import { eq } from "drizzle-orm";
import { db } from "../config/db.config";
import { userTable, type NewUser } from "../config/db/user.table";

type AuthUserReturn = {
    readonly id: string;
    readonly email: string;
}

class AuthRepository {
    public async findUserByEmail(email: string) {
        return await db.query.userTable.findFirst({
            where: eq(userTable.email, email),
            with: {
                email: true,
            },
        })
    }
    
    public async getUserById(id: string): Promise<AuthUserReturn | undefined> {
        return await db.query.userTable.findFirst({
            where: eq(userTable.id, id),
            with: {
                email: true,
                id: true
            },
        });
    }
    
    public async createrUser(user: NewUser): Promise<AuthUserReturn | undefined> {
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
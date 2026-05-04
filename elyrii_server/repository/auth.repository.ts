import { and, eq } from "drizzle-orm";
import { db } from "../config/db.config";
import { userTable, type NewUser, type User } from "../config/db/user.table";
import { oauthAccountsTable, type OAuthAccount } from "../config/db/oauth.table";

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

    public async findOAuthAccount(provider: string, providerUserId: string): Promise<OAuthAccount | undefined> {
        const result = await db
            .select()
            .from(oauthAccountsTable)
            .where(and(
                eq(oauthAccountsTable.provider, provider),
                eq(oauthAccountsTable.providerUserId, providerUserId),
            ))
            .limit(1);
        return result[0];
    }

    public async linkOAuthAccount(
        userId: string,
        provider: string,
        providerUserId: string,
        email?: string,
    ): Promise<OAuthAccount | undefined> {
        const linked = await db.insert(oauthAccountsTable).values({
            userId,
            provider,
            providerUserId,
            email: email ?? null,
        }).onConflictDoNothing().returning();

        if (linked[0]) {
            return linked[0];
        }
        return this.findOAuthAccount(provider, providerUserId);
    }
}

export default AuthRepository;

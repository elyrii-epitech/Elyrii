import { and, eq, gt } from "drizzle-orm";
import { db } from "../config/db.config";
import { userTable, type NewUser, type User } from "../config/db/user.table";
import { oauthAccountsTable, type OAuthAccount } from "../config/db/oauth.table";
import { emailVerificationTokensTable } from "../config/db/email-verification.table";

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
            throw error;
        }
    }

    public async updateUserPassword(userId: string, plainPassword: string): Promise<boolean> {
        const hashedPass = await Bun.password.hash(plainPassword);
        const [updated] = await db.update(userTable).set({
            password: hashedPass,
        }).where(eq(userTable.id, userId)).returning({ id: userTable.id });

        return Boolean(updated);
    }

    public async updateEmailVerified(userId: string, verified: boolean): Promise<boolean> {
        const [updated] = await db.update(userTable).set({
            emailVerified: verified,
        }).where(eq(userTable.id, userId)).returning({ id: userTable.id });
        return Boolean(updated);
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

    public async createEmailVerificationToken(userId: string, ttlSeconds = 60 * 60 * 24): Promise<string> {
        const tokenId = crypto.randomUUID();
        const secret = crypto.randomUUID().replaceAll("-", "") + crypto.randomUUID().replaceAll("-", "");
        const tokenHash = await Bun.password.hash(secret);
        const expiresAt = new Date(Date.now() + ttlSeconds * 1000);

        await db.insert(emailVerificationTokensTable).values({
            id: tokenId,
            userId,
            tokenHash,
            expiresAt,
        });

        return `${tokenId}.${secret}`;
    }

    public async clearEmailVerificationTokens(userId: string): Promise<void> {
        await db.delete(emailVerificationTokensTable).where(eq(emailVerificationTokensTable.userId, userId));
    }

    public async consumeEmailVerificationToken(rawToken: string): Promise<User | undefined> {
        const [tokenId, secret] = rawToken.split(".");
        if (!tokenId || !secret) {
            return undefined;
        }

        const [verification] = await db
            .select()
            .from(emailVerificationTokensTable)
            .where(and(
                eq(emailVerificationTokensTable.id, tokenId),
                gt(emailVerificationTokensTable.expiresAt, new Date()),
            ))
            .limit(1);
        if (!verification) {
            return undefined;
        }

        const ok = await Bun.password.verify(secret, verification.tokenHash);
        if (!ok) {
            return undefined;
        }

        await db.transaction(async (tx) => {
            await tx.update(userTable)
                .set({ emailVerified: true })
                .where(eq(userTable.id, verification.userId));
            await tx.delete(emailVerificationTokensTable)
                .where(eq(emailVerificationTokensTable.userId, verification.userId));
        });

        return this.getUserById(verification.userId);
    }
}

export default AuthRepository;

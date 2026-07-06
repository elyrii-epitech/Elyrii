import { and, eq, gt } from "drizzle-orm";
import { db } from "../config/db.config";
import { revokedAccessTokensTable, tokenTable } from "../config/db/tokens.table";

class TokenRepository {
    public async createToken(token: string, userId: string, device: string): Promise<void> {
        try {
            const hashedToken = await Bun.password.hash(token);
            await db.insert(tokenTable).values({
                hash_token: hashedToken,
                userId: userId,
                device: device,
            })
        } catch (error) {
            throw new Error(error instanceof Error ? error.message : String(error));
        }
    }
    
    public async getTokenByUserId(userId: string): Promise<string | undefined> {
        const token = await db.query.tokenTable.findFirst({
            where: (table, { eq }) => eq(table.userId, userId),
        })
        return token?.hash_token;
    };

    public async getValidSessionForUser(userId: string, refreshToken: string) {
        const sessions = await db
            .select()
            .from(tokenTable)
            .where(eq(tokenTable.userId, userId));

        for (const session of sessions) {
            if (await Bun.password.verify(refreshToken, session.hash_token)) {
                return session;
            }
        }
        return null;
    }

    public async deleteToken(refreshToken: string, userId?: string): Promise<void> {
        if (userId) {
            const session = await this.getValidSessionForUser(userId, refreshToken);
            if (!session) return;
            await db.delete(tokenTable).where(eq(tokenTable.id, session.id));
            return;
        }

        const sessions = await db.select().from(tokenTable);
        for (const session of sessions) {
            if (await Bun.password.verify(refreshToken, session.hash_token)) {
                await db.delete(tokenTable).where(eq(tokenTable.id, session.id));
                return;
            }
        }
    };

    public async updateToken(token: string, userId: string, device: string, sessionId: string): Promise<string> {
        const hashedToken = await Bun.password.hash(token);
        const updatedToken = await db.update(tokenTable).set({
            hash_token: hashedToken,
            userId: userId,
            device: device,
        }).where(eq(tokenTable.id, sessionId)).returning();
        
        if (!updatedToken || !updatedToken[0]) {
            throw new Error("Token not found");
        }
        const { id } = updatedToken[0]
        return id;
    }

    public async revokeAccessToken(userId: string, jti: string, expiresAt: Date): Promise<void> {
        await db.insert(revokedAccessTokensTable).values({
            userId,
            jti,
            expiresAt,
        });
    }

    public async isAccessTokenRevoked(jti: string): Promise<boolean> {
        const [revoked] = await db
            .select({ id: revokedAccessTokensTable.id })
            .from(revokedAccessTokensTable)
            .where(and(
                eq(revokedAccessTokensTable.jti, jti),
                gt(revokedAccessTokensTable.expiresAt, new Date()),
            ))
            .limit(1);
        return Boolean(revoked);
    }
}

export default TokenRepository;

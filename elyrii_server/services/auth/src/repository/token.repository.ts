import { db } from "../config/db.config";
import { tokenTable } from "../config/db/token.table";
import { eq } from "drizzle-orm";

class TokenRepository {
    async createToken(token: string, userId: string, device: string) {
        await db.insert(tokenTable).values({
            hash_token: token,
            userId: userId,
            device: device,
        });
    }

    async getTokenByToken(token: string) {
        return (await db.select().from(tokenTable).where(eq(tokenTable.hash_token, token)))[0];
    }

    async updateToken(token: string, userId: string, device: string, sessionId: string) {
        const updatedToken = await db.update(tokenTable).set({
            hash_token: token,
            userId: userId,
            device: device,
        }).where(eq(tokenTable.id, sessionId)).returning({
            id: tokenTable.id,
        });
        if (!updatedToken) {
            throw new Error("Token not found");
        }
        return updatedToken;
    }

    async deleteToken(sessionId: string) {
        await db.delete(tokenTable).where(eq(tokenTable.id, sessionId));
    }
}

export default TokenRepository;
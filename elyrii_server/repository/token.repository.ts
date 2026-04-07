import { eq } from "drizzle-orm";
import { db } from "../config/db.config";
import { tokenTable } from "../config/db/tokens.table";

class TokenRepository {
    public async createToken(token: string, userId: string, device: string): Promise<void> {  
        try {
            await db.insert(tokenTable).values({
                hash_token: token,
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
    
    public async getTokenByToken(token: string) {
        const tokenData = await db.query.tokenTable.findFirst({
            where: (table, { eq }) => eq(table.hash_token, token),
        })
        return tokenData;
    };
    
    public async deleteToken(token: string): Promise<void> {
        await db.delete(tokenTable).where(eq(tokenTable.hash_token, token));
    };
    
    public async updateToken(token: string, userId: string, device: string, sessionId: string): Promise<string> {
        const updatedToken = await db.update(tokenTable).set({
            hash_token: token,
            userId: userId,
            device: device,
        }).where(eq(tokenTable.id, sessionId)).returning();
        
        if (!updatedToken || !updatedToken[0]) {
            throw new Error("Token not found");
        }
        const { id } = updatedToken[0]
        return id;
    }
}

export default TokenRepository;
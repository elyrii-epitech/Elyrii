import { db } from "../config/db.config";
import { tokenTable } from "../config/db/token.table";

class TokenRepository {
    async createToken(token: string, userId: string, device: string) {
        await db.insert(tokenTable).values({
            hash_token: token,
            userId: userId,
            device: device,
        });
    }
}

export default TokenRepository;
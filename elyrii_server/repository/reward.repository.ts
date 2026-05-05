import { eq, sql } from "drizzle-orm";
import { db } from "../config/db.config";
import { pointsLedgerTable } from "../config/db/reward.table";

class RewardRepository {
    async grantChallengeCompletionPoints(
        userId: string,
        userChallengeId: string,
        points: number,
        metadata?: Record<string, unknown>,
    ): Promise<boolean> {
        const inserted = await db
            .insert(pointsLedgerTable)
            .values({
                userId,
                userChallengeId,
                points,
                reason: "challenge_completion",
                metadata: metadata ?? null,
            })
            .onConflictDoNothing()
            .returning({ id: pointsLedgerTable.id });

        return inserted.length > 0;
    }

    async getTotalPoints(userId: string): Promise<number> {
        const [result] = await db
            .select({ points: sql<number>`coalesce(sum(${pointsLedgerTable.points}), 0)` })
            .from(pointsLedgerTable)
            .where(eq(pointsLedgerTable.userId, userId));

        return Number(result?.points ?? 0);
    }
}

export default RewardRepository;

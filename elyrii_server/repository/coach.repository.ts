import { desc, eq } from "drizzle-orm";
import { db } from "../config/db.config";
import { coachSessionsTable, type CoachSession, type NewCoachSession } from "../config/db/coach.table";

class CoachRepository {
    async createSession(data: NewCoachSession): Promise<CoachSession> {
        const [session] = await db.insert(coachSessionsTable).values(data).returning();
        if (!session) {
            throw new Error("Failed to create coach session");
        }
        return session;
    }

    async getSessions(userId: string, limit = 20): Promise<CoachSession[]> {
        return db
            .select()
            .from(coachSessionsTable)
            .where(eq(coachSessionsTable.userId, userId))
            .orderBy(desc(coachSessionsTable.createdAt))
            .limit(limit);
    }
}

export default CoachRepository;

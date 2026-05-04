import { and, desc, eq } from "drizzle-orm";
import { db } from "../config/db.config";
import { meditationSessionsTable, type MeditationSession, type NewMeditationSession } from "../config/db/meditation.table";

class MeditationRepository {
    async startSession(data: NewMeditationSession): Promise<MeditationSession> {
        const [session] = await db.insert(meditationSessionsTable).values(data).returning();
        if (!session) {
            throw new Error("Failed to start meditation session");
        }
        return session;
    }

    async listSessions(userId: string, limit = 50): Promise<MeditationSession[]> {
        return db
            .select()
            .from(meditationSessionsTable)
            .where(eq(meditationSessionsTable.userId, userId))
            .orderBy(desc(meditationSessionsTable.createdAt))
            .limit(limit);
    }

    async getSessionByIdForUser(id: string, userId: string): Promise<MeditationSession | null> {
        const [session] = await db
            .select()
            .from(meditationSessionsTable)
            .where(and(
                eq(meditationSessionsTable.id, id),
                eq(meditationSessionsTable.userId, userId),
            ))
            .limit(1);
        return session ?? null;
    }

    async completeSession(
        id: string,
        userId: string,
        data: Partial<Pick<MeditationSession, "endedAt" | "notes" | "moodBefore" | "moodAfter">>,
    ): Promise<MeditationSession> {
        const [updated] = await db
            .update(meditationSessionsTable)
            .set({
                status: "COMPLETED",
                endedAt: data.endedAt ?? new Date(),
                notes: data.notes,
                moodBefore: data.moodBefore,
                moodAfter: data.moodAfter,
            })
            .where(and(
                eq(meditationSessionsTable.id, id),
                eq(meditationSessionsTable.userId, userId),
            ))
            .returning();

        if (!updated) {
            throw new Error("Meditation session not found");
        }
        return updated;
    }

    async cancelSession(id: string, userId: string): Promise<MeditationSession> {
        const [updated] = await db
            .update(meditationSessionsTable)
            .set({
                status: "CANCELED",
                endedAt: new Date(),
            })
            .where(and(
                eq(meditationSessionsTable.id, id),
                eq(meditationSessionsTable.userId, userId),
            ))
            .returning();

        if (!updated) {
            throw new Error("Meditation session not found");
        }
        return updated;
    }
}

export default MeditationRepository;

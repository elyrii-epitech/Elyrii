import {and, desc, eq} from "drizzle-orm";
import {db} from "../config/db.config";
import {meditationSessionsTable, type MeditationSession, type NewMeditationSession} from "../config/db/meditation.table";
import {userTable} from "../config/db/user.table";
import {MeditationRequestError} from "../modules/meditation/meditation.contracts";

class MeditationRepository {
    async startSession(data: NewMeditationSession): Promise<MeditationSession> {
        return db.transaction(async tx => {
            const [owner] = await tx.select({id: userTable.id}).from(userTable).where(eq(userTable.id, data.userId)).for("update");
            if (!owner) throw new MeditationRequestError("Account not found", 404);
            // The optional mobile UUID uses the existing primary key, so a
            // lost acknowledgement can be retried without another row.
            // Drizzle serializes Date values in UTC. Avoid a database-local
            // timestamp default being interpreted as UTC on a non-UTC host.
            const now = new Date();
            const [created] = await tx.insert(meditationSessionsTable).values({
                startedAt: now, createdAt: now, updatedAt: now, ...data,
            }).onConflictDoNothing().returning();
            if (created) return created;
            const [existing] = await tx.select().from(meditationSessionsTable).where(and(
                eq(meditationSessionsTable.id, data.id!), eq(meditationSessionsTable.userId, data.userId)));
            if (!existing || existing.type !== data.type || existing.durationMinutes !== data.durationMinutes) {
                throw new MeditationRequestError("Session identifier already used", 409);
            }
            return existing;
        });
    }

    async listSessions(userId: string, limit = 50): Promise<MeditationSession[]> {
        return db.select().from(meditationSessionsTable).where(eq(meditationSessionsTable.userId, userId))
            .orderBy(desc(meditationSessionsTable.createdAt), desc(meditationSessionsTable.id)).limit(limit);
    }

    async getSessionByIdForUser(id: string, userId: string): Promise<MeditationSession | null> {
        const [session] = await db.select().from(meditationSessionsTable).where(and(
            eq(meditationSessionsTable.id, id), eq(meditationSessionsTable.userId, userId))).limit(1);
        return session ?? null;
    }

    private async transition(id: string, userId: string, status: "COMPLETED" | "CANCELED",
        data: Partial<Pick<MeditationSession, "endedAt" | "notes" | "moodBefore" | "moodAfter">> = {}): Promise<MeditationSession> {
        return db.transaction(async tx => {
            const [owner] = await tx.select({id: userTable.id}).from(userTable).where(eq(userTable.id, userId)).for("update");
            if (!owner) throw new MeditationRequestError("Account not found", 404);
            const [session] = await tx.select().from(meditationSessionsTable).where(and(
                eq(meditationSessionsTable.id, id), eq(meditationSessionsTable.userId, userId))).for("update");
            if (!session) throw new MeditationRequestError("Meditation session not found", 404);
            if (session.status !== "STARTED" && session.status !== status) {
                throw new MeditationRequestError("Meditation session already ended", 409);
            }
            if (status === "CANCELED" && session.status === status) return session;
            const endedAt = session.endedAt ?? data.endedAt ?? new Date();
            if (!session.endedAt && data.endedAt &&
                (endedAt < session.startedAt || endedAt.getTime() > Date.now() + 60000)) {
                throw new MeditationRequestError("Invalid session end time", 400);
            }
            const [updated] = await tx.update(meditationSessionsTable).set({
                status, endedAt,
                ...(status === "COMPLETED" ? {notes: data.notes, moodBefore: data.moodBefore, moodAfter: data.moodAfter} : {}),
            }).where(eq(meditationSessionsTable.id, id)).returning();
            return updated!;
        });
    }

    async completeSession(id: string, userId: string,
        data: Partial<Pick<MeditationSession, "endedAt" | "notes" | "moodBefore" | "moodAfter">>): Promise<MeditationSession> {
        return this.transition(id, userId, "COMPLETED", data);
    }

    async cancelSession(id: string, userId: string): Promise<MeditationSession> {
        return this.transition(id, userId, "CANCELED");
    }
}
export default MeditationRepository;

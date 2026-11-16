import {and, eq} from "drizzle-orm";
import {db} from "../config/db.config";
import {coachJourneysTable, type CoachJourney} from "../config/db/coach.table";
import {userTable} from "../config/db/user.table";
import {COACH_CATALOG} from "../modules/coach/coach.catalog";
import {coachEnrollmentSchema, coachPathSchema, CoachJourneyError, type CoachEnrollment} from "../modules/coach/coach.journey-contracts";

const currentWhere = (userId: string) => and(eq(coachJourneysTable.userId, userId), eq(coachJourneysTable.isCurrent, true));
const enrollment = (row: CoachJourney): CoachEnrollment => coachEnrollmentSchema.parse({
    enrollmentId: row.id, path: row.path, status: row.status, completedStepCount: row.completedStepCount,
    revision: row.revision, startedAt: row.startedAt.toISOString(), updatedAt: row.updatedAt.toISOString(),
    completedAt: row.completedAt?.toISOString() ?? null,
});

class CoachJourneyRepository {
    async getCurrent(userId: string) {
        const [row] = await db.select().from(coachJourneysTable).where(currentWhere(userId));
        return row ? enrollment(row) : null;
    }

    private async locked<T>(userId: string, action: (tx: Parameters<Parameters<typeof db.transaction>[0]>[0], row: CoachJourney | undefined) => Promise<T>) {
        return db.transaction(async tx => {
            const [owner] = await tx.select({id: userTable.id}).from(userTable).where(eq(userTable.id, userId)).for("update");
            if (!owner) throw new CoachJourneyError("Account not found", 404);
            const [current] = await tx.select().from(coachJourneysTable).where(currentWhere(userId)).for("update");
            return action(tx, current);
        });
    }

    async choose(userId: string, input: {pathId: string; contentVersion: number; expectedEnrollmentId: string | null}) {
        const path = COACH_CATALOG.find(p => p.pathId === input.pathId && p.contentVersion === input.contentVersion);
        if (!path) throw new CoachJourneyError("Programme indisponible. Actualise le catalogue.", 400);
        return this.locked(userId, async (tx, current) => {
            if (current?.path.pathId === path.pathId && current.path.contentVersion === path.contentVersion) {
                return {current: enrollment(current), changed: false};
            }
            if ((current?.id ?? null) !== input.expectedEnrollmentId) {
                throw new CoachJourneyError("Le programme a changé. Actualise ta progression.", 409);
            }
            if (current) await tx.update(coachJourneysTable).set({isCurrent: false}).where(eq(coachJourneysTable.id, current.id));
            const now = new Date();
            const [created] = await tx.insert(coachJourneysTable).values({userId, path, startedAt: now, updatedAt: now}).returning();
            return {current: enrollment(created!), changed: true};
        });
    }

    async importLocal(userId: string, input: CoachEnrollment) {
        const known = COACH_CATALOG.find(p => p.pathId === input.path.pathId);
        if (!known || ![1, known.contentVersion].includes(input.path.contentVersion) ||
            (input.path.contentVersion === known.contentVersion && JSON.stringify(coachPathSchema.parse(input.path)) !== JSON.stringify(known))) {
            throw new CoachJourneyError("Ce programme local ne peut pas être importé. Tes données restent sur cet appareil.", 400);
        }
        return this.locked(userId, async (tx, current) => {
            // Another device or a previous lost acknowledgement wins over a
            // legacy cache. Import can never overwrite a server enrollment.
            if (current) return {current: enrollment(current), changed: false};
            const [created] = await tx.insert(coachJourneysTable).values({
                id: input.enrollmentId, userId, path: input.path, status: input.status,
                completedStepCount: input.completedStepCount, revision: input.revision,
                startedAt: new Date(input.startedAt), updatedAt: new Date(input.updatedAt),
                completedAt: input.completedAt ? new Date(input.completedAt) : null,
            }).onConflictDoNothing().returning();
            if (!created) throw new CoachJourneyError("Identifiant de programme déjà utilisé.", 409);
            return {current: enrollment(created), changed: true};
        });
    }

    async command(userId: string, input: {enrollmentId: string; revision: number}, command: "pause" | "resume" | "complete", stepId?: string) {
        return this.locked(userId, async (tx, current) => {
            if (!current || current.id !== input.enrollmentId) throw new CoachJourneyError("Programme introuvable. Actualise ta progression.", 404);
            if (input.revision > current.revision) throw new CoachJourneyError("Actualise ta progression avant de réessayer.", 409);
            let status = current.status, count = current.completedStepCount;
            if (command === "complete") {
                const index = current.path.steps.findIndex(s => s.stepId === stepId);
                if (index < 0 || index > count) throw new CoachJourneyError("Seule l’étape en cours peut être validée.", 400);
                if (index < count) return {current: enrollment(current), changed: false};
                if (status !== "active") throw new CoachJourneyError("Reprends ce programme avant de valider une étape.", 409);
                count++;
                if (count === current.path.steps.length) status = "completed";
            } else {
                const desired = command === "pause" ? "paused" : "active";
                if (status === desired) return {current: enrollment(current), changed: false};
                if (status === "completed") throw new CoachJourneyError("Ce programme est terminé. Tu peux en choisir un autre.", 409);
                status = desired;
            }
            if (input.revision !== current.revision) throw new CoachJourneyError("Le programme a changé. Actualise ta progression.", 409);
            const now = new Date(Math.max(Date.now(), current.updatedAt.getTime()));
            const [updated] = await tx.update(coachJourneysTable).set({status, completedStepCount: count,
                revision: current.revision + 1, updatedAt: now, completedAt: status === "completed" ? now : null})
                .where(eq(coachJourneysTable.id, current.id)).returning();
            return {current: enrollment(updated!), changed: true};
        });
    }
}
export default CoachJourneyRepository;

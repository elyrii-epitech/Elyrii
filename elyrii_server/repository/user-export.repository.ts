import {and, asc, eq, isNull} from "drizzle-orm";
import {db} from "../config/db.config";
import {moodLogsTable, userTable} from "../config/db/user.table";
import {userSettingsTable} from "../config/db/settings.table";
import {journalEntriesTable, journalTagsTable, journalEntryTagsTable, journalMediaTable} from "../config/db/journal.table";
import {chatMessagesTable} from "../config/db/chat.table";
import {challengesTable, userChallengesTable} from "../config/db/quest.table";
import {meditationSessionsTable} from "../config/db/meditation.table";
import {coachSessionsTable, coachJourneysTable} from "../config/db/coach.table";
import {notificationsTable} from "../config/db/notification.table";
import {pointsLedgerTable} from "../config/db/reward.table";

/** User-facing account data from one consistent read-only snapshot. */
class UserExportRepository {
    async exportAccount(userId: string) {
        return db.transaction(async tx => {
            // Explicit allowlist: credentials, refresh sessions and internal AI
            // job payloads are never part of this user-facing export.
            const [profile] = await tx.select({id: userTable.id, email: userTable.email,
                firstName: userTable.firstName, lastName: userTable.lastName, age: userTable.age,
                emailVerified: userTable.emailVerified, pfp: userTable.pfp, bio: userTable.bio,
                gender: userTable.gender, pronouns: userTable.pronouns, wellnessGoal: userTable.wellnessGoal,
                timezone: userTable.timezone, currentStreak: userTable.currentStreak, highestStreak: userTable.highestStreak,
                createdAt: userTable.createdAt, updatedAt: userTable.updatedAt,
            }).from(userTable).where(eq(userTable.id, userId));
            if (!profile) return null;
            const ownEntry = and(eq(journalEntriesTable.userId, userId), isNull(journalEntriesTable.deletedAt));
            const [settings, moods, entries, tags, entryTags, media, messages, challenges, meditations, coaching, journeys, notifications, points] = await Promise.all([
                tx.select().from(userSettingsTable).where(eq(userSettingsTable.userId, userId)),
                tx.select().from(moodLogsTable).where(eq(moodLogsTable.userId, userId)).orderBy(asc(moodLogsTable.createdAt), asc(moodLogsTable.id)),
                tx.select().from(journalEntriesTable).where(ownEntry).orderBy(asc(journalEntriesTable.createdAt), asc(journalEntriesTable.id)),
                tx.select().from(journalTagsTable).where(eq(journalTagsTable.userId, userId)),
                tx.select({entryId: journalEntryTagsTable.entryId, tagId: journalEntryTagsTable.tagId})
                    .from(journalEntryTagsTable).innerJoin(journalEntriesTable, eq(journalEntriesTable.id, journalEntryTagsTable.entryId))
                    .innerJoin(journalTagsTable, eq(journalTagsTable.id, journalEntryTagsTable.tagId))
                    .where(and(ownEntry, eq(journalTagsTable.userId, userId))),
                tx.select({id: journalMediaTable.id, entryId: journalMediaTable.entryId, url: journalMediaTable.url,
                    type: journalMediaTable.type, createdAt: journalMediaTable.createdAt})
                    .from(journalMediaTable).innerJoin(journalEntriesTable, eq(journalEntriesTable.id, journalMediaTable.entryId)).where(ownEntry),
                tx.select({id: chatMessagesTable.id, userId: chatMessagesTable.userId, conversationId: chatMessagesTable.conversationId,
                    role: chatMessagesTable.role, message: chatMessagesTable.message, createdAt: chatMessagesTable.createdAt})
                    .from(chatMessagesTable).where(eq(chatMessagesTable.userId, userId)).orderBy(asc(chatMessagesTable.createdAt), asc(chatMessagesTable.id)),
                tx.select({assignment: userChallengesTable, challenge: challengesTable})
                    .from(userChallengesTable).innerJoin(challengesTable, eq(challengesTable.id, userChallengesTable.challengeId)).where(eq(userChallengesTable.userId, userId)),
                tx.select().from(meditationSessionsTable).where(eq(meditationSessionsTable.userId, userId)),
                tx.select().from(coachSessionsTable).where(eq(coachSessionsTable.userId, userId)),
                tx.select().from(coachJourneysTable).where(eq(coachJourneysTable.userId, userId)),
                tx.select().from(notificationsTable).where(eq(notificationsTable.userId, userId)),
                tx.select().from(pointsLedgerTable).where(eq(pointsLedgerTable.userId, userId)),
            ]);
            return {schemaVersion: 1, exportedAt: new Date().toISOString(), profile, settings: settings[0] ?? null,
                moods, journal: {entries, tags, entryTags, media}, messages, challenges,
                meditationSessions: meditations, coachSessions: coaching, coachJourneys: journeys, notifications, points};
        }, {isolationLevel: "repeatable read", accessMode: "read only"});
    }
}
export default UserExportRepository;

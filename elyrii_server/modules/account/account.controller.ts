import { createFactory } from 'hono/factory';
import { sValidator } from '@hono/standard-validator';
import { and, eq, desc, gt, isNull, sql, getTableColumns } from 'drizzle-orm';
import { z } from 'zod';
import { db } from '../../config/db.config';
import * as tables from '../../config/db/schema';
import type { HonoEnv } from '../../utils/hono.types';

export const aiReportSchema = z.object({
  messageId: z.uuid(), conversationId: z.string().min(1).max(100),
  reason: z.enum(['DANGEROUS', 'INACCURATE', 'OFFENSIVE', 'PRIVACY', 'OTHER']),
  content: z.string().min(1).max(16000),
});
// An empty allowlist denies every account. Never trust a role supplied by clients.
export function canModerate(userId: string, allowlist = Bun.env.MODERATION_ADMIN_USER_IDS ?? ''): boolean {
  return allowlist.split(',').map(id => id.trim()).filter(Boolean).includes(userId);
}
export default class AccountController {
  private readonly factory = createFactory<HonoEnv>();
  readonly report = this.factory.createHandlers(sValidator('json', aiReportSchema), async c => {
    const userId = c.get('user').userId;
    const input = c.req.valid('json');
    // Per-account daily cap, including retries; enforcement is serialized in SQL.
    const result = await db.transaction(async tx => {
      await tx.execute(sql`SELECT pg_advisory_xact_lock(hashtext(${userId}))`);
      const [{ count } = { count: 0 }] = await tx.select({count: sql<number>`count(*)::int`}).from(tables.aiReportsTable).where(and(eq(tables.aiReportsTable.userId, userId), gt(tables.aiReportsTable.createdAt, new Date(Date.now() - 86400000))));
      if (count >= 20) return null;
      const [report] = await tx.insert(tables.aiReportsTable).values({...input, userId}).returning({id: tables.aiReportsTable.id});
      return report;
    });
    if (!result) return c.json({error: 'Limite quotidienne atteinte. Réessaie demain.'}, 429);
    return c.json({id: result.id, message: 'Signalement enregistré'}, 201);
  });
  readonly queue = this.factory.createHandlers(async c => {
    if (!canModerate(c.get('user').userId)) return c.json({error: 'Forbidden'}, 403);
    const reports = await db.select().from(tables.aiReportsTable).where(eq(tables.aiReportsTable.status, 'OPEN')).orderBy(desc(tables.aiReportsTable.createdAt)).limit(50);
    return c.json(reports);
  });
  readonly review = this.factory.createHandlers(sValidator('json', z.object({status: z.enum(['REVIEWED', 'ACTIONED'])})), async c => {
    if (!canModerate(c.get('user').userId)) return c.json({error: 'Forbidden'}, 403);
    const id = z.uuid().safeParse(c.req.param('reportId'));
    if (!id.success) return c.json({error: 'Invalid ID'}, 400);
    const [updated] = await db.update(tables.aiReportsTable).set({status: c.req.valid('json').status, reviewedAt: new Date()}).where(eq(tables.aiReportsTable.id, id.data)).returning({id: tables.aiReportsTable.id});
    return updated ? c.json(updated) : c.json({error: 'Not found'}, 404);
  });
  readonly export = this.factory.createHandlers(async c => {
    c.header('Cache-Control', 'no-store');
    const owner = c.get('user').userId;
    // A repeatable-read snapshot and explicit profile fields exclude credentials.
    const result = await db.transaction(async tx => {
      const [profile] = await tx.select({id: tables.userTable.id, email: tables.userTable.email, firstName: tables.userTable.firstName, lastName: tables.userTable.lastName, age: tables.userTable.age, pfp: tables.userTable.pfp, bio: tables.userTable.bio, gender: tables.userTable.gender, pronouns: tables.userTable.pronouns, wellnessGoal: tables.userTable.wellnessGoal, timezone: tables.userTable.timezone, currentStreak: tables.userTable.currentStreak, highestStreak: tables.userTable.highestStreak, lastActivityDate: tables.userTable.lastActivityDate, createdAt: tables.userTable.createdAt, updatedAt: tables.userTable.updatedAt}).from(tables.userTable).where(eq(tables.userTable.id, owner));
      const [settings] = await tx.select().from(tables.userSettingsTable).where(eq(tables.userSettingsTable.userId, owner));
      const journal = await tx.select().from(tables.journalEntriesTable).where(and(eq(tables.journalEntriesTable.userId, owner), isNull(tables.journalEntriesTable.deletedAt)));
      const ownedEntries = and(eq(tables.journalEntriesTable.userId, owner), isNull(tables.journalEntriesTable.deletedAt));
      const journalTagLinks = await tx.select(getTableColumns(tables.journalEntryTagsTable)).from(tables.journalEntryTagsTable).innerJoin(tables.journalEntriesTable, eq(tables.journalEntryTagsTable.entryId, tables.journalEntriesTable.id)).where(ownedEntries);
      const journalMedia = await tx.select(getTableColumns(tables.journalMediaTable)).from(tables.journalMediaTable).innerJoin(tables.journalEntriesTable, eq(tables.journalMediaTable.entryId, tables.journalEntriesTable.id)).where(ownedEntries);
      const tags = await tx.select().from(tables.journalTagsTable).where(eq(tables.journalTagsTable.userId, owner));
      const moods = await tx.select().from(tables.moodLogsTable).where(eq(tables.moodLogsTable.userId, owner));
      const meditation = await tx.select().from(tables.meditationSessionsTable).where(eq(tables.meditationSessionsTable.userId, owner));
      const coach = await tx.select().from(tables.coachSessionsTable).where(eq(tables.coachSessionsTable.userId, owner));
      const chat = await tx.select().from(tables.chatMessagesTable).where(eq(tables.chatMessagesTable.userId, owner));
      const challenges = await tx.select().from(tables.userChallengesTable).where(eq(tables.userChallengesTable.userId, owner));
      const points = await tx.select().from(tables.pointsLedgerTable).where(eq(tables.pointsLedgerTable.userId, owner));
      const notifications = await tx.select().from(tables.notificationsTable).where(eq(tables.notificationsTable.userId, owner));
      const reports = await tx.select().from(tables.aiReportsTable).where(eq(tables.aiReportsTable.userId, owner));
      return {schemaVersion: 1, exportedAt: new Date().toISOString(), profile, settings, journal, journalTagLinks, journalMedia, tags, moods, meditation, coach, chat, challenges, points, notifications, reports};
    }, {isolationLevel: 'repeatable read', accessMode: 'read only'});
    return c.json(result);
  });
}

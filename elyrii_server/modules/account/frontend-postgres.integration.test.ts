import {afterAll, beforeAll, describe, expect, test} from 'bun:test';
import {Hono} from 'hono';
import {eq, inArray, sql} from 'drizzle-orm';
import {db} from '../../config/db.config';
import * as tables from '../../config/db/schema';
import type {HonoEnv} from '../../utils/hono.types';
import JournalRepository from '../../repository/journal.repository';
import AccountController from './account.controller';
import PasswordResetController from '../auth/password-reset.controller';
import {resetHash} from '../auth/password-reset.service';
import AuthController from '../auth/auth.controller';
import AuthRepository from '../../repository/auth.repository';

const integration = Bun.env.FRONTEND_DB_INTEGRATION === '1' ? describe : describe.skip;
integration('frontend corrections against a disposable PostgreSQL database', () => {
  const owner = crypto.randomUUID();
  const other = crypto.randomUUID();
  const repository = new JournalRepository();
  const controller = new AccountController();
  const reset = new PasswordResetController();
  const app = new Hono<HonoEnv>();
  app.use('*', async (c, next) => {
    // This test harness supplies an identity; deployed routes use authMiddleware.
    c.set('user', {userId: c.req.header('X-Test-Owner') ?? owner, email: 'fixture@example.test'});
    await next();
  });
  app.get('/export', ...controller.export);
  app.post('/reports', ...controller.report);
  app.get('/queue', ...controller.queue);
  app.put('/queue/:reportId', ...controller.review);
  app.post('/reset', ...reset.confirm);
  const json = (data: unknown, method = 'POST') => ({method, headers: {'Content-Type': 'application/json'}, body: JSON.stringify(data)});

  beforeAll(async () => {
    if (Bun.env.DB_NAME !== 'elyrii_frontend_test' || Bun.env.NODE_ENV === 'production') throw new Error('Integration tests require the disposable elyrii_frontend_test database');
    // Recreate the additive migration from the previous schema, then prove replay.
    await db.execute(sql.raw('DROP TABLE IF EXISTS ai_content_reports, password_reset_tokens; ALTER TABLE journal_entries DROP COLUMN IF EXISTS client_request_id; DROP INDEX IF EXISTS journal_entries_page_idx;'));
    const migration = await Bun.file(new URL('../../migrations/20261010_frontend_reliability.sql', import.meta.url)).text();
    await db.execute(sql.raw(migration));
    await db.execute(sql.raw(migration));
    await db.insert(tables.userTable).values([owner, other].map((id, i) => ({id, email: `frontend-${id}@example.test`, firstName: 'Fixture', lastName: String(i), age: 25, password: 'credential-must-never-appear-in-export'})));
  });
  afterAll(async () => {
    const entries = await db.select({id: tables.journalEntriesTable.id}).from(tables.journalEntriesTable).where(inArray(tables.journalEntriesTable.userId, [owner, other]));
    if (entries.length) {
      const ids = entries.map(e => e.id);
      await db.delete(tables.journalMediaTable).where(inArray(tables.journalMediaTable.entryId, ids));
      await db.delete(tables.journalEntryTagsTable).where(inArray(tables.journalEntryTagsTable.entryId, ids));
    }
    await db.delete(tables.journalEntriesTable).where(inArray(tables.journalEntriesTable.userId, [owner, other]));
    await db.delete(tables.journalTagsTable).where(inArray(tables.journalTagsTable.userId, [owner, other]));
    await db.delete(tables.userTable).where(inArray(tables.userTable.id, [owner, other]));
  });

  test('concurrent retries create one owned entry and attach tags once', async () => {
    const clientRequestId = crypto.randomUUID();
    const input = {userId: owner, title: 'An acknowledged note', clientRequestId, tags: ['fixture']};
    const results = await Promise.all(Array.from({length: 12}, () => repository.createEntryWithRelations(input)));
    expect(new Set(results.map(e => e.id)).size).toBe(1);
    expect(results.filter(e => e.wasCreated).length).toBe(1);
    const independent = await repository.createEntryWithRelations({...input, userId: other});
    expect(independent.id).not.toBe(results[0]!.id);
    const tags = await db.select().from(tables.journalEntryTagsTable).where(eq(tables.journalEntryTagsTable.entryId, results[0]!.id));
    expect(tags.length).toBe(1);
  });

  test('pagination does not skip timestamps with microseconds or leak another owner, in either order', async () => {
    await db.execute(sql`INSERT INTO journal_entries (user_id, title, created_at) SELECT ${owner}::uuid, 'paging-fixture-' || n, timestamp '2026-10-10 12:00:00.123456' FROM generate_series(1, 230) n`);
    await repository.createEntryWithRelations({userId: other, title: 'other-owner-private'});
    for (const order of ['asc', 'desc'] as const) {
      const seen = new Set<string>();
      let cursor: {createdAt: Date, id: string} | undefined;
      let count = 0;
      do {
        const page = await repository.getPage(owner, 100, order, cursor);
        count = page.totalCount;
        expect(page.entries.length).toBeLessThanOrEqual(100);
        for (const entry of page.entries) {
          expect(entry.userId).toBe(owner);
          expect(seen.has(entry.id)).toBe(false);
          seen.add(entry.id);
        }
        cursor = page.nextCursor ? {...page.nextCursor, createdAt: new Date(page.nextCursor.createdAt)} : undefined;
      } while (cursor);
      expect(seen.size).toBe(count);
      expect(seen.size).toBeGreaterThanOrEqual(230);
    }
  });

  test('export includes owned tag links and media and excludes credentials, other owners and deleted notes', async () => {
    const entry = await repository.createEntryWithRelations({userId: owner, title: 'export-owned', tags: ['export-tag']});
    await db.insert(tables.journalMediaTable).values({entryId: entry.id, url: 'https://example.test/owned-photo.jpg', type: 'image'});
    const removed = await repository.createEntryWithRelations({userId: owner, title: 'deleted-private'});
    await db.update(tables.journalEntriesTable).set({deletedAt: new Date()}).where(eq(tables.journalEntriesTable.id, removed.id));
    const response = await app.request('/export');
    expect(response.status).toBe(200);
    expect(response.headers.get('Cache-Control')).toBe('no-store');
    const data = await response.json() as {profile: Record<string, unknown>, journalTagLinks: Array<{entryId: string}>, journalMedia: Array<{entryId: string}>};
    const text = JSON.stringify(data);
    expect(text).not.toContain('credential-must-never');
    expect(text).not.toContain('other-owner-private');
    expect(text).not.toContain('deleted-private');
    expect(data.profile).not.toHaveProperty('password');
    expect(data.journalTagLinks.some((link: {entryId: string}) => link.entryId === entry.id)).toBe(true);
    expect(data.journalMedia.some((media: {entryId: string}) => media.entryId === entry.id)).toBe(true);
  });

  test('report quotas survive concurrent requests and moderation denies unconfigured accounts', async () => {
    const input = {messageId: crypto.randomUUID(), conversationId: 'owned-local-conversation', reason: 'DANGEROUS', content: 'Selected fixture response'};
    const responses = await Promise.all(Array.from({length: 21}, () => app.request('/reports', json(input))));
    expect(responses.filter(r => r.status === 201).length).toBe(20);
    expect(responses.filter(r => r.status === 429).length).toBe(1);
    const previous = Bun.env.MODERATION_ADMIN_USER_IDS;
    try {
      Bun.env.MODERATION_ADMIN_USER_IDS = '';
      expect((await app.request('/queue')).status).toBe(403);
      Bun.env.MODERATION_ADMIN_USER_IDS = owner;
      const queue = await (await app.request('/queue')).json() as Array<{id: string, userId: string}>;
      expect(queue.some((report: {userId: string}) => report.userId === owner)).toBe(true);
      expect((await app.request('/queue/' + queue[0]!.id, json({status: 'REVIEWED'}, 'PUT'))).status).toBe(200);
    } finally {
      if (previous === undefined) delete Bun.env.MODERATION_ADMIN_USER_IDS;
      else Bun.env.MODERATION_ADMIN_USER_IDS = previous;
    }
  });

  test('password recovery consumes the persisted code exactly once and hashes the replacement', async () => {
    const code = crypto.getRandomValues(new Uint8Array(32));
    const value = Buffer.from(code).toString('base64url');
    await db.insert(tables.passwordResetTable).values({userId: owner, tokenHash: resetHash(value), expiresAt: new Date(Date.now() + 60000)});
    const request = json({code: value, password: 'une phrase secrète de test longue'});
    const responses = await Promise.all([app.request('/reset', request), app.request('/reset', request)]);
    expect(responses.map(r => r.status).sort()).toEqual([200, 400]);
    const [user] = await db.select().from(tables.userTable).where(eq(tables.userTable.id, owner));
    expect(await Bun.password.verify('une phrase secrète de test longue', user!.password)).toBe(true);
    expect((await db.select().from(tables.passwordResetTable).where(eq(tables.passwordResetTable.userId, owner))).length).toBe(0);
  });

  test('a failed email delivery only discards its own token, not a newer resend', async () => {
    const auth = new AuthRepository();
    const failedToken = await auth.createEmailVerificationToken(other);
    const newerToken = await auth.createEmailVerificationToken(other);
    await auth.discardEmailVerificationToken(other, failedToken);
    expect(await auth.consumeEmailVerificationToken(failedToken)).toBeUndefined();
    expect((await auth.consumeEmailVerificationToken(newerToken))?.id).toBe(other);
  });

  test('email activation delivers a usable token, retries failed delivery and consumes once', async () => {
    const previous = Bun.env.REQUIRE_EMAIL_VERIFICATION;
    Bun.env.REQUIRE_EMAIL_VERIFICATION = 'true';
    const email = `verification-${crypto.randomUUID()}@example.test`;
    let token = '';
    let failDelivery = true;
    const auth = new AuthController({available: () => true, send: async (_email, value) => {
      if (failDelivery) throw new Error('Fixture mail unavailable');
      token = value;
    }});
    const router = new Hono();
    router.post('/register', ...auth.register);
    router.post('/login', ...auth.login);
    router.post('/verify', ...auth.verifyEmail);
    const signup = {email, password: 'A fixture password 2026!', firstName: 'Email', lastName: 'Fixture'};
    try {
      expect((await router.request('/register', json(signup))).status).toBe(503);
      failDelivery = false;
      const response = await router.request('/register', json(signup));
      expect(response.status).toBe(201);
      expect(await response.json()).toMatchObject({emailVerificationRequired: true});
      expect(token).not.toBe('');
      expect((await router.request('/login', json(signup))).status).toBe(403);
      const results = await Promise.all([router.request('/verify', json({token})), router.request('/verify', json({token}))]);
      expect(results.map(r => r.status).sort()).toEqual([200, 400]);
      const login = await router.request('/login', json(signup));
      expect(login.status).toBe(200);
      expect(await login.json()).toHaveProperty('refreshToken');
    } finally {
      await db.delete(tables.userTable).where(eq(tables.userTable.email, email));
      if (previous === undefined) delete Bun.env.REQUIRE_EMAIL_VERIFICATION;
      else Bun.env.REQUIRE_EMAIL_VERIFICATION = previous;
    }
  });
});

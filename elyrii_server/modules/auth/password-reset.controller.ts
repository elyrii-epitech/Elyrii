import { createFactory } from 'hono/factory';
import { sValidator } from '@hono/standard-validator';
import { and, eq, gt, lt } from 'drizzle-orm';
import { z } from 'zod';
import { db } from '../../config/db.config';
import { passwordResetTable, tokenTable, userTable } from '../../config/db/schema';
import { PasswordResetService, type PasswordResetStore, type ResetMailer } from './password-reset.service';

class DatabaseResetStore implements PasswordResetStore {
  async issue(email: string, tokenHash: string, expiresAt: Date, now: Date) {
    const [user] = await db.select({id: userTable.id, email: userTable.email}).from(userTable).where(eq(userTable.email, email)).limit(1);
    if (!user) return null;
    const [issued] = await db.insert(passwordResetTable).values({userId: user.id, tokenHash, expiresAt, createdAt: now}).onConflictDoUpdate({target: passwordResetTable.userId, set: {tokenHash, expiresAt, createdAt: now}, setWhere: lt(passwordResetTable.createdAt, new Date(now.getTime() - 60000))}).returning({id: passwordResetTable.userId});
    return issued ? user.email : null;
  }
  async valid(tokenHash: string, now: Date) {
    const [token] = await db.select({userId: passwordResetTable.userId}).from(passwordResetTable).where(and(eq(passwordResetTable.tokenHash, tokenHash), gt(passwordResetTable.expiresAt, now))).limit(1);
    return !!token;
  }
  async consume(tokenHash: string, password: string, now: Date) {
    return db.transaction(async tx => {
      const [consumed] = await tx.delete(passwordResetTable).where(and(eq(passwordResetTable.tokenHash, tokenHash), gt(passwordResetTable.expiresAt, now))).returning({userId: passwordResetTable.userId});
      if (!consumed) return false;
      await tx.update(userTable).set({password}).where(eq(userTable.id, consumed.userId));
      await tx.delete(tokenTable).where(eq(tokenTable.userId, consumed.userId));
      return true;
    });
  }
  async discard(tokenHash: string) { await db.delete(passwordResetTable).where(eq(passwordResetTable.tokenHash, tokenHash)); }
}
class WebhookResetMailer implements ResetMailer {
  async send(email: string, code: string) {
    const url = new URL(Bun.env.PASSWORD_RESET_MAIL_WEBHOOK!);
    if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash) throw new Error('Invalid mail configuration');
    const response = await fetch(url, {method: 'POST', redirect: 'error', signal: AbortSignal.timeout(10000), headers: {'Content-Type': 'application/json', Authorization: `Bearer ${Bun.env.PASSWORD_RESET_MAIL_SECRET}`}, body: JSON.stringify({template: 'password-reset', to: email, code, expiresInMinutes: 15})});
    if (!response.ok) throw new Error('Delivery failed');
  }
}
export default class PasswordResetController {
  private readonly factory = createFactory();
  private readonly service = new PasswordResetService(new DatabaseResetStore(), new WebhookResetMailer());
  readonly request = this.factory.createHandlers(sValidator('json', z.object({email: z.email().max(254)})), async c => {
    if (!Bun.env.PASSWORD_RESET_MAIL_WEBHOOK || !Bun.env.PASSWORD_RESET_MAIL_SECRET) return c.json({message: 'La récupération est temporairement indisponible. Réessaie plus tard.'}, 503);
    // Uniform response and asynchronous delivery avoid account enumeration.
    // The DB enforces a per-account cooldown across all service instances.
    void this.service.request(c.req.valid('json').email).catch(() => console.error('[password-reset] Delivery or storage unavailable'));
    c.header('Cache-Control', 'no-store');
    return c.json({message: 'Si ce compte existe, un code de récupération a été envoyé.'}, 202);
  });
  readonly confirm = this.factory.createHandlers(sValidator('json', z.object({code: z.string().regex(/^[A-Za-z0-9_-]{43}$/), password: z.string().min(12).max(128)})), async c => {
    const {code, password} = c.req.valid('json');
    const ok = await this.service.confirm(code, password);
    c.header('Cache-Control', 'no-store');
    return ok ? c.json({message: 'Mot de passe modifié. Reconnecte-toi.'}) : c.json({message: 'Code invalide ou expiré. Demande un nouveau code.'}, 400);
  });
}

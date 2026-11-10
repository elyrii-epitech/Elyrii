import { randomBytes, createHash } from 'node:crypto';
export const resetLifetimeMs = 15 * 60 * 1000;
export const resetHash = (token: string) => createHash('sha256').update(token).digest('hex');
export interface PasswordResetStore {
  issue(email: string, tokenHash: string, expiresAt: Date, now: Date): Promise<string | null>;
  valid(tokenHash: string, now: Date): Promise<boolean>;
  consume(tokenHash: string, passwordHash: string, now: Date): Promise<boolean>;
  discard(tokenHash: string): Promise<void>;
}
export interface ResetMailer { send(email: string, token: string): Promise<void> }
export class PasswordResetService {
  constructor(private readonly store: PasswordResetStore, private readonly mailer: ResetMailer, private readonly now: () => Date = () => new Date()) {}
  async request(email: string): Promise<void> {
    const token = randomBytes(32).toString('base64url');
    const hash = resetHash(token);
    const now = this.now();
    const destination = await this.store.issue(email.trim(), hash, new Date(now.getTime() + resetLifetimeMs), now);
    if (destination == null) return;
    try { await this.mailer.send(destination, token); }
    catch { await this.store.discard(hash); throw new Error('Password reset delivery failed'); }
  }
  async confirm(token: string, password: string): Promise<boolean> {
    if (!/^[A-Za-z0-9_-]{43}$/.test(token) || password.length < 12 || password.length > 128) return false;
    const hash = resetHash(token);
    if (!await this.store.valid(hash, this.now())) return false;
    const passwordHash = await Bun.password.hash(password, {algorithm: 'argon2id'});
    return this.store.consume(hash, passwordHash, this.now());
  }
}

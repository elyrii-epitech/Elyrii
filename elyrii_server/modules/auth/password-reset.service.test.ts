import {describe, expect, test} from 'bun:test';
import {PasswordResetService, resetHash, resetLifetimeMs, type PasswordResetStore} from './password-reset.service';
class Store implements PasswordResetStore {
  token: {hash: string, expiry: Date} | null = null;
  passwordHash: string | null = null;
  async issue(email: string, hash: string, expiry: Date) { if (email !== 'fixture@example.test') return null; this.token = {hash, expiry}; return email; }
  async valid(hash: string, now: Date) { return this.token?.hash === hash && this.token.expiry > now; }
  async consume(hash: string, password: string, now: Date) { if (!await this.valid(hash, now)) return false; if (this.token == null) return false; this.token = null; this.passwordHash = password; return true; }
  async discard(hash: string) { if (this.token?.hash === hash) this.token = null; }
}
describe('one-use password recovery', () => {
  test('the mail code has 256 bits of randomness; the store receives only a hash', async () => {
    const store = new Store(); let sent = '';
    const service = new PasswordResetService(store, {async send(_, code) {sent = code;}});
    await service.request('fixture@example.test');
    expect(sent).toMatch(/^[A-Za-z0-9_-]{43}$/);
    expect(store.token?.hash).toBe(resetHash(sent)); expect(store.token?.hash).not.toContain(sent);
    expect(await service.confirm('invalid', 'a long passphrase')).toBe(false);
    expect(await service.confirm(sent, 'short')).toBe(false);
    expect(await service.confirm(sent, 'une longue phrase secrète')).toBe(true);
    expect(await Bun.password.verify('une longue phrase secrète', store.passwordHash!)).toBe(true);
    expect(await service.confirm(sent, 'une autre phrase secrète')).toBe(false);
  });
  test('expired codes and unknown accounts cannot change a password', async () => {
    const store = new Store(); let time = new Date('2026-10-10T00:00:00Z'); let code = ''; let mails = 0;
    const service = new PasswordResetService(store, {async send(_, value) {code = value; mails++;}}, () => time);
    await service.request('missing@example.test'); expect(mails).toBe(0);
    await service.request('fixture@example.test');
    time = new Date(time.getTime() + resetLifetimeMs + 1);
    expect(await service.confirm(code, 'une longue phrase secrète')).toBe(false); expect(store.passwordHash).toBeNull();
  });
  test('failed delivery discards the code instead of leaving an undisclosed credential', async () => {
    const store = new Store(); const service = new PasswordResetService(store, {async send() {throw new Error('offline');}});
    await expect(service.request('fixture@example.test')).rejects.toThrow('delivery failed');
    expect(store.token).toBeNull();
  });
});

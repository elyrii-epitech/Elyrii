import { isIP } from 'node:net';
import { getConnInfo } from 'hono/bun';
import type { MiddlewareHandler } from 'hono';

/** Bounded per-process defense; the gateway must enforce shared replica quotas. */
export class FixedWindowLimiter {
  private readonly windows = new Map<string, {count: number, until: number}>();
  constructor(private readonly limit: number, private readonly windowMs: number, private readonly capacity = 10000) {}
  take(key: string, now = Date.now()): boolean {
    const current = this.windows.get(key);
    if (current && now < current.until) {
      if (current.count >= this.limit) return false;
      current.count++;
      return true;
    }
    this.windows.delete(key);
    if (this.windows.size >= this.capacity) {
      for (const [address, window] of this.windows) if (now >= window.until) this.windows.delete(address);
      if (this.windows.size >= this.capacity) return false;
    }
    this.windows.set(key, {count: 1, until: now + this.windowMs});
    return true;
  }
}

export function clientAddress(peer: string | undefined, realIP: string | undefined, trustedPeers: string): string {
  const trusted = peer && trustedPeers.split(',').map(v => v.trim()).includes(peer);
  return trusted && realIP && isIP(realIP) ? realIP : peer ?? 'unknown';
}

export function resetRateLimit(limit: number): MiddlewareHandler {
  const limiter = new FixedWindowLimiter(limit, 15 * 60 * 1000);
  return async (c, next) => {
    let peer: string | undefined;
    try { peer = getConnInfo(c).remote.address; } catch { /* Test harness or non-Bun adapter. */ }
    const address = clientAddress(peer, c.req.header('X-Real-IP'), Bun.env.PASSWORD_RESET_TRUSTED_PROXY_IPS ?? '');
    if (!limiter.take(address)) {
      c.header('Retry-After', '900');
      c.header('Cache-Control', 'no-store');
      return c.json({message: 'Trop de tentatives. Réessaie dans quelques minutes.'}, 429);
    }
    await next();
  };
}

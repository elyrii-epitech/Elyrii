import {expect, test} from 'bun:test';
import {clientAddress, FixedWindowLimiter} from './password-reset.rate-limit';
import AuthRoutes from './auth.routes';

test('oversized public recovery bodies are rejected before parsing or password hashing', async () => {
  const app = new AuthRoutes().Router;
  for (const route of ['request', 'confirm']) {
    const body = JSON.stringify({email: 'fixture@example.test', password: 'x'.repeat(5000)});
    const response = await app.request('/password-reset/' + route, {method: 'POST', headers: {'Content-Type': 'application/json', 'Content-Length': String(Buffer.byteLength(body))}, body});
    expect(response.status).toBe(413);
  }
});

test('recovery limits reset after expiry and fail closed when capacity is exhausted', () => {
  const limiter = new FixedWindowLimiter(2, 100, 2);
  expect(limiter.take('a', 0)).toBe(true);
  expect(limiter.take('a', 1)).toBe(true);
  expect(limiter.take('a', 2)).toBe(false);
  expect(limiter.take('b', 3)).toBe(true);
  expect(limiter.take('new', 4)).toBe(false);
  expect(limiter.take('new', 104)).toBe(true);
  expect(limiter.take('a', 104)).toBe(true);
});

test('forwarding headers cannot change quota identity unless the actual peer is trusted', () => {
  expect(clientAddress('192.0.2.1', '198.51.100.2', '')).toBe('192.0.2.1');
  expect(clientAddress('192.0.2.1', '198.51.100.2', '192.0.2.1')).toBe('198.51.100.2');
  expect(clientAddress('192.0.2.1', 'forged,198.51.100.2', '192.0.2.1')).toBe('192.0.2.1');
  expect(clientAddress(undefined, '198.51.100.2', '')).toBe('unknown');
});

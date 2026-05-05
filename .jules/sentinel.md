## 2026-05-05 - Rate Limiting Auth Endpoints
**Vulnerability:** Missing rate limiting on sensitive authentication endpoints (login/register).
**Learning:** The application was vulnerable to brute-force and credential stuffing attacks due to lack of rate limiting on `/login` and `/register` endpoints.
**Prevention:** Always implement rate limiting on sensitive endpoints. Be cautious with IP detection; while `x-forwarded-for` is common, ensure a secure fallback (e.g., using `getConnInfo`) and avoid fallback mechanisms that generate a unique ID per request (like `crypto.randomUUID()`) as it bypasses the limiter completely. A static fallback like 'unknown-ip' is safer to prevent global bypass.

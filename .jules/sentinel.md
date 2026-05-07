## 2025-02-27 - [Information Disclosure in Error Response]
**Vulnerability:** The registration endpoint in `auth.controller.ts` was returning internal error details directly to the client via `error: String(error)` on a 500 status code.
**Learning:** This is a security anti-pattern because it can leak internal application state, database details, or stack traces to an attacker.
**Prevention:** Remove raw error strings from API responses. Instead, log the detailed error internally (`console.error`) and return a generic user-friendly error message (`registration failed`).

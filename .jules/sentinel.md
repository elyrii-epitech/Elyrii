## 2024-05-08 - [Medium] Prevent Information Leakage in Registration Error
**Vulnerability:** The registration endpoint in `elyrii_server/modules/auth/auth.controller.ts` includes `error: String(error)` in its 500 internal server error response.
**Learning:** Returning stringified internal errors to the client can leak stack traces, database schema details, or other sensitive internals, providing reconnaissance material to an attacker.
**Prevention:** Catch blocks should log the detailed error internally but only return a generic error message (e.g., 'registration failed') to the client without exposing the underlying `error` object.

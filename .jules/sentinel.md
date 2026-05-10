
## 2026-05-10 - Insecure WebSocket Authentication Fallback Default
**Vulnerability:** Chat WebSocket endpoint allowed unauthorized connection and impersonation by using a `?userId=<id>` query parameter fallback that defaulted to `true` globally.
**Learning:** Hardcoded boolean fallbacks for ease of development can inadvertently introduce authentication bypasses in production. Environmental context (`NODE_ENV`) should be strictly enforced to determine fallback availability.
**Prevention:** Always default development-only authentication bypasses or fallbacks to `process.env.NODE_ENV !== "production"` rather than raw `true` values.

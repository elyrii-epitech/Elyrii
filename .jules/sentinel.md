## 2025-05-06 - Insecure WebSocket User Impersonation
**Vulnerability:** The WebSocket endpoint for the chat service allowed connections to bypass JWT authentication by supplying a `userId` query parameter. This insecure fallback was enabled globally by default, allowing attackers to impersonate any user in production.
**Learning:** Development convenience features (like insecure auth fallbacks) must never default to true globally. Relying on explicit disable flags (`ALLOW_INSECURE_WS_USER_ID === "false"`) is dangerous as missing environment variables lead to insecure defaults.
**Prevention:** Always default development backdoors to `false` in production by checking `process.env.NODE_ENV !== "production"`.

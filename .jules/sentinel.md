## 2024-05-09 - Remove error leakage on registration
**Vulnerability:** Error string (`String(error)`) from registration exception was being returned in 500 error response.
**Learning:** Application error handling occasionally leaked details to clients while correctly logging them internally.
**Prevention:** Avoid returning raw exception objects or stack trace strings in `ctx.json` across all endpoints; ensure generic fallback messages are used.

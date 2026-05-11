## 2025-05-11 - [Raw Errors in HTTP Responses]
**Vulnerability:** Information Disclosure
**Learning:** Found stringified errors (`String(error)`) being directly sent to the client in HTTP responses, like `return ctx.json({ error: String(error) }, 500);` during user registration. This exposes internal stack traces or database errors to end users, presenting an information disclosure vulnerability.
**Prevention:** Avoid stringifying errors and returning them in HTTP responses. Always log raw errors internally (`console.error(...)`) and return a generic error message, such as `Registration failed`, to the client instead. When rethrowing errors in repositories, simply throw `error` instead of `new Error(String(error))` to ensure the original error structure isn't lost.

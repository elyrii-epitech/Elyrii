## 2024-05-04 - [Information Disclosure]

**Vulnerability:** The registration endpoint in `auth.controller.ts` was leaking error objects (`String(error)`) directly back to the user upon a registration failure.

**Learning:** Internal exceptions (such as database unique constraint failures, networking stack errors, or misconfigurations) should not be leaked to clients as they can reveal underlying schema structure, stack trace hints, and database software versions, enabling further attacks.

**Prevention:** Ensure that all endpoints "fail securely" by separating internal logging (`console.error(...)` or structured logging tools) from external responses (`return ctx.json({ message: "Registration failed" }, 500);`). Never send the raw `error` object or its stringified version in the API response.

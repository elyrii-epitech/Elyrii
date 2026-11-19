import { Hono } from "hono";
import { bodyLimit } from "hono/body-limit";
import { z } from "zod";
import { authMiddleware } from "../../middleware/auth.middleware";
import type { HonoEnv } from "../../utils/hono.types";
import { ContextLifecycleRepository } from "../../repository/context-lifecycle.repository";
import { ContextAccessError, ContextConflictError } from "../../repository/context.repository";

export function createContextRouter(repository = new ContextLifecycleRepository()) {
    const router = new Hono<HonoEnv>();
    router.use("*", authMiddleware, bodyLimit({ maxSize: 50000 }));
    router.use("*", async (c, next) => { c.header("Cache-Control", "no-store"); await next(); });
    router.onError((error, c) => {
        if (error instanceof z.ZodError || error instanceof SyntaxError) return c.json({ error: "Invalid context request" }, 400);
        if (error instanceof ContextAccessError) return c.json({ error: "Context unavailable" }, 404);
        if (error instanceof ContextConflictError) return c.json({ error: "Context is no longer active" }, 409);
        // Never log request bodies, source text, SQL parameters, or exception details.
        console.error("[Context] Management operation failed");
        return c.json({ error: "Context operation failed" }, 500);
    });
    for (const kind of ["facts", "memories"] as const) {
        router.get(`/${kind}`, async c => c.json(await repository.list(c.get("user").userId, kind, c.req.query())));
        router.patch(`/${kind}/:id`, async c => c.json(await repository.correct(c.get("user").userId, kind, c.req.param("id"), await c.req.json())));
        router.delete(`/${kind}/:id`, async c => { await repository.forget(c.get("user").userId, kind, c.req.param("id")); return c.body(null, 204); });
    }
    router.delete("/all", async c => { await repository.forgetAll(c.get("user").userId); return c.body(null, 204); });
    router.delete("/messages/:id", async c => { await repository.deleteMessages(c.get("user").userId, { messageId: c.req.param("id") }); return c.body(null, 204); });
    router.delete("/conversations/:id", async c => { await repository.deleteMessages(c.get("user").userId, { conversationId: c.req.param("id") }); return c.body(null, 204); });
    return router;
}

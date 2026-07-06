import { createFactory } from "hono/factory";
import { describeRoute } from "hono-openapi";
import { sValidator } from "@hono/standard-validator";
import { z } from "zod";
import type { HonoEnv } from "../../utils/hono.types";
import CoachRepository from "../../repository/coach.repository";
import CoachLogic from "./coach.logic";
import UserRepository from "../../repository/user.repository";

class CoachController {
    private readonly factory = createFactory<HonoEnv>();
    private readonly coachRepository = new CoachRepository();
    private readonly coachLogic = new CoachLogic();
    private readonly userRepository = new UserRepository();

    public readonly getSessions = this.factory.createHandlers(
        describeRoute({
            summary: "Get Coach Sessions",
            description: "Retrieve coaching sessions for the authenticated user.",
            tags: ["Coach"],
            responses: { 200: { description: "List of coaching sessions" } },
        }),
        async (ctx) => {
            const userId = ctx.get("user").userId;
            const limitRaw = ctx.req.query("limit");
            const limit = Math.min(Math.max(Number(limitRaw || 20), 1), 100);
            const sessions = await this.coachRepository.getSessions(userId, limit);
            return ctx.json(sessions, 200);
        }
    );

    public readonly createSession = this.factory.createHandlers(
        describeRoute({
            summary: "Create Coach Session",
            description: "Generate and store a coaching response for the authenticated user.",
            tags: ["Coach"],
            responses: {
                201: { description: "Session created" },
                400: { description: "Invalid request" },
            },
        }),
        sValidator("json", z.object({
            prompt: z.string().min(3),
            context: z.record(z.string(), z.any()).optional(),
        })),
        async (ctx) => {
            const userId = ctx.get("user").userId;
            const body = ctx.req.valid("json");
            const generated = await this.coachLogic.generateResponse(userId, body.prompt);

            const session = await this.coachRepository.createSession({
                userId,
                prompt: body.prompt,
                response: generated.response,
                context: {
                    ...generated.context,
                    ...(body.context ?? {}),
                },
            });
            this.userRepository.touchActivity(userId).catch(() => {});

            return ctx.json(session, 201);
        }
    );
}

export default CoachController;

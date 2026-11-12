import { createFactory } from "hono/factory";
import { describeRoute } from "hono-openapi";
import { sValidator } from "@hono/standard-validator";
import { z } from "zod";
import type { HonoEnv } from "../../utils/hono.types";
import MeditationRepository from "../../repository/meditation.repository";
import { getMeditationProgramById, MEDITATION_PROGRAMS } from "./meditation.catalog";
import UserRepository from "../../repository/user.repository";
import type {Context} from "hono";
import {completeMeditationSchema, MeditationRequestError, startMeditationSchema} from "./meditation.contracts";

class MeditationController {
    private readonly factory = createFactory<HonoEnv>();
    private readonly meditationRepository = new MeditationRepository();
    private readonly userRepository = new UserRepository();

    private failure(ctx: Context<HonoEnv>, error: unknown) {
        if (error instanceof MeditationRequestError) return ctx.json({error: error.message}, error.status);
        console.error("[Meditation] Request failed");
        return ctx.json({error: "Meditation temporarily unavailable"}, 500);
    }

    public readonly getSessions = this.factory.createHandlers(
        describeRoute({
            summary: "Get Meditation Sessions",
            description: "Retrieve meditation sessions for the authenticated user.",
            tags: ["Meditation"],
            responses: { 200: { description: "List of sessions" } },
        }),
        sValidator("query", z.object({limit: z.coerce.number().int().min(1).max(100).default(50)})),
        async (ctx) => {
            const userId = ctx.get("user").userId;
            ctx.header("Cache-Control", "no-store");
            try {
                return ctx.json(await this.meditationRepository.listSessions(userId, ctx.req.valid("query").limit), 200);
            } catch (error) { return this.failure(ctx, error); }
        }
    );

    public readonly getCatalog = this.factory.createHandlers(
        describeRoute({
            summary: "Get Meditation Catalog",
            description: "Retrieve available guided meditation programs.",
            tags: ["Meditation"],
            responses: { 200: { description: "Catalog of guided meditations" } },
        }),
        async (ctx) => {
            return ctx.json(MEDITATION_PROGRAMS, 200);
        }
    );

    public readonly startSession = this.factory.createHandlers(
        describeRoute({
            summary: "Start Meditation Session",
            description: "Start a guided meditation session.",
            tags: ["Meditation"],
            responses: {
                201: { description: "Session started" },
                400: { description: "Invalid payload" },
                409: { description: "Session identifier already used" },
            },
        }),
        sValidator("json", startMeditationSchema),
        async (ctx) => {
            const userId = ctx.get("user").userId;
            const body = ctx.req.valid("json");
            const program = getMeditationProgramById(body.type);

            if (!program) {
                return ctx.json({ error: "Unknown meditation program type" }, 400);
            }
            if (program.minDurationMinutes == null && body.durationMinutes !== program.durationMinutes) {
                return ctx.json({ error: "Duration does not match selected meditation program" }, 400);
            }

            try {
                const session = await this.meditationRepository.startSession({
                    id: body.clientSessionId,
                    userId,
                    type: body.type,
                    durationMinutes: body.durationMinutes,
                    moodBefore: body.moodBefore,
                });
                return ctx.json(session, 201);
            } catch (error) { return this.failure(ctx, error); }
        }
    );

    public readonly completeSession = this.factory.createHandlers(
        describeRoute({
            summary: "Complete Meditation Session",
            description: "Mark a meditation session as completed.",
            tags: ["Meditation"],
            responses: {
                200: { description: "Session completed" },
                404: { description: "Session not found" },
                409: { description: "Session was canceled" },
            },
        }),
        sValidator("param", z.object({sessionId: z.uuid()})),
        sValidator("json", completeMeditationSchema),
        async (ctx) => {
            const userId = ctx.get("user").userId;
            const sessionId = ctx.req.param("sessionId");
            if (!sessionId) {
                return ctx.json({ error: "Session ID is required" }, 400);
            }
            const body = ctx.req.valid("json");

            try {
                const updated = await this.meditationRepository.completeSession(sessionId, userId, {
                    notes: body.notes,
                    moodBefore: body.moodBefore,
                    moodAfter: body.moodAfter,
                    endedAt: body.endedAt ? new Date(body.endedAt) : undefined,
                });
                await this.userRepository.touchActivity(userId).catch(() => console.warn("[Meditation] Activity refresh deferred"));
                return ctx.json(updated, 200);
            } catch (error) {
                return this.failure(ctx, error);
            }
        }
    );

    public readonly cancelSession = this.factory.createHandlers(
        describeRoute({
            summary: "Cancel Meditation Session",
            description: "Cancel a meditation session.",
            tags: ["Meditation"],
            responses: {
                200: { description: "Session canceled" },
                404: { description: "Session not found" },
                409: { description: "Session was completed" },
            },
        }),
        sValidator("param", z.object({sessionId: z.uuid()})),
        async (ctx) => {
            const userId = ctx.get("user").userId;
            const sessionId = ctx.req.param("sessionId");
            if (!sessionId) {
                return ctx.json({ error: "Session ID is required" }, 400);
            }

            try {
                const updated = await this.meditationRepository.cancelSession(sessionId, userId);
                return ctx.json(updated, 200);
            } catch (error) {
                return this.failure(ctx, error);
            }
        }
    );
}

export default MeditationController;

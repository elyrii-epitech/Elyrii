import { createFactory } from "hono/factory";
import { describeRoute } from "hono-openapi";
import { sValidator } from "@hono/standard-validator";
import { z } from "zod";
import type { HonoEnv } from "../../utils/hono.types";
import MeditationRepository from "../../repository/meditation.repository";
import { getMeditationProgramById, MEDITATION_PROGRAMS } from "./meditation.catalog";
import UserRepository from "../../repository/user.repository";

class MeditationController {
    private readonly factory = createFactory<HonoEnv>();
    private readonly meditationRepository = new MeditationRepository();
    private readonly userRepository = new UserRepository();

    public readonly getSessions = this.factory.createHandlers(
        describeRoute({
            summary: "Get Meditation Sessions",
            description: "Retrieve meditation sessions for the authenticated user.",
            tags: ["Meditation"],
            responses: { 200: { description: "List of sessions" } },
        }),
        async (ctx) => {
            const userId = ctx.get("user").userId;
            const limitRaw = ctx.req.query("limit");
            const limit = Math.min(Math.max(Number(limitRaw || 50), 1), 100);
            const sessions = await this.meditationRepository.listSessions(userId, limit);
            return ctx.json(sessions, 200);
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
            },
        }),
        sValidator("json", z.object({
            type: z.string().min(1),
            durationMinutes: z.number().int().positive().max(180),
            moodBefore: z.string().optional(),
        })),
        async (ctx) => {
            const userId = ctx.get("user").userId;
            const body = ctx.req.valid("json");
            const program = getMeditationProgramById(body.type);

            if (!program) {
                return ctx.json({ error: "Unknown meditation program type" }, 400);
            }
            if (body.durationMinutes !== program.durationMinutes) {
                return ctx.json({ error: "Duration does not match selected meditation program" }, 400);
            }

            const session = await this.meditationRepository.startSession({
                userId,
                type: body.type,
                durationMinutes: body.durationMinutes,
                moodBefore: body.moodBefore,
            });
            return ctx.json(session, 201);
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
            },
        }),
        sValidator("json", z.object({
            notes: z.string().max(5000).optional(),
            moodBefore: z.string().optional(),
            moodAfter: z.string().optional(),
            endedAt: z.string().datetime().optional(),
        })),
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
                this.userRepository.touchActivity(userId).catch(() => {});
                return ctx.json(updated, 200);
            } catch (error) {
                return ctx.json({ error: "Meditation session not found" }, 404);
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
            },
        }),
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
                return ctx.json({ error: "Meditation session not found" }, 404);
            }
        }
    );
}

export default MeditationController;

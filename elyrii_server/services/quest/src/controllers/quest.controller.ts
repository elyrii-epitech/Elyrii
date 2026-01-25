import { createFactory } from "hono/factory";
import QuestRepository from "../repository/quest.repository";
import type { HonoEnv } from "../utils/hono.types";
import { z } from "zod";
import { sValidator } from "@hono/standard-validator";

class QuestController {
    private readonly factory = createFactory<HonoEnv>();
    private readonly questRepository: QuestRepository = new QuestRepository();

    public readonly getActiveChallenges = this.factory.createHandlers(async (ctx) => {
        const userId = ctx.get("user").userId;
        const challenges = await this.questRepository.getUserChallenges(userId, 'ACTIVE');
        return ctx.json(challenges);
    });

    public readonly getCompletedChallenges = this.factory.createHandlers(async (ctx) => {
        const userId = ctx.get("user").userId;
        const challenges = await this.questRepository.getUserChallenges(userId, 'COMPLETED');
        return ctx.json(challenges);
    });

    public readonly getPendingChallenges = this.factory.createHandlers(async (ctx) => {
        const userId = ctx.get("user").userId;
        const challenges = await this.questRepository.getUserChallenges(userId, 'PENDING');
        return ctx.json(challenges);
    });

    public readonly acceptChallenge = this.factory.createHandlers(async (ctx) => {
        const challengeId = ctx.req.param("challengeId");
        if (!challengeId) {
            return ctx.json({ error: "Challenge ID is required" }, 400);
        }
        // Verify ownership/existence would be good here, assuming repo handles basic checks or we add logic
        try {
            const updated = await this.questRepository.updateUserChallengeStatus(challengeId, 'ACTIVE');
            return ctx.json(updated);
        } catch (e) {
            return ctx.json({ error: "Failed to accept challenge" }, 500);
        }
    });

    public readonly rejectChallenge = this.factory.createHandlers(async (ctx) => {
        const challengeId = ctx.req.param("challengeId");
        if (!challengeId) {
            return ctx.json({ error: "Challenge ID is required" }, 400);
        }
        try {
            const updated = await this.questRepository.updateUserChallengeStatus(challengeId, 'REJECTED');
            return ctx.json(updated);
        } catch (e) {
            return ctx.json({ error: "Failed to reject challenge" }, 500);
        }
    });

    // Internal endpoint for AI to propose challenges
    public readonly createProposal = this.factory.createHandlers(
        sValidator("json", z.object({
            title: z.string(),
            description: z.string().optional(),
            conditions: z.any(),
            aggregator: z.enum(['ALL', 'ANY']).default('ALL'),
            constraints: z.any(),
            userId: z.string().uuid()
        })),
        async (ctx) => {
            const body = ctx.req.valid("json");
            
            // 1. Create Template
            const template = await this.questRepository.createChallengeTemplate({
                title: body.title,
                description: body.description,
                source: 'AI',
                conditions: body.conditions,
                aggregator: body.aggregator,
                constraints: body.constraints
            });

            // 2. Assign to User as PENDING
            const userChallenge = await this.questRepository.assignChallengeToUser({
                userId: body.userId,
                challengeId: template.id,
                status: 'PENDING',
                progress: {}
            });

            return ctx.json({ template, userChallenge }, 201);
        }
    );
}

export default QuestController;

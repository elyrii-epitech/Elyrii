import { Hono } from "hono";
import { openAPIRouteHandler } from "hono-openapi";
import { swaggerUI } from "@hono/swagger-ui";
import type { HonoEnv } from "../../utils/hono.types";
import QuestController from "./quest.controller";
import { authMiddleware } from "../../middleware/auth.middleware";

class QuestRoutes {
    private readonly router = new Hono<HonoEnv>();
    private readonly questController = new QuestController();
    
    constructor() {
        this.initRoutes();
    }
    
    private initRoutes() {
        this.router.get("/health", (c) => c.text("Quest Service Healthy"));
        
        // Protect remaining routes with auth middleware
        this.router.use("*", authMiddleware);

        // Défis disponibles (SYSTEM, non commencés)
        this.router.get("/available", ...this.questController.getAvailableChallenges);
        this.router.post("/available/:challengeId/start", ...this.questController.startChallenge);

        // Défis en cours et terminés
        this.router.get("/list", ...this.questController.listChallenges);
        this.router.get("/active", ...this.questController.getActiveChallenges);
        this.router.get("/completed", ...this.questController.getCompletedChallenges);

        // Propositions IA (PENDING)
        this.router.get("/proposals", ...this.questController.getPendingChallenges);
        this.router.post("/proposals", ...this.questController.createProposal);
        this.router.post("/proposals/:challengeId/accept", ...this.questController.acceptChallenge);
        this.router.post("/proposals/:challengeId/reject", ...this.questController.rejectChallenge);
    }
    
    get getRouter() {
        return this.router;
    }
}

export default QuestRoutes;

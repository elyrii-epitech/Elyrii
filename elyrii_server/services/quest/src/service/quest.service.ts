import { Hono } from "hono";
import { openAPIRouteHandler } from "hono-openapi";
import { swaggerUI } from "@hono/swagger-ui";
import QuestController from "../controllers/quest.controller";
import type { HonoEnv } from "../utils/hono.types";
import { authMiddleware } from "../middleware/auth.middleware";

class QuestService {
    private readonly router = new Hono<HonoEnv>().basePath("/challenge");
    private readonly questController = new QuestController();
    
    constructor() {
        // Protect all routes with auth middleware
        this.router.use("*", authMiddleware);
        this.initRoutes();
    }
    
    private initRoutes() {
        this.router.get("/health", (c) => c.text("Quest Service Healthy"));

        // User facing
        this.router.get("/active", ...this.questController.getActiveChallenges);
        this.router.get("/completed", ...this.questController.getCompletedChallenges);
        
        // Proposals (AI Generated)
        this.router.get("/proposals", ...this.questController.getPendingChallenges);
        this.router.post("/proposals", ...this.questController.createProposal); // AI calls this? Or user requesting one?
        this.router.post("/proposals/:challengeId/accept", ...this.questController.acceptChallenge);
        this.router.post("/proposals/:challengeId/reject", ...this.questController.rejectChallenge);

        this.router.get("/openapi.json", openAPIRouteHandler(this.router, {
            documentation: {
                info: {
                    title: "Elyrii Quest Service",
                    version: "1.0.0",
                    description: "Quest and Challenge service API"
                },
                servers: [
                    {
                        url: Bun.env.QUEST_SERVICE_PUBLIC_URL ?? "http://localhost:3004/",
                        description: "Local development server"
                    }
                ]
            }
        }));

        this.router.get("/swagger", swaggerUI({
            url: "/challenge/openapi.json"
        }));
    }
    
    get getRouter() {
        return this.router;
    }
}

export default QuestService;
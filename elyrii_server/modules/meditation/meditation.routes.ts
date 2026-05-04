import { Hono } from "hono";
import type { HonoEnv } from "../../utils/hono.types";
import { authMiddleware } from "../../middleware/auth.middleware";
import MeditationController from "./meditation.controller";

class MeditationRoutes {
    private readonly router = new Hono<HonoEnv>();
    private readonly meditationController = new MeditationController();

    constructor() {
        this.initRoutes();
    }

    private initRoutes() {
        this.router.get("/health", (c) => c.text("Meditation Service Healthy"));
        this.router.use("*", authMiddleware);

        this.router.get("/sessions", ...this.meditationController.getSessions);
        this.router.post("/sessions/start", ...this.meditationController.startSession);
        this.router.post("/sessions/:sessionId/complete", ...this.meditationController.completeSession);
        this.router.post("/sessions/:sessionId/cancel", ...this.meditationController.cancelSession);
    }

    get getRouter() {
        return this.router;
    }
}

export default MeditationRoutes;

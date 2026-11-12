import { Hono } from "hono";
import type { HonoEnv } from "../../utils/hono.types";
import { authMiddleware } from "../../middleware/auth.middleware";
import CoachController from "./coach.controller";
import CoachJourneyController from "./coach.journey-controller";

class CoachRoutes {
    private readonly router = new Hono<HonoEnv>();
    private readonly coachController = new CoachController();
    private readonly journeys = new CoachJourneyController();

    constructor() {
        this.initRoutes();
    }

    private initRoutes() {
        this.router.get("/health", (c) => c.text("Coach Service Healthy"));
        this.router.use("*", authMiddleware);

        this.router.get("/sessions", ...this.coachController.getSessions);
        this.router.post("/sessions", ...this.coachController.createSession);
        this.router.get("/catalog", ...this.journeys.catalog);
        this.router.get("/journey", ...this.journeys.current);
        this.router.post("/journey/choose", ...this.journeys.choose);
        this.router.post("/journey/import", ...this.journeys.importLocal);
        this.router.post("/journey/pause", ...this.journeys.pause);
        this.router.post("/journey/resume", ...this.journeys.resume);
        this.router.post("/journey/steps/:stepId/complete", ...this.journeys.complete);
    }

    get getRouter() {
        return this.router;
    }
}

export default CoachRoutes;

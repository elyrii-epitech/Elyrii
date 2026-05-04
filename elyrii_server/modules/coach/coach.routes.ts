import { Hono } from "hono";
import type { HonoEnv } from "../../utils/hono.types";
import { authMiddleware } from "../../middleware/auth.middleware";
import CoachController from "./coach.controller";

class CoachRoutes {
    private readonly router = new Hono<HonoEnv>();
    private readonly coachController = new CoachController();

    constructor() {
        this.initRoutes();
    }

    private initRoutes() {
        this.router.get("/health", (c) => c.text("Coach Service Healthy"));
        this.router.use("*", authMiddleware);

        this.router.get("/sessions", ...this.coachController.getSessions);
        this.router.post("/sessions", ...this.coachController.createSession);
    }

    get getRouter() {
        return this.router;
    }
}

export default CoachRoutes;

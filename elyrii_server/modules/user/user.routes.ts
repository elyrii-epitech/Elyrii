import { Hono } from "hono";
import UserController from "./user.controller";
import { authMiddleware } from "../../middleware/auth.middleware";
import type { HonoEnv } from "../../utils/hono.types";

class UserRoutes {
    private readonly router = new Hono<HonoEnv>();
    private readonly userController = new UserController();

    constructor() {
        this.initRoutes();
    }

    private initRoutes() {
        this.router.get("/health", (c) => c.text("User Service Healthy"));
        this.router.use("*", authMiddleware);
        this.router.get("/me", ...this.userController.getMe);
        this.router.put("/me", ...this.userController.updateMe);
        this.router.post("/avatar", ...this.userController.uploadAvatar);
        this.router.get("/dashboard", ...this.userController.getDashboard);
        this.router.get("/settings", ...this.userController.getSettings);
        this.router.put("/settings", ...this.userController.updateSettings);
        this.router.get("/mascot", ...this.userController.getMascot);
        this.router.put("/mascot", ...this.userController.updateMascot);
        this.router.put("/account/password", ...this.userController.changePassword);
        this.router.delete("/account", ...this.userController.deleteAccount);
        this.router.post("/mood", ...this.userController.logMood);
        this.router.get("/mood/latest", ...this.userController.getLatestMood);
        this.router.get("/stats", ...this.userController.getStats);
    }

    get getRouter() {
        return this.router;
    }
}

export default UserRoutes;

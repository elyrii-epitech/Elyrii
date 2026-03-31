import { Hono } from "hono";
import UserController from "./user.controller";
import { authMiddleware } from "../../middleware/auth.middleware";
import type { HonoEnv } from "../../utils/hono.types";

class UserRoutes {
    private readonly router = new Hono<HonoEnv>().basePath("/user");
    private readonly userController = new UserController();

    constructor() {
        this.router.use("*", authMiddleware);
        this.initRoutes();
    }

    private initRoutes() {
        this.router.get("/health", (c) => c.text("User Service Healthy"));
        this.router.get("/me", ...this.userController.getMe);
        this.router.put("/me", ...this.userController.updateMe);
    }

    get getRouter() {
        return this.router;
    }
}

export default UserRoutes;

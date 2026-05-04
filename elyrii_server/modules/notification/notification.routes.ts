import { Hono } from "hono";
import type { HonoEnv } from "../../utils/hono.types";
import { authMiddleware } from "../../middleware/auth.middleware";
import NotificationController from "./notification.controller";

class NotificationRoutes {
    private readonly router = new Hono<HonoEnv>();
    private readonly notificationController = new NotificationController();

    constructor() {
        this.initRoutes();
    }

    private initRoutes() {
        this.router.get("/health", (c) => c.text("Notification Service Healthy"));
        this.router.use("*", authMiddleware);

        this.router.get("/", ...this.notificationController.listNotifications);
        this.router.post("/read-all", ...this.notificationController.markAllAsRead);
        this.router.post("/:notificationId/read", ...this.notificationController.markAsRead);
    }

    get getRouter() {
        return this.router;
    }
}

export default NotificationRoutes;

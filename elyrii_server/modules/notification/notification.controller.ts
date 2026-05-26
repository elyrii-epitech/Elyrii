import { createFactory } from "hono/factory";
import { describeRoute } from "hono-openapi";
import type { HonoEnv } from "../../utils/hono.types";
import NotificationRepository from "../../repository/notification.repository";

class NotificationController {
    private readonly factory = createFactory<HonoEnv>();
    private readonly notificationRepository = new NotificationRepository();

    readonly listNotifications = this.factory.createHandlers(
        describeRoute({
            summary: "List Notifications",
            description: "Retrieve notifications for authenticated user.",
            tags: ["Notification"],
            responses: { 200: { description: "List of notifications" } },
        }),
        async (ctx) => {
            const userId = ctx.get("user").userId;
            const limit = Math.min(Math.max(Number(ctx.req.query("limit") || 50), 1), 200);
            const notifications = await this.notificationRepository.listUserNotifications(userId, limit);
            return ctx.json(notifications, 200);
        }
    );

    readonly markAsRead = this.factory.createHandlers(
        describeRoute({
            summary: "Mark Notification as Read",
            description: "Mark one notification as read.",
            tags: ["Notification"],
            responses: { 200: { description: "Notification updated" }, 404: { description: "Not found" } },
        }),
        async (ctx) => {
            const userId = ctx.get("user").userId;
            const id = ctx.req.param("notificationId");
            if (!id) {
                return ctx.json({ error: "Notification ID is required" }, 400);
            }
            const updated = await this.notificationRepository.markAsRead(userId, id);
            if (!updated) {
                return ctx.json({ error: "Notification not found" }, 404);
            }
            return ctx.json({ message: "Notification marked as read" }, 200);
        }
    );

    readonly markAllAsRead = this.factory.createHandlers(
        describeRoute({
            summary: "Mark All Notifications as Read",
            description: "Mark all user notifications as read.",
            tags: ["Notification"],
            responses: { 200: { description: "Notifications updated" } },
        }),
        async (ctx) => {
            const userId = ctx.get("user").userId;
            const updatedCount = await this.notificationRepository.markAllAsRead(userId);
            return ctx.json({ updatedCount }, 200);
        }
    );
}

export default NotificationController;

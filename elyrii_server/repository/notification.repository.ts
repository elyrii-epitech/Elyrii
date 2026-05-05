import { and, desc, eq } from "drizzle-orm";
import { db } from "../config/db.config";
import { notificationsTable, type NewNotification, type Notification } from "../config/db/notification.table";

class NotificationRepository {
    async createNotification(data: NewNotification): Promise<Notification> {
        const [notification] = await db.insert(notificationsTable).values(data).returning();
        if (!notification) {
            throw new Error("Failed to create notification");
        }
        return notification;
    }

    async listUserNotifications(userId: string, limit = 50): Promise<Notification[]> {
        return db
            .select()
            .from(notificationsTable)
            .where(eq(notificationsTable.userId, userId))
            .orderBy(desc(notificationsTable.createdAt))
            .limit(limit);
    }

    async markAsRead(userId: string, notificationId: string): Promise<boolean> {
        const [updated] = await db
            .update(notificationsTable)
            .set({
                isRead: true,
                readAt: new Date(),
            })
            .where(and(
                eq(notificationsTable.userId, userId),
                eq(notificationsTable.id, notificationId),
            ))
            .returning({ id: notificationsTable.id });
        return Boolean(updated);
    }

    async markAllAsRead(userId: string): Promise<number> {
        const updated = await db
            .update(notificationsTable)
            .set({
                isRead: true,
                readAt: new Date(),
            })
            .where(and(
                eq(notificationsTable.userId, userId),
                eq(notificationsTable.isRead, false),
            ))
            .returning({ id: notificationsTable.id });
        return updated.length;
    }
}

export default NotificationRepository;

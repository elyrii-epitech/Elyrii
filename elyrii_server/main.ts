import { Hono } from "hono";
import { cors } from "hono/cors";
import { logger } from "hono/logger";
import AuthRoutes from "./modules/auth/auth.routes";
import JournalRoutes from "./modules/journal/journal.routes";
import UserRoutes from "./modules/user/user.routes";
import QuestRoutes from "./modules/quest/quest.routes";
import CoachRoutes from "./modules/coach/coach.routes";
import MeditationRoutes from "./modules/meditation/meditation.routes";
import NotificationRoutes from "./modules/notification/notification.routes";
import type { WSContext } from "hono/ws";
import chatRouter from "./modules/chat/chat.controller";
import { initKafka } from "./config/kafka.config";
import { handleAiResponse } from "./modules/chat/consumer.service";
import { initQuestConsumers } from "./modules/quest/consumer.service";
import { openAPIRouteHandler } from "hono-openapi";
import { swaggerUI } from "@hono/swagger-ui";

export const clientSockets = new Map<string, WSContext>();
const AVATAR_UPLOAD_DIR = Bun.env.AVATAR_UPLOAD_DIR ?? "./uploads/avatars";

const app = new Hono()

const authRouter = new AuthRoutes();
const journalRouter = new JournalRoutes();
const userRouter = new UserRoutes();
const questRouter = new QuestRoutes();
const coachRouter = new CoachRoutes();
const meditationRouter = new MeditationRoutes();
const notificationRouter = new NotificationRoutes();
const corsOrigin = Bun.env.CORS_ORIGIN
    ? Bun.env.CORS_ORIGIN.split(",").map((o) => o.trim()).filter(Boolean)
    : "*";

console.log(`[Main] Starting Elyrii Server in ${Bun.env.NODE_ENV} mode`);
console.log(`[Main] CORS Origin: ${corsOrigin}`);

app.use(logger());
app.use("*", cors({
    origin: corsOrigin,
    allowMethods: ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allowHeaders: ["Content-Type", "Authorization", "Accept"],
    exposeHeaders: ["Content-Length"],
}));

app.get("/uploads/avatars/:filename", async (c) => {
    const filename = c.req.param("filename");
    if (!/^[a-zA-Z0-9_-]+-[0-9a-f-]+\.(jpg|png|webp|gif)$/.test(filename)) {
        return c.notFound();
    }

    const file = Bun.file(`${AVATAR_UPLOAD_DIR}/${filename}`);
    if (!(await file.exists())) {
        return c.notFound();
    }

    return new Response(file, {
        headers: {
            "Cache-Control": "public, max-age=31536000, immutable",
        },
    });
});

app.route("/auth", authRouter.Router);
app.route("/journal", journalRouter.getRouter);
app.route("/user", userRouter.getRouter);
app.route("/chat", chatRouter);
app.route("/challenge", questRouter.getRouter);
app.route("/coach", coachRouter.getRouter);
app.route("/meditation", meditationRouter.getRouter);
app.route("/notifications", notificationRouter.getRouter);

app.get("/openapi.json", openAPIRouteHandler(app, {
    documentation: {
        info: {
            title: "Elyrii API",
            version: "1.0.0",
            description: "Monolithic API for Elyrii."
        },
        servers: [
            {
                url: Bun.env.PUBLIC_URL ?? "http://localhost:3000",
                description: "API Server"
            }
        ]
    }
}));

app.get("/swagger", swaggerUI({
    url: "/openapi.json"
}));

const shouldEnableKafkaConsumers =
    Bun.env.ENABLE_KAFKA_CONSUMERS === "true" ||
    Bun.env.NODE_ENV === "production" ||
    Bun.env.NODE_ENV === "development"; // Enable by default in dev

console.log(`[Main] Kafka consumers enabled: ${shouldEnableKafkaConsumers}`);

// Initialize Kafka and consumers only when explicitly enabled.
if (shouldEnableKafkaConsumers) {
    initKafka()
        .then(() => {
            console.log("[Kafka] initialized");
            handleAiResponse().catch((err) => console.error("Failed to start Chat consumer", err));
            initQuestConsumers().catch((err) => console.error("Failed to start Quest consumer", err));
        })
        .catch((err) => {
            console.error("[Kafka] initialization failed:", err);
        });
}

export default app;

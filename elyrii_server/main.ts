import { Hono } from "hono";
import { cors } from "hono/cors";
import { logger } from "hono/logger";
import AuthRoutes from "./modules/auth/auth.routes";
import JournalRoutes from "./modules/journal/journal.routes";
import UserRoutes from "./modules/user/user.routes";
import QuestRoutes from "./modules/quest/quest.routes";
import type { WSContext } from "hono/ws";
import chatRouter from "./modules/chat/chat.controller";
import { initKafka } from "./config/kafka.config";
import { handleAiResponse } from "./modules/chat/consumer.service";
import { initQuestConsumers } from "./modules/quest/consumer.service";
import { openAPIRouteHandler } from "hono-openapi";
import { swaggerUI } from "@hono/swagger-ui";

export const clientSockets = new Map<string, WSContext>();

const app = new Hono()

const authRouter = new AuthRoutes();
const journalRouter = new JournalRoutes();
const userRouter = new UserRoutes();
const questRouter = new QuestRoutes();

app.use(logger());
app.use("*", cors({
    origin: "*",
    allowMethods: ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allowHeaders: ["Content-Type", "Authorization", "Accept"],
    exposeHeaders: ["Content-Length"],
}));

app.route("/auth", authRouter.Router);
app.route("/journal", journalRouter.getRouter);
app.route("/user", userRouter.getRouter);
app.route("/chat", chatRouter);
app.route("/challenge", questRouter.getRouter);

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
    Bun.env.NODE_ENV === "production";

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

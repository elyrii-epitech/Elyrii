import { Hono } from "hono";
import { cors } from "hono/cors";
import { logger } from "hono/logger";
import AuthRoutes from "./modules/auth/auth.routes";
import JournalRoutes from "./modules/journal/journal.routes";



const app = new Hono()

const authRouter = new AuthRoutes();
const journalRouter = new JournalRoutes();

app.use(logger());
app.use("*", cors({
    origin: "*",
    allowMethods: ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allowHeaders: ["Content-Type", "Authorization", "Accept"],
    exposeHeaders: ["Content-Length"],
    maxAge: 86400,
}));

app.route("/auth", authRouter.Router);
app.route("/journal", journalRouter.getRouter);

export default app;
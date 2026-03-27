import { Hono } from "hono";
import { openAPIRouteHandler } from "hono-openapi";
import { swaggerUI } from "@hono/swagger-ui";
import JournalController from "../controllers/journal.controller";
import type { HonoEnv } from "../utils/hono.types";
import { authMiddleware } from "../middleware/auth.middleware";

class JournalService {
    private readonly router = new Hono<HonoEnv>().basePath("/journal");
    private readonly journalController = new JournalController();
    
    constructor() {
        this.router.use("*", authMiddleware);
        this.initRoutes();
    }
    
    private initRoutes() {
        this.router.get("/health", (c) => c.text("Journal Service Healthy"));

        this.router.get("/", ...this.journalController.getEntries);
        this.router.get("/:entryId", ...this.journalController.getEntryById);
        this.router.post("/", ...this.journalController.createEntry);
        this.router.put("/:entryId", ...this.journalController.updateEntry);
        this.router.delete("/:entryId", ...this.journalController.deleteEntry);
        
        this.router.post("/:entryId/media", (c) => c.text("Add media to entry"));
        this.router.delete("/:entryId/media/:mediaId", (c) => c.text("Delete media from entry"));
        
        this.router.get("/tags", (c) => c.text("Get all tags"));
        this.router.post("/tags", (c) => c.text("Create tag"));
        this.router.put("/tags/:tagId", (c) => c.text("Update tag by ID"));
        this.router.delete("/tags/:tagId", (c) => c.text("Delete tag by ID"));

        this.router.get("/openapi.json", openAPIRouteHandler(this.router, {
            documentation: {
                info: {
                    title: "Elyrii Journal Service",
                    version: "1.0.0",
                    description: "Journaling service API"
                },
                servers: [
                    {
                        url: Bun.env.JOURNAL_SERVICE_PUBLIC_URL ?? "http://localhost:3003/",
                        description: "Local development server"
                    }
                ]
            }
        }));

        this.router.get("/swagger", swaggerUI({
            url: "/journal/openapi.json"
        }));
    }
    
    get getRouter() {
        return this.router;
    }
}

export default JournalService;

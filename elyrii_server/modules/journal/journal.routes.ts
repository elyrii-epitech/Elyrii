import { Hono } from "hono";
import { openAPIRouteHandler } from "hono-openapi";
import { swaggerUI } from "@hono/swagger-ui";

import type { HonoEnv } from "../../utils/hono.types";
import { authMiddleware } from "../../middleware/auth.middleware";
import JournalController from "./journal.controller";

class JournalRoutes {
    private readonly Router = new Hono<HonoEnv>();
    private readonly journalController = new JournalController();
    
    constructor() {
        this.initRoutes();
    }
    
    private initRoutes() {
        this.Router.get("/health", (c) => c.text("Journal Service Healthy"));
        this.Router.use("*", authMiddleware);

        this.Router.get("/", ...this.journalController.getEntries);
        this.Router.get("/:entryId", ...this.journalController.getEntryById);
        this.Router.post("/", ...this.journalController.createEntry);
        this.Router.put("/:entryId", ...this.journalController.updateEntry);
        this.Router.delete("/:entryId", ...this.journalController.deleteEntry);
        
        this.Router.post("/:entryId/media", (c) => c.text("Add media to entry"));
        this.Router.delete("/:entryId/media/:mediaId", (c) => c.text("Delete media from entry"));
        
        this.Router.get("/tags", (c) => c.text("Get all tags"));
        this.Router.post("/tags", (c) => c.text("Create tag"));
        this.Router.put("/tags/:tagId", (c) => c.text("Update tag by ID"));
        this.Router.delete("/tags/:tagId", (c) => c.text("Delete tag by ID"));

        this.Router.get("/openapi.json", openAPIRouteHandler(this.Router, {
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

        this.Router.get("/swagger", swaggerUI({
            url: "/journal/openapi.json"
        }));
    }
    
    get getRouter() {
        return this.Router;
    }
}

export default JournalRoutes;

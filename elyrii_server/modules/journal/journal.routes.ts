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

        this.Router.get("/tags", ...this.journalController.getTags);
        this.Router.post("/tags", ...this.journalController.createTag);
        this.Router.put("/tags/:tagId", ...this.journalController.updateTag);
        this.Router.delete("/tags/:tagId", ...this.journalController.deleteTag);

        this.Router.get("/", ...this.journalController.getEntries);
        this.Router.get("/:entryId/media", ...this.journalController.listMedia);
        this.Router.post("/:entryId/media", ...this.journalController.addMedia);
        this.Router.delete("/:entryId/media/:mediaId", ...this.journalController.deleteMedia);
        this.Router.get("/:entryId", ...this.journalController.getEntryById);
        this.Router.post("/", ...this.journalController.createEntry);
        this.Router.put("/:entryId", ...this.journalController.updateEntry);
        this.Router.delete("/:entryId", ...this.journalController.deleteEntry);

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

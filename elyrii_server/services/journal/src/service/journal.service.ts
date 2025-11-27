import { Hono } from "hono";
import JournalController from "../controllers/journal.controller";

class JournalService {
    private readonly router = new Hono().basePath("/journal");
    private readonly journalController = new JournalController();
    
    constructor() {
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
    }
    
    get getRouter() {
        return this.router;
    }
}

export default JournalService;

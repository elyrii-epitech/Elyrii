import { Hono } from "hono";

class JournalService {
    private readonly router = new Hono().basePath("/journal");
    
    constructor() {
        this.initRoutes();
    }
    
    private initRoutes() {
        this.router.get("/health", (c) => c.text("Journal Service Healthy"));


        this.router.get("/", (c) => c.text("Journal Service Root"));
        this.router.get("/:entryId", (c) => c.text("Get entry by ID"));
        this.router.post("/", (c) => c.text("Create journal entry"));
        this.router.put("/:entryId", (c) => c.text("Update entry by ID"));
        this.router.delete("/:entryId", (c) => c.text("Delete entry by ID"));
        
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

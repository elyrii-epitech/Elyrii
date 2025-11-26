import { Hono } from "hono";

class JournalService {
    private readonly router = new Hono().basePath("/journal");
    
    constructor() {
        this.initRoutes();
    }
    
    private initRoutes() {
        this.router.get("/health", (c) => c.text("Journal Service Healthy"));
    }
    
    get getRouter() {
        return this.router;
    }
}

export default JournalService;

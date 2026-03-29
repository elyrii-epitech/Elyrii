import { Hono } from "hono";
import { swaggerUI } from "@hono/swagger-ui";

class AuthRoutes {
    private readonly router = new Hono();
    
    constructor() {
        this.initRoutes();
    }
    
    public initRoutes() {
        this.router.get('/health', );
        
        this.router.post('/login',);
        this.router.post('/register', );
        this.router.post('/logout',);
        
        this.router.get("/openapi.json",);
        
        this.router.get("/swagger", swaggerUI({
            url: "/auth/openapi.json"
        }));
    }
    
    get Router() {
        return this.router;
    }
}

export default AuthRoutes;
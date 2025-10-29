import { Hono } from "hono";

class AuthService {
    private readonly router = new Hono().basePath("/auth");

    constructor() {
        
        this.router.get("/", (c) => c.text("Hello World"));
    }

    public getRouter() {
        return this.router;
    }
}

export default AuthService;
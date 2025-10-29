import { Hono } from "hono";
import AuthController from "./controller";

class AuthService {
    private readonly router = new Hono().basePath("/auth");
    private readonly controller = new AuthController();

    constructor() {
        this.router.post("/register", ...this.controller.register);
        this.router.post("/login", ...this.controller.login);
        this.router.post("/logout", ...this.controller.logout);
    }
    
    public getRouter() {
        return this.router;
    }
}

export default AuthService;
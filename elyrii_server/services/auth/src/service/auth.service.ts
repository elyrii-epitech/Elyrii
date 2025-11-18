import { Hono } from "hono";
import AuthController from "../controller/auth.controller";

class AuthService {
    private readonly app = new Hono().basePath("/auth");
    private readonly controller = new AuthController();

    constructor() {
        this.useMiddlewares();
        this.initRoutes();
    }

    useMiddlewares() {}

    initRoutes() {
        this.app.get("/health", (c) => c.text("Auth Service Healthy"));

        this.app.post("/login", ...this.controller.login);
        this.app.post("/logout", ...this.controller.logout);
        this.app.post("/register", ...this.controller.register);
    }

    get service() {
        return this.app;
    }
}

export default AuthService;
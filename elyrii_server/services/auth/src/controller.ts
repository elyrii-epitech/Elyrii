import { createFactory } from "hono/factory";

class AuthController {
    private readonly factory = createFactory();

    public register = this.factory.createHandlers(async (ctx) => {
        return ctx.json({ message: "Register" });
    });

    public login = this.factory.createHandlers(async (ctx) => {
        return ctx.json({ message: "Login" });
    });

    public logout = this.factory.createHandlers(async (ctx) => {
        return ctx.json({ message: "Logout" });
    });

}

export default AuthController;
import { createFactory } from "hono/factory";

class AuthController {
    private readonly factory = createFactory();

    readonly login = this.factory.createHandlers(async (ctx) => {
        return ctx.json({ message: "Login" });
    });

    readonly register = this.factory.createHandlers(async (ctx) => {
        return ctx.json({ message: "Register" });
    });

    readonly logout = this.factory.createHandlers(async (ctx) => {
        return ctx.json({ message: "Logout" });
    });
}

export default AuthController;

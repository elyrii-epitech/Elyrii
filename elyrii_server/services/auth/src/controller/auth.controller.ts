import { createFactory } from "hono/factory";
/**
 * Controller that defines HTTP handlers for authentication routes.
 */
class AuthController {
    private readonly factory = createFactory();

    /**
     * Handler for processing user login requests.
     */
    readonly login = this.factory.createHandlers(async (ctx) => {
        return ctx.json({ message: "Login" });
    });

    /**
     * Handler for processing new user registration requests.
     */
    readonly register = this.factory.createHandlers(async (ctx) => {
        return ctx.json({ message: "Register" });
    });

    /**
     * Handler for processing user logout requests.
     */
    readonly logout = this.factory.createHandlers(async (ctx) => {
        return ctx.json({ message: "Logout" });
    });
}

export default AuthController;

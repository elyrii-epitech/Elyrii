import { sValidator } from "@hono/standard-validator";
import { createFactory } from "hono/factory";
import { registerValidation } from "../utils/zod.valid";
import AuthRepository from "../repository/auth.repository";
import { generateAccessToken } from "../utils/jwt.utils";
/**
 * Controller that defines HTTP handlers for authentication routes.
 */
class AuthController {
    private readonly factory = createFactory();
    private readonly authRepository = new AuthRepository();
    /**
     * Handler for processing user login requests.
     */
    readonly login = this.factory.createHandlers(async (ctx) => {
        return ctx.json({ message: "Login" });
    });

    /**
     * Handler for processing new user registration requests.
     */
    readonly register = this.factory.createHandlers(
        sValidator("json", registerValidation),
        async (ctx) => {
            const { email, password, lastName, firstName, age } = ctx.req.valid("json");
            // TODO: Implement registration logic using authRepository
            try {
                const user = await this.authRepository.createUser({
                    email,
                    password,
                    lastName,
                    firstName,
                    age: age ?? 18,
                });
                //TODO: create the jwt logic here

                const tokenPayload = {
                    userId: user!.id,
                    email: user!.email
                };
                const token = await generateAccessToken(tokenPayload);
                return ctx.json({ message: "User registered successfully", token});
            } catch (error) {
                console.error("Registration error:", error);
                return ctx.json({ error: "Registration failed" }, 500);
            }
        }
    );

    /**
     * Handler for processing user logout requests.
     */
    readonly logout = this.factory.createHandlers(async (ctx) => {
        return ctx.json({ message: "Logout" });
    });
}

export default AuthController;

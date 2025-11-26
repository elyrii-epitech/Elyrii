import { sValidator } from "@hono/standard-validator";
import { createFactory } from "hono/factory";
import { loginValidation, registerValidation } from "../utils/zod.valid";
import AuthRepository from "../repository/auth.repository";
import {JwtUtils} from "../utils/jwt.utils";
import TokenRepository from "../repository/token.repository";
import { setCookie } from "hono/cookie";
/**
 * Controller that defines HTTP handlers for authentication routes.
 */
class AuthController {
    private readonly factory = createFactory();
    private readonly authRepository = new AuthRepository();
    private readonly tokenRepository = new TokenRepository();
    /**
     * Handler for processing user login requests.
     */
    readonly login = this.factory.createHandlers(sValidator("json", loginValidation), async (ctx) => {
        const { email, password } = ctx.req.valid("json");
        if (!email || !password) {
            return ctx.json({ error: "Invalid email or password" }, 400);
        }
        try {
            const user = await this.authRepository.getUserByEmail(email);
            if (!user || !user.password || !user.email) {
                return ctx.json({ error: "User not found" }, 404);
            }
            const isPasswordValid = await Bun.password.verify(password, user.password);
            if (!isPasswordValid) {
                return ctx.json({ error: "Invalid password" }, 401);
            }
            const tokenPayload = {
                userId: user.id,
                email: user.email
            };
            const [token, refreshToken] = await Promise.all([
                JwtUtils.generateAccessToken(tokenPayload),
                JwtUtils.generateRefreshToken(tokenPayload)
            ]);

            await this.tokenRepository.createToken(refreshToken, user.id, ctx.req.header("User-Agent") || "Unknown");
            setCookie(ctx, "refresh_token", refreshToken, {
                httpOnly: true,
                secure: true,
                sameSite: "lax",
                path: "/auth/refresh",
                maxAge: JwtUtils.REFRESH_TOKEN_EXP
            });
            return ctx.json({ message: "Login successful", token });
        } catch (error) {
            console.error("Login error:", error);
            return ctx.json({ error: "Login failed" }, 500);
        }
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
                const [token, refreshToken] = await Promise.all([
                    JwtUtils.generateAccessToken(tokenPayload),
                    JwtUtils.generateRefreshToken(tokenPayload)
                ]);
                await this.tokenRepository.createToken(refreshToken, user!.id, ctx.req.header("User-Agent") || "Unknown");
                return ctx.json({ message: "User registered successfully", token });
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
    

    /**
     * Handler for refreshing access tokens.
     */
    readonly refreshToken = this.factory.createHandlers(async (ctx) => {
        // TODO: Implement refresh token logic
        return ctx.json({ message: "Refresh token" });
    });

    /**
     * Handler for verifying access tokens.
     */
    readonly verifyToken = this.factory.createHandlers(async (ctx) => {
        // TODO: Implement token verification logic
        return ctx.json({ message: "Token verified" });
    });
}

export default AuthController;

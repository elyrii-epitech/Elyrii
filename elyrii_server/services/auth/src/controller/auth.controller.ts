import { sValidator } from "@hono/standard-validator";
import { createFactory } from "hono/factory";
import { loginValidation, registerValidation } from "../utils/zod.valid";
import AuthRepository from "../repository/auth.repository";
import {JwtUtils} from "../utils/jwt.utils";
import TokenRepository from "../repository/token.repository";
import { getCookie, setCookie } from "hono/cookie";
/**
 * Controller that defines HTTP handlers for authentication routes.
 * 
 * @remarks
 * This controller handles:
 * - User Registration
 * - User Login (Issue Access & Refresh Tokens)
 * - Token Refresh
 * - Logout
 */
class AuthController {
    private readonly factory = createFactory();
    private readonly authRepository = new AuthRepository();
    private readonly tokenRepository = new TokenRepository();

    /**
     * Handler for processing user login requests.
     * 
     * @remarks
     * Validates user credentials, generates an access token and a refresh token.
     * The refresh token is stored in an HTTP-only cookie and in the database.
     * 
     * @param ctx - Hono Context containing the JSON body { email, password }
     * @returns JSON response with access token or error message
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
     * 
     * @remarks
     * Creates a new user in the database and automatically logs them in by issuing tokens.
     * 
     * @param ctx - Hono Context containing the JSON body { email, password, lastName, firstName, age }
     * @returns JSON response with success message and access token
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
     * 
     * @remarks
     * In a full implementation, this should invalidate the refresh token in the database.
     * Currently returns a simple logout message.
     * 
     * @param ctx - Hono Context
     * @returns JSON response confirming logout
     */
    readonly logout = this.factory.createHandlers(async (ctx) => {
        return ctx.json({ message: "Logout" });
    });
    

    /**
     * Handler for refreshing access tokens.
     * 
     * @remarks
     * Uses the `refresh_token` HTTP-only cookie to issue a new access token.
     * Rotates the refresh token (issues a new one and invalidates the old one).
     * 
     * @param ctx - Hono Context containing the refresh_token cookie
     * @returns JSON response with new access token or error
     */
    readonly refreshToken = this.factory.createHandlers(async (ctx) => {
        // TODO: Implement refresh token logic
        const oldRefreshToken = getCookie(ctx, "refresh_token");
        if (!oldRefreshToken) {
            return ctx.json({ error: "Refresh token not found" }, 401);
        }
        const session = await this.tokenRepository.getTokenByToken(oldRefreshToken);
        if (!session) {
            return ctx.json({ error: "Invalid refresh token" }, 401);
        }

        let payload;
        try {
            payload = await JwtUtils.verifyRefreshToken(oldRefreshToken);
            if (!payload) {
                return ctx.json({ error: "Invalid refresh token" }, 401);
            }
        } catch (error) {
            return ctx.json({ error: "Invalid refresh token" }, 401);
        }

        const refreshToken = await JwtUtils.generateRefreshToken(payload);
        const newSession = await this.tokenRepository.updateToken(
            refreshToken,
            payload.userId,
            ctx.req.header("User-Agent") || "Unknown",
            session.id
        );
        if (!newSession) {
            return ctx.json({ error: "Invalid refresh token" }, 401);
        }

        setCookie(ctx, "refresh_token", refreshToken, {
            httpOnly: true,
            secure: true,
            sameSite: "lax",
            path: "/auth/refresh",
            maxAge: JwtUtils.REFRESH_TOKEN_EXP
        });

        const tokenPayload = {
            userId: payload.userId,
            email: payload.email
        };

        const token = await JwtUtils.generateAccessToken(tokenPayload);
        return ctx.json({ message: "Refresh token", token });
    });
}

export default AuthController;

import { sValidator } from '@hono/standard-validator';
import { zValidator } from '@hono/zod-validator';
import { describeRoute } from 'hono-openapi';
import { createFactory } from 'hono/factory';
import { loginValidation, registerValidation } from '../../utils/zod.valid';
import AuthRepository from '../../repository/auth.repository';
import { JwtUtils, type TokenPayload } from '../../utils/jwt.utils';
import TokenRepository from '../../repository/token.repository';
import { deleteCookie, getCookie, setCookie } from 'hono/cookie';

class AuthController {
    private readonly factory = createFactory();
    private readonly authRepository = new AuthRepository();
    private readonly tokenRepository = new TokenRepository();
    
    constructor() { }
    
    public readonly register = this.factory.createHandlers(
        describeRoute({
            summary: "User Registration",
            description: "Register a new user and automatically log them in.",
            tags: ["Auth"],
            responses: {
                200: { description: "User registered successfully" },
                400: { description: "User already exists" },
                500: { description: "Registration failed" },
            }
        }),
        zValidator("json", registerValidation),
        async (ctx) => {
            try {
                const { email, password, lastName, firstName } = ctx.req.valid("json");
                const existUser = await this.authRepository.findUserByEmail(email);
                if (existUser) {
                    return ctx.json({ message: 'user already exists' }, 400);
                }

                const newUser = await this.authRepository.createUser({
                    email,
                    password,
                    lastName,
                    firstName,
                    age: 18
                });
                
                if (!newUser) {
                    return ctx.json({ message: 'registration failed' }, 500);
                }
                const tokenPayload: TokenPayload = {
                    userId: newUser.id,
                    email: newUser.email
                }
                const [token, refreshToken] = await Promise.all([
                    JwtUtils.generateAccessToken(tokenPayload),
                    JwtUtils.generateRefreshToken(tokenPayload)
                ])
                await this.tokenRepository.createToken(refreshToken, newUser.id, ctx.req.header("User-Agent") || "unknown");
                
                setCookie(ctx, "refresh_token", refreshToken, {
                    httpOnly: true,
                    secure: process.env.NODE_ENV === "production",
                    sameSite: "lax",
                    maxAge: JwtUtils.REFRESH_TOKEN_EXP,
                    path: "/auth/refresh"
                });
                return ctx.json({ message: 'User registered successfully', token: token });
            } catch (error) {
                console.error("Registration error details:", error);
                return ctx.json({ message: 'registration failed', error: String(error) }, 500);
            }
    })
    
    public readonly login = this.factory.createHandlers(describeRoute({
        summary: "User Login",
        description: "Log in a user and receive an access token and refresh token.",
        tags: ["Auth"],
        responses: {
            200: { description: "Login successful" },
            400: { description: "Invalid credentials" },
            404: { description: "User not found" },
            500: { description: "Login failed" },
        }
        }), sValidator("json", loginValidation), async (ctx) => {
        const { email, password } = ctx.req.valid("json");
        if (!email || !password) {
            return ctx.json({ message: 'invalid credentials' }, 400);
        }
        
        try {
            const isUser = await this.authRepository.findUserByEmail(email);
            if (!isUser) {
                return ctx.json({ message: 'user not found' }, 404);
            }
            if (!await Bun.password.verify(password, isUser.password)) {
                return ctx.json({ message: 'invalid credentials' }, 401);
            }
            const tokenPayload: TokenPayload = {
                userId: isUser.id,
                email: isUser.email
            }
            const [token, refreshToken] = await Promise.all([
                JwtUtils.generateAccessToken(tokenPayload),
                JwtUtils.generateRefreshToken(tokenPayload)
            ])
            await this.tokenRepository.createToken(refreshToken, isUser.id, ctx.req.header("User-Agent") || "Unknown");
            setCookie(ctx, "refresh_token", refreshToken, { 
                httpOnly: true, 
                secure: process.env.NODE_ENV === "production", 
                sameSite: "lax", 
                path: "/auth/refresh",
                maxAge: JwtUtils.REFRESH_TOKEN_EXP
            });
            return ctx.json({ message: 'Login successful', token });
        } catch (error) {
            console.error("Login error:", error);
            return ctx.json({ message: 'login failed' }, 500);
        }
    })
    
    public readonly logout = this.factory.createHandlers(describeRoute({
        summary: "User Logout",
        description: "Log out the user (invalidate session).",
        tags: ["Auth"],
        responses: {
            200: { description: "Logout successful" },
        }
    }), async (ctx) => {
        const refreshToken = getCookie(ctx, "refresh_token");
        if (refreshToken) {
            try {
                await this.tokenRepository.deleteToken(refreshToken);
            } catch (error) {
                console.error("Logout session invalidation error:", error);
            }
        }
        deleteCookie(ctx, "refresh_token", { path: "/auth/refresh" });
        return ctx.json({ message: 'logout success' });
    })
    
    public readonly refreshToken = this.factory.createHandlers(describeRoute({
        summary: "Refresh Access Token",
        description: "Issue a new access token using a valid refresh token cookie.",
        tags: ["Auth"],
        responses: {
            200: { description: "Token refreshed successfully" },
            401: { description: "Invalid or missing refresh token" },
        }
    }), async (ctx) => {
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
        const newSessionId = await this.tokenRepository.updateToken(
            refreshToken,
            payload.userId,
            ctx.req.header("User-Agent") || "Unknown",
            session.id
        );
        
        if (!newSessionId) {
            return ctx.json({ error: "Invalid refresh token" }, 401);
        }

        setCookie(ctx, "refresh_token", refreshToken, {
            httpOnly: true,
            secure: process.env.NODE_ENV === "production",
            sameSite: "lax",
            path: "/auth/refresh",
            maxAge: JwtUtils.REFRESH_TOKEN_EXP
        });

        const tokenPayload = {
            userId: payload.userId,
            email: payload.email
        };

        const token = await JwtUtils.generateAccessToken(tokenPayload);
        return ctx.json({ message: "Refresh token successful", token });
    });
    
}

export default AuthController;

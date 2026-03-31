import { sValidator } from '@hono/standard-validator';
import { describeRoute } from 'hono-openapi';
import { createFactory } from 'hono/factory';
import { registerValidation } from '../../utils/zod.valid';
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
                500: { description: "Registration failed" },
            }
        }),
        sValidator("json", registerValidation),
        async (ctx) => {
            const { email, password, lastName, firstName, age } = ctx.req.valid("json");
            try {
                const existUser = await this.authRepository.findUserByEmail(email);
                if (existUser) {
                    return ctx.json({ message: 'user already exists' }, 400);
                }
                
                const newUser = await this.authRepository.createrUser({
                    email,
                    password,
                    lastName,
                    firstName,
                    age: age ?? 18
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
                
                setCookie(ctx, "refreshToken", refreshToken, {
                    httpOnly: true,
                    secure: true,
                    sameSite: "strict",
                    maxAge: JwtUtils.REFRESH_TOKEN_EXP,
                    path: "/auth/refresh"
                });
                return ctx.json({ message: 'register', token: token });
            } catch (error) {
                return ctx.json({ message: 'registration failed' }, 500);
            }
    })
    
    public readonly login = this.factory.createHandlers((ctx) => {
        return ctx.json({ message: 'login' });
    })
    
    public readonly logout = this.factory.createHandlers(async (ctx) => {
        const refreshToken = getCookie(ctx, "refreshToken");
        if (refreshToken) {
            await this.tokenRepository.deleteToken(refreshToken);
        }
        deleteCookie(ctx, "refreshToken");
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
        return ctx.json({ message: "Refresh token", token });
    });
    
}

export default AuthController;
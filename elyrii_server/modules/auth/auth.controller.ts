import { sValidator } from '@hono/standard-validator';
import { zValidator } from '@hono/zod-validator';
import { describeRoute } from 'hono-openapi';
import { createFactory } from 'hono/factory';
import { loginValidation, registerValidation } from '../../utils/zod.valid';
import AuthRepository from '../../repository/auth.repository';
import { JwtUtils, type TokenPayload } from '../../utils/jwt.utils';
import TokenRepository from '../../repository/token.repository';
import { deleteCookie, getCookie, setCookie } from 'hono/cookie';
import { z } from 'zod';
import { verifyAppleOAuth, verifyGoogleOAuth } from '../../utils/oauth.utils';

class AuthController {
    private readonly factory = createFactory();
    private readonly authRepository = new AuthRepository();
    private readonly tokenRepository = new TokenRepository();
    
    constructor() { }

    private get requireEmailVerification() {
        return Bun.env.REQUIRE_EMAIL_VERIFICATION === "true" || Bun.env.NODE_ENV === "production";
    }

    private get includeVerificationTokenInResponse() {
        return Bun.env.NODE_ENV !== "production";
    }

    private async issueSession(ctx: any, payload: TokenPayload) {
        const [token, refreshToken] = await Promise.all([
            JwtUtils.generateAccessToken(payload),
            JwtUtils.generateRefreshToken(payload),
        ]);

        await this.tokenRepository.createToken(
            refreshToken,
            payload.userId,
            ctx.req.header("User-Agent") || "Unknown",
        );

        setCookie(ctx, "refresh_token", refreshToken, {
            httpOnly: true,
            secure: process.env.NODE_ENV === "production",
            sameSite: "lax",
            maxAge: JwtUtils.REFRESH_TOKEN_EXP,
            path: "/auth/refresh",
        });

        return { token, refreshToken };
    }
    
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
                const { email, password, lastName, firstName, age } = ctx.req.valid("json");
                const existUser = await this.authRepository.findUserByEmail(email);
                if (existUser) {
                    return ctx.json({ message: 'user already exists' }, 400);
                }

                const newUser = await this.authRepository.createUser({
                    email,
                    password,
                    lastName,
                    firstName,
                    age: age ?? 18
                });
                
                if (!newUser) {
                    return ctx.json({ message: 'registration failed' }, 500);
                }

                if (this.requireEmailVerification) {
                    await this.authRepository.clearEmailVerificationTokens(newUser.id);
                    const verificationToken = await this.authRepository.createEmailVerificationToken(newUser.id);
                    return ctx.json({
                        message: "User registered successfully. Email verification required.",
                        emailVerificationRequired: true,
                        ...(this.includeVerificationTokenInResponse ? { verificationToken } : {}),
                    }, 201);
                }

                const tokenPayload: TokenPayload = {
                    userId: newUser.id,
                    email: newUser.email
                };
                const { token } = await this.issueSession(ctx, tokenPayload);
                return ctx.json({ message: 'User registered successfully', token: token }, 201);
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
            if (this.requireEmailVerification && !isUser.emailVerified) {
                return ctx.json({ message: "email not verified" }, 403);
            }
            if (!await Bun.password.verify(password, isUser.password)) {
                return ctx.json({ message: 'invalid credentials' }, 401);
            }
            const tokenPayload: TokenPayload = {
                userId: isUser.id,
                email: isUser.email
            }
            const { token } = await this.issueSession(ctx, tokenPayload);
            return ctx.json({ message: 'Login successful', token });
        } catch (error) {
            console.error("Login error:", error);
            return ctx.json({ message: 'login failed' }, 500);
        }
    })

    public readonly googleOAuth = this.factory.createHandlers(
        describeRoute({
            summary: "Google OAuth Login",
            description: "Authenticate with Google OAuth and create/link user account.",
            tags: ["Auth"],
            responses: {
                200: { description: "OAuth login successful" },
                400: { description: "Invalid OAuth payload" },
                500: { description: "OAuth login failed" },
            }
        }),
        zValidator("json", z.object({
            idToken: z.string().optional(),
            accessToken: z.string().optional(),
            email: z.string().email().optional(),
            providerUserId: z.string().optional(),
            firstName: z.string().optional(),
            lastName: z.string().optional(),
        })),
        async (ctx) => {
            try {
                const body = ctx.req.valid("json");
                const profile = await verifyGoogleOAuth(body);

                const linked = await this.authRepository.findOAuthAccount("google", profile.providerUserId);
                let user = linked ? await this.authRepository.getUserById(linked.userId) : undefined;

                if (!user && profile.email) {
                    user = await this.authRepository.findUserByEmail(profile.email);
                }

                if (!user) {
                    user = await this.authRepository.createUser({
                        email: profile.email,
                        password: crypto.randomUUID(),
                        firstName: profile.firstName ?? "Google",
                        lastName: profile.lastName ?? "User",
                        age: 18,
                        emailVerified: profile.emailVerified,
                    });
                }

                if (!user) {
                    return ctx.json({ error: "Unable to create OAuth user" }, 500);
                }

                await this.authRepository.linkOAuthAccount(
                    user.id,
                    "google",
                    profile.providerUserId,
                    profile.email,
                );
                if (!user.emailVerified && profile.emailVerified) {
                    await this.authRepository.updateEmailVerified(user.id, true);
                }

                const tokenPayload: TokenPayload = { userId: user.id, email: user.email };
                const { token } = await this.issueSession(ctx, tokenPayload);
                return ctx.json({ message: "OAuth login successful", token }, 200);
            } catch (error) {
                console.error("Google OAuth error:", error);
                return ctx.json({ error: "Google OAuth failed" }, 500);
            }
        }
    );

    public readonly appleOAuth = this.factory.createHandlers(
        describeRoute({
            summary: "Apple OAuth Login",
            description: "Authenticate with Apple OAuth and create/link user account.",
            tags: ["Auth"],
            responses: {
                200: { description: "OAuth login successful" },
                400: { description: "Invalid OAuth payload" },
                500: { description: "OAuth login failed" },
            }
        }),
        zValidator("json", z.object({
            idToken: z.string().optional(),
            email: z.string().email().optional(),
            providerUserId: z.string().optional(),
            firstName: z.string().optional(),
            lastName: z.string().optional(),
        })),
        async (ctx) => {
            try {
                const body = ctx.req.valid("json");
                const profile = await verifyAppleOAuth(body);

                const linked = await this.authRepository.findOAuthAccount("apple", profile.providerUserId);
                let user = linked ? await this.authRepository.getUserById(linked.userId) : undefined;

                if (!user && profile.email) {
                    user = await this.authRepository.findUserByEmail(profile.email);
                }

                if (!user) {
                    user = await this.authRepository.createUser({
                        email: profile.email,
                        password: crypto.randomUUID(),
                        firstName: profile.firstName ?? "Apple",
                        lastName: profile.lastName ?? "User",
                        age: 18,
                        emailVerified: profile.emailVerified,
                    });
                }

                if (!user) {
                    return ctx.json({ error: "Unable to create OAuth user" }, 500);
                }

                await this.authRepository.linkOAuthAccount(
                    user.id,
                    "apple",
                    profile.providerUserId,
                    profile.email,
                );
                if (!user.emailVerified && profile.emailVerified) {
                    await this.authRepository.updateEmailVerified(user.id, true);
                }

                const tokenPayload: TokenPayload = { userId: user.id, email: user.email };
                const { token } = await this.issueSession(ctx, tokenPayload);
                return ctx.json({ message: "OAuth login successful", token }, 200);
            } catch (error) {
                console.error("Apple OAuth error:", error);
                return ctx.json({ error: "Apple OAuth failed" }, 500);
            }
        }
    );
    
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
                const refreshPayload = await JwtUtils.verifyRefreshToken(refreshToken);
                await this.tokenRepository.deleteToken(refreshToken, refreshPayload?.userId);
            } catch (error) {
                console.error("Logout session invalidation error:", error);
            }
        }

        const authHeader = ctx.req.header("Authorization");
        if (authHeader?.startsWith("Bearer ")) {
            const accessToken = authHeader.slice("Bearer ".length).trim();
            const payload = await JwtUtils.verifyAccessToken(accessToken);
            if (payload?.jti && payload.exp && payload.userId) {
                try {
                    await this.tokenRepository.revokeAccessToken(
                        payload.userId,
                        payload.jti,
                        new Date(payload.exp * 1000),
                    );
                } catch (error) {
                    console.error("Failed to revoke access token:", error);
                }
            }
        }

        deleteCookie(ctx, "refresh_token", { path: "/auth/refresh" });
        return ctx.json({ message: 'logout success' });
    })
    
    private readonly refreshHandler = async (ctx: any) => {
        const oldRefreshToken = getCookie(ctx, "refresh_token");
        if (!oldRefreshToken) {
            return ctx.json({ error: "Refresh token not found" }, 401);
        }

        const payload = await JwtUtils.verifyRefreshToken(oldRefreshToken);
        if (!payload?.userId || !payload.email) {
            return ctx.json({ error: "Invalid refresh token" }, 401);
        }

        const session = await this.tokenRepository.getValidSessionForUser(payload.userId, oldRefreshToken);
        if (!session) {
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
    };

    public readonly refreshToken = this.factory.createHandlers(describeRoute({
        summary: "Refresh Access Token",
        description: "Issue a new access token using a valid refresh token cookie.",
        tags: ["Auth"],
        responses: {
            200: { description: "Token refreshed successfully" },
            401: { description: "Invalid or missing refresh token" },
        }
    }), this.refreshHandler);

    public readonly refreshTokenPost = this.factory.createHandlers(
        describeRoute({
            summary: "Refresh Access Token (POST)",
            description: "Issue a new access token using a valid refresh token cookie.",
            tags: ["Auth"],
            responses: {
                200: { description: "Token refreshed successfully" },
                401: { description: "Invalid or missing refresh token" },
            }
        }),
        this.refreshHandler
    );

    public readonly verifyEmail = this.factory.createHandlers(
        describeRoute({
            summary: "Verify Email",
            description: "Verify a user email with a one-time verification token.",
            tags: ["Auth"],
            responses: {
                200: { description: "Email verified successfully" },
                400: { description: "Invalid verification token" },
            }
        }),
        zValidator("json", z.object({ token: z.string().min(10) })),
        async (ctx) => {
            const { token } = ctx.req.valid("json");
            const user = await this.authRepository.consumeEmailVerificationToken(token);
            if (!user) {
                return ctx.json({ error: "Invalid or expired verification token" }, 400);
            }

            const tokenPayload: TokenPayload = { userId: user.id, email: user.email };
            const { token: accessToken } = await this.issueSession(ctx, tokenPayload);
            return ctx.json({
                message: "Email verified successfully",
                token: accessToken,
            }, 200);
        }
    );

    public readonly resendVerification = this.factory.createHandlers(
        describeRoute({
            summary: "Resend Verification Email",
            description: "Regenerate a verification token for users who are not yet verified.",
            tags: ["Auth"],
            responses: {
                200: { description: "Verification token regenerated" },
            }
        }),
        zValidator("json", z.object({ email: z.string().email() })),
        async (ctx) => {
            const { email } = ctx.req.valid("json");
            const user = await this.authRepository.findUserByEmail(email);
            if (!user || user.emailVerified) {
                return ctx.json({ message: "If the account exists, a verification email has been sent." }, 200);
            }

            await this.authRepository.clearEmailVerificationTokens(user.id);
            const verificationToken = await this.authRepository.createEmailVerificationToken(user.id);
            return ctx.json({
                message: "Verification token regenerated.",
                ...(this.includeVerificationTokenInResponse ? { verificationToken } : {}),
            }, 200);
        }
    );
    
}

export default AuthController;

import { createFactory } from "hono/factory";
import { sValidator } from "@hono/standard-validator";
import { z } from "zod";
import UserRepository from "../../repository/user.repository";
import { updateProfileValidation } from "../../utils/zod.valid";
import type { HonoEnv } from "../../utils/hono.types";
import QuestLogic from "../quest/quest.logic";
import AuthRepository from "../../repository/auth.repository";
import QuestRepository from "../../repository/quest.repository";

const updateSettingsValidation = z.object({
    themeMode: z.enum(["LIGHT", "DARK", "SYSTEM"]).optional(),
    notificationsEnabled: z.boolean().optional(),
    privacyMode: z.enum(["STANDARD", "STRICT"]).optional(),
});

const updateMascotValidation = z.object({
    appearance: z.string().min(1).max(50).optional(),
    themeId: z.string().min(1).max(50).optional(),
    equippedCosmetics: z.array(z.string().min(1).max(80)).max(20).optional(),
    personality: z.object({
        tone: z.enum(["supportive", "neutral", "energetic", "calm"]).optional(),
        energy: z.enum(["low", "balanced", "high"]).optional(),
        humor: z.enum(["none", "light", "playful"]).optional(),
        themeId: z.string().min(1).max(50).optional(),
        equippedCosmetics: z.array(z.string().min(1).max(80)).max(20).optional(),
    }).partial().optional(),
});

const changePasswordValidation = z.object({
    currentPassword: z.string().min(6),
    newPassword: z.string().min(6),
});

const deleteAccountValidation = z.object({
    password: z.string().min(6),
});

function parseStatsRange(range?: string): number {
    if (!range) return 7;
    const normalized = range.trim().toLowerCase();
    if (normalized === "7d") return 7;
    if (normalized === "30d") return 30;
    if (normalized === "90d") return 90;
    if (normalized === "365d") return 365;
    const parsed = Number(normalized.replace("d", ""));
    if (Number.isFinite(parsed) && parsed > 0) {
        return Math.min(parsed, 365);
    }
    return 7;
}

class UserController {
    private readonly factory = createFactory<HonoEnv>();
    private readonly userRepository = new UserRepository();
    private readonly authRepository = new AuthRepository();
    private readonly questRepository = new QuestRepository();
    private readonly questLogic = new QuestLogic();

    readonly getMe = this.factory.createHandlers(async (ctx) => {
        const { userId } = ctx.get("user");

        try {
            const user = await this.userRepository.getUserById(userId);
            if (!user) {
                return ctx.json({ error: "User not found" }, 404);
            }
            return ctx.json(user, 200);
        } catch (error) {
            console.error("getMe error:", error);
            return ctx.json({ error: "Failed to retrieve profile" }, 500);
        }
    });

    readonly updateMe = this.factory.createHandlers(
        sValidator("json", updateProfileValidation),
        async (ctx) => {
            const { userId } = ctx.get("user");
            const body = ctx.req.valid("json");

            try {
                const updated = await this.userRepository.updateUser(userId, body);
                if (!updated) {
                    return ctx.json({ error: "User not found" }, 404);
                }
                return ctx.json(updated, 200);
            } catch (error) {
                console.error("updateMe error:", error);
                return ctx.json({ error: "Failed to update profile" }, 500);
            }
        }
    );

    readonly logMood = this.factory.createHandlers(
        sValidator("json", z.object({ moodType: z.string() })),
        async (ctx) => {
            const { userId } = ctx.get("user");
            const { moodType } = ctx.req.valid("json");

            try {
                const log = await this.userRepository.logMood(userId, moodType);
                // Déclencher la vérification des défis en arrière-plan (non bloquant)
                this.questLogic.checkAndUpdateProgress(userId, 'mood_logged').catch(() => {});
                return ctx.json(log, 201);
            } catch (error) {
                console.error("logMood error:", error);
                return ctx.json({ error: "Failed to log mood" }, 500);
            }
        }
    );

    readonly getLatestMood = this.factory.createHandlers(async (ctx) => {
        const { userId } = ctx.get("user");

        try {
            const log = await this.userRepository.getLatestMood(userId);
            if (!log) {
                return ctx.json({ moodType: null }, 200);
            }
            return ctx.json({ moodType: log.moodType }, 200);
        } catch (error) {
            console.error("getLatestMood error:", error);
            return ctx.json({ error: "Failed to retrieve latest mood" }, 500);
        }
    });

    readonly getStats = this.factory.createHandlers(async (ctx) => {
        const { userId } = ctx.get("user");
        const range = parseStatsRange(ctx.req.query("range"));

        try {
            const stats = await this.userRepository.getStats(userId, range);
            return ctx.json(stats, 200);
        } catch (error) {
            console.error("getStats error:", error);
            return ctx.json({ error: "Failed to retrieve statistics" }, 500);
        }
    });

    readonly getDashboard = this.factory.createHandlers(async (ctx) => {
        const { userId } = ctx.get("user");
        const range = parseStatsRange(ctx.req.query("range"));

        try {
            const [stats, activeChallenges, pendingChallenges, latestMood] = await Promise.all([
                this.userRepository.getStats(userId, range),
                this.questRepository.getUserChallenges(userId, "ACTIVE"),
                this.questRepository.getUserChallenges(userId, "PENDING"),
                this.userRepository.getLatestMood(userId),
            ]);

            return ctx.json({
                latestMood: latestMood?.moodType ?? null,
                stats,
                challenges: {
                    active: activeChallenges.slice(0, 5),
                    pending: pendingChallenges.slice(0, 5),
                },
            }, 200);
        } catch (error) {
            console.error("getDashboard error:", error);
            return ctx.json({ error: "Failed to retrieve dashboard" }, 500);
        }
    });

    readonly getSettings = this.factory.createHandlers(async (ctx) => {
        const { userId } = ctx.get("user");
        try {
            const settings = await this.userRepository.getOrCreateUserSettings(userId);
            return ctx.json(settings, 200);
        } catch (error) {
            console.error("getSettings error:", error);
            return ctx.json({ error: "Failed to retrieve user settings" }, 500);
        }
    });

    readonly updateSettings = this.factory.createHandlers(
        sValidator("json", updateSettingsValidation),
        async (ctx) => {
            const { userId } = ctx.get("user");
            const body = ctx.req.valid("json");

            try {
                if (Object.keys(body).length === 0) {
                    const current = await this.userRepository.getOrCreateUserSettings(userId);
                    return ctx.json(current, 200);
                }
                const updated = await this.userRepository.updateUserSettings(userId, body);
                return ctx.json(updated, 200);
            } catch (error) {
                console.error("updateSettings error:", error);
                return ctx.json({ error: "Failed to update user settings" }, 500);
            }
        }
    );

    readonly getMascot = this.factory.createHandlers(async (ctx) => {
        const { userId } = ctx.get("user");
        try {
            const settings = await this.userRepository.getOrCreateUserSettings(userId);
            return ctx.json({
                appearance: settings.mascotAppearance,
                personality: settings.mascotPersonality,
            }, 200);
        } catch (error) {
            console.error("getMascot error:", error);
            return ctx.json({ error: "Failed to retrieve mascot settings" }, 500);
        }
    });

    readonly updateMascot = this.factory.createHandlers(
        sValidator("json", updateMascotValidation),
        async (ctx) => {
            const { userId } = ctx.get("user");
            const body = ctx.req.valid("json");

            try {
                const current = await this.userRepository.getOrCreateUserSettings(userId);
                const currentPersonality = current.mascotPersonality as Record<string, unknown>;
                const mascotAppearance = body.appearance ?? body.themeId ?? current.mascotAppearance;
                const mascotPersonality = {
                    ...currentPersonality,
                    ...(body.personality ?? {}),
                    ...(body.themeId ? { themeId: body.themeId } : {}),
                    ...(body.equippedCosmetics ? { equippedCosmetics: body.equippedCosmetics } : {}),
                };
                const updated = await this.userRepository.updateUserSettings(userId, {
                    mascotAppearance,
                    mascotPersonality,
                });
                return ctx.json({
                    appearance: updated.mascotAppearance,
                    personality: updated.mascotPersonality,
                }, 200);
            } catch (error) {
                console.error("updateMascot error:", error);
                return ctx.json({ error: "Failed to update mascot settings" }, 500);
            }
        }
    );

    readonly changePassword = this.factory.createHandlers(
        sValidator("json", changePasswordValidation),
        async (ctx) => {
            const { userId } = ctx.get("user");
            const { currentPassword, newPassword } = ctx.req.valid("json");

            try {
                const user = await this.authRepository.getUserById(userId);
                if (!user) {
                    return ctx.json({ error: "User not found" }, 404);
                }

                const isCurrentValid = await Bun.password.verify(currentPassword, user.password);
                if (!isCurrentValid) {
                    return ctx.json({ error: "Current password is incorrect" }, 401);
                }

                const updated = await this.authRepository.updateUserPassword(userId, newPassword);
                if (!updated) {
                    return ctx.json({ error: "Failed to update password" }, 500);
                }

                return ctx.json({ message: "Password updated successfully" }, 200);
            } catch (error) {
                console.error("changePassword error:", error);
                return ctx.json({ error: "Failed to update password" }, 500);
            }
        }
    );

    readonly deleteAccount = this.factory.createHandlers(
        sValidator("json", deleteAccountValidation),
        async (ctx) => {
            const { userId } = ctx.get("user");
            const { password } = ctx.req.valid("json");

            try {
                const user = await this.authRepository.getUserById(userId);
                if (!user) {
                    return ctx.json({ error: "User not found" }, 404);
                }

                const isPasswordValid = await Bun.password.verify(password, user.password);
                if (!isPasswordValid) {
                    return ctx.json({ error: "Password is incorrect" }, 401);
                }

                const deleted = await this.userRepository.deleteUserAccount(userId);
                if (!deleted) {
                    return ctx.json({ error: "Failed to delete account" }, 500);
                }

                return ctx.json({ message: "Account deleted successfully" }, 200);
            } catch (error) {
                console.error("deleteAccount error:", error);
                return ctx.json({ error: "Failed to delete account" }, 500);
            }
        }
    );
}

export default UserController;

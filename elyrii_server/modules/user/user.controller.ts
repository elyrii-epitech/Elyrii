import { createFactory } from "hono/factory";
import { sValidator } from "@hono/standard-validator";
import { z } from "zod";
import UserRepository from "../../repository/user.repository";
import { updateProfileValidation } from "../../utils/zod.valid";
import type { HonoEnv } from "../../utils/hono.types";
import QuestLogic from "../quest/quest.logic";

const updateSettingsValidation = z.object({
    themeMode: z.enum(["LIGHT", "DARK", "SYSTEM"]).optional(),
    notificationsEnabled: z.boolean().optional(),
    privacyMode: z.enum(["STANDARD", "STRICT"]).optional(),
});

class UserController {
    private readonly factory = createFactory<HonoEnv>();
    private readonly userRepository = new UserRepository();
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

        try {
            const stats = await this.userRepository.getStats(userId);
            return ctx.json(stats, 200);
        } catch (error) {
            console.error("getStats error:", error);
            return ctx.json({ error: "Failed to retrieve statistics" }, 500);
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
}

export default UserController;

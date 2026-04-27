import { createFactory } from "hono/factory";
import { sValidator } from "@hono/standard-validator";
import { z } from "zod";
import UserRepository from "../../repository/user.repository";
import { updateProfileValidation } from "../../utils/zod.valid";
import type { HonoEnv } from "../../utils/hono.types";

class UserController {
    private readonly factory = createFactory<HonoEnv>();
    private readonly userRepository = new UserRepository();

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
}

export default UserController;

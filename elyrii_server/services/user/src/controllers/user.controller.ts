import { createFactory } from "hono/factory";
import { sValidator } from "@hono/standard-validator";
import UserRepository from "../repository/user.repository";
import { updateProfileValidation } from "../utils/zod.valid";
import type { HonoEnv } from "../utils/hono.types";

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
}

export default UserController;

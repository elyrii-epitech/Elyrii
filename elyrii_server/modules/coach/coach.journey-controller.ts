import {createFactory} from "hono/factory";
import {describeRoute} from "hono-openapi";
import {z} from "zod";
import type {Context} from "hono";
import type {HonoEnv} from "../../utils/hono.types";
import CoachJourneyRepository from "../../repository/coach-journey.repository";
import UserRepository from "../../repository/user.repository";
import {COACH_CATALOG} from "./coach.catalog";
import {coachCommandSchema, coachEnrollmentSchema, chooseCoachSchema, CoachJourneyError} from "./coach.journey-contracts";

class CoachJourneyController {
    private readonly factory = createFactory<HonoEnv>();
    private readonly repository = new CoachJourneyRepository();
    private readonly users = new UserRepository();
    private doc(summary: string) {
        return describeRoute({summary, tags: ["Coach"], responses: {
            200: {description: "Owned coach program or mutation result"},
            400: {description: "Invalid program request"}, 404: {description: "Program not found"},
            409: {description: "Program changed; reload before retrying"}, 500: {description: "Coach temporarily unavailable"},
        }});
    }
    private async safely(ctx: Context<HonoEnv>, action: () => Promise<Response>) {
        ctx.header("Cache-Control", "no-store");
        try { return await action(); }
        catch (error) {
            if (error instanceof z.ZodError || error instanceof SyntaxError) return ctx.json({error: "Invalid coach request"}, 400);
            if (error instanceof CoachJourneyError) return ctx.json({error: error.message}, error.status);
            console.error("[Coach] Program request failed");
            return ctx.json({error: "Coach temporarily unavailable"}, 500);
        }
    }
    readonly catalog = this.factory.createHandlers(this.doc("Get Coach Programs"), ctx => ctx.json(COACH_CATALOG));
    readonly current = this.factory.createHandlers(this.doc("Get Current Coach Program"), ctx => this.safely(ctx, async () => {
        const owner = ctx.get("user").userId;
        return ctx.json({schemaVersion: 1, owner, current: await this.repository.getCurrent(owner)});
    }));
    readonly choose = this.factory.createHandlers(this.doc("Choose Coach Program"), ctx => this.safely(ctx, async () =>
        ctx.json(await this.repository.choose(ctx.get("user").userId, chooseCoachSchema.parse(await ctx.req.json())))));
    readonly importLocal = this.factory.createHandlers(this.doc("Import Legacy Coach Progress"), ctx => this.safely(ctx, async () =>
        ctx.json(await this.repository.importLocal(ctx.get("user").userId, coachEnrollmentSchema.parse(await ctx.req.json())))));
    private async command(ctx: Context<HonoEnv>, command: "pause" | "resume" | "complete") {
        const owner = ctx.get("user").userId;
        const input = coachCommandSchema.parse(await ctx.req.json());
        const result = await this.repository.command(owner, input, command,
            command === "complete" ? z.string().min(1).max(100).parse(ctx.req.param("stepId")) : undefined);
        if (command === "complete" && result.changed) {
            await this.users.touchActivity(owner).catch(() => console.warn("[Coach] Activity refresh deferred"));
        }
        return ctx.json(result);
    }
    readonly pause = this.factory.createHandlers(this.doc("Pause Coach Program"), ctx => this.safely(ctx, () => this.command(ctx, "pause")));
    readonly resume = this.factory.createHandlers(this.doc("Resume Coach Program"), ctx => this.safely(ctx, () => this.command(ctx, "resume")));
    readonly complete = this.factory.createHandlers(this.doc("Complete Current Coach Step"), ctx => this.safely(ctx, () => this.command(ctx, "complete")));
}
export default CoachJourneyController;

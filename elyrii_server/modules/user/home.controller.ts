import {createFactory} from "hono/factory";
import {z} from "zod";
import type {Context} from "hono";
import type {HonoEnv} from "../../utils/hono.types";
import HomeRepository from "../../repository/home.repository";
import {HomeError, homeCommandSchema, importHomeSchema} from "./home.contracts";

export default class HomeController {
    private readonly factory = createFactory<HonoEnv>();
    private readonly repository = new HomeRepository();
    private async safely(ctx: Context<HonoEnv>, operation: () => Promise<unknown>) {
        ctx.header("Cache-Control", "no-store");
        try { return ctx.json(await operation() as any); }
        catch (error) {
            if (error instanceof z.ZodError || error instanceof SyntaxError) return ctx.json({error: "Activité invalide."}, 400);
            if (error instanceof HomeError) return ctx.json({error: error.message}, error.status);
            console.error("[Home] Account activity request failed");
            return ctx.json({error: "Tes activités sont momentanément indisponibles."}, 500);
        }
    }
    readonly get = this.factory.createHandlers(ctx => this.safely(ctx, () => this.repository.get(ctx.get("user").userId)));
    readonly importLocal = this.factory.createHandlers(ctx => this.safely(ctx, async () =>
        this.repository.importLocal(ctx.get("user").userId, importHomeSchema.parse(await ctx.req.json()))));
    readonly command = this.factory.createHandlers(ctx => this.safely(ctx, async () =>
        this.repository.command(ctx.get("user").userId, homeCommandSchema.parse(await ctx.req.json()))));
}

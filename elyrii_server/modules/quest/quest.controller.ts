import {createFactory} from "hono/factory";
import type {Context} from "hono";
import {z} from "zod";
import {describeRoute} from "hono-openapi";
import QuestRepository from "../../repository/quest.repository";
import type {HonoEnv} from "../../utils/hono.types";
import QuestLogic from "./quest.logic";
import {challengePageSchema, proposalSchema, QuestRequestError} from "./quest.contracts";

type Ctx = Context<HonoEnv>;
const statusSchema = z.enum(["PENDING", "ACTIVE", "COMPLETED", "REJECTED", "SKIPPED", "EXPIRED"]);
const legacySchema = z.object({limit: z.coerce.number().int().min(1).max(200).default(100),
    sort: z.enum(["newest", "oldest", "points_desc", "completed_desc"]).default("newest")});
class QuestController {
    private readonly factory = createFactory<HonoEnv>();
    private readonly repository = new QuestRepository();
    private readonly logic = new QuestLogic();

    private document(summary: string, description: string, created = false) {
        return describeRoute({summary, description, tags: ["Quest"], responses: {
            200: {description: "Challenge result (including idempotent command retries)"},
            ...(created ? {201: {description: "Challenge assignment or proposal created"}} : {}),
            400: {description: "Invalid request"},
            404: {description: "Challenge or account not found"},
            409: {description: "Conflicting challenge transition"},
            422: {description: "Unsupported challenge definition"},
            500: {description: "Challenges temporarily unavailable"},
        }});
    }

    private async safely(ctx: Ctx, action: () => Promise<Response>): Promise<Response> {
        try { return await action(); }
        catch (error) {
            if (error instanceof z.ZodError || error instanceof SyntaxError) return ctx.json({error: "Invalid challenge request"}, 400);
            if (error instanceof QuestRequestError) return ctx.json({error: error.message}, error.status);
            console.error("[Quest] Request failed");
            return ctx.json({error: "Challenges temporarily unavailable"}, 500);
        }
    }
    private page(ctx: Ctx) {
        const input = challengePageSchema.parse(ctx.req.query());
        return {limit: input.pageSize, cursor: input.cursorDate && input.cursorId ?
            {date: new Date(input.cursorDate), id: input.cursorId} : undefined};
    }
    private async readUser(ctx: Ctx, status?: string) {
        const userId = ctx.get("user").userId;
        ctx.header("Cache-Control", "no-store");
        // Repair deferred work before the first page; later pages only continue.
        if (!ctx.req.query("cursorId") && (!status || status === "ACTIVE" || status === "COMPLETED")) {
            await this.logic.checkAndUpdateProgress(userId);
        }
        if (ctx.req.query("pageSize") != null) {
            const page = this.page(ctx);
            return ctx.json(await this.repository.getUserChallengePage(userId, status, page.limit, page.cursor));
        }
        const {limit, sort} = legacySchema.parse(ctx.req.query());
        const rows = await this.repository.getUserChallenges(userId, status);
        rows.sort((a, b) => sort === "points_desc" ? b.challenge.rewardPoints - a.challenge.rewardPoints :
            sort === "completed_desc" ? +(b.completedAt ?? 0) - +(a.completedAt ?? 0) :
            sort === "oldest" ? +(a.createdAt ?? 0) - +(b.createdAt ?? 0) : +(b.createdAt ?? 0) - +(a.createdAt ?? 0));
        return ctx.json(rows.slice(0, limit));
    }
    readonly getActiveChallenges = this.factory.createHandlers(
        this.document("Get Active Challenges", "Retrieve active challenges; pageSize enables cursor pagination."),
        ctx => this.safely(ctx, () => this.readUser(ctx, "ACTIVE")));
    readonly getCompletedChallenges = this.factory.createHandlers(
        this.document("Get Completed Challenges", "Retrieve completed challenges; pageSize enables cursor pagination."),
        ctx => this.safely(ctx, () => this.readUser(ctx, "COMPLETED")));
    readonly getPendingChallenges = this.factory.createHandlers(
        this.document("Get Pending Proposals", "Retrieve pending proposals; pageSize enables cursor pagination."),
        ctx => this.safely(ctx, () => this.readUser(ctx, "PENDING")));
    readonly listChallenges = this.factory.createHandlers(
        this.document("List Challenges", "List owned challenges with an optional status filter or cursor pagination."),
        ctx => this.safely(ctx, () =>
        this.readUser(ctx, ctx.req.query("status") ? statusSchema.parse(ctx.req.query("status")!.toUpperCase()) : undefined)));
    readonly getAvailableChallenges = this.factory.createHandlers(
        this.document("Get Available Challenges", "Retrieve SYSTEM challenges not yet active or completed."),
        ctx => this.safely(ctx, async () => {
        const userId = ctx.get("user").userId;
        ctx.header("Cache-Control", "no-store");
        if (ctx.req.query("pageSize") != null) {
            const page = this.page(ctx);
            return ctx.json(await this.repository.getAvailablePage(userId, page.limit, page.cursor));
        }
        const {limit, sort} = legacySchema.parse(ctx.req.query());
        const rows = await this.repository.getAvailableChallenges(userId);
        rows.sort((a, b) => sort === "points_desc" ? b.rewardPoints - a.rewardPoints :
            sort === "oldest" ? +(a.createdAt ?? 0) - +(b.createdAt ?? 0) : +(b.createdAt ?? 0) - +(a.createdAt ?? 0));
        return ctx.json(rows.slice(0, limit));
    }));
    readonly startChallenge = this.factory.createHandlers(
        this.document("Start Challenge", "Start a SYSTEM challenge or return the existing assignment on retry.", true),
        ctx => this.safely(ctx, async () => {
        const userId = ctx.get("user").userId;
        const {assignment, created} = await this.repository.startSystemChallenge(userId, z.uuid().parse(ctx.req.param("challengeId")));
        await this.logic.checkAndUpdateProgress(userId);
        const joined = await this.repository.getJoinedAssignment(userId, assignment.id);
        return ctx.json({challenge: joined.challenge, userChallenge: joined}, created ? 201 : 200);
    }));
    private async transition(ctx: Ctx, status: "ACTIVE" | "REJECTED") {
        const userId = ctx.get("user").userId;
        const assignment = await this.repository.transitionProposal(userId, z.uuid().parse(ctx.req.param("challengeId")), status);
        if (status === "ACTIVE") await this.logic.checkAndUpdateProgress(userId);
        return ctx.json(await this.repository.getJoinedAssignment(userId, assignment.id));
    }
    readonly acceptChallenge = this.factory.createHandlers(
        this.document("Accept Challenge", "Accept an owned pending proposal and reconcile its activity progress."),
        ctx => this.safely(ctx, () => this.transition(ctx, "ACTIVE")));
    readonly rejectChallenge = this.factory.createHandlers(
        this.document("Reject Challenge", "Reject an owned pending proposal; matching retries are idempotent."),
        ctx => this.safely(ctx, () => this.transition(ctx, "REJECTED")));
    readonly createProposal = this.factory.createHandlers(
        this.document("Create Challenge Proposal", "Create a validated proposal and pending assignment for the authenticated user.", true),
        ctx => this.safely(ctx, async () =>
        ctx.json(await this.repository.createProposal(ctx.get("user").userId, proposalSchema.parse(await ctx.req.json())), 201)));
}
export default QuestController;

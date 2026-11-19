import { z } from "zod";

export const SUMMARY_JOBS_TOPIC = "elyrii.context.summary.jobs.v1";
export const SUMMARY_RESULTS_TOPIC = "elyrii.context.summary.results.v1";
export const summaryPolicySchema = z.strictObject({
    messageThreshold: z.number().int().min(1).max(64),
    tokenThreshold: z.number().int().min(1).max(32000),
    maxInputTokens: z.number().int().min(256).max(32000),
    maxOutputTokens: z.number().int().min(16).max(2048),
});
export const summaryConfigSchema = summaryPolicySchema.extend({
    keepRecent: z.number().int().min(0).max(100),
    model: z.string().min(1).max(200),
});
export function summaryConfig() {
    return summaryConfigSchema.parse({
        messageThreshold: Number(process.env.SUMMARY_MESSAGE_THRESHOLD || 24),
        tokenThreshold: Number(process.env.SUMMARY_TOKEN_THRESHOLD || 2000),
        maxInputTokens: Number(process.env.SUMMARY_INPUT_TOKENS || 3000),
        maxOutputTokens: Number(process.env.SUMMARY_OUTPUT_TOKENS || 512),
        keepRecent: Number(process.env.SUMMARY_KEEP_RECENT || 8),
        model: process.env.SUMMARY_AI_MODEL || process.env.AI_MODEL || "mistral",
    });
}
const identity = {
    version: z.literal(1), jobId: z.uuid(), userId: z.uuid(), conversationId: z.string().min(1).max(200),
    revision: z.number().int().nonnegative(), attempt: z.number().int().min(1).max(5), model: z.string().min(1).max(200),
};
export const summaryJobSchema = z.strictObject({ ...identity, policy: summaryPolicySchema,
    timezone: z.string().min(1).max(100),
    priorSummary: z.string().max(20000).nullable(),
    priorThroughMessageId: z.uuid().nullable(),
    messages: z.array(z.strictObject({ id: z.uuid(), role: z.enum(["user", "assistant", "system"]),
        content: z.string().min(1).max(100000), messageAt: z.iso.datetime({ offset: true }) })).min(1).max(64),
});
export const summaryResultSchema = z.discriminatedUnion("status", [
    z.strictObject({ ...identity, status: z.literal("success"), summary: z.string().trim().min(1).max(20000),
        throughMessageId: z.uuid(), outputTokens: z.number().int().positive() }),
    z.strictObject({ ...identity, status: z.literal("skipped") }),
    z.strictObject({ ...identity, status: z.literal("failure"), error: z.enum(["inference_failed", "input_too_large", "invalid_input"]) }),
]);
export type SummaryJob = z.infer<typeof summaryJobSchema>;
export type SummaryConfig = z.infer<typeof summaryConfigSchema>;

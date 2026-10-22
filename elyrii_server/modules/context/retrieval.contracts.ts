import { z } from "zod";
import type { UserContextFact, UserMemory, ConversationSummary } from "../../config/db/context.table";
import type { chatMessagesTable } from "../../config/db/chat.table";

export const retrievalConfigSchema = z.strictObject({
    minSimilarity: z.number().finite().min(-1).max(1).default(0.65),
    topK: z.number().int().min(1).max(50).default(5),
    recentLimit: z.number().int().min(1).max(200).default(12),
    timeoutMs: z.number().int().min(1).max(30000).default(3000),
});
export type RetrievalConfig = z.infer<typeof retrievalConfigSchema>;
export const retrievalConfig = () => retrievalConfigSchema.parse({
    minSimilarity: Number(process.env.CONTEXT_MIN_SIMILARITY ?? 0.65),
    topK: Number(process.env.CONTEXT_TOP_K ?? 5),
    recentLimit: Number(process.env.CONTEXT_RECENT_LIMIT ?? 12),
    timeoutMs: Number(process.env.CONTEXT_EMBEDDING_TIMEOUT_MS ?? 3000),
});
export const retrievalRequestSchema = z.strictObject({
    conversationId: z.string().min(1).max(200),
    query: z.string().min(1).max(10000).refine(s => s.trim().length > 0 && Buffer.byteLength(s) <= 40000),
    // Required when the current input has already been persisted. Never supplied as an owner ID.
    currentMessageId: z.uuid().optional(),
});
export type RetrievalRequest = z.infer<typeof retrievalRequestSchema>;
export type RankedMemory = { id: string; contentRevision: number; similarity: number; vectorUpdatedAt: string };
export type RetrievedContext = {
    moodObservation?: import("./mood.contracts").MoodObservation;
    facts: UserContextFact[];
    continuity: { summary: ConversationSummary | null; messages: (typeof chatMessagesTable.$inferSelect)[]; truncated: boolean };
    memories: (UserMemory & { similarity: number; model: string })[];
    semanticStatus: "ok" | "unavailable";
};

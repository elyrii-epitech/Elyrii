import { and, asc, desc, eq, inArray, ne, sql } from "drizzle-orm";
import { db } from "../config/db.config";
import { userContextFactsTable as facts, userMemoriesTable as memories, memoryEmbeddingsTable as vectors,
    conversationSummariesTable as summaries } from "../config/db/context.table";
import { chatMessagesTable as messages } from "../config/db/chat.table";
import { embeddingModels as models } from "../config/db/embedding.table";
import { ContextPolicy } from "../modules/context/context.policy";
import type { EmbeddingModel } from "../modules/context/embedding.contracts";
import type { RankedMemory, RetrievedContext, RetrievalConfig, RetrievalRequest } from "../modules/context/retrieval.contracts";

import { moodObservationSchema } from "../modules/context/mood.contracts";
import { historyBoundary } from "../modules/context/history-boundary";
import { contextSourceEligible, conversationHasExpiredContext } from "../modules/context/source-eligibility";

export class RetrievalRepository {
    constructor(private readonly database: typeof db = db, private readonly clock = () => new Date()) {}

    /** Independent read: a mood failure must never abort the context transaction. */
    async moodObservation(userId: string, freshnessHours: number) {
        const now = this.clock().toISOString();
        const result = await this.database.execute(sql`
            SELECT id AS "logId", user_id AS "userId", 'mood_logs' AS source,
                CASE lower(btrim(mood_type)) WHEN 'verysad' THEN 'verySad'
                    WHEN 'veryhappy' THEN 'veryHappy' ELSE lower(btrim(mood_type)) END AS mood,
                to_char(created_at, 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') AS "observedAt",
                to_char(created_at + ${freshnessHours} * interval '1 hour', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') AS "freshUntil",
                (SELECT timezone FROM users WHERE users.id = ${userId}::uuid) AS timezone
            FROM mood_logs WHERE user_id = ${userId}::uuid AND NOT context_suppressed
                AND NOT EXISTS (SELECT 1 FROM user_settings WHERE user_settings.user_id = ${userId}::uuid AND privacy_mode = 'STRICT')
                AND isfinite(created_at) AND created_at <= ${now}::timestamp
                AND created_at > ${now}::timestamp - ${freshnessHours} * interval '1 hour'
                AND lower(btrim(mood_type)) IN ('verysad', 'sad', 'neutral', 'happy', 'veryhappy')
            ORDER BY created_at DESC, id DESC LIMIT 1`);
        const row = result.rows[0];
        if (!row) return undefined;
        let timezone = "UTC";
        try { timezone = new Intl.DateTimeFormat("en", { timeZone: String(row.timezone || "UTC") }).resolvedOptions().timeZone; } catch { /* UTC display fallback. */ }
        return moodObservationSchema.parse({ ...row, timezone });
    }

    async search(userId: string, spec: EmbeddingModel, vector: number[], config: RetrievalConfig): Promise<RankedMemory[]> {
        const now = this.clock();
        // CASE guards the distance operation itself, even if the planner reorders predicates.
        // MATERIALIZED also ensures owner/eligibility/version filtering precedes ranking.
        const result = await this.database.execute<RankedMemory>(sql`
            WITH eligible AS MATERIALIZED (
                SELECT m.id, m.content_revision, m.content, m.source_message_id, e.updated_at,
                    CASE WHEN vector_dims(e.embedding) = ${spec.dimensions} AND vector_norm(e.embedding) > 0
                         THEN 1 - (e.embedding <=> ${JSON.stringify(vector)}::vector) ELSE NULL END AS similarity
                FROM user_memories m JOIN memory_embeddings e ON e.memory_id = m.id
                JOIN embedding_models model ON model.id = e.model
                WHERE m.user_id = ${userId}::uuid AND m.status = 'active'
                    AND m.valid_from <= ${now} AND (m.valid_until IS NULL OR m.valid_until > ${now})
                    AND (m.expires_at IS NULL OR m.expires_at > ${now})
                    AND e.model = ${spec.id} AND e.dimensions = ${spec.dimensions}
                    AND e.content_revision = m.content_revision AND model.enabled
                    AND model.dimensions = ${spec.dimensions} AND model.digest = ${spec.digest}
            ), unique_content AS (
                SELECT *, row_number() OVER (PARTITION BY lower(regexp_replace(btrim(content), '\\s+', ' ', 'g'))
                    ORDER BY similarity DESC NULLS LAST, id) AS duplicate
                FROM eligible WHERE similarity >= ${config.minSimilarity}
            ), unique_source AS (
                SELECT *, row_number() OVER (PARTITION BY coalesce(source_message_id, id)
                    ORDER BY similarity DESC, id) AS source_duplicate
                FROM unique_content WHERE duplicate = 1
            )
            SELECT id, content_revision AS "contentRevision", similarity, updated_at::text AS "vectorUpdatedAt"
            FROM unique_source WHERE source_duplicate = 1
            ORDER BY similarity DESC, id LIMIT ${config.topK}`);
        return result.rows;
    }

    /** Fresh snapshot after slow provider/search work. Never return cached readable content. */
    async assemble(userId: string, request: RetrievalRequest, spec: EmbeddingModel | undefined,
        ranked: RankedMemory[], config: RetrievalConfig): Promise<Omit<RetrievedContext, "semanticStatus">> {
        return this.database.transaction(async tx => {
            const now = this.clock(), policy = new ContextPolicy(() => now);
            const scope = and(eq(messages.userId, userId), eq(messages.conversationId, request.conversationId), contextSourceEligible(now));
            const [current] = request.currentMessageId ? await tx.select().from(messages)
                .where(and(scope, eq(messages.id, request.currentMessageId), eq(messages.role, "user"))) : [];
            // A deleted/wrong-owner/wrong-conversation input must not fall back to unrelated history.
            const validCurrent = !request.currentMessageId || !!current;
            const [storedSummary] = validCurrent ? await tx.select().from(summaries)
                .where(and(eq(summaries.userId, userId), eq(summaries.conversationId, request.conversationId), sql`NOT ${conversationHasExpiredContext(userId, request.conversationId, now)}`)) : [];
            const [boundary] = storedSummary ? await tx.select().from(messages).where(and(scope, eq(messages.id, storedSummary.throughMessageId))) : [];
            const [boundaryBeforeCurrent] = boundary && current ? await tx.select({ id: messages.id }).from(messages)
                .where(and(scope, eq(messages.id, boundary.id), historyBoundary(current.id, "before"))) : [];
            // If an asynchronous summary already covers this input, omit it and rebuild the tail from raw history.
            const summary = storedSummary && boundary && (!current || boundaryBeforeCurrent) ? storedSummary : null;
            const afterSummary = summary && boundary ? historyBoundary(boundary.id, "after") : undefined;
            const beforeInput = current ? historyBoundary(current.id, "before") : undefined;
            const tail = validCurrent ? await tx.select().from(messages).where(and(scope, afterSummary, beforeInput,
                request.currentMessageId ? ne(messages.id, request.currentMessageId) : undefined))
                .orderBy(desc(messages.createdAt), desc(messages.id)).limit(config.recentLimit + 1) : [];
            const recent = tail.slice(0, config.recentLimit).reverse();
            const stable = await tx.select().from(facts).where(policy.factsEligible(userId)).orderBy(asc(facts.key), asc(facts.id));
            const selected: RetrievedContext["memories"] = [];
            if (spec && ranked.length) {
                const rows = await tx.select({ memory: memories, vectorUpdatedAt: sql<string>`${vectors.updatedAt}::text` })
                    .from(memories).innerJoin(vectors, eq(vectors.memoryId, memories.id)).innerJoin(models, eq(models.id, vectors.model))
                    .where(and(policy.memoriesEligible(userId), inArray(memories.id, ranked.map(r => r.id)),
                        eq(vectors.model, spec.id), eq(vectors.dimensions, spec.dimensions), eq(models.enabled, true),
                        eq(vectors.contentRevision, memories.contentRevision)));
                const sources = new Set([...recent.map(m => m.id), ...stable.flatMap(f => f.sourceMessageId ? [f.sourceMessageId] : []),
                    ...(request.currentMessageId ? [request.currentMessageId] : [])]);
                // Suppress experiences already covered by this conversation's summary.
                if (summary && boundary) {
                    const covered = await tx.select({ id: messages.id }).from(messages).where(and(scope,
                        inArray(messages.id, rows.flatMap(r => r.memory.sourceMessageId ? [r.memory.sourceMessageId] : [])),
                        historyBoundary(boundary.id, "through")));
                    covered.forEach(m => sources.add(m.id));
                }
                for (const candidate of ranked) {
                    const row = rows.find(r => r.memory.id === candidate.id && r.memory.contentRevision === candidate.contentRevision && r.vectorUpdatedAt === candidate.vectorUpdatedAt);
                    if (!row || (row.memory.sourceMessageId && sources.has(row.memory.sourceMessageId))) continue;
                    selected.push({ ...row.memory, similarity: candidate.similarity, model: spec.id });
                }
            }
            return { facts: stable, continuity: { summary, messages: recent, truncated: tail.length > config.recentLimit }, memories: selected };
        }, { isolationLevel: "repeatable read", accessMode: "read only" });
    }
}

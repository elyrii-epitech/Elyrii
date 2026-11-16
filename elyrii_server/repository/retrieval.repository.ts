import { and, asc, desc, eq, getTableName, inArray, ne, sql } from "drizzle-orm";
import { db } from "../config/db.config";
import { userContextFactsTable as facts, userMemoriesTable as memories, memoryEmbeddingsTable as vectors,
    conversationSummariesTable as summaries } from "../config/db/context.table";
import { chatMessagesTable as messages } from "../config/db/chat.table";
import { embeddingModels as models } from "../config/db/embedding.table";
import { ContextPolicy } from "../modules/context/context.policy";
import type { EmbeddingModel } from "../modules/context/embedding.contracts";
import type { RankedMemory, RetrievedContext, RetrievalConfig, RetrievalRequest } from "../modules/context/retrieval.contracts";

import { sourceEvidenceSchema } from "../modules/context/source.contracts";
import { moodObservationSchema } from "../modules/context/mood.contracts";
import { historyBoundary } from "../modules/context/history-boundary";
import { contextSourceEligible, conversationHasExpiredContext, journalRecallEligible } from "../modules/context/source-eligibility";

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
                WHERE m.user_id = ${userId}::uuid AND m.status = 'active' AND ${journalRecallEligible({ userId: sql`m.user_id`, sourceKind: sql`m.source_kind`, sourceId: sql`m.source_id`, sourceRevision: sql`m.source_revision` }, config.journalRecall, now)}
                    AND (m.source_kind IS NULL OR EXISTS (SELECT 1 FROM context_source_versions v
                        WHERE v.user_id = m.user_id AND v.kind = m.source_kind AND v.source_id = m.source_id AND v.revision = m.source_revision AND v.active))
                    AND m.valid_from <= ${now} AND (m.valid_until IS NULL OR m.valid_until > ${now})
                    AND (m.expires_at IS NULL OR m.expires_at > ${now})
                    AND e.model = ${spec.id} AND e.dimensions = ${spec.dimensions}
                    AND e.content_revision = m.content_revision AND model.enabled
                    AND model.dimensions = ${spec.dimensions} AND model.digest = ${spec.digest}
            ), unique_content AS (
                SELECT *, row_number() OVER (PARTITION BY lower(btrim(regexp_replace(content, '\\s+', ' ', 'g')))
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
            const stableRows = await tx.select({ row: facts, observedAt: sourceObservedAt(facts) }).from(facts).where(and(policy.factsEligible(userId), journalRecallEligible(facts, config.journalRecall, now))).orderBy(asc(facts.key), asc(facts.id));
            const stable = stableRows.map(({ row, observedAt }) => attribute(row, observedAt));
            const selected: RetrievedContext["memories"] = [];
            if (spec && ranked.length) {
                const rows = await tx.select({ memory: memories, observedAt: sourceObservedAt(memories), vectorUpdatedAt: sql<string>`${vectors.updatedAt}::text` })
                    .from(memories).innerJoin(vectors, eq(vectors.memoryId, memories.id)).innerJoin(models, eq(models.id, vectors.model))
                    .where(and(policy.memoriesEligible(userId), journalRecallEligible(memories, config.journalRecall, now), inArray(memories.id, ranked.map(r => r.id)),
                        eq(vectors.model, spec.id), eq(vectors.dimensions, spec.dimensions), eq(models.enabled, true),
                        eq(vectors.contentRevision, memories.contentRevision), eq(models.digest, spec.digest), eq(models.dimensions, spec.dimensions)));
                const sources = new Set([...recent.map(m => m.id), ...stable.flatMap(f => f.sourceMessageId ? [f.sourceMessageId] : []),
                    ...(request.currentMessageId ? [request.currentMessageId] : [])]);
                // Suppress experiences already covered by this conversation's summary.
                if (summary && boundary) {
                    const covered = await tx.select({ id: messages.id }).from(messages).where(and(scope,
                        inArray(messages.id, rows.flatMap(r => r.memory.sourceMessageId ? [r.memory.sourceMessageId] : [])),
                        historyBoundary(boundary.id, "through")));
                    covered.forEach(m => sources.add(m.id));
                }
                const contents = new Set<string>();
                for (const candidate of ranked) {
                    const row = rows.find(r => r.memory.id === candidate.id && r.memory.contentRevision === candidate.contentRevision && r.vectorUpdatedAt === candidate.vectorUpdatedAt);
                    if (!row || (row.memory.sourceMessageId && sources.has(row.memory.sourceMessageId))) continue;
                    const normalized = row.memory.content.trim().replace(/\s+/g, " ").toLowerCase();
                    if (contents.has(normalized)) continue;
                    contents.add(normalized);
                    selected.push({ ...attribute(row.memory, row.observedAt), similarity: candidate.similarity, model: spec.id });
                }
            }
            return { facts: stable, continuity: { summary, messages: recent, truncated: tail.length > config.recentLimit }, memories: selected };
        }, { isolationLevel: "repeatable read", accessMode: "read only" });
    }
}

function sourceObservedAt(row: typeof facts | typeof memories) {
    // Explicit identifiers keep the outer qualification even when Drizzle strips
    // column prefixes in a single-table SELECT projection.
    const column = (name: string) => sql`${sql.identifier(getTableName(row))}.${sql.identifier(name)}`;
    return sql<string | null>`(SELECT to_char(source_created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"')
        FROM context_source_versions v WHERE v.user_id = ${column("user_id")} AND v.kind = ${column("source_kind")}
        AND v.source_id = ${column("source_id")} AND v.revision = ${column("source_revision")})`;
}
function attribute<T extends { sourceKind: "chat" | "journal" | null; sourceId: string | null; sourceRevision: number | null; evidence: unknown }>(row: T, observedAt: string | null) {
    const metadata = sourceEvidenceSchema.safeParse(row.evidence);
    return { ...row, ...(row.sourceKind && row.sourceId && row.sourceRevision ? {
        source: { kind: row.sourceKind, id: row.sourceId, revision: row.sourceRevision, observedAt },
    } : {}), ...(row.sourceKind === "journal" && metadata.success ? {
        eventDate: metadata.data.eventDate, temporalExpression: metadata.data.temporalExpression, sourceTimezone: metadata.data.timezone,
    } : {}) };
}

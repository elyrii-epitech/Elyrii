import { randomUUID } from "node:crypto";
import { and, asc, count, eq, gt, inArray, lte, or, sql } from "drizzle-orm";
import { z } from "zod";
import { db } from "../config/db.config";
import { summaryTasks as tasks } from "../config/db/summary.table";
import { conversationSummariesTable as summaries } from "../config/db/context.table";
import { chatMessagesTable as messages } from "../config/db/chat.table";
import { userTable as users } from "../config/db/user.table";
import { summaryConfig, summaryConfigSchema, summaryJobSchema, summaryResultSchema, type SummaryConfig, type SummaryJob } from "../modules/context/summary.contracts";
import { retryDelay } from "../modules/context/extraction.contracts";
import { summaryInputSchema, type SummaryInput } from "../modules/context/context.candidates";

const scope = (table: typeof tasks | typeof summaries | typeof messages, userId: string, conversationId: string) =>
    and(eq(table.userId, userId), eq(table.conversationId, conversationId));
const afterBoundary = (boundary?: { createdAt: Date; id: string }) => boundary ?
    or(gt(messages.createdAt, boundary.createdAt), and(eq(messages.createdAt, boundary.createdAt), gt(messages.id, boundary.id))) : undefined;
const clearJob = { jobId: null, sourceIds: null, snapshotThroughAt: null, snapshotThroughId: null, attempts: 0 };

export class SummaryRepository {
    private readonly config: SummaryConfig;
    constructor(private readonly database: typeof db = db, config: SummaryConfig = summaryConfig(), private readonly clock = () => new Date()) {
        this.config = summaryConfigSchema.parse(config);
    }

    async claim(): Promise<SummaryJob | null> {
        return this.database.transaction(async tx => {
            const now = this.clock();
            const [task] = await tx.select().from(tasks).where(and(inArray(tasks.status, ["pending", "retry", "awaiting"]), lte(tasks.nextAttemptAt, now)))
                .orderBy(tasks.nextAttemptAt, tasks.userId, tasks.conversationId).limit(1).for("update", { skipLocked: true });
            if (!task) return null;
            const where = scope(tasks, task.userId, task.conversationId);
            if (task.attempts >= 5) {
                await tx.update(tasks).set({ status: "failed", lastError: "attempts_exhausted" }).where(where); return null;
            }
            const [prior] = await tx.select().from(summaries).where(scope(summaries, task.userId, task.conversationId));
            const [boundary] = prior ? await tx.select().from(messages).where(and(scope(messages, task.userId, task.conversationId), eq(messages.id, prior.throughMessageId))) : [];
            const uncovered = and(scope(messages, task.userId, task.conversationId), afterBoundary(boundary));
            let rows;
            if (task.sourceIds) {
                rows = await tx.select().from(messages).where(and(uncovered, inArray(messages.id, task.sourceIds)))
                    .orderBy(asc(messages.createdAt), asc(messages.id));
                if (rows.map(m => m.id).join() !== task.sourceIds.join()) {
                    await tx.execute(sql`SELECT invalidate_conversation_summary(${task.userId}::uuid, ${task.conversationId})`); return null;
                }
            } else {
                const [total] = await tx.select({ total: count() }).from(messages).where(uncovered);
                const take = Math.min(64, Math.max(0, total!.total - this.config.keepRecent));
                if (!take) { await tx.update(tasks).set({ status: "idle", dirty: false, ...clearJob }).where(where); return null; }
                rows = await tx.select().from(messages).where(uncovered).orderBy(asc(messages.createdAt), asc(messages.id)).limit(take);
                // Never skip an oversized source to reach later messages.
                let bytes = 0;
                rows = rows.filter((row, index) => {
                    bytes += Buffer.byteLength(JSON.stringify(row));
                    return index === 0 || bytes < 200000;
                });
            }
            const [owner] = await tx.select({ timezone: users.timezone }).from(users).where(eq(users.id, task.userId));
            let timezone = owner?.timezone || "UTC";
            try { timezone = new Intl.DateTimeFormat("en", { timeZone: timezone }).resolvedOptions().timeZone; } catch { timezone = "UTC"; }
            const { keepRecent, model, ...policy } = this.config;
            const candidate = summaryJobSchema.safeParse({ version: 1, jobId: task.jobId ?? randomUUID(), userId: task.userId,
                conversationId: task.conversationId, revision: task.revision, attempt: task.attempts + 1,
                model: task.model && task.jobId ? task.model : model, policy: task.policy && task.jobId ? task.policy : policy, timezone,
                priorSummary: prior?.summary ?? null, priorThroughMessageId: prior?.throughMessageId ?? null,
                messages: rows.map(row => ({ id: row.id, role: row.role === "ai" ? "assistant" : row.role,
                    content: row.message, messageAt: row.createdAt.toISOString() })) });
            if (!candidate.success || Buffer.byteLength(JSON.stringify(candidate.data)) > 250000) {
                await tx.update(tasks).set({ status: "failed", lastError: "invalid_input" }).where(where); return null;
            }
            const job = candidate.data;
            await tx.update(tasks).set({ status: "awaiting", jobId: job.jobId, sourceIds: rows.map(m => m.id),
                snapshotThroughAt: rows.at(-1)!.createdAt, snapshotThroughId: rows.at(-1)!.id,
                attempts: job.attempt, model: job.model, policy: job.policy, dirty: task.jobId ? task.dirty : false,
                nextAttemptAt: new Date(+now + 120000 + retryDelay(job.attempt)), lastError: null }).where(where);
            return job;
        });
    }

    async publishNext(publish: (job: SummaryJob) => Promise<void>) {
        const job = await this.claim();
        if (!job) return false;
        try { await publish(job); } catch {
            await this.database.update(tasks).set({ status: job.attempt === 5 ? "failed" : "retry", lastError: "publish_failed",
                nextAttemptAt: new Date(+this.clock() + retryDelay(job.attempt)) })
                .where(and(scope(tasks, job.userId, job.conversationId), eq(tasks.jobId, job.jobId), eq(tasks.revision, job.revision),
                    eq(tasks.attempts, job.attempt), eq(tasks.status, "awaiting")));
        }
        return true;
    }

    async complete(raw: unknown) {
        const parsed = summaryResultSchema.safeParse(raw);
        if (!parsed.success) return "invalid";
        const result = parsed.data;
        return this.database.transaction(async tx => {
            const [owner] = await tx.select({ id: users.id }).from(users).where(eq(users.id, result.userId)).for("update");
            if (!owner) return "discarded";
            const where = scope(tasks, result.userId, result.conversationId);
            const [task] = await tx.select().from(tasks).where(where).for("update");
            if (!task || task.jobId !== result.jobId || task.revision !== result.revision || task.attempts !== result.attempt ||
                task.model !== result.model || !["awaiting", "retry"].includes(task.status)) return "discarded";
            if (result.status === "failure") {
                if (task.status === "retry") return "discarded";
                const status = result.error !== "inference_failed" || task.attempts === 5 ? "failed" : "retry";
                await tx.update(tasks).set({ status, lastError: result.error, nextAttemptAt: new Date(+this.clock() + retryDelay(task.attempts)) }).where(where);
                return status;
            }
            if (result.status === "skipped") {
                await tx.update(tasks).set({ ...clearJob, status: task.dirty ? "pending" : "idle", nextAttemptAt: this.clock() }).where(where);
                return "skipped";
            }
            if (!task.sourceIds?.includes(result.throughMessageId) || result.outputTokens > task.policy!.maxOutputTokens) return "invalid";
            // Re-read the contiguous prefix, not just the boundary FK. Mutation
            // triggers fence edits/deletions and backfilled messages with revision.
            const [prior] = await tx.select().from(summaries).where(scope(summaries, task.userId, task.conversationId));
            const [boundary] = prior ? await tx.select().from(messages).where(eq(messages.id, prior.throughMessageId)) : [];
            const rows = await tx.select().from(messages).where(and(scope(messages, task.userId, task.conversationId), afterBoundary(boundary)))
                .orderBy(asc(messages.createdAt), asc(messages.id)).limit(task.sourceIds.length);
            if (rows.map(m => m.id).join() !== task.sourceIds.join()) return "discarded";
            const now = this.clock();
            await tx.insert(summaries).values({ userId: task.userId, conversationId: task.conversationId,
                summary: result.summary, throughMessageId: result.throughMessageId, createdAt: now, updatedAt: now })
                .onConflictDoUpdate({ target: [summaries.userId, summaries.conversationId],
                    set: { summary: result.summary, throughMessageId: result.throughMessageId, updatedAt: now } });
            await tx.update(tasks).set({ ...clearJob, revision: task.revision + 1, status: "pending", dirty: true,
                nextAttemptAt: now, lastError: null }).where(where);
            return "completed";
        });
    }

    /** Snapshot-consistent continuity; callers can page the tail without omission. */
    async continuity(userId: string, conversationId: string, limit = 200,
        cursor?: { createdAt: string; id: string; revision: number; historyVersion: number }) {
        z.uuid().parse(userId); z.string().min(1).max(200).parse(conversationId); z.number().int().min(1).max(500).parse(limit);
        if (cursor) { z.uuid().parse(cursor.id); z.iso.datetime({ offset: true }).parse(cursor.createdAt); }
        return this.database.transaction(async tx => {
            const [task] = await tx.select().from(tasks).where(scope(tasks, userId, conversationId));
            const revision = task?.revision ?? 0;
            const historyVersion = task?.historyVersion ?? 0;
            if (cursor && (cursor.revision !== revision || cursor.historyVersion !== historyVersion)) throw new Error("Conversation changed; restart continuity pagination");
            const [summary] = await tx.select().from(summaries).where(scope(summaries, userId, conversationId));
            const [boundary] = summary ? await tx.select().from(messages).where(eq(messages.id, summary.throughMessageId)) : [];
            const rows = await tx.select().from(messages).where(and(scope(messages, userId, conversationId), afterBoundary(boundary),
                cursor ? afterBoundary({ id: cursor.id, createdAt: new Date(cursor.createdAt) }) : undefined))
                .orderBy(asc(messages.createdAt), asc(messages.id)).limit(limit + 1);
            const tail = rows.slice(0, limit), last = tail.at(-1);
            return { summary: summary ?? null, messages: tail, revision, historyVersion,
                nextCursor: rows.length > limit && last ? { id: last.id, createdAt: last.createdAt.toISOString(), revision, historyVersion } : null };
        }, { isolationLevel: "repeatable read", accessMode: "read only" });
    }

    /** Compatibility for explicit summaries: fence asynchronous jobs and never regress. */
    async putManual(userId: string, candidate: SummaryInput) {
        const input = summaryInputSchema.parse(candidate);
        return this.database.transaction(async tx => {
            const [owner] = await tx.select({ id: users.id }).from(users).where(eq(users.id, userId)).for("update");
            if (!owner) throw new Error("Conversation is unavailable");
            const where = scope(tasks, userId, input.conversationId);
            const [task] = await tx.select().from(tasks).where(where).for("update");
            if (!task) throw new Error("Conversation is unavailable");
            const [source] = await tx.select().from(messages).where(and(scope(messages, userId, input.conversationId), eq(messages.id, input.throughMessageId)));
            if (!source) throw new Error("Summary boundary is unavailable");
            const [current] = await tx.select().from(summaries).innerJoin(messages, eq(messages.id, summaries.throughMessageId))
                .where(scope(summaries, userId, input.conversationId));
            if (current && (+source.createdAt < +current.chat_messages.createdAt || (+source.createdAt === +current.chat_messages.createdAt && source.id < current.chat_messages.id))) {
                throw new Error("Summary boundary cannot move backwards");
            }
            const [row] = await tx.insert(summaries).values({ ...input, userId, updatedAt: this.clock() })
                .onConflictDoUpdate({ target: [summaries.userId, summaries.conversationId], set: { ...input, updatedAt: this.clock() } }).returning();
            await tx.update(tasks).set({ ...clearJob, revision: task.revision + 1, status: "pending", dirty: true, nextAttemptAt: this.clock() }).where(where);
            return row!;
        });
    }
}

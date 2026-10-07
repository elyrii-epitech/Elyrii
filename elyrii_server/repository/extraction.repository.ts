import { createHash } from "node:crypto";
import { and, desc, eq, inArray, lt, lte, or } from "drizzle-orm";
import { db } from "../config/db.config";
import { extractionJobs as jobs, extractionKeys as keys } from "../config/db/extraction.table";
import { userTable as users } from "../config/db/user.table";
import { chatMessagesTable as messages } from "../config/db/chat.table";
import { userContextFactsTable as facts, userMemoriesTable as memories } from "../config/db/context.table";
import { ContextPolicy } from "../modules/context/context.policy";
import { canonical, extractionJobSchema, extractionResultSchema, MAX_ATTEMPTS, retryDelay, supportedBySource,
    type ExtractionJob, type Proposal } from "../modules/context/extraction.contracts";

const pending = ["pending", "retry", "awaiting"];
const memoryKey = (p: Proposal) => {
    const c = p.candidate;
    if (c.kind !== "memory") return `fact:${c.key}`;
    return `memory:${createHash("sha256").update(canonical([c.content, c.retention, c.eventAt])).digest("hex")}`;
};

export class ExtractionRepository {
    constructor(private readonly database: typeof db = db, private readonly policy = new ContextPolicy()) {}

    /** Commit the lease before publishing. A crash at either side is recoverable. */
    async claim(): Promise<ExtractionJob | null> {
        return this.database.transaction(async tx => {
            const now = this.policy.now();
            const [job] = await tx.select().from(jobs).where(and(inArray(jobs.status, pending), lte(jobs.nextAttemptAt, now)))
                .orderBy(jobs.nextAttemptAt, jobs.sequence).limit(1).for("update", { skipLocked: true });
            if (!job) return null;
            if (job.attempts >= MAX_ATTEMPTS) {
                await tx.update(jobs).set({ status: "failed", lastError: "attempts_exhausted", completedAt: now }).where(eq(jobs.id, job.id));
                return null;
            }
            const [source] = await tx.select().from(messages).where(and(eq(messages.id, job.sourceMessageId),
                eq(messages.userId, job.userId), eq(messages.conversationId, job.conversationId), eq(messages.role, "user")));
            const [owner] = await tx.select().from(users).where(eq(users.id, job.userId));
            if (!source || !owner || owner.contextGeneration !== job.generation) {
                await tx.update(jobs).set({ status: "discarded", completedAt: now }).where(eq(jobs.id, job.id));
                return null;
            }
            const history = await tx.select().from(messages).where(and(eq(messages.userId, job.userId),
                eq(messages.conversationId, job.conversationId), eq(messages.role, "user"),
                or(lt(messages.createdAt, source.createdAt), and(eq(messages.createdAt, source.createdAt), lt(messages.id, source.id)))))
                .orderBy(desc(messages.createdAt), desc(messages.id)).limit(12);
            const input: ExtractionJob["input"] = { source: { id: source.id, role: "user", content: source.message,
                messageAt: source.createdAt.toISOString() }, context: [], timezone: job.timezone };
            for (const row of history) {
                if (row.message.length > 4000 || !row.message.trim()) continue;
                const context = [{ id: row.id, role: "user" as const, content: row.message, messageAt: row.createdAt.toISOString() }, ...input.context];
                if (Buffer.byteLength(JSON.stringify({ ...input, context })) > 23000) break;
                input.context = context;
            }
            const parsed = extractionJobSchema.safeParse({ version: 1, jobId: job.id, requestId: job.requestId,
                userId: job.userId, conversationId: job.conversationId, sourceMessageId: job.sourceMessageId,
                extractorVersion: job.extractorVersion, attempt: job.attempts + 1, input });
            if (!parsed.success) {
                await tx.update(jobs).set({ status: "failed", lastError: "invalid_input", completedAt: now }).where(eq(jobs.id, job.id));
                return null;
            }
            await tx.update(jobs).set({ status: "awaiting", attempts: parsed.data.attempt,
                nextAttemptAt: new Date(+now + 120_000 + retryDelay(parsed.data.attempt)), lastError: null }).where(eq(jobs.id, job.id));
            return parsed.data;
        });
    }

    async publishNext(publish: (job: ExtractionJob) => Promise<void>) {
        const job = await this.claim();
        if (!job) return false;
        try { await publish(job); }
        catch {
            // Fence the update: a fast result or another lease may already have won.
            await this.database.update(jobs).set({ status: job.attempt >= MAX_ATTEMPTS ? "failed" : "retry",
                nextAttemptAt: new Date(+this.policy.now() + retryDelay(job.attempt)), lastError: "publish_failed",
                completedAt: job.attempt >= MAX_ATTEMPTS ? this.policy.now() : null })
                .where(and(eq(jobs.id, job.jobId), eq(jobs.attempts, job.attempt), eq(jobs.status, "awaiting")));
        }
        return true;
    }

    async complete(raw: unknown): Promise<"completed" | "discarded" | "invalid" | "retry" | "failed"> {
        const parsed = extractionResultSchema.safeParse(raw);
        if (!parsed.success) return "invalid";
        const result = parsed.data;
        return this.database.transaction(async tx => {
            const [owner] = await tx.select().from(users).where(eq(users.id, result.userId)).for("update");
            if (!owner) return "discarded";
            const [job] = await tx.select().from(jobs).where(and(eq(jobs.id, result.jobId), eq(jobs.userId, owner.id))).for("update");
            if (!job || job.requestId !== result.requestId || job.sourceMessageId !== result.sourceMessageId ||
                job.conversationId !== result.conversationId || job.extractorVersion !== result.extractorVersion ||
                job.attempts !== result.attempt || !["awaiting", "retry"].includes(job.status)) return "discarded";
            const now = this.policy.now();
            const finish = async (status: string, lastError: string | null = null) => {
                await tx.update(jobs).set({ status, lastError, completedAt: now }).where(eq(jobs.id, job.id));
            };
            const [source] = await tx.select().from(messages).where(and(eq(messages.id, job.sourceMessageId),
                eq(messages.userId, owner.id), eq(messages.conversationId, job.conversationId), eq(messages.role, "user"))).for("key share");
            if (!source || owner.contextGeneration !== job.generation) {
                await finish("discarded"); return "discarded";
            }
            if (result.status === "failure") {
                if (job.status === "retry") return "discarded";
                const terminal = result.error === "invalid_input" || job.attempts >= MAX_ATTEMPTS;
                await tx.update(jobs).set({ status: terminal ? "failed" : "retry", lastError: result.error,
                    completedAt: terminal ? now : null, nextAttemptAt: new Date(+now + retryDelay(job.attempts)) }).where(eq(jobs.id, job.id));
                return terminal ? "failed" : "retry";
            }
            const proposals = new Map<string, Proposal>();
            for (const proposal of result.output.candidates) {
                const key = memoryKey(proposal);
                const previous = proposals.get(key);
                if (!supportedBySource(proposal, source) || (previous && canonical(previous.candidate) !== canonical(proposal.candidate))) {
                    await finish("failed", "invalid_candidates"); return "invalid";
                }
                proposals.set(key, proposal);
            }
            for (const [key, proposal] of proposals) {
                // Storage DTOs have no certainty field. Do not promote tentative
                // proposals into authoritative context by dropping that metadata.
                if (proposal.certainty === "uncertain") continue;
                const [watermark] = await tx.select().from(keys).where(and(eq(keys.userId, owner.id), eq(keys.key, key)));
                if (watermark && watermark.sequence >= job.sequence) continue;
                const c = proposal.candidate;
                let targetId: string;
                if (c.kind === "memory") {
                    // Exact content dedup only. Distinct life events must not be merged heuristically.
                    const existing = await tx.select().from(memories).where(and(eq(memories.userId, owner.id),
                        eq(memories.content, c.content), eq(memories.retention, c.retention), eq(memories.status, "active")));
                    const same = existing.find(m => (m.eventAt?.toISOString() ?? null) === (c.eventAt ? new Date(c.eventAt).toISOString() : null));
                    if (same) targetId = same.id;
                    else {
                        const [row] = await tx.insert(memories).values({ userId: owner.id, content: c.content,
                            origin: c.origin, retention: c.retention, sourceMessageId: source.id,
                            ...this.policy.memoryTimes({ ...c, eventAt: c.eventAt ? new Date(c.eventAt) : null }, now),
                            createdAt: now, updatedAt: now }).returning();
                        targetId = row!.id;
                    }
                } else {
                    const [current] = await tx.select().from(facts).where(and(eq(facts.userId, owner.id), eq(facts.key, c.key), eq(facts.status, "active")));
                    // Respect explicit repository corrections made after this job's source.
                    if (current && current.id !== watermark?.targetId && current.updatedAt > job.createdAt) continue;
                    if (current && current.kind === c.kind && canonical(current.value) === canonical(c.value)) targetId = current.id;
                    else {
                        if (current) await tx.update(facts).set({ status: "superseded", updatedAt: now }).where(eq(facts.id, current.id));
                        const [row] = await tx.insert(facts).values({ userId: owner.id, kind: c.kind, key: c.key, value: c.value,
                            origin: c.origin, sourceMessageId: source.id, validFrom: now, createdAt: now, updatedAt: now }).returning();
                        targetId = row!.id;
                    }
                }
                await tx.insert(keys).values({ userId: owner.id, key, sequence: job.sequence, targetId })
                    .onConflictDoUpdate({ target: [keys.userId, keys.key], set: { sequence: job.sequence, targetId } });
            }
            await finish("completed");
            return "completed";
        });
    }
}

import { randomUUID } from "node:crypto";
import { and, asc, eq, gt, inArray, lte, or, sql } from "drizzle-orm";
import { z } from "zod";
import { db } from "../config/db.config";
import { embeddingModels as models, embeddingJobs as jobs, embeddingBackfills as scans } from "../config/db/embedding.table";
import { userMemoriesTable as memories, memoryEmbeddingsTable as vectors } from "../config/db/context.table";
import { embeddingModelSchema, embeddingJobSchema, embeddingResultSchema, type EmbeddingModel, type EmbeddingJob } from "../modules/context/embedding.contracts";
import { retryDelay } from "../modules/context/extraction.contracts";
import { ContextPolicy } from "../modules/context/context.policy";

type Tx = Parameters<Parameters<typeof db.transaction>[0]>[0];
type Memory = typeof memories.$inferSelect;
const pending = ["pending", "retry", "awaiting"];
const key = (memoryId: string, model: string) => and(eq(jobs.memoryId, memoryId), eq(jobs.model, model));

export class EmbeddingRepository {
    readonly spec: EmbeddingModel;
    constructor(spec: EmbeddingModel, private readonly database: typeof db = db, private readonly clock = () => new Date()) {
        this.spec = embeddingModelSchema.parse(spec);
    }
    private eligible(memory: Memory, now = this.clock()) {
        return memory.status === "active" && memory.validFrom <= now && (!memory.validUntil || memory.validUntil > now) && (!memory.expiresAt || memory.expiresAt > now);
    }
    async register() {
        await this.database.transaction(async tx => {
            await tx.insert(models).values(this.spec).onConflictDoNothing();
            const [stored] = await tx.select().from(models).where(eq(models.id, this.spec.id));
            for (const [field, value] of Object.entries(this.spec)) {
                if (stored?.[field as keyof typeof stored] !== value) throw new Error("Embedding model version metadata changed");
            }
            if (!stored!.enabled) throw new Error("Embedding model disabled");
            await tx.insert(scans).values({ model: this.spec.id }).onConflictDoNothing();
        });
    }
    /** Explicit new scan; repeated process startup uses register() to resume instead. */
    async startBackfill(rebuild = false) {
        await this.database.insert(scans).values({ model: this.spec.id, rebuild })
            .onConflictDoUpdate({ target: scans.model, set: { afterId: null, done: false, rebuild } });
    }
    private async enqueue(tx: Tx, memory: Memory, force: boolean) {
        const where = key(memory.id, this.spec.id);
        const [old] = await tx.select().from(jobs).where(where);
        if (!force && old && old.contentRevision === memory.contentRevision && ["pending", "retry", "awaiting", "failed"].includes(old.status)) return;
        if (force) await tx.delete(vectors).where(and(eq(vectors.memoryId, memory.id), eq(vectors.model, this.spec.id)));
        const update = { userId: memory.userId, contentRevision: memory.contentRevision, jobId: randomUUID(), status: "pending",
            attempts: 0, nextAttemptAt: new Date(Math.max(+this.clock(), +memory.validFrom)), lastError: null };
        await tx.insert(jobs).values({ memoryId: memory.id, model: this.spec.id, ...update })
            .onConflictDoUpdate({ target: [jobs.memoryId, jobs.model], set: update });
    }
    /** Cursor and enqueued work commit together. New/changed rows are also covered by triggers. */
    async backfillBatch(limit = 100) {
        z.number().int().min(1).max(500).parse(limit);
        return this.database.transaction(async tx => {
            const [scan] = await tx.select().from(scans).where(eq(scans.model, this.spec.id)).for("update");
            if (!scan || scan.done) return false;
            const rows = await tx.select().from(memories).where(scan.afterId ? gt(memories.id, scan.afterId) : undefined)
                .orderBy(asc(memories.id)).limit(limit).for("update");
            for (const memory of rows) {
                const start = new Date(Math.max(+this.clock(), +memory.validFrom));
                if (memory.status !== "active" || (memory.expiresAt && memory.expiresAt <= start) || (memory.validUntil && memory.validUntil <= start)) continue;
                const [vector] = await tx.select().from(vectors).where(and(eq(vectors.memoryId, memory.id), eq(vectors.model, this.spec.id),
                    eq(vectors.contentRevision, memory.contentRevision), eq(vectors.dimensions, this.spec.dimensions)));
                if (scan.rebuild || !vector) await this.enqueue(tx, memory, scan.rebuild);
            }
            await tx.update(scans).set({ afterId: rows.at(-1)?.id ?? scan.afterId, done: rows.length < limit }).where(eq(scans.model, this.spec.id));
            return rows.length > 0;
        });
    }
    async retryFailed(limit = 100) {
        z.number().int().min(1).max(500).parse(limit);
        const failed = await this.database.select().from(jobs).where(and(eq(jobs.model, this.spec.id), eq(jobs.status, "failed")))
            .orderBy(jobs.memoryId).limit(limit);
        for (const failedJob of failed) await this.database.transaction(async tx => {
            const [memory] = await tx.select().from(memories).where(eq(memories.id, failedJob.memoryId)).for("update");
            const [job] = await tx.select().from(jobs).where(key(failedJob.memoryId, this.spec.id)).for("update");
            if (memory && job?.status === "failed") {
                if (this.eligible(memory)) await this.enqueue(tx, memory, true);
                else await tx.update(jobs).set({ status: "discarded" }).where(key(memory.id, this.spec.id));
            }
        });
        return failed.length;
    }
    /** Time-based expiry cannot fire a row trigger; remove the derived cache in bounded batches. */
    async prune(limit = 100) {
        z.number().int().min(1).max(500).parse(limit);
        const now = this.clock();
        return this.database.transaction(async tx => {
            const rows = await tx.select({ id: memories.id }).from(memories).where(and(
                or(sql`${memories.status} <> 'active'`, gt(memories.validFrom, now), lte(memories.validUntil, now), lte(memories.expiresAt, now)),
                sql`EXISTS (SELECT 1 FROM memory_embeddings e WHERE e.memory_id = ${memories.id})`))
                .orderBy(memories.id).limit(limit).for("update", { skipLocked: true });
            for (const memory of rows) await tx.delete(vectors).where(eq(vectors.memoryId, memory.id));
            return rows.length;
        });
    }
    async claim(): Promise<EmbeddingJob | null> {
        const due = and(eq(jobs.model, this.spec.id), inArray(jobs.status, pending), lte(jobs.nextAttemptAt, this.clock()));
        const candidates = await this.database.select().from(jobs).where(due).orderBy(jobs.nextAttemptAt, jobs.memoryId).limit(20);
        for (const candidate of candidates) {
            const result = await this.database.transaction(async tx => {
                // Parent before job, matching mutation triggers and result writers.
                const [memory] = await tx.select().from(memories).where(eq(memories.id, candidate.memoryId)).for("update", { skipLocked: true });
                if (!memory) return null;
                const where = key(memory.id, this.spec.id);
                const [job] = await tx.select().from(jobs).where(and(where, due)).for("update");
                if (!job) return null;
                const [model] = await tx.select().from(models).where(eq(models.id, job.model));
                if (!model?.enabled || memory.userId !== job.userId || memory.contentRevision !== job.contentRevision || !this.eligible(memory)) {
                    await tx.update(jobs).set({ status: "discarded" }).where(where); return null;
                }
                if (job.attempts >= 5) { await tx.update(jobs).set({ status: "failed", lastError: "attempts_exhausted" }).where(where); return null; }
                const parsed = embeddingJobSchema.safeParse({ version: 1, jobId: job.jobId, memoryId: job.memoryId, userId: job.userId,
                    model: job.model, spec: this.spec, contentRevision: job.contentRevision, content: memory.content, attempt: job.attempts + 1 });
                if (!parsed.success) { await tx.update(jobs).set({ status: "failed", lastError: "invalid_input" }).where(where); return null; }
                await tx.update(jobs).set({ status: "awaiting", attempts: parsed.data.attempt, lastError: null,
                    nextAttemptAt: new Date(+this.clock() + 120000 + retryDelay(parsed.data.attempt)) }).where(where);
                return parsed.data;
            });
            if (result) return result;
        }
        return null;
    }
    async publishNext(publish: (job: EmbeddingJob) => Promise<void>) {
        await this.backfillBatch();
        await this.prune();
        const job = await this.claim();
        if (!job) return false;
        try { await publish(job); } catch {
            await this.database.update(jobs).set({ status: job.attempt === 5 ? "failed" : "retry", lastError: "publish_failed",
                nextAttemptAt: new Date(+this.clock() + retryDelay(job.attempt)) }).where(and(key(job.memoryId, job.model),
                eq(jobs.jobId, job.jobId), eq(jobs.attempts, job.attempt), eq(jobs.status, "awaiting")));
        }
        return true;
    }
    async complete(raw: unknown) {
        const parsed = embeddingResultSchema.safeParse(raw);
        if (!parsed.success || parsed.data.model !== this.spec.id) return "invalid";
        const result = parsed.data;
        return this.database.transaction(async tx => {
            const [memory] = await tx.select().from(memories).where(and(eq(memories.id, result.memoryId), eq(memories.userId, result.userId))).for("update");
            if (!memory) return "discarded";
            const where = key(memory.id, result.model);
            const [job] = await tx.select().from(jobs).where(where).for("update");
            if (!job || job.jobId !== result.jobId || job.attempts !== result.attempt || job.contentRevision !== result.contentRevision ||
                job.userId !== result.userId || !["awaiting", "retry"].includes(job.status)) return "discarded";
            const [model] = await tx.select().from(models).where(eq(models.id, result.model));
            if (!model?.enabled || memory.contentRevision !== result.contentRevision || !this.eligible(memory)) {
                await tx.update(jobs).set({ status: "discarded" }).where(where); return "discarded";
            }
            if (result.status === "failure") {
                if (job.status === "retry") return "discarded";
                const status = result.error !== "provider_failed" || job.attempts === 5 ? "failed" : "retry";
                await tx.update(jobs).set({ status, lastError: result.error, nextAttemptAt: new Date(+this.clock() + retryDelay(job.attempts)) }).where(where);
                return status;
            }
            const now = this.clock();
            const value = { contentRevision: result.contentRevision, dimensions: result.dimensions, embedding: result.embedding, updatedAt: now };
            await tx.insert(vectors).values({ memoryId: memory.id, model: result.model, ...value, createdAt: now })
                .onConflictDoUpdate({ target: [vectors.memoryId, vectors.model], set: value });
            await tx.update(jobs).set({ status: "completed", lastError: null }).where(where);
            return "completed";
        });
    }
    /** Version-specific candidates for future exact cosine search; no mixed model space. */
    async listVectors(userId: string, limit = 100) {
        z.uuid().parse(userId); z.number().int().min(1).max(500).parse(limit);
        return this.database.select({ memoryId: vectors.memoryId, model: vectors.model, contentRevision: vectors.contentRevision,
            dimensions: vectors.dimensions, embedding: vectors.embedding }).from(vectors)
            .innerJoin(memories, eq(memories.id, vectors.memoryId)).innerJoin(models, eq(models.id, vectors.model))
            .where(and(eq(vectors.model, this.spec.id), eq(vectors.dimensions, this.spec.dimensions), eq(models.enabled, true),
                eq(vectors.contentRevision, memories.contentRevision), new ContextPolicy(this.clock).memoriesEligible(userId)))
            .orderBy(memories.id).limit(limit);
    }
}

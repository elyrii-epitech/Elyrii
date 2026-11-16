import { and, eq, gte, gt, inArray, isNull, lte, sql } from "drizzle-orm";
import { db } from "../config/db.config";
import { journalExtractionJobs as jobs } from "../config/db/journal-extraction.table";
import { contextSourceEvents as events } from "../config/db/context-source.table";
import { journalEntriesTable as journals } from "../config/db/journal.table";
import { userTable as users } from "../config/db/user.table";
import { ContextPolicy } from "../modules/context/context.policy";
import { ContextSourceRepository } from "./context-source.repository";
import { canonical, retryDelay } from "../modules/context/extraction.contracts";
import { eligibleJournalProposal, journalEventDate, journalJobSchema, journalResultSchema, supportedJournalProposal, type JournalJob } from "../modules/context/journal-extraction.contracts";
const pending = ["pending", "retry", "awaiting"];

export class JournalExtractionRepository {
    constructor(private readonly database: typeof db = db, private readonly policy = new ContextPolicy(), private readonly startAt: Date | null = null) {}

    /** At most 100 events per page; explicit cursor is resumable, including skipped events. */
    async enqueuePage(options: { userId?: string; after?: string; limit?: number; backfill?: boolean } = {}) {
        if (!options.backfill && !this.startAt) return { cursor: options.after ?? null, scanned: 0 };
        if (options.backfill && !options.userId) throw new Error("Backfill requires an owner");
        const rows = await this.database.select({ event: events, timezone: users.timezone }).from(events)
            .innerJoin(users, eq(users.id, events.userId)).innerJoin(journals, and(eq(journals.id, events.sourceId), eq(journals.userId, events.userId)))
            .where(and(eq(events.kind, "journal"), eq(events.status, "pending"), inArray(events.change, ["created", "updated"]),
                eq(events.generation, users.contextGeneration), eq(events.revision, journals.contextRevision), eq(journals.contextSuppressed, false), isNull(journals.deletedAt),
                options.userId ? eq(events.userId, options.userId) : undefined, options.after ? gt(events.id, options.after) : undefined,
                options.backfill ? undefined : gte(events.createdAt, this.startAt!),
                sql`NOT EXISTS (SELECT 1 FROM journal_extraction_jobs j WHERE j.event_id = ${events.id} AND j.extractor_version = 'journal-v1')`))
            .orderBy(events.id).limit(Math.max(1, Math.min(100, options.limit ?? 20)));
        for (const row of rows) await this.database.insert(jobs).values({ eventId: row.event.id, timezone: row.timezone }).onConflictDoNothing();
        return { cursor: rows.at(-1)?.event.id ?? options.after ?? null, scanned: rows.length };
    }

    async claim(): Promise<JournalJob | null> {
        const now = this.policy.now();
        const [next] = await this.database.select({ id: jobs.id, userId: events.userId }).from(jobs).innerJoin(events, eq(events.id, jobs.eventId))
            .where(and(inArray(jobs.status, pending), lte(jobs.nextAttemptAt, now))).orderBy(jobs.nextAttemptAt, jobs.id).limit(1);
        if (!next) return null;
        return this.database.transaction(async tx => {
            const [owner] = await tx.select().from(users).where(eq(users.id, next.userId)).for("update");
            const [job] = await tx.select().from(jobs).where(and(eq(jobs.id, next.id), inArray(jobs.status, pending), lte(jobs.nextAttemptAt, now))).for("update");
            if (!job || !owner) return null;
            const fail = async (status: string, lastError: string | null = null) => { await tx.update(jobs).set({ status, lastError, completedAt: now }).where(eq(jobs.id, job.id)); return null; };
            const [event] = await tx.select().from(events).where(eq(events.id, job.eventId));
            const [source] = event ? await tx.select().from(journals).where(and(eq(journals.id, event.sourceId), eq(journals.userId, owner.id))) : [];
            if (!event || event.status !== "pending" || event.generation !== owner.contextGeneration || !source || source.contextRevision !== event.revision || source.contextSuppressed || source.deletedAt) return fail("discarded");
            if (job.attempts >= 5) return fail("failed", "attempts_exhausted");
            const parsed = journalJobSchema.safeParse({ version: 2, jobId: job.id, eventId: event.id, userId: owner.id, generation: event.generation,
                source: { kind: "journal", id: source.id, revision: source.contextRevision }, extractorVersion: job.extractorVersion, attempt: job.attempts + 1,
                input: { source: { kind: "journal", id: source.id, revision: source.contextRevision, title: source.title, body: source.content ?? "", mood: source.mood,
                    createdAt: source.createdAt?.toISOString() }, timezone: job.timezone } });
            if (!parsed.success) return fail("failed", "invalid_input");
            await tx.update(jobs).set({ status: "awaiting", attempts: parsed.data.attempt, lastError: null,
                nextAttemptAt: new Date(+now + 120000 + retryDelay(parsed.data.attempt)) }).where(eq(jobs.id, job.id));
            return parsed.data;
        });
    }
    async publishNext(publish: (job: JournalJob) => Promise<void>) {
        await this.enqueuePage();
        const job = await this.claim();
        if (!job) return false;
        try { await publish(job); } catch {
            await this.database.update(jobs).set({ status: job.attempt === 5 ? "failed" : "retry", lastError: "publish_failed",
                nextAttemptAt: new Date(+this.policy.now() + retryDelay(job.attempt)), completedAt: job.attempt === 5 ? this.policy.now() : null })
                .where(and(eq(jobs.id, job.jobId), eq(jobs.attempts, job.attempt), eq(jobs.status, "awaiting")));
        }
        return true;
    }
    async complete(raw: unknown): Promise<string> {
        const parsed = journalResultSchema.safeParse(raw);
        if (!parsed.success) return "invalid";
        const r = parsed.data;
        return this.database.transaction(async tx => {
            const [owner] = await tx.select().from(users).where(eq(users.id, r.userId)).for("update");
            if (!owner) return "discarded";
            const [job] = await tx.select().from(jobs).where(eq(jobs.id, r.jobId)).for("update");
            const [event] = await tx.select().from(events).where(and(eq(events.id, r.eventId), eq(events.userId, owner.id))).for("update");
            if (!job || !event || job.eventId !== event.id || job.extractorVersion !== r.extractorVersion || event.sourceId !== r.source.id || event.revision !== r.source.revision || event.generation !== r.generation || job.attempts !== r.attempt || !["awaiting", "retry"].includes(job.status)) return "discarded";
            const now = this.policy.now();
            const finish = async (status: string, lastError: string | null = null) => { await tx.update(jobs).set({ status, lastError, completedAt: now }).where(eq(jobs.id, job.id)); return status; };
            const [source] = await tx.select().from(journals).where(and(eq(journals.id, event.sourceId), eq(journals.userId, owner.id)));
            if (!source || event.status !== "pending" || owner.contextGeneration !== event.generation || source.contextRevision !== event.revision || source.contextSuppressed || source.deletedAt || !source.createdAt) return finish("discarded");
            if (r.status === "failure") {
                if (job.status === "retry") return "discarded";
                if (r.error === "invalid_input" || job.attempts >= 5) return finish("failed", r.error);
                await tx.update(jobs).set({ status: "retry", lastError: r.error, nextAttemptAt: new Date(+now + retryDelay(job.attempts)) }).where(eq(jobs.id, job.id));
                return "retry";
            }
            const input = { source: { kind: "journal" as const, id: source.id, revision: source.contextRevision, title: source.title, body: source.content ?? "", mood: source.mood, createdAt: source.createdAt.toISOString() }, timezone: job.timezone };
            if (r.output.candidates.some(p => !supportedJournalProposal(p, input))) return finish("failed", "invalid_candidates");
            const candidates = new Map<string, unknown>();
            for (const p of r.output.candidates) {
                if (!eligibleJournalProposal(p)) continue;
                const evidence = { field: p.field, quote: p.evidence, certainty: "certain", category: p.category,
                    temporalExpression: p.temporalExpression, eventDate: journalEventDate(p.temporalExpression, input.source.createdAt, job.timezone),
                    timezone: job.timezone, referenceAt: input.source.createdAt, extractorVersion: "journal-v1" };
                const key = canonical(p.candidate);
                if (!candidates.has(key)) candidates.set(key, { ...p.candidate, evidence });
            }
            // Nested transaction is a savepoint: evidence, context, outbox and job completion commit together.
            const applied = await new ContextSourceRepository(tx as unknown as typeof db, this.policy).apply({ version: 2,
                eventId: event.id, userId: owner.id, generation: event.generation, source: r.source, candidates: [...candidates.values()] });
            if (applied === "invalid") return finish("failed", "invalid_candidates");
            return finish(applied);
        });
    }
}

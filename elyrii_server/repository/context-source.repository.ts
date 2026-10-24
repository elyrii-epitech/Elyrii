import { and, eq } from "drizzle-orm";
import { db } from "../config/db.config";
import { userTable as users } from "../config/db/user.table";
import { contextSourceEvents as events, contextSourceVersions as versions } from "../config/db/context-source.table";
import { userContextFactsTable as facts, userMemoriesTable as memories } from "../config/db/context.table";
import { extractionKeys as keys } from "../config/db/extraction.table";
import { sourceResultSchema } from "../modules/context/source.contracts";
import { ContextPolicy } from "../modules/context/context.policy";
import { canonical } from "../modules/context/extraction.contracts";

/** Persistence boundary for a future journal consumer. No inference or dispatch runs here. */
export class ContextSourceRepository {
    constructor(private readonly database: typeof db = db, private readonly policy = new ContextPolicy()) {}

    async apply(raw: unknown): Promise<"completed" | "discarded" | "invalid"> {
        const parsed = sourceResultSchema.safeParse(raw);
        if (!parsed.success) return "invalid";
        const result = parsed.data;
        return this.database.transaction(async tx => {
            const [owner] = await tx.select().from(users).where(eq(users.id, result.userId)).for("update");
            if (!owner || owner.contextGeneration !== result.generation) return "discarded";
            const [event] = await tx.select().from(events).where(and(eq(events.id, result.eventId), eq(events.userId, owner.id))).for("update");
            if (!event || event.generation !== result.generation || event.kind !== result.source.kind || event.sourceId !== result.source.id ||
                event.revision !== result.source.revision || !["created", "updated"].includes(event.change)) return "discarded";
            const [source] = await tx.select().from(versions).where(and(eq(versions.userId, owner.id), eq(versions.kind, event.kind),
                eq(versions.sourceId, event.sourceId), eq(versions.revision, event.revision))).for("share");
            if (!source?.active || source.excluded || !source.sourceCreatedAt || source.sourceCreatedAt > this.policy.now()) return "discarded";
            if (event.status === "completed") return "completed";
            if (event.status !== "pending") return "discarded";
            const now = this.policy.now();
            const provenance = { userId: owner.id, sourceKind: source.kind, sourceId: source.sourceId, sourceRevision: source.revision,
                sourceMessageId: source.kind === "chat" ? source.sourceId : null };
            // Ambiguous duplicate fact keys in one proposal cannot pick a winner by array order.
            const proposed = new Map<string, string>();
            for (const candidate of result.candidates) if (candidate.kind !== "memory") {
                const value = canonical([candidate.kind, candidate.value]);
                if (proposed.has(candidate.key) && proposed.get(candidate.key) !== value) return "invalid";
                proposed.set(candidate.key, value);
            }
            for (const candidate of result.candidates) {
                if (candidate.origin !== "explicit") continue; // No promotion of uncertain inference.
                if (candidate.kind === "memory") {
                    const input = { ...candidate, sourceMessageId: source.sourceId, eventAt: candidate.eventAt ? new Date(candidate.eventAt) : null };
                    // A calendar date is not an exact event instant. Even in UTC-12 the
                    // day ends by the following 12:00 UTC; cap freshness at that
                    // conservative upper bound without inventing eventAt precision.
                    const latestEventAt = candidate.evidence?.eventDate
                        ? new Date(+new Date(candidate.evidence.eventDate + "T00:00:00Z") + 36 * 3600000) : undefined;
                    const times = this.policy.sourceMemoryTimes(input, now, source.sourceCreatedAt, latestEventAt);
                    if (!times) continue;
                    const existing = await tx.select().from(memories).where(and(eq(memories.userId, owner.id), eq(memories.sourceKind, source.kind),
                        eq(memories.sourceId, source.sourceId), eq(memories.sourceRevision, source.revision), eq(memories.content, candidate.content),
                        eq(memories.retention, candidate.retention), eq(memories.status, "active")));
                    if (existing.some(m => (m.eventAt?.toISOString() ?? null) === times.eventAt?.toISOString() || (!m.eventAt && !times.eventAt))) continue;
                    await tx.insert(memories).values({ ...provenance, content: candidate.content, origin: candidate.origin,
                        retention: candidate.retention, evidence: candidate.evidence, ...times, createdAt: now, updatedAt: now });
                } else {
                    const [barrier] = await tx.select().from(keys).where(and(eq(keys.userId, owner.id), eq(keys.key, `fact:${candidate.key}`)));
                    if (barrier?.suppressed) continue;
                    const [current] = await tx.select().from(facts).where(and(eq(facts.userId, owner.id), eq(facts.key, candidate.key), eq(facts.status, "active")));
                    // Journal processing order is not evidence recency. Never auto-replace an active fact;
                    // matching values also retain their original attribution. Explicit correction stays separate.
                    if (current) continue;
                    await tx.insert(facts).values({ ...provenance, key: candidate.key, kind: candidate.kind, value: candidate.value,
                        origin: candidate.origin, evidence: candidate.evidence, validFrom: now, createdAt: now, updatedAt: now });
                }
            }
            await tx.update(events).set({ status: "completed" }).where(eq(events.id, event.id));
            return "completed";
        });
    }
}

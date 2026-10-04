import { and, eq, gt, isNull, lte, or } from "drizzle-orm";
import { z } from "zod";
import { userContextFactsTable as facts, userMemoriesTable as memories } from "../../config/db/context.table";
import type { ParsedMemoryCandidate } from "./context.candidates";

export type Clock = () => Date;
const hour = 60 * 60 * 1000;
const retentionConfigSchema = z.strictObject({
    minMs: z.number().int().positive(),
    defaultMs: z.number().int().positive(),
    maxMs: z.number().int().positive(),
}).refine(c => c.minMs <= c.defaultMs && c.defaultMs <= c.maxMs, "Expected min <= default <= max retention");
export type RetentionConfig = z.infer<typeof retentionConfigSchema>;
export const defaultRetention: Readonly<RetentionConfig> = Object.freeze({ minMs: hour, defaultMs: 48 * hour, maxMs: 7 * 24 * hour });

/** One policy for storage validation and eligible reads. Times are UTC instants.
 * validFrom <= now < validUntil, and now < expiresAt. Null ends are unbounded.
 */
export class ContextPolicy {
    readonly retention: Readonly<RetentionConfig>;
    constructor(private readonly clock: Clock = () => new Date(), retention: RetentionConfig = defaultRetention) {
        this.retention = Object.freeze(retentionConfigSchema.parse(retention));
    }
    now(): Date {
        return new Date(z.date().parse(this.clock()).getTime());
    }
    validity(input: { validFrom?: Date; validUntil?: Date | null }, now: Date) {
        const validFrom = input.validFrom ?? now;
        const validUntil = input.validUntil ?? null;
        if (validUntil && validUntil <= validFrom) throw new Error("Validity end must follow its start");
        return { validFrom, validUntil };
    }
    memoryTimes(input: ParsedMemoryCandidate, now: Date) {
        let expiresAt = input.expiresAt ?? null;
        if (input.retention === "short_term") {
            expiresAt ??= new Date(now.getTime() + this.retention.defaultMs);
            const duration = expiresAt.getTime() - now.getTime();
            if (duration < this.retention.minMs || duration > this.retention.maxMs) {
                throw new Error("Short-term expiry is outside configured retention bounds");
            }
        }
        if (expiresAt && (!Number.isFinite(expiresAt.getTime()) || expiresAt <= now)) {
            throw new Error("Expiry must be a valid future instant");
        }
        return { ...this.validity(input, now), expiresAt, eventAt: input.eventAt ?? null };
    }
    factsEligible(userId: string, now = this.now()) {
        return and(eq(facts.userId, userId), eq(facts.status, "active"), lte(facts.validFrom, now),
            or(isNull(facts.validUntil), gt(facts.validUntil, now)));
    }
    memoriesEligible(userId: string, now = this.now()) {
        return and(eq(memories.userId, userId), eq(memories.status, "active"), lte(memories.validFrom, now),
            or(isNull(memories.validUntil), gt(memories.validUntil, now)),
            or(isNull(memories.expiresAt), gt(memories.expiresAt, now)));
    }
}

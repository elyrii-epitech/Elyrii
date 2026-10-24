import { z } from "zod";
import { JournalExtractionRepository } from "../repository/journal-extraction.repository";
// One bounded page per invocation. Persist the emitted cursor to resume explicitly.
const args = z.strictObject({ enabled: z.literal("true"), userId: z.uuid(), after: z.uuid().optional(),
    limit: z.coerce.number().int().min(1).max(100).default(20) }).parse({ enabled: Bun.env.JOURNAL_BACKFILL_ENABLED,
    userId: process.argv[2], after: process.argv[3] || undefined, limit: process.argv[4] || 20 });
try {
    const result = await new JournalExtractionRepository().enqueuePage({ userId: args.userId, after: args.after, limit: args.limit, backfill: true });
    console.log(JSON.stringify(result));
    process.exit(0);
} catch { console.error("journal_backfill_failed"); process.exit(1); }

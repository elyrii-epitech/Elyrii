import { JournalExtractionRepository } from "../../repository/journal-extraction.repository";
import { startDurableContextService } from "./extraction.service";
import { JOURNAL_JOBS_TOPIC, JOURNAL_RESULTS_TOPIC } from "./journal-extraction.contracts";
export function startJournalExtractionService(env = Bun.env) {
    if (env.JOURNAL_EXTRACTION_ENABLED !== "true") return;
    const raw = env.JOURNAL_EXTRACTION_START_AT;
    if (!raw || !/^\d{4}-\d{2}-\d{2}T.*(?:Z|[+-]\d\d:\d\d)$/.test(raw) || !Number.isFinite(+new Date(raw))) {
        console.error("[JournalExtraction] disabled: invalid_start_at"); return;
    }
    const repository = new JournalExtractionRepository(undefined, undefined, new Date(raw));
    return startDurableContextService({ clientId: "elyrii-journal", groupId: "elyrii-journal-results-v1",
        jobsTopic: JOURNAL_JOBS_TOPIC, resultsTopic: JOURNAL_RESULTS_TOPIC, resultLimitBytes: 65536,
        repository: {
            publishNext: publish => repository.publishNext(publish),
            complete: async raw => {
                const started = performance.now();
                const status = await repository.complete(raw);
                console.info(JSON.stringify({ component: "journal_extraction", operation: "completion", count: 1, status, durationMs: Math.round(performance.now() - started) }));
                return status;
            },
        } });
}

import { SummaryRepository } from "../../repository/summary.repository";
import { startDurableContextService } from "./extraction.service";
import { SUMMARY_JOBS_TOPIC, SUMMARY_RESULTS_TOPIC } from "./summary.contracts";

export function startSummaryService() {
    return startDurableContextService({ clientId: "elyrii-summaries", groupId: "elyrii-summary-results-v1",
        jobsTopic: SUMMARY_JOBS_TOPIC, resultsTopic: SUMMARY_RESULTS_TOPIC,
        resultLimitBytes: 100000, repository: new SummaryRepository() });
}

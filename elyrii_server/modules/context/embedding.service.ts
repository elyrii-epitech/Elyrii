import { EmbeddingRepository } from "../../repository/embedding.repository";
import { embeddingConfig, EMBEDDING_JOBS_TOPIC, EMBEDDING_RESULTS_TOPIC } from "./embedding.contracts";
import { startDurableContextService } from "./extraction.service";

export async function startEmbeddingService() {
    const repository = new EmbeddingRepository(embeddingConfig());
    await repository.register();
    return startDurableContextService({ clientId: "elyrii-embeddings", groupId: `elyrii-embeddings-${repository.spec.digest}`,
        jobsTopic: EMBEDDING_JOBS_TOPIC, resultsTopic: EMBEDDING_RESULTS_TOPIC, resultLimitBytes: 100000, repository });
}

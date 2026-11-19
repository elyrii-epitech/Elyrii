import { EmbeddingRepository } from "../repository/embedding.repository";
import { embeddingConfig } from "../modules/context/embedding.contracts";

// Uses normal DB_* settings. Only embedding cache/jobs are changed, never memories.
const repository = new EmbeddingRepository(embeddingConfig());
const mode = process.argv[2] || "resume";
if (!["resume", "backfill", "rebuild", "retry"].includes(mode)) throw new Error("Usage: embedding-backfill.ts [resume|backfill|rebuild|retry]");
try {
    await repository.register();
    if (mode === "backfill" || mode === "rebuild") await repository.startBackfill(mode === "rebuild");
    if (mode === "retry") {
        while (await repository.retryFailed()) { /* bounded transactions; safe to interrupt */ }
    } else {
        while (await repository.backfillBatch()) { /* progress commits with each batch */ }
    }
    console.log(`Embedding ${mode} queued for ${repository.spec.id}. The asynchronous worker generates vectors.`);
    process.exit(0);
} catch (error) {
    console.error("Embedding maintenance failed; the committed cursor can be resumed.");
    process.exit(1);
}

import JournalService from "./src/service/journal.service";
import { runMigrations } from "./src/config/db.config";

if (!Bun.env.JOURNAL_SERVICE_PORT) {
    console.error("[ERROR] JOURNAL_SERVICE_PORT environment variable is not set");
    process.exit(1);
}

// Run migrations before starting the service
await runMigrations();

const journalService = new JournalService();

Bun.serve({
    port: Number(Bun.env.JOURNAL_SERVICE_PORT),
    fetch: journalService.getRouter.fetch.bind(journalService.getRouter),
    error(error) {
        console.error("[Journal Service Error]", error);
        return new Response("Internal Server Error", { status: 500 });
    }
});

console.log(`[INFO] Journal service running on port ${Bun.env.JOURNAL_SERVICE_PORT}`);
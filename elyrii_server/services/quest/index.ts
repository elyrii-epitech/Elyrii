import QuestService from "./src/service/quest.service";

if (!Bun.env.QUEST_SERVICE_PORT) {
    console.error("[ERROR] QUEST_SERVICE_PORT environment variable is not set");
    process.exit(1);
}

const questService = new QuestService();

Bun.serve({
    port: Number(Bun.env.QUEST_SERVICE_PORT),
    fetch: questService.getRouter.fetch.bind(questService.getRouter),
    error(error) {
        console.error("[Quest Service Error]", error);
        return new Response("Internal Server Error", { status: 500 });
    }
});

console.log(`[INFO] Quest service running on port ${Bun.env.QUEST_SERVICE_PORT}`);

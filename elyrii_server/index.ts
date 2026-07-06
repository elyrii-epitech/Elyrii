import app from "./main";
import { websocket } from "hono/bun";
import { seedChallenges } from "./seed";

Bun.serve({
    port: process.env.PORT || 3000,
    fetch: app.fetch,
    websocket,
});

// Seeding au démarrage (non bloquant)
seedChallenges().catch((e) => console.error("[seed] Erreur:", e));

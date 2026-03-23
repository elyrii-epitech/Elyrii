import AuthService from "./src/service/auth.service";
import { runMigrations } from "./src/config/db.config";

// Run migrations before starting the service
await runMigrations();

Bun.serve({
    port: Bun.env.AUTH_PORT || 3001,
    fetch: new AuthService().service.fetch
});

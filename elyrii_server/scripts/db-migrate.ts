import { drizzle } from "drizzle-orm/node-postgres";
import { migrate } from "drizzle-orm/node-postgres/migrator";
import { Pool } from "pg";
import { fileURLToPath } from "node:url";

const pool = new Pool({
    host: process.env.DB_HOST || "localhost",
    port: Number(process.env.DB_PORT || 5432),
    user: process.env.DB_USER || "postgres",
    password: process.env.DB_PASSWORD || process.env.DB_PASS || "postgres",
    database: process.env.DB_NAME || "elyrii_db",
});
try {
    await migrate(drizzle(pool), {
        migrationsFolder: fileURLToPath(new URL("../migrations", import.meta.url)),
        migrationsTable: "drizzle_migrations",
        migrationsSchema: "drizzle",
    });
    console.log("Database migrations complete.");
} finally {
    await pool.end();
}
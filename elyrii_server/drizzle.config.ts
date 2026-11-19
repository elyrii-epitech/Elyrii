import { defineConfig } from 'drizzle-kit';

export default defineConfig({
    out: "./migrations/",
    schema: "./config/db/schema.ts",
    dialect: "postgresql",
    dbCredentials: {
        host: process.env.DB_HOST || "localhost",
        port: Number(process.env.DB_PORT || 5432),
        user: process.env.DB_USER || "postgres",
        password: process.env.DB_PASSWORD || process.env.DB_PASS || "postgres",
        database: process.env.DB_NAME || "elyrii_db",
    },
    migrations: {
        table: "drizzle_migrations",
    },
});
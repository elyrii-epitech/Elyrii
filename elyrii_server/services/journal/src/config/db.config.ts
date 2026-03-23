import { drizzle } from "drizzle-orm/node-postgres";
import { migrate } from "drizzle-orm/node-postgres/migrator";
import path from "path";

/**
 * Builds the database configuration object from environment variables.
 * Falls back to sensible defaults for local development.
 */
const getDatabaseConfig = () => {
    const config = {
        host: process.env.DB_HOST || 'localhost',
        user: process.env.DB_USER || 'postgres',
        password: process.env.DB_PASS || 'postgres',
        database: process.env.DB_NAME || 'postgres',
        port: Number(process.env.DB_PORT) || 5432,
        ssl: { rejectUnauthorized: false },
    };

    if (process.env.NODE_ENV === 'production') {
        if (!process.env.DB_HOST || !process.env.DB_PASS) {
            throw new Error('Database configuration missing required values in production');
        }
    }

    return config;
};

const config = getDatabaseConfig();
const connectionString = `postgres://${config.user}:${config.password}@${config.host}:${config.port}/${config.database}`;

/**
 * Drizzle ORM database client used by the journal service.
 */
export const db = drizzle(connectionString);

/**
 * Runs the database migrations for the journal service.
 */
export const runMigrations = async () => {
    try {
        console.log("[INFO] Running database migrations for journal service...");
        await migrate(db, { migrationsFolder: path.join(__dirname, "../../.drizzle") });
        console.log("[INFO] Database migrations for journal service completed successfully");
    } catch (error) {
        console.error("[ERROR] Failed to run database migrations for journal service. Continuing startup...", error);
        // We don't re-throw here to allow the service to start even if migrations fail
        // (e.g. if the tables already exist or there's a transient connection issue)
    }
};

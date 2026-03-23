import { drizzle } from "drizzle-orm/node-postgres";

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

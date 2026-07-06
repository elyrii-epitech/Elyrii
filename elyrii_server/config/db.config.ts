import { drizzle } from "drizzle-orm/node-postgres";
import * as schema from "./db/schema";
import { Pool } from "pg";

const getDatabaseConfig = () => {
    const config = {
        host: process.env.DB_HOST || 'localhost',
        user: process.env.DB_USER || 'postgres',
        password: process.env.DB_PASSWORD || process.env.DB_PASS || 'postgres',
        database: process.env.DB_NAME || 'postgres',
        port: Number(process.env.DB_PORT) || 5432,
        ssl: { rejectUnauthorized: false },
    };

    if (process.env.NODE_ENV === 'production') {
        if (!process.env.DB_HOST || (!process.env.DB_PASSWORD && !process.env.DB_PASS)) {
            throw new Error('Database configuration missing required values in production');
        }
    }

    return config;
};

const config = getDatabaseConfig();
const pool = new Pool({
    host: config.host,
    port: config.port,
    user: config.user,
    password: config.password,
    database: config.database,
    ssl: process.env.NODE_ENV === 'production' ? config.ssl : false,
});

/**
 * Drizzle ORM database client with schema support.
 */
export const db = drizzle(pool, { schema });

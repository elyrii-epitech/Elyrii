import { drizzle as neonDrizzle } from "drizzle-orm/neon-http";
import { drizzle as pgDrizzle } from "drizzle-orm/node-postgres";
import * as schema from "./db/schema";
import { neon } from "@neondatabase/serverless";
import { Pool } from "pg";
import type { NodePgDatabase } from "drizzle-orm/node-postgres"; // Correct import
import type { NeonHttpDatabase } from "drizzle-orm/neon-http";

const getDatabaseConfig = () => {
    const config = {
        host: process.env.DATABASE_HOST || 'localhost',
        user: process.env.DATABASE_USER || 'postgres',
        password: process.env.DATABASE_PASSWORD || 'postgres',
        database: process.env.DATABASE_NAME || 'postgres',
        port: 5432,
        ssl: { rejectUnauthorized: false },
    }

    if (process.env.NODE_ENV === 'production') {
        if (!process.env.DATABASE_HOST || !process.env.DATABASE_PASSWORD) {
            throw new Error('Database configuration missing required values in production');
        }
    }

    return config;
};

const config = getDatabaseConfig();
const connectionString = `postgres://${config.user}:${config.password}@${config.host}:${config.port}/${config.database}`;

type Schema = typeof schema;

export function getDb(): NodePgDatabase<Schema> | NeonHttpDatabase<Schema> {
    if (process.env.NODE_ENV === 'development') {
        const pool = new Pool({ connectionString });
        return pgDrizzle(pool, { schema }) as NodePgDatabase<Schema>;
    } if (process.env.NODE_ENV === 'production' || process.env.NODE_ENV === 'staging') {
        const sql = neon(connectionString);
        return neonDrizzle(sql, { schema }) as NeonHttpDatabase<Schema>;
    } else {
        const sql = neon(connectionString);
        return neonDrizzle(sql, { schema }) as NeonHttpDatabase<Schema>;
    }
}

export const db = getDb();
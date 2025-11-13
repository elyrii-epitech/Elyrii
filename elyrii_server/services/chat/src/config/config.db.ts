import { drizzle } from "drizzle-orm/node-postgres";

const getDatabaseConfig = () => {
    const config = {
        host: process.env.DB_HOST || 'localhost',
        user: process.env.DB_USER || 'postgres',
        password: process.env.DB_PASS || 'postgres',
        database: process.env.DB_NAME || 'postgres',
        port: 5432,
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
const connectionString = `postgres://${config.user}:${config.password}@${config.host}:${config.port}/${config.database}?sslmode=require`;

export const db = drizzle(connectionString);
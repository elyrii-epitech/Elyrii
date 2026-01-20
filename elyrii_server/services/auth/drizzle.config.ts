import { defineConfig } from "drizzle-kit";

export default defineConfig({
    out: './.drizzle/',
    schema: 'src/config/db/',
    dialect: "postgresql",
    dbCredentials: {
        url: `postgres://${process.env.DB_USER}:${process.env.DB_PASS}@${process.env.DB_HOST}:${process.env.DB_PORT}/${process.env.DB_NAME}`,
        ssl: { rejectUnauthorized: false }
    }
})

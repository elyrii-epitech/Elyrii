/** Explicit adoption of a database previously managed with db:push.
 * Verify columns, defaults, constraints and indexes against migration 0000 in
 * a disposable schema before recording it. Any mismatch rolls everything back.
 */
import { createHash, randomUUID } from "node:crypto";
import { readFile } from "node:fs/promises";
import { Client } from "pg";

const sql = await readFile(new URL("../migrations/0000_existing_schema.sql", import.meta.url), "utf8");
const journal = JSON.parse(await readFile(new URL("../migrations/meta/_journal.json", import.meta.url), "utf8"));
const baseline = journal.entries[0];
if (baseline?.tag !== "0000_existing_schema") throw new Error("Unexpected baseline migration");

const client = new Client({
    host: process.env.DB_HOST || "localhost",
    port: Number(process.env.DB_PORT || 5432),
    user: process.env.DB_USER || "postgres",
    password: process.env.DB_PASSWORD || process.env.DB_PASS || "postgres",
    database: process.env.DB_NAME || "elyrii_db",
});
const scratch = `baseline_${randomUUID().replaceAll("-", "")}`;

async function describe(schema: string) {
    // pg_catalog search_path makes deparsed references schema-qualified.
    const { rows } = await client.query(`
        SELECT c.relname AS name,
          (SELECT jsonb_agg(jsonb_build_array(a.attname, format_type(a.atttypid, a.atttypmod),
                    a.attnotnull, pg_get_expr(d.adbin, d.adrelid)) ORDER BY a.attname)
           FROM pg_attribute a LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
           WHERE a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped) AS columns,
          (SELECT jsonb_agg(pg_get_constraintdef(k.oid) ORDER BY pg_get_constraintdef(k.oid))
           FROM pg_constraint k WHERE k.conrelid = c.oid) AS constraints,
          (SELECT jsonb_agg(pg_get_indexdef(i.indexrelid) ORDER BY pg_get_indexdef(i.indexrelid))
           FROM pg_index i WHERE i.indrelid = c.oid) AS indexes
        FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = $1 AND c.relkind = 'r' ORDER BY c.relname`, [schema]);
    return JSON.stringify(rows).replaceAll(`${schema}.`, "public.");
}

await client.connect();
try {
    await client.query("BEGIN");
    await client.query("CREATE SCHEMA IF NOT EXISTS drizzle");
    await client.query(`CREATE TABLE IF NOT EXISTS drizzle.drizzle_migrations (
        id serial PRIMARY KEY, hash text NOT NULL, created_at bigint)`);
    await client.query("LOCK TABLE drizzle.drizzle_migrations IN EXCLUSIVE MODE");
    const { rows } = await client.query("SELECT 1 FROM drizzle.drizzle_migrations LIMIT 1");
    if (rows.length) throw new Error("Migration history already exists; use db:migrate instead");

    await client.query(`CREATE SCHEMA "${scratch}"`);
    await client.query(`SET LOCAL search_path TO "${scratch}"`);
    await client.query(sql.replaceAll('"public".', `"${scratch}".`));
    await client.query("SET LOCAL search_path TO pg_catalog");
    if (await describe("public") !== await describe(scratch)) {
        throw new Error("Database differs from migration 0000. No baseline recorded. Reconcile the schema before retrying.");
    }
    await client.query(`DROP SCHEMA "${scratch}" CASCADE`);
    await client.query("INSERT INTO drizzle.drizzle_migrations (hash, created_at) VALUES ($1, $2)",
        [createHash("sha256").update(sql).digest("hex"), baseline.when]);
    await client.query("COMMIT");
    console.log("Existing schema verified and baseline recorded. Run db:migrate next.");
} catch (error) {
    await client.query("ROLLBACK");
    throw error;
} finally {
    await client.end();
}
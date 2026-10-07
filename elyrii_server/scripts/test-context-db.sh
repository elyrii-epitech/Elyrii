#!/usr/bin/env bash
# Isolated databases on tmpfs; never connects to an application database.
set -euo pipefail
cd "$(dirname "$0")/.."
container="elyrii-context-test-$$"
image="elyrii-context-migrations-test"
cleanup() {
    local result=$?
    if [ "$result" -ne 0 ]; then docker logs "$container" 2>&1 || true; fi
    docker rm -f "$container" >/dev/null 2>&1 || true
}
trap cleanup EXIT
docker build --target db-migrations -t "$image" .
docker run -d --name "$container" --tmpfs /var/lib/postgresql/data \
    -e POSTGRES_USER=context_test -e POSTGRES_PASSWORD=test -e POSTGRES_DB=fresh \
    -v "$PWD/init_dbs.sh:/docker-entrypoint-initdb.d/init_dbs.sh:ro" \
    pgvector/pgvector:0.8.6-pg16-bookworm >/dev/null
ready=false
for attempt in {1..60}; do
    # TCP avoids mistaking the entrypoint's temporary initialization server for readiness.
    if docker exec "$container" pg_isready -h 127.0.0.1 -U context_test -d fresh >/dev/null 2>&1; then
        ready=true
        break
    fi
    sleep 1
done
if [ "$ready" != true ]; then docker logs "$container"; exit 1; fi
run() {
    local database=$1
    shift
    docker run --rm --network "container:$container" -e DB_HOST=127.0.0.1 \
        -e DB_USER=context_test -e DB_PASSWORD=test -e DB_NAME="$database" "$image" "$@"
}
psql_test() {
    local database=$1
    shift
    docker exec -i "$container" psql -U context_test -d "$database" -v ON_ERROR_STOP=1 "$@"
}
run fresh bun run db:migrate
run fresh bun run db:migrate
# Reuse the image's locked dependencies; mount only application source under test.
docker run --rm --network "container:$container" -e DB_HOST=127.0.0.1 \
    -e DB_USER=context_test -e DB_PASSWORD=test -e DB_NAME=fresh -e CONTEXT_DB_TEST=1 \
    -v "$PWD/repository:/app/repository:ro" -v "$PWD/modules/context:/app/modules/context:ro" \
    -v "$PWD/config:/app/config:ro" -v "$PWD/../elyrii_ai/test/fixtures:/elyrii_ai/test/fixtures:ro" "$image" \
    bun test modules/context repository/context.repository.test.ts repository/extraction.repository.test.ts
psql_test fresh < scripts/test-context-schema.sql

psql_test fresh -c 'CREATE DATABASE upgraded'
psql_test upgraded < migrations/0000_existing_schema.sql
psql_test upgraded -c "INSERT INTO users (first_name, last_name, email, password, age) VALUES ('Existing', 'User', 'existing@example.test', 'test', 30)"
psql_test upgraded -c "INSERT INTO chat_messages (user_id, role, message) SELECT id, 'user', 'Preserve this message' FROM users"
run upgraded bun run db:baseline
run upgraded bun run db:migrate
psql_test upgraded -c "DO \$\$ BEGIN IF (SELECT count(*) FROM chat_messages WHERE message = 'Preserve this message') <> 1 THEN RAISE EXCEPTION 'Existing history lost'; END IF; END \$\$"
psql_test upgraded < scripts/test-context-schema.sql

psql_test fresh -c 'CREATE DATABASE drifted'
psql_test drifted < migrations/0000_existing_schema.sql
psql_test drifted -c 'ALTER TABLE users DROP COLUMN bio'
if run drifted bun run db:baseline; then
    echo 'ERROR: Baseline accepted a mismatched schema'; exit 1
fi
psql_test drifted -c "DO \$\$ BEGIN IF to_regclass('drizzle.drizzle_migrations') IS NOT NULL THEN RAISE EXCEPTION 'Failed baseline left migration history'; END IF; END \$\$"
echo 'Context database checks passed: fresh install, repeat migration, upgrade, schema drift, constraints and cascades.'

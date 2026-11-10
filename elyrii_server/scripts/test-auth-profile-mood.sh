#!/usr/bin/env bash
# Starts only disposable local services; never reads a production .env.
set -euo pipefail
cd "$(dirname "$0")/.."
postgres_bin="${POSTGRES_BINDIR:-$(pg_config --bindir)}"
runtime="$(mktemp -d "${TMPDIR:-/tmp}/elyrii-auth-profile-mood.XXXXXX")"
export DB_HOST=127.0.0.1 DB_PORT="${MOBILE_TEST_DB_PORT:-15448}"
export DB_USER=integration_test DB_PASSWORD=fixture-local-only DB_NAME=elyrii_frontend_test
export NODE_ENV=test PORT="${MOBILE_TEST_API_PORT:-3188}"
export SECRET_KEY=local-auth-integration-secret REFRESH_SECRET_KEY=local-auth-refresh-integration-secret
export REQUIRE_EMAIL_VERIFICATION=false ENABLE_KAFKA_CONSUMERS=false KAFKAJS_NO_PARTITIONER_WARNING=1
export AUTH_PROFILE_MOOD_INTEGRATION=1 MOBILE_TEST_API_URL="http://127.0.0.1:$PORT"
export JOURNAL_INTEGRATION=1
unset PASSWORD_RESET_MAIL_WEBHOOK PASSWORD_RESET_MAIL_SECRET EMAIL_VERIFICATION_MAIL_WEBHOOK EMAIL_VERIFICATION_MAIL_SECRET
api_pid=""
cleanup() {
    result=$?
    trap - EXIT INT TERM
    if [[ -n "$api_pid" ]]; then kill "$api_pid" 2>/dev/null || true; wait "$api_pid" 2>/dev/null || true; fi
    "$postgres_bin/pg_ctl" -D "$runtime/data" -m fast -w stop >/dev/null 2>&1 || true
    if [[ "$result" -ne 0 ]]; then tail -80 "$runtime/api.log" 2>/dev/null || true; fi
    echo "Local services stopped; diagnostics: $runtime"
    exit "$result"
}
trap cleanup EXIT INT TERM
if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null ||
   lsof -nP -iTCP:"$DB_PORT" -sTCP:LISTEN >/dev/null; then
    echo "Choose unused MOBILE_TEST_API_PORT and MOBILE_TEST_DB_PORT values." >&2
    exit 1
fi
"$postgres_bin/initdb" -D "$runtime/data" --username="$DB_USER" --auth=trust --encoding=UTF8 --locale=C >/dev/null
"$postgres_bin/pg_ctl" -D "$runtime/data" -l "$runtime/postgres.log" -o "-h 127.0.0.1 -p $DB_PORT" -w start >/dev/null
"$postgres_bin/createdb" -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$DB_NAME"
# Mobile fixture: real baseline tables plus the existing user context
# generation column. The pgvector/AI migration suite is a separate check.
"$postgres_bin/psql" -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 -q -f migrations/0000_existing_schema.sql
"$postgres_bin/psql" -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 -q -c 'ALTER TABLE users ADD COLUMN context_generation integer DEFAULT 0 NOT NULL'
"$postgres_bin/psql" -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 -q -f migrations/0006_native_auth_recovery.sql
"$postgres_bin/psql" -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 -q -f migrations/0007_journal_mobile_contracts.sql
bun --no-env-file run index.ts >"$runtime/api.log" 2>&1 &
api_pid=$!
ready=false
for attempt in {1..50}; do
    if curl --silent --fail "$MOBILE_TEST_API_URL/auth/health" >/dev/null; then ready=true; break; fi
    if ! kill -0 "$api_pid" 2>/dev/null; then break; fi
    sleep 0.2
done
if [[ "$ready" != true ]]; then echo "Local API failed to start." >&2; exit 1; fi
bun --no-env-file test --timeout 30000 modules/user/auth-profile-mood.integration.test.ts modules/auth/auth-database.integration.test.ts modules/journal/journal-connected.integration.test.ts
if [[ "${RUN_FLUTTER_CONNECTED_TEST:-1}" == 1 ]]; then
    (cd ../elyrii_app && flutter test --no-pub test/frontend/auth_profile_mood_connected_test.dart test/frontend/journal_connected_test.dart \
        --dart-define=MOBILE_API_INTEGRATION=true --dart-define=MOBILE_TEST_API_URL="$MOBILE_TEST_API_URL")
fi
if [[ -n "${IOS_SIMULATOR_UDID:-}" ]]; then
    (cd ../elyrii_app && flutter test --no-pub "${IOS_CONNECTED_TEST:-integration_test/auth_profile_mood_test.dart}" \
        -d "$IOS_SIMULATOR_UDID" --dart-define=ELYRII_ENV=development --dart-define=ELYRII_API_URL="$MOBILE_TEST_API_URL")
fi

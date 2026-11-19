#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
postgres_bin="${POSTGRES_BINDIR:-$(pg_config --bindir)}"
runtime="$(mktemp -d "${TMPDIR:-/tmp}/elyrii-chat.XXXXXX")"
export DB_HOST=127.0.0.1 DB_PORT="${MOBILE_TEST_DB_PORT:-15448}"
export DB_USER=integration_test DB_PASSWORD=fixture-local-only DB_NAME=elyrii_frontend_test
export NODE_ENV=test PORT="${MOBILE_TEST_API_PORT:-3188}"
export SECRET_KEY=local-chat-access REFRESH_SECRET_KEY=local-chat-refresh
export REQUIRE_EMAIL_VERIFICATION=false ENABLE_KAFKA_CONSUMERS=true KAFKAJS_NO_PARTITIONER_WARNING=1
export ENABLE_PERSISTENT_CONTEXT=false ENABLE_EMBEDDINGS=false ENABLE_SUMMARIES=false ENABLE_CONTEXT_CLEANUP=false
export CHAT_INTEGRATION=1 MOBILE_TEST_API_URL="http://127.0.0.1:$PORT"
export KAFKA_BROKER="127.0.0.1:${CHAT_TEST_KAFKA_PORT:-19092}"
unset REDPANDA_URL KAFKA_BROKER_URL REDPANDA_HOST PASSWORD_RESET_MAIL_WEBHOOK PASSWORD_RESET_MAIL_SECRET EMAIL_VERIFICATION_MAIL_WEBHOOK EMAIL_VERIFICATION_MAIL_SECRET
export CHAT_FIXTURE_READY="$runtime/worker-ready"
api_pid="" worker_pid="" kafka_pid=""
cleanup() {
  result=$?
  trap - EXIT INT TERM
  for task_pid in "$api_pid" "$worker_pid" "$kafka_pid"; do
    if [[ -n "$task_pid" ]]; then kill "$task_pid" 2>/dev/null || true; fi
  done
  for task_pid in "$api_pid" "$worker_pid" "$kafka_pid"; do
    if [[ -n "$task_pid" ]]; then wait "$task_pid" 2>/dev/null || true; fi
  done
  "$postgres_bin/pg_ctl" -D "$runtime/data" -m fast -w stop >/dev/null 2>&1 || true
  echo "Local services stopped; diagnostics: $runtime"
  exit "$result"
}
trap cleanup EXIT INT TERM
for port in "$PORT" "$DB_PORT" "${CHAT_TEST_KAFKA_PORT:-19092}" "${CHAT_TEST_CONTROLLER_PORT:-19093}"; do
  if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null; then echo "Test port $port is occupied." >&2; exit 1; fi
done
"$postgres_bin/initdb" -D "$runtime/data" --username="$DB_USER" --auth=trust --encoding=UTF8 --locale=C >/dev/null
"$postgres_bin/pg_ctl" -D "$runtime/data" -l "$runtime/postgres.log" -o "-h 127.0.0.1 -p $DB_PORT" -w start >/dev/null
"$postgres_bin/createdb" -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$DB_NAME"
bun --no-env-file scripts/prepare-chat-fixture.ts "$runtime/context.sql"
for migration in migrations/0000_existing_schema.sql "$runtime/context.sql" migrations/0002_extraction_outbox.sql migrations/0003_rolling_summaries.sql migrations/0005_brainy_mystique.sql migrations/0006_native_auth_recovery.sql migrations/0007_journal_mobile_contracts.sql migrations/0008_chat_mobile_contracts.sql; do
  "$postgres_bin/psql" -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 -q -f "$migration"
done
cat > "$runtime/kafka.properties" <<EOF
process.roles=broker,controller
node.id=1
controller.quorum.bootstrap.servers=127.0.0.1:${CHAT_TEST_CONTROLLER_PORT:-19093}
listeners=PLAINTEXT://127.0.0.1:${CHAT_TEST_KAFKA_PORT:-19092},CONTROLLER://127.0.0.1:${CHAT_TEST_CONTROLLER_PORT:-19093}
advertised.listeners=PLAINTEXT://127.0.0.1:${CHAT_TEST_KAFKA_PORT:-19092}
controller.listener.names=CONTROLLER
listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
inter.broker.listener.name=PLAINTEXT
log.dirs=$runtime/kafka-data
num.partitions=1
offsets.topic.replication.factor=1
transaction.state.log.replication.factor=1
transaction.state.log.min.isr=1
group.initial.rebalance.delay.ms=0
num.network.threads=2
num.io.threads=2
log.segment.bytes=16777216
EOF
kafka-storage format --standalone --cluster-id "$(kafka-storage random-uuid)" --config "$runtime/kafka.properties" > "$runtime/kafka-format.log" 2>&1
KAFKA_HEAP_OPTS="-Xms128m -Xmx384m" kafka-server-start "$runtime/kafka.properties" > "$runtime/kafka.log" 2>&1 &
kafka_pid=$!
for attempt in {1..150}; do
  if lsof -nP -iTCP:"${CHAT_TEST_KAFKA_PORT:-19092}" -sTCP:LISTEN >/dev/null; then break; fi
  if ! kill -0 "$kafka_pid" 2>/dev/null; then echo "Local Kafka failed; see $runtime/kafka.log"; exit 1; fi
  sleep 0.2
done
bun --no-env-file run scripts/chat-fixture-worker.ts > "$runtime/worker.log" 2>&1 &
worker_pid=$!
for attempt in {1..150}; do
  if [[ -f "$CHAT_FIXTURE_READY" ]]; then break; fi
  if ! kill -0 "$worker_pid" 2>/dev/null; then echo "Local fixture worker failed; see $runtime/worker.log"; exit 1; fi
  sleep 0.2
done
bun --no-env-file run index.ts > "$runtime/api.log" 2>&1 &
api_pid=$!
ready=false
for attempt in {1..250}; do
  if [[ -f "$CHAT_FIXTURE_READY" ]] && rg -q 'Consumer has joined.*"groupId":"chat-service"' "$runtime/api.log" &&
     curl --silent --fail "$MOBILE_TEST_API_URL/auth/health" >/dev/null; then ready=true; break; fi
  if ! kill -0 "$api_pid" 2>/dev/null || ! kill -0 "$worker_pid" 2>/dev/null; then break; fi
  sleep 0.2
done
if [[ "$ready" != true ]]; then echo "Local chat services failed to become ready; see $runtime"; exit 1; fi
bun --no-env-file test --timeout 30000 modules/chat/chat-connected.integration.test.ts
if [[ "${RUN_FLUTTER_CONNECTED_TEST:-1}" == 1 ]]; then
  (cd ../elyrii_app && flutter test --no-pub test/frontend/chat_connected_test.dart --dart-define=MOBILE_API_INTEGRATION=true --dart-define=MOBILE_TEST_API_URL="$MOBILE_TEST_API_URL")
fi
if [[ -n "${IOS_SIMULATOR_UDID:-}" ]]; then
  (cd ../elyrii_app && flutter test --no-pub integration_test/chat_connected_test.dart -d "$IOS_SIMULATOR_UDID" --dart-define=ELYRII_ENV=development --dart-define=ELYRII_API_URL="$MOBILE_TEST_API_URL" --dart-define=HOLD_CHAT_QA_FRAME="${HOLD_CHAT_QA_FRAME:-false}")
fi

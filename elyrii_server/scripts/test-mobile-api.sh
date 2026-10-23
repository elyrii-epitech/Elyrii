#!/usr/bin/env bash
set -euo pipefail

# Only use the disposable PostgreSQL fixture already prepared by CI/development.
if [[ "${DB_NAME:-}" != "elyrii_frontend_test" || "${NODE_ENV:-}" == "production" || ! "${DB_HOST:-}" =~ ^(localhost|127\.0\.0\.1)$ ]]; then
  echo 'Connected API checks require the disposable elyrii_frontend_test database.' >&2
  exit 1
fi
api_port="${MOBILE_TEST_API_PORT:-3188}"
if [[ ! "$api_port" =~ ^[0-9]+$ ]] || ((api_port < 1 || api_port > 65535)); then
  echo 'MOBILE_TEST_API_PORT must be a valid local TCP port.' >&2
  exit 1
fi
# Refuse an occupied port rather than accidentally testing another application.
bun -e 'const server = Bun.serve({hostname:"127.0.0.1", port:Number(Bun.argv[1]), fetch:() => new Response()}); server.stop(true);' "$api_port"
api_url="http://127.0.0.1:${api_port}"
api_log="$(mktemp -t elyrii-mobile-api.XXXXXX)"
NODE_ENV=test ENABLE_KAFKA_CONSUMERS=false REQUIRE_EMAIL_VERIFICATION=false \
SECRET_KEY=local-fixture-access REFRESH_SECRET_KEY=local-fixture-refresh \
PUBLIC_URL="$api_url" PORT="$api_port" bun index.ts >"$api_log" 2>&1 &
api_pid=$!
cleanup() {
  kill "$api_pid" 2>/dev/null || true
  wait "$api_pid" 2>/dev/null || true
}
trap cleanup EXIT INT TERM
ready=false
for ((attempt=0; attempt<80; attempt++)); do
  if ! kill -0 "$api_pid" 2>/dev/null; then
    cat "$api_log"
    exit 1
  fi
  if curl --fail --silent "$api_url/auth/health" >/dev/null; then
    ready=true
    break
  fi
  sleep 0.25
done
if [[ "$ready" != true ]]; then
  cat "$api_log"
  exit 1
fi
NODE_ENV=test MOBILE_API_INTEGRATION=1 MOBILE_TEST_API_URL="$api_url" \
bun test modules/account/mobile-api.integration.test.ts

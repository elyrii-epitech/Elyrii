#!/usr/bin/env bash
# Synthetic PostgreSQL lifecycle -> bridge prompt fixtures. Never uses production data.
set -euo pipefail
cd "$(dirname "$0")/../.."
export CONTEXT_EVAL_DIR="${CONTEXT_EVAL_DIR:-$(mktemp -d /tmp/elyrii-context-evaluation.XXXXXX)}"
mkdir -p "$CONTEXT_EVAL_DIR"
bash elyrii_server/scripts/test-context-db.sh
export CONTEXT_E2E_FIXTURE="$CONTEXT_EVAL_DIR/lifecycle.json"
export CONTEXT_EVAL_REPORT="$CONTEXT_EVAL_DIR/report.json"
"${EVAL_PYTHON:-python3}" -m unittest discover -s elyrii_ai/test
printf 'Synthetic evaluation report: %s\n' "$CONTEXT_EVAL_REPORT"

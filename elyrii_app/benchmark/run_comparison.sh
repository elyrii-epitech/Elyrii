#!/usr/bin/env bash
set -euo pipefail

# Run both revisions serially on the same pinned SDK, fixtures and harness.
# Output is synthetic measurements only; the detached baseline is temporary.
PERF_APP_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
PERF_REPO_DIR=$(git -C "$PERF_APP_DIR" rev-parse --show-toplevel)
PERF_BASELINE_SHA=f8f2f174ca3a8c81fe363bfda9417c1ab224565a
PERF_OUTPUT_DIR=$(realpath -m -- "${1:-$PERF_APP_DIR/build/performance}")
PERF_TMP_DIR=$(mktemp -d -t elyrii-perf.XXXXXXXX)
cleanup_performance_archive() {
  python3 - "$PERF_TMP_DIR" <<'PY'
import pathlib
import shutil
import sys
import tempfile

directory = pathlib.Path(sys.argv[1]).resolve()
if directory.parent != pathlib.Path(tempfile.gettempdir()).resolve() or not directory.name.startswith('elyrii-perf.'):
    raise RuntimeError('Refusing to remove a directory outside this benchmark archive')
shutil.rmtree(directory)
PY
}
trap cleanup_performance_archive EXIT
mkdir -p -- "$PERF_OUTPUT_DIR"

flutter --version > "$PERF_OUTPUT_DIR/sdk.txt"
git -C "$PERF_REPO_DIR" archive "$PERF_BASELINE_SHA" elyrii_app |
  tar -x -C "$PERF_TMP_DIR"
cp -R -- "$PERF_APP_DIR/benchmark" "$PERF_TMP_DIR/elyrii_app/"
cp -- "$PERF_APP_DIR/test/support/traced_database_factory.dart" \
  "$PERF_TMP_DIR/elyrii_app/test/support/"
(
  cd -- "$PERF_TMP_DIR/elyrii_app"
  flutter pub get --offline --enforce-lockfile > "$PERF_OUTPUT_DIR/baseline-pub.log" 2>&1
  flutter test --no-pub benchmark/app_performance_benchmark_test.dart \
    --concurrency=1 --reporter expanded \
    --dart-define=PERF_PHASE=baseline \
    "--dart-define=PERF_OUTPUT=$PERF_OUTPUT_DIR/before.json" \
    > "$PERF_OUTPUT_DIR/before.log" 2>&1
)
(
  cd -- "$PERF_APP_DIR"
  flutter test --no-pub benchmark/app_performance_benchmark_test.dart \
    --concurrency=1 --reporter expanded \
    --dart-define=PERF_PHASE=final \
    "--dart-define=PERF_OUTPUT=$PERF_OUTPUT_DIR/after.json" \
    > "$PERF_OUTPUT_DIR/after.log" 2>&1
)
python3 "$PERF_APP_DIR/benchmark/compare.py" "$PERF_OUTPUT_DIR"

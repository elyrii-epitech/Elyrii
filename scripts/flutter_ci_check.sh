#!/usr/bin/env bash
# Run the frontend quality checks with the Flutter SDK pinned in .fvmrc.
set -euo pipefail

FRONTEND_APP_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../elyrii_app" && pwd)
cd -- "$FRONTEND_APP_DIR"

flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test tool integration_test
dart run tool/check_design_tokens.dart
flutter analyze --no-pub
flutter test --no-pub --coverage

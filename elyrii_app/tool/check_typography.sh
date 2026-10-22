#!/usr/bin/env bash
# Screens pick an AppTextStyles role; only lib/core/theme defines sizes and fonts.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

if grep -rnE '\b(fontSize|fontFamily)[[:space:]]*:' lib --include='*.dart' | grep -v '^lib/core/theme/'; then
  echo 'Use an AppTextStyles role (lib/core/theme/app_text_styles.dart) instead of fontSize or fontFamily.' >&2
  exit 1
fi

#!/bin/bash
# Replique localement les checks de la CI/CD Flutter.
# Workflow GitHub Actions :
#   .github/workflows/flutter-check-and-docs.yml
#   .github/workflows/flutter-build.yml
#
# Etapes :
#   1. dart format --set-exit-if-changed .
#   2. flutter analyze
#   3. flutter test
#
# Usage :
#   ./scripts/flutter_ci_check.sh
#
# Sortie de code 0 = tout passe, 1 = au moins un check a echoue.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR/../elyrii_app"

cd "$APP_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS=0
FAIL=0

run_check() {
  local name="$1"
  local cmd="$2"
  echo ""
  echo "──────────────────────────────────────────"
  echo "  $name"
  echo "──────────────────────────────────────────"
  if eval "$cmd"; then
    echo -e "${GREEN}  -> PASS${NC}"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}  -> FAIL${NC}"
    FAIL=$((FAIL + 1))
  fi
}

echo "=========================================="
echo "  Elyrii Flutter CI/CD - Checks locaux"
echo "=========================================="

run_check \
  "1/3  Formatage (dart format)" \
  "dart format --set-exit-if-changed ."

run_check \
  "2/3  Analyse statique (flutter analyze)" \
  "flutter analyze"

run_check \
  "3/3  Tests (flutter test)" \
  "flutter test"

echo ""
echo "=========================================="
echo "  Resultat : ${PASS} reussi(s), ${FAIL} echec(s)"
echo "=========================================="

if [ "$FAIL" -gt 0 ]; then
  echo -e "${RED}ECHEC : corrige les erreurs ci-dessus avant de push.${NC}"
  exit 1
else
  echo -e "${GREEN}SUCCES : le code passe la CI/CD.${NC}"
  exit 0
fi

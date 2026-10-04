#!/bin/bash
set -euo pipefail

# The upstream entrypoint creates POSTGRES_DB; migrations also cover old volumes.
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  -c 'CREATE EXTENSION IF NOT EXISTS vector;'

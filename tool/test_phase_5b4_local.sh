#!/bin/sh
set -eu

workspace_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$workspace_root"

db_container='supabase_db_avaryn-flutterflow-workspace'
status_file=$(mktemp "${TMPDIR:-/tmp}/avaryn-phase5b4-status.XXXXXX")
trap 'rm -f "$status_file"' EXIT HUP INT TERM

run_sql() {
  docker exec -i "$db_container" \
    psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 \
    -f /dev/stdin < "$1"
}

run_sql supabase/tests/phase_4c5_media.sql
docker exec -i "$db_container" \
  psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -v avaryn_local_test=1 -f /dev/stdin \
  < supabase/tests/phase_5b4_media_alpha_acceptance.sql

ITERATIONS=50 ruby supabase/tests/phase_4c5_media_concurrency.rb \
  "$db_container"

.flutterflow/sdk/bin/supabase status -o env > "$status_file"
ruby supabase/tests/phase_4c5_media_integration.rb "$status_file"

if command -v flutterflow >/dev/null 2>&1; then
  PATH="$workspace_root/.flutterflow/sdk/flutter/bin:$PATH" \
    flutterflow ai test
else
  PATH="$workspace_root/.flutterflow/sdk/flutter/bin:$PATH" \
    .flutterflow/sdk/flutter/bin/dart pub global run \
      flutterflow_cli:flutterflow_cli ai test
fi

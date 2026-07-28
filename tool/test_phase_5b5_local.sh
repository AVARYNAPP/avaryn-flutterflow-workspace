#!/bin/sh
set -eu

workspace_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$workspace_root"

db_container='supabase_db_avaryn-flutterflow-workspace'

docker exec -i "$db_container" \
  psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -f /dev/stdin < supabase/tests/phase_4c6_realtime_offline_sync.sql

ITERATIONS=50 ruby \
  supabase/tests/phase_4c6_realtime_offline_sync_concurrency.rb \
  "$db_container"

if command -v flutterflow >/dev/null 2>&1; then
  PATH="$workspace_root/.flutterflow/sdk/flutter/bin:$PATH" \
    flutterflow ai test
else
  PATH="$workspace_root/.flutterflow/sdk/flutter/bin:$PATH" \
    .flutterflow/sdk/flutter/bin/dart pub global run \
      flutterflow_cli:flutterflow_cli ai test
fi

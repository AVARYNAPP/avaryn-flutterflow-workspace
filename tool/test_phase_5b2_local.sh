#!/bin/sh
set -eu

workspace_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$workspace_root"

db_container='supabase_db_avaryn-flutterflow-workspace'

run_sql() {
  docker exec -i "$db_container" \
    psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 \
    -f /dev/stdin < "$1"
}

run_sql supabase/tests/phase_4c2a_horse_core.sql
run_sql supabase/tests/phase_4c2b_horse_identity_relationships.sql
docker exec -i "$db_container" \
  psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -v avaryn_local_test=1 -f /dev/stdin \
  < supabase/tests/phase_5b2_horse_alpha_acceptance.sql

ruby supabase/tests/phase_4c2a_horse_concurrency.rb
ruby supabase/tests/phase_4c2b_horse_identity_relationships_concurrency.rb
ruby supabase/tests/phase_4c2a_horse_concurrency.rb \
  --scenario update-update --iterations 25 --quiet
ruby supabase/tests/phase_4c2b_horse_identity_relationships_concurrency.rb \
  --iterations 10 --quiet

if command -v flutterflow >/dev/null 2>&1; then
  PATH="$workspace_root/.flutterflow/sdk/flutter/bin:$PATH" \
    flutterflow ai test
else
  PATH="$workspace_root/.flutterflow/sdk/flutter/bin:$PATH" \
    .flutterflow/sdk/flutter/bin/dart pub global run \
      flutterflow_cli:flutterflow_cli ai test
fi

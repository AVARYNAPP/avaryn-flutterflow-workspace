#!/bin/sh
set -eu

workspace_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$workspace_root"

if [ "${1:-}" != '--confirm-local-reset' ]; then
  echo 'Refusing Phase 5D.1 reset. Pass --confirm-local-reset explicitly.' >&2
  exit 2
fi

db_container='supabase_db_avaryn-flutterflow-workspace'
expected_label='avaryn-flutterflow-workspace'
actual_label=$(docker inspect \
  --format '{{ index .Config.Labels "com.supabase.cli.project" }}' \
  "$db_container")
if [ "$actual_label" != "$expected_label" ]; then
  echo 'Refusing SQL tests: local Supabase container label mismatch.' >&2
  exit 2
fi

reset_log=$(mktemp "${TMPDIR:-/tmp}/avaryn-phase5d1-reset.XXXXXX")
trap 'rm -f "$reset_log"' EXIT HUP INT TERM
if tool/provision_phase_5c_profile_local.sh \
  basis --confirm-local-reset >"$reset_log" 2>&1
then
  cat "$reset_log"
else
  cat "$reset_log" >&2
  if ! grep -Eqi \
    '502[[:space:]]+Bad Gateway|unexpected status[[:space:]]+502|status code[[:space:]]+502|received a[[:space:]]+502|Error[[:space:]]+status[[:space:]]+502' \
    "$reset_log"; then
    echo 'Refusing recovery: provisioner failure was not the allowed final 502.' >&2
    exit 2
  fi
  reset_state=$(docker exec "$db_container" \
    psql -X -U postgres -d postgres -Atc \
    "select (select count(*) from auth.users)::text || ':' ||
      (select count(*) from supabase_migrations.schema_migrations
       where version = '202607290001')::text;")
  if [ "$reset_state" != '0:1' ]; then
    echo 'Refusing recovery: reset did not leave an empty current schema.' >&2
    exit 2
  fi
  docker exec -i "$db_container" \
    psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 \
    -v avaryn_local_test=1 -v profile=basis \
    -v horse_count=3 -v routine_count=3 -v item_count=6 \
    -v media_count=1 -v conflict_count=1 -f /dev/stdin \
    < supabase/fixtures/phase_5c_test_profile.sql
  docker exec -i "$db_container" \
    psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 \
    -v avaryn_local_test=1 -v profile=basis \
    -v horse_count=3 -v routine_count=3 -v item_count=6 \
    -v media_count=1 -v conflict_count=1 -f /dev/stdin \
    < supabase/tests/phase_5c_test_profile_verification.sql
fi

docker exec -i "$db_container" \
  psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -v avaryn_local_test=1 -f /dev/stdin \
  < supabase/tests/phase_5d1_planning_alpha_acceptance.sql

docker exec -i "$db_container" \
  psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -v avaryn_local_test=1 -f /dev/stdin \
  < supabase/tests/phase_5_alpha_product_recovery.sql

ruby supabase/tests/phase_4c3_planning_tasks_concurrency.rb
ruby supabase/tests/phase_4c3_planning_tasks_concurrency.rb \
  --iterations 25 --quiet

.flutterflow/sdk/flutter/bin/dart \
  --packages=.flutterflow/sdk/flutterflow_ai/.dart_tool/package_config.json \
  .flutterflow/sdk/flutterflow_ai/bin/flutterflow_ai.dart test

echo 'PASS: Phase 5D.1 local planning gate is green.'

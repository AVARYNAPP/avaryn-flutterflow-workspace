#!/bin/sh
set -eu

workspace_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$workspace_root"

if [ "${1:-}" != '--confirm-local-reset' ]; then
  echo 'Refusing Phase 5D.3 reset. Pass --confirm-local-reset explicitly.' >&2
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

provision_basis_after_verified_reset() {
  docker exec -i "$db_container" \
    psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 \
    -v avaryn_local_test=1 \
    -v profile=basis \
    -v horse_count=3 \
    -v routine_count=3 \
    -v item_count=6 \
    -v media_count=1 \
    -v conflict_count=1 \
    -f /dev/stdin < supabase/fixtures/phase_5c_test_profile.sql

  docker exec -i "$db_container" \
    psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 \
    -v avaryn_local_test=1 \
    -v profile=basis \
    -v horse_count=3 \
    -v routine_count=3 \
    -v item_count=6 \
    -v media_count=1 \
    -v conflict_count=1 \
    -f /dev/stdin < supabase/tests/phase_5c_test_profile_verification.sql
}

db_started_before=$(docker inspect \
  --format '{{.State.StartedAt}}' \
  "$db_container")
if ! tool/provision_phase_5c_profile_local.sh basis --confirm-local-reset; then
  echo 'Supabase CLI reset returned an error; verifying the local reset before recovery.' >&2

  required_containers="
$db_container
supabase_auth_avaryn-flutterflow-workspace
supabase_storage_avaryn-flutterflow-workspace
supabase_realtime_avaryn-flutterflow-workspace
supabase_kong_avaryn-flutterflow-workspace
"
  reset_ready=false
  attempt=0
  while [ "$attempt" -lt 30 ]; do
    reset_ready=true
    for required_container in $required_containers; do
      container_state=$(docker inspect \
        --format '{{.State.Status}}/{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' \
        "$required_container")
      case "$container_state" in
        running/healthy|running/none) ;;
        *) reset_ready=false ;;
      esac
    done
    if [ "$reset_ready" = true ]; then
      break
    fi
    attempt=$((attempt + 1))
    sleep 1
  done

  migration_count=$(docker exec "$db_container" \
    psql -X -U postgres -d postgres -Atqc \
    "select count(*) from supabase_migrations.schema_migrations where version = '202607280005'")
  fixture_user_count=$(docker exec "$db_container" \
    psql -X -U postgres -d postgres -Atqc \
    "select count(*) from auth.users where raw_app_meta_data @> '{\"phase_5c_fixture\":true}'::jsonb")
  db_started_after=$(docker inspect \
    --format '{{.State.StartedAt}}' \
    "$db_container")
  if [ "$reset_ready" != true ] \
    || [ "$migration_count" != '1' ] \
    || [ "$fixture_user_count" != '0' ] \
    || [ "$db_started_after" = "$db_started_before" ]; then
    echo 'Refusing recovery: local stack or migration state is not exact.' >&2
    exit 1
  fi

  provision_basis_after_verified_reset
  echo 'PASS: recovered only after exact local reset and health verification.'
fi

docker exec -i "$db_container" \
  psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -f /dev/stdin \
  < supabase/tests/phase_4c6_realtime_offline_sync.sql

ITERATIONS=50 ruby \
  supabase/tests/phase_4c6_realtime_offline_sync_concurrency.rb \
  "$db_container"

docker exec -i "$db_container" \
  psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -v avaryn_local_test=1 -f /dev/stdin \
  < supabase/tests/phase_5d3_realtime_browser_acceptance.sql

.flutterflow/sdk/flutter/bin/dart \
  --packages=.flutterflow/sdk/flutterflow_ai/.dart_tool/package_config.json \
  .flutterflow/sdk/flutterflow_ai/bin/flutterflow_ai.dart test

echo 'PASS: Phase 5D.3 local Realtime and lifecycle gate is green.'

#!/bin/sh
set -eu

workspace_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$workspace_root"

if [ "${1:-}" != '--confirm-local-reset' ]; then
  echo 'Refusing Phase 5D.1 reset. Pass --confirm-local-reset explicitly.' >&2
  exit 2
fi

tool/provision_phase_5c_profile_local.sh basis --confirm-local-reset

db_container='supabase_db_avaryn-flutterflow-workspace'
expected_label='avaryn-flutterflow-workspace'
actual_label=$(docker inspect \
  --format '{{ index .Config.Labels "com.supabase.cli.project" }}' \
  "$db_container")
if [ "$actual_label" != "$expected_label" ]; then
  echo 'Refusing SQL tests: local Supabase container label mismatch.' >&2
  exit 2
fi

docker exec -i "$db_container" \
  psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -v avaryn_local_test=1 -f /dev/stdin \
  < supabase/tests/phase_5d1_planning_alpha_acceptance.sql

ruby supabase/tests/phase_4c3_planning_tasks_concurrency.rb
ruby supabase/tests/phase_4c3_planning_tasks_concurrency.rb \
  --iterations 25 --quiet

.flutterflow/sdk/flutter/bin/dart \
  --packages=.flutterflow/sdk/flutterflow_ai/.dart_tool/package_config.json \
  .flutterflow/sdk/flutterflow_ai/bin/flutterflow_ai.dart test

echo 'PASS: Phase 5D.1 local planning gate is green.'

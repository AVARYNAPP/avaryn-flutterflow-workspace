#!/bin/sh
set -eu

workspace_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$workspace_root"

db_container=${AVARYN_C007_DB_CONTAINER:-supabase_db_avaryn-c003ef-fresh}

run_sql() {
  docker exec -i "$db_container" \
    psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 \
    -f /dev/stdin < "$1"
}

run_sql supabase/tests/c007_personal_auth_onboarding.sql
run_sql supabase/tests/c003f_security_gate.sql
run_sql supabase/tests/c004_account_foundation_acceptance.sql
ruby supabase/tests/c007_profile_concurrency.rb "$db_container"

PATH="$workspace_root/.flutterflow/sdk/flutter/bin:$PATH" \
  "$workspace_root/.flutterflow/sdk/flutter/bin/dart" \
  --packages="$workspace_root/.flutterflow/sdk/flutterflow_ai/.dart_tool/package_config.json" \
  "$workspace_root/.flutterflow/sdk/flutterflow_ai/bin/flutterflow_ai.dart" test

git diff --check
echo 'PASS: C-007 local Auth/onboarding, security, concurrency and client gates are green.'

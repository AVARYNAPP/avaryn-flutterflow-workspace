#!/bin/sh
set -eu

workspace_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$workspace_root"

db_container='supabase_db_avaryn-flutterflow-workspace'

docker exec -i "$db_container" \
  psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -c "drop function if exists public.get_horse_capabilities(uuid); delete from supabase_migrations.schema_migrations where version = '202607280001';"

docker exec -i "$db_container" \
  psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -f /dev/stdin < supabase/tests/phase_5b2_upgrade_fixture.sql

.flutterflow/sdk/bin/supabase migration up --local --include-all

docker exec -i "$db_container" \
  psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -f /dev/stdin < supabase/tests/phase_5b2_upgrade_verification.sql

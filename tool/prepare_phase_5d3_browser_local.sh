#!/bin/sh
set -eu

workspace_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$workspace_root"

if [ "${1:-}" != '--confirm-local-reset' ] || [ "${2:-}" != '--password-file' ]; then
  echo 'Usage: prepare_phase_5d3_browser_local.sh --confirm-local-reset --password-file PATH' >&2
  exit 2
fi

password_file=${3:-}
if [ -z "$password_file" ] || [ ! -f "$password_file" ]; then
  echo 'Refusing browser fixture: password file is missing.' >&2
  exit 2
fi

password_mode=$(stat -f '%Lp' "$password_file")
if [ "$password_mode" != '600' ]; then
  echo 'Refusing browser fixture: password file mode must be 600.' >&2
  exit 2
fi

db_container='supabase_db_avaryn-flutterflow-workspace'
expected_label='avaryn-flutterflow-workspace'
actual_label=$(docker inspect \
  --format '{{ index .Config.Labels "com.supabase.cli.project" }}' \
  "$db_container")
if [ "$actual_label" != "$expected_label" ]; then
  echo 'Refusing browser fixture: local Supabase label mismatch.' >&2
  exit 2
fi

tool/provision_phase_5c_profile_local.sh basis --confirm-local-reset

browser_password=$(dd if="$password_file" bs=4096 count=1 2>/dev/null)
if [ "${#browser_password}" -lt 20 ]; then
  unset browser_password
  echo 'Refusing browser fixture: password is too short.' >&2
  exit 2
fi

docker exec -i \
  -e AVARYN_BROWSER_TEST_PASSWORD="$browser_password" \
  "$db_container" \
  psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -v avaryn_local_test=1 -f /dev/stdin \
  < supabase/tests/phase_5d3_browser_fixture.sql
unset browser_password

echo 'PASS: Phase 5D.3 local browser fixture is ready.'

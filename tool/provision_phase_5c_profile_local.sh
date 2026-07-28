#!/bin/sh
set -eu

workspace_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$workspace_root"

profile=${1:-}
confirmation=${2:-}
db_container='supabase_db_avaryn-flutterflow-workspace'

if [ "$confirmation" != '--confirm-local-reset' ]; then
  echo 'Refusing to reset. Pass --confirm-local-reset explicitly.' >&2
  exit 2
fi

if ! grep -q '^project_id = "avaryn-flutterflow-workspace"$' \
  supabase/config.toml; then
  echo 'Refusing to reset: unexpected Supabase project_id.' >&2
  exit 2
fi

case "${DOCKER_HOST:-}" in
  ''|unix://*) ;;
  *)
    echo 'Refusing to reset: DOCKER_HOST is not a local Unix socket.' >&2
    exit 2
    ;;
esac

docker_context=$(docker context show)
docker_host=$(docker context inspect \
  --format '{{.Endpoints.docker.Host}}' \
  "$docker_context")
case "$docker_host" in
  unix://*) ;;
  *)
    echo 'Refusing to reset: Docker context is not a local Unix socket.' >&2
    exit 2
    ;;
esac

case "$profile" in
  basis)
    horse_count=3
    routine_count=3
    item_count=6
    media_count=1
    conflict_count=1
    ;;
  medium)
    horse_count=8
    routine_count=8
    item_count=24
    media_count=4
    conflict_count=2
    ;;
  extreme)
    horse_count=15
    routine_count=15
    item_count=90
    media_count=15
    conflict_count=5
    ;;
  custom)
    horse_count=${AVARYN_CUSTOM_HORSES:-5}
    routine_count=${AVARYN_CUSTOM_ROUTINES:-5}
    item_count=${AVARYN_CUSTOM_ITEMS:-12}
    media_count=${AVARYN_CUSTOM_MEDIA:-2}
    conflict_count=${AVARYN_CUSTOM_CONFLICTS:-2}
    ;;
  *)
    echo 'Usage: provision_phase_5c_profile_local.sh PROFILE --confirm-local-reset' >&2
    echo 'PROFILE: basis | medium | extreme | custom' >&2
    exit 2
    ;;
esac

is_unsigned_integer() {
  case "$1" in
    ''|*[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

for value in \
  "$horse_count" \
  "$routine_count" \
  "$item_count" \
  "$media_count" \
  "$conflict_count"
do
  if ! is_unsigned_integer "$value"; then
    echo 'Refusing to reset: custom counts must be unsigned integers.' >&2
    exit 2
  fi
done

if [ "$horse_count" -lt 1 ] || [ "$horse_count" -gt 50 ] \
  || [ "$routine_count" -lt 3 ] || [ "$routine_count" -gt 100 ] \
  || [ "$item_count" -lt 6 ] || [ "$item_count" -gt 500 ] \
  || [ "$media_count" -lt 1 ] || [ "$media_count" -gt 50 ] \
  || [ "$conflict_count" -lt 1 ] || [ "$conflict_count" -gt 25 ]; then
  echo 'Refusing to reset: profile counts exceed documented test bounds.' >&2
  exit 2
fi

container_project=$(docker inspect \
  --format '{{ index .Config.Labels "com.supabase.cli.project" }}' \
  "$db_container")
if [ "$container_project" != 'avaryn-flutterflow-workspace' ]; then
  echo 'Refusing to reset: unexpected Supabase container label.' >&2
  exit 2
fi

.flutterflow/sdk/bin/supabase db reset --local

docker exec -i "$db_container" \
  psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -v avaryn_local_test=1 \
  -v profile="$profile" \
  -v horse_count="$horse_count" \
  -v routine_count="$routine_count" \
  -v item_count="$item_count" \
  -v media_count="$media_count" \
  -v conflict_count="$conflict_count" \
  -f /dev/stdin < supabase/fixtures/phase_5c_test_profile.sql

docker exec -i "$db_container" \
  psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -v avaryn_local_test=1 \
  -v profile="$profile" \
  -v horse_count="$horse_count" \
  -v routine_count="$routine_count" \
  -v item_count="$item_count" \
  -v media_count="$media_count" \
  -v conflict_count="$conflict_count" \
  -f /dev/stdin < supabase/tests/phase_5c_test_profile_verification.sql

echo "PASS: local Phase 5C profile '$profile' is provisioned and verified."

#!/bin/sh
set -eu

workspace_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$workspace_root"

if [ "${1:-}" != '--confirm-local-reset' ]; then
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

container_project=$(docker inspect \
  --format '{{ index .Config.Labels "com.supabase.cli.project" }}' \
  supabase_db_avaryn-flutterflow-workspace)
if [ "$container_project" != 'avaryn-flutterflow-workspace' ]; then
  echo 'Refusing to reset: unexpected Supabase container label.' >&2
  exit 2
fi

.flutterflow/sdk/bin/supabase db reset --local

echo 'PASS: local AVARYN Supabase testdata reset; no profile provisioned.'

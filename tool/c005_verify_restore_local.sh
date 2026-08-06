#!/usr/bin/env bash
set -euo pipefail
umask 077

workspace_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "$workspace_root/tool/lib/c005_safety.sh"

backup_dir=
confirmation=
local_project_id='avaryn-flutterflow-workspace'
while [ "$#" -gt 0 ]; do
  case "$1" in
    --backup-dir) [ "$#" -ge 2 ] || c005_die 'missing backup directory';backup_dir=$2;shift 2 ;;
    --confirm-local-restore) confirmation=yes;shift ;;
    --local-project-id) [ "$#" -ge 2 ] || c005_die 'missing local project ID';local_project_id=$2;shift 2 ;;
    *) c005_die "unknown argument: $1" ;;
  esac
done
[ "$confirmation" = yes ] || c005_die '--confirm-local-restore is required'
[ -n "$backup_dir" ] || c005_die '--backup-dir is required'
c005_require_external_path "$workspace_root" "$backup_dir"
[ -d "$backup_dir" ] && [ ! -L "$backup_dir" ] || c005_die 'backup directory is invalid'
for file in full.dump.enc schema-only.dump SHA256SUMS manifest.txt BACKUP_COMPLETE; do
  [ -f "$backup_dir/$file" ] && [ ! -L "$backup_dir/$file" ] \
    || c005_die "backup evidence lacks $file"
done
(CDPATH= cd -- "$backup_dir" && shasum -a 256 -c SHA256SUMS) \
  || c005_die 'backup checksum verification failed'
command -v openssl >/dev/null 2>&1 || c005_die 'openssl is required'
c005_require_backup_passphrase

case "${DOCKER_HOST:-}" in ''|unix://*) ;;*) c005_die 'DOCKER_HOST is not local' ;;esac
docker_context=$(docker context show)
docker_host=$(docker context inspect --format '{{.Endpoints.docker.Host}}' "$docker_context")
case "$docker_host" in unix://*) ;;*) c005_die 'Docker context is not a local Unix socket' ;;esac
case "$local_project_id" in
  avaryn-*[!A-Za-z0-9_-]*) c005_die 'local project ID contains unsafe characters' ;;
  avaryn-*) ;;
  *) c005_die 'local project ID must use the avaryn- prefix' ;;
esac
container="supabase_db_${local_project_id}"
container_project=$(docker inspect --format '{{ index .Config.Labels "com.supabase.cli.project" }}' "$container")
[ "$container_project" = "$local_project_id" ] \
  || c005_die 'local Supabase container identity mismatch'

restore_db="avaryn_c005_restore_$(date -u +%Y%m%d%H%M%S)_$$"
cleanup() {
  docker exec "$container" psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 \
    -c "drop database if exists \"$restore_db\" with (force);" >/dev/null 2>&1 || true
}
trap cleanup EXIT HUP INT TERM

docker exec "$container" psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -c "create database \"$restore_db\" template template0;" >/dev/null
docker exec "$container" psql -X -U postgres -d "$restore_db" -v ON_ERROR_STOP=1 \
  -c 'create schema vault;' >/dev/null
openssl enc -d -aes-256-cbc -pbkdf2 \
  -pass env:AVARYN_C005_BACKUP_PASSPHRASE -in "$backup_dir/full.dump.enc" \
  | docker exec -i "$container" pg_restore -U postgres -d "$restore_db" \
      --no-owner --no-privileges
restored=$(docker exec "$container" psql -X -A -t -q -U postgres -d "$restore_db" \
  -v ON_ERROR_STOP=1 -c "select (to_regclass('public.profiles') is not null)::text;" \
  | tr -d '[:space:]')
[ "$restored" = 'true' ] || c005_die 'restored database lacks required pre-C006 baseline tables'
{
  echo 'result=PASS'
  echo 'target=disposable-local-database'
  echo "verified_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "full_sha256=$(shasum -a 256 "$backup_dir/full.dump.enc" | awk '{print $1}')"
} > "$backup_dir/restore-verification.txt"

echo 'PASS: full backup restored and verified in a disposable local database.'

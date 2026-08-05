#!/usr/bin/env bash
set -euo pipefail
umask 077

workspace_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "$workspace_root/tool/lib/c005_safety.sh"

mode=
evidence_dir=
approval_file=
auth_evidence=
storage_evidence=
platform_evidence=
confirmation=
while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) mode=dry-run;shift ;;
    --execute) mode=execute;shift ;;
    --evidence-dir) [ "$#" -ge 2 ] || c005_die 'missing evidence directory';evidence_dir=$2;shift 2 ;;
    --approval-file) [ "$#" -ge 2 ] || c005_die 'missing approval file';approval_file=$2;shift 2 ;;
    --auth-config-evidence) [ "$#" -ge 2 ] || c005_die 'missing Auth evidence';auth_evidence=$2;shift 2 ;;
    --storage-backup-evidence) [ "$#" -ge 2 ] || c005_die 'missing Storage evidence';storage_evidence=$2;shift 2 ;;
    --platform-backup-evidence) [ "$#" -ge 2 ] || c005_die 'missing platform backup evidence';platform_evidence=$2;shift 2 ;;
    --confirm) [ "$#" -ge 2 ] || c005_die 'missing confirmation';confirmation=$2;shift 2 ;;
    *) c005_die "unknown argument: $1" ;;
  esac
done

[ -n "$mode" ] || c005_die 'choose --dry-run or --execute explicitly'
[ -n "$evidence_dir" ] || c005_die '--evidence-dir is required'
c005_require_target_identity
c005_require_external_path "$workspace_root" "$evidence_dir"

if [ "$mode" = dry-run ]; then
  echo "DRY RUN PASS: backup target is allowlisted staging ${C005_STAGING_PROJECT_REF}."
  echo 'Would create a schema-only dump and encrypted full logical dump outside Git.'
  echo 'Would hash and bind redacted Auth, Storage and platform evidence without copying secrets.'
  exit 0
fi

c005_require_repository "$workspace_root"
[ "$confirmation" = "BACKUP-STAGING-${C005_STAGING_PROJECT_REF}" ] \
  || c005_die 'exact backup confirmation is missing'
[ -n "$approval_file" ] || c005_die '--approval-file is required'
c005_require_approval "$approval_file" staging-backup "$AVARYN_C005_RELEASE_COMMIT"
for evidence in "$auth_evidence" "$storage_evidence" "$platform_evidence"; do
  [ -f "$evidence" ] && [ ! -L "$evidence" ] \
    || c005_die 'redacted Auth, Storage and platform evidence files are required'
done
[ ! -e "$evidence_dir" ] || c005_die 'evidence directory must not already exist'
c005_require_credentials
c005_require_backup_tools
c005_require_backup_passphrase

mkdir -m 700 "$evidence_dir"
schema_dump="$evidence_dir/schema-only.dump"
full_dump="$evidence_dir/full.dump.enc"

pg_dump --host="$AVARYN_C005_DB_HOST" --port="${AVARYN_C005_DB_PORT:-5432}" \
  --username="${AVARYN_C005_DB_USER:-postgres}" --dbname="${AVARYN_C005_DB_NAME:-postgres}" \
  --format=custom --schema-only --no-owner --no-privileges \
  --exclude-schema=vault --exclude-schema=realtime --file="$schema_dump"
pg_dump --host="$AVARYN_C005_DB_HOST" --port="${AVARYN_C005_DB_PORT:-5432}" \
  --username="${AVARYN_C005_DB_USER:-postgres}" --dbname="${AVARYN_C005_DB_NAME:-postgres}" \
  --format=custom --no-owner --no-privileges \
  --exclude-schema=vault --exclude-schema=realtime \
  | openssl enc -aes-256-cbc -salt -pbkdf2 \
      -pass env:AVARYN_C005_BACKUP_PASSPHRASE -out "$full_dump"

remote_database=$(c005_psql -A -t -q -c 'select current_database();' | tr -d '[:space:]')
[ "$remote_database" = 'postgres' ] || c005_die 'remote database identity mismatch'
remote_migration=$(c005_psql -A -t -q -c \
  'select version from supabase_migrations.schema_migrations order by version desc limit 1;' \
  | tr -d '[:space:]')
[ "$remote_migration" = "$(c005_approval_value "$approval_file" pre_reset_migration)" ] \
  || c005_die 'remote migration changed after backup approval'

schema_hash=$(shasum -a 256 "$schema_dump" | awk '{print $1}')
full_hash=$(shasum -a 256 "$full_dump" | awk '{print $1}')
auth_hash=$(shasum -a 256 "$auth_evidence" | awk '{print $1}')
storage_hash=$(shasum -a 256 "$storage_evidence" | awk '{print $1}')
platform_hash=$(shasum -a 256 "$platform_evidence" | awk '{print $1}')
{
  echo "project_ref=${C005_STAGING_PROJECT_REF}"
  echo 'environment=staging'
  echo "release_commit=${AVARYN_C005_RELEASE_COMMIT}"
  echo "pre_reset_migration=${remote_migration}"
  echo "schema_only_sha256=${schema_hash}"
  echo "full_sha256=${full_hash}"
  echo "auth_config_evidence_sha256=${auth_hash}"
  echo "storage_backup_evidence_sha256=${storage_hash}"
  echo "platform_backup_evidence_sha256=${platform_hash}"
} > "$evidence_dir/manifest.txt"
{
  echo "${schema_hash}  schema-only.dump"
  echo "${full_hash}  full.dump.enc"
} > "$evidence_dir/SHA256SUMS"
touch "$evidence_dir/BACKUP_COMPLETE"

echo "PASS: staging backup evidence created outside Git at $evidence_dir"

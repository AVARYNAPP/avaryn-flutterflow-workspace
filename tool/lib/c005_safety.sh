#!/bin/sh

C005_STAGING_PROJECT_REF='ipdovjdtnfslrftvrdrl'
C005_C003_APPROVED_BASE='4fee78c8b24099cf4eac254fd083f062827f1ee3'

c005_die() {
  echo "C005 refused: $*" >&2
  exit 2
}

c005_require_repository() {
  workspace_root=$1
  git -C "$workspace_root" merge-base --is-ancestor \
    "$C005_C003_APPROVED_BASE" HEAD >/dev/null 2>&1 \
    || c005_die 'approved C-003 base is not an ancestor of HEAD'
  if [ "${AVARYN_C005_RELEASE_COMMIT:-}" != "$(git -C "$workspace_root" rev-parse HEAD)" ]; then
    c005_die 'AVARYN_C005_RELEASE_COMMIT must equal the checked-out full HEAD SHA'
  fi
  git -C "$workspace_root" diff --quiet \
    || c005_die 'working tree has unstaged changes'
  git -C "$workspace_root" diff --cached --quiet \
    || c005_die 'working tree has staged changes'
  [ -z "$(git -C "$workspace_root" status --porcelain=v1)" ] \
    || c005_die 'working tree contains untracked files'
}

c005_require_target_identity() {
  [ "${AVARYN_C005_ENVIRONMENT:-}" = 'staging' ] \
    || c005_die 'AVARYN_C005_ENVIRONMENT must be exactly staging'
  [ "${AVARYN_C005_PROJECT_REF:-}" = "$C005_STAGING_PROJECT_REF" ] \
    || c005_die 'project ref is not the allowlisted AVARYN staging project'
  (
    [ "${AVARYN_C005_DB_HOST:-}" = "db.${C005_STAGING_PROJECT_REF}.supabase.co" ] &&
    [ "${AVARYN_C005_DB_USER:-}" = 'postgres' ]
  ) || (
    [ "${AVARYN_C005_DB_HOST:-}" = 'aws-0-eu-central-1.pooler.supabase.com' ] &&
    [ "${AVARYN_C005_DB_USER:-}" = "postgres.${C005_STAGING_PROJECT_REF}" ]
  ) || c005_die 'database host/user combination is not the allowlisted AVARYN staging project'
  [ "${AVARYN_C005_DB_PORT:-5432}" = '5432' ] \
    || c005_die 'database port must be 5432'
  [ "${AVARYN_C005_DB_NAME:-postgres}" = 'postgres' ] \
    || c005_die 'database name must be postgres'
  [ "${PGSSLMODE:-}" = 'verify-full' ] \
    || c005_die 'PGSSLMODE must be verify-full'
}

c005_require_credentials() {
  [ -n "${PGPASSWORD:-}" ] || c005_die 'PGPASSWORD is required via the environment'
  command -v psql >/dev/null 2>&1 || c005_die 'psql is required'
}

c005_require_backup_tools() {
  command -v pg_dump >/dev/null 2>&1 || c005_die 'pg_dump is required'
  command -v shasum >/dev/null 2>&1 || c005_die 'shasum is required'
  command -v openssl >/dev/null 2>&1 || c005_die 'openssl is required'
}

c005_require_backup_passphrase() {
  backup_passphrase=${AVARYN_C005_BACKUP_PASSPHRASE:-}
  [ "${#backup_passphrase}" -ge 32 ] \
    || c005_die 'AVARYN_C005_BACKUP_PASSPHRASE must contain at least 32 characters'
}

c005_psql() {
  psql -X -v ON_ERROR_STOP=1 \
    --host="$AVARYN_C005_DB_HOST" \
    --port="${AVARYN_C005_DB_PORT:-5432}" \
    --username="${AVARYN_C005_DB_USER:-postgres}" \
    --dbname="${AVARYN_C005_DB_NAME:-postgres}" "$@"
}

c005_safe_db_url() {
  printf 'postgresql://%s@%s:%s/%s?sslmode=verify-full' \
    "${AVARYN_C005_DB_USER:-postgres}" "$AVARYN_C005_DB_HOST" \
    "${AVARYN_C005_DB_PORT:-5432}" "${AVARYN_C005_DB_NAME:-postgres}"
}

c005_canonical_parent() {
  target=$1
  parent=$(dirname "$target")
  [ -d "$parent" ] || c005_die "parent directory does not exist: $parent"
  (CDPATH= cd -- "$parent" && pwd -P)
}

c005_require_external_path() {
  workspace_root=$1
  target=$2
  case "$target" in
    /*) ;;
    *) c005_die 'evidence path must be absolute' ;;
  esac
  parent=$(c005_canonical_parent "$target")
  case "$parent/$(basename "$target")" in
    "$workspace_root"|"$workspace_root"/*)
      c005_die 'backup/evidence must remain outside the repository'
      ;;
  esac
}

c005_approval_value() {
  approval_file=$1
  key=$2
  value=$(sed -n "s/^${key}=//p" "$approval_file")
  [ -n "$value" ] || c005_die "approval file lacks $key"
  [ "$(printf '%s\n' "$value" | wc -l | tr -d ' ')" = '1' ] \
    || c005_die "approval file repeats $key"
  printf '%s' "$value"
}

c005_require_approval() {
  approval_file=$1
  expected_action=$2
  release_commit=$3
  [ -f "$approval_file" ] && [ ! -L "$approval_file" ] \
    || c005_die 'approval file must be a regular non-symlink file'
  [ "$(c005_approval_value "$approval_file" environment)" = 'staging' ] \
    || c005_die 'approval environment mismatch'
  [ "$(c005_approval_value "$approval_file" project_ref)" = "$C005_STAGING_PROJECT_REF" ] \
    || c005_die 'approval project_ref mismatch'
  [ "$(c005_approval_value "$approval_file" action)" = "$expected_action" ] \
    || c005_die 'approval action mismatch'
  [ "$(c005_approval_value "$approval_file" release_commit)" = "$release_commit" ] \
    || c005_die 'approval release_commit mismatch'
  pre_reset_migration=$(c005_approval_value "$approval_file" pre_reset_migration)
  approved_by=$(c005_approval_value "$approval_file" approved_by)
  approval_id=$(c005_approval_value "$approval_file" approval_id)
  approved_at_utc=$(c005_approval_value "$approval_file" approved_at_utc)
  case "$pre_reset_migration" in
    [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]) ;;
    *) c005_die 'approval pre_reset_migration must be a 12-digit version' ;;
  esac
  case "$approved_by:$approval_id:$approved_at_utc" in
    *PLACEHOLDER*|*CHANGEME*) c005_die 'approval contains a placeholder' ;;
  esac
}

c005_latest_local_migration() {
  workspace_root=$1
  latest_name=$(basename "$(find "$workspace_root/supabase/migrations" -type f -name '*.sql' | sort | tail -1)")
  printf '%s' "${latest_name%%_*}"
}

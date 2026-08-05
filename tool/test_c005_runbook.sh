#!/bin/sh
set -eu

workspace_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$workspace_root"

for script in tool/c005_*.sh tool/lib/c005_safety.sh tool/test_c005_runbook.sh; do
  bash -n "$script"
done

previous_version=
for migration in $(find supabase/migrations -type f -name '*.sql' | sort); do
  filename=$(basename "$migration")
  version=${filename%%_*}
  case "$filename" in
    [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]_*.sql) ;;
    *) echo "invalid migration filename: $filename" >&2;exit 1 ;;
  esac
  if [ -n "$previous_version" ] && [ "$version" -le "$previous_version" ]; then
    echo "migration versions are not strictly increasing: $filename" >&2
    exit 1
  fi
  previous_version=$version
done
[ -n "$previous_version" ] || { echo 'no migrations found' >&2;exit 1; }

release_commit=$(git rev-parse HEAD)
valid_environment() {
  AVARYN_C005_ENVIRONMENT=staging \
  AVARYN_C005_PROJECT_REF=ipdovjdtnfslrftvrdrl \
  AVARYN_C005_DB_HOST=db.ipdovjdtnfslrftvrdrl.supabase.co \
  AVARYN_C005_DB_PORT=5432 AVARYN_C005_DB_NAME=postgres AVARYN_C005_DB_USER=postgres \
  AVARYN_C005_RELEASE_COMMIT="$release_commit" PGSSLMODE=verify-full "$@"
}

valid_environment tool/c005_backup_staging.sh --dry-run \
  --evidence-dir /private/tmp/avaryn-c005-dry-run-backup >/dev/null
valid_environment tool/c005_reset_staging.sh --dry-run >/dev/null

if AVARYN_C005_ENVIRONMENT=production \
  AVARYN_C005_PROJECT_REF=ipdovjdtnfslrftvrdrl \
  AVARYN_C005_DB_HOST=db.ipdovjdtnfslrftvrdrl.supabase.co \
  PGSSLMODE=verify-full tool/c005_reset_staging.sh --dry-run >/dev/null 2>&1
then echo 'production environment was not blocked' >&2;exit 1;fi

if AVARYN_C005_ENVIRONMENT=staging AVARYN_C005_PROJECT_REF=unknown \
  AVARYN_C005_DB_HOST=db.unknown.supabase.co PGSSLMODE=verify-full \
  tool/c005_reset_staging.sh --dry-run >/dev/null 2>&1
then echo 'unknown project was not blocked' >&2;exit 1;fi

if AVARYN_C005_ENVIRONMENT=staging \
  AVARYN_C005_PROJECT_REF=ipdovjdtnfslrftvrdrl \
  AVARYN_C005_DB_HOST=pooler.example.invalid PGSSLMODE=verify-full \
  tool/c005_reset_staging.sh --dry-run >/dev/null 2>&1
then echo 'unknown database host was not blocked' >&2;exit 1;fi

if rg -n -- '--linked|supabase[[:space:]]+link|PGPASSWORD=' \
  tool/c005_*.sh tool/lib/c005_safety.sh
then echo 'unsafe linked target or embedded password found' >&2;exit 1;fi

if rg -n -i '(service_role_key|supabase_service_role_key|postgresql://[^@[:space:]]+:[^@[:space:]]+@)' \
  docs/implementation/C004_ACCOUNT_FOUNDATION_V2.md \
  docs/runbooks/C005_BACKUP_RESET_SEED.md \
  docs/templates/c005-staging-approval.txt \
  tool/c005_*.sh tool/lib/c005_safety.sh \
  supabase/seeds/c005_account_foundation_v2.sql \
  supabase/tests/c004_account_foundation_acceptance.sql \
  supabase/tests/c005_account_foundation_seed_smoke.sql
then echo 'possible committed secret found' >&2;exit 1;fi

echo 'PASS: C-005 scripts are syntactically valid and fail closed for production and unknown targets.'

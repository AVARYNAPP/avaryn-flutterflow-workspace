#!/bin/sh
set -eu
umask 077

workspace_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "$workspace_root/tool/lib/c005_safety.sh"

mode=
backup_dir=
approval_file=
confirmation=
while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) mode=dry-run;shift ;;
    --execute) mode=execute;shift ;;
    --backup-dir) [ "$#" -ge 2 ] || c005_die 'missing backup directory';backup_dir=$2;shift 2 ;;
    --approval-file) [ "$#" -ge 2 ] || c005_die 'missing approval file';approval_file=$2;shift 2 ;;
    --confirm) [ "$#" -ge 2 ] || c005_die 'missing confirmation';confirmation=$2;shift 2 ;;
    *) c005_die "unknown argument: $1" ;;
  esac
done
[ -n "$mode" ] || c005_die 'choose --dry-run or --execute explicitly'
c005_require_target_identity

if [ "$mode" = dry-run ]; then
  latest=$(c005_latest_local_migration "$workspace_root")
  echo "DRY RUN PASS: reset target is allowlisted staging ${C005_STAGING_PROJECT_REF}."
  echo "Would apply ordered local migrations through ${latest}, then the C005 fictitious seed and security smoke."
  echo 'Would stop without automatic rollback on any failure.'
  exit 0
fi

c005_require_repository "$workspace_root"
[ "$confirmation" = "RESET-STAGING-${C005_STAGING_PROJECT_REF}" ] \
  || c005_die 'exact destructive reset confirmation is missing'
[ -n "$backup_dir" ] || c005_die '--backup-dir is required'
c005_require_external_path "$workspace_root" "$backup_dir"
for file in BACKUP_COMPLETE SHA256SUMS manifest.txt restore-verification.txt; do
  [ -f "$backup_dir/$file" ] && [ ! -L "$backup_dir/$file" ] \
    || c005_die "reset evidence lacks $file"
done
(CDPATH= cd -- "$backup_dir" && shasum -a 256 -c SHA256SUMS) \
  || c005_die 'backup checksums changed after restore verification'
grep -Fx 'result=PASS' "$backup_dir/restore-verification.txt" >/dev/null \
  || c005_die 'restore verification did not pass'
[ -n "$approval_file" ] || c005_die '--approval-file is required'
c005_require_approval "$approval_file" staging-reset "$AVARYN_C005_RELEASE_COMMIT"
c005_require_credentials

expected_pre_reset=$(c005_approval_value "$approval_file" pre_reset_migration)
[ "$(c005_approval_value "$backup_dir/manifest.txt" project_ref)" = "$C005_STAGING_PROJECT_REF" ] \
  || c005_die 'backup manifest project_ref mismatch'
[ "$(c005_approval_value "$backup_dir/manifest.txt" environment)" = 'staging' ] \
  || c005_die 'backup manifest environment mismatch'
[ "$(c005_approval_value "$backup_dir/manifest.txt" release_commit)" = "$AVARYN_C005_RELEASE_COMMIT" ] \
  || c005_die 'backup manifest release_commit mismatch'
[ "$(c005_approval_value "$backup_dir/manifest.txt" pre_reset_migration)" = "$expected_pre_reset" ] \
  || c005_die 'backup manifest migration does not match reset approval'
verified_full_hash=$(c005_approval_value "$backup_dir/restore-verification.txt" full_sha256)
manifest_full_hash=$(c005_approval_value "$backup_dir/manifest.txt" full_sha256)
[ "$verified_full_hash" = "$manifest_full_hash" ] \
  || c005_die 'restore verification is not bound to this full backup'
actual_pre_reset=$(c005_psql -A -t -q -c \
  'select version from supabase_migrations.schema_migrations order by version desc limit 1;' \
  | tr -d '[:space:]')
[ "$actual_pre_reset" = "$expected_pre_reset" ] \
  || c005_die 'remote migration changed after approval/backup'

safe_url=$(c005_safe_db_url)
echo 'C005 authorized staging reset begins; credentials remain environment-only.'
if ! "$workspace_root/.flutterflow/sdk/bin/supabase" db reset \
  --db-url "$safe_url" --no-seed --yes; then
  echo 'C005 STOP: reset failed. Keep staging closed; do not auto-restore.' >&2
  exit 1
fi
if ! c005_psql -v c005_environment=staging \
  -f "$workspace_root/supabase/seeds/c005_account_foundation_v2.sql"; then
  echo 'C005 STOP: seed failed. Keep staging closed; do not auto-restore.' >&2
  exit 1
fi
if ! c005_psql -f "$workspace_root/supabase/tests/c005_account_foundation_seed_smoke.sql"; then
  echo 'C005 STOP: post-reset smoke failed. Keep staging closed; do not auto-restore.' >&2
  exit 1
fi

expected_post_reset=$(c005_latest_local_migration "$workspace_root")
actual_post_reset=$(c005_psql -A -t -q -c \
  'select version from supabase_migrations.schema_migrations order by version desc limit 1;' \
  | tr -d '[:space:]')
[ "$actual_post_reset" = "$expected_post_reset" ] \
  || c005_die 'post-reset migration order mismatch'

echo 'PASS: explicitly authorized staging reset, v2 seed and security smoke completed.'

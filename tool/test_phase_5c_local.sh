#!/bin/sh
set -eu

workspace_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$workspace_root"

if [ "${1:-}" != '--confirm-local-reset' ]; then
  echo 'Refusing to run four resets. Pass --confirm-local-reset explicitly.' >&2
  exit 2
fi

for profile in basis medium extreme custom
do
  tool/provision_phase_5c_profile_local.sh \
    "$profile" \
    --confirm-local-reset
done

if command -v flutterflow >/dev/null 2>&1; then
  PATH="$workspace_root/.flutterflow/sdk/flutter/bin:$PATH" \
    flutterflow ai test
else
  PATH="$workspace_root/.flutterflow/sdk/flutter/bin:$PATH" \
    .flutterflow/sdk/flutter/bin/dart pub global run \
      flutterflow_cli:flutterflow_cli ai test
fi

echo 'PASS: all four local Phase 5C profiles and workspace tests are green.'

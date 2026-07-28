#!/bin/sh
set -eu

workspace_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$workspace_root"

required_documents='
docs/phase-5e-alpha-test-protocol.md
docs/phase-5e-operations-runbook.md
docs/phase-5e-deployment-gate.md
docs/templates/phase-5-alpha-bug-report.md
docs/templates/phase-5-alpha-incident-record.md
docs/templates/phase-5-alpha-test-session.md
'

for document in $required_documents; do
  if [ ! -s "$document" ]; then
    echo "Missing Phase 5E document: $document" >&2
    exit 1
  fi
done

for script in tool/test_phase_5*.sh tool/provision_phase_5c_profile_local.sh \
  tool/reset_phase_5c_local.sh
do
  sh -n "$script"
done

if rg -n \
  '(supabase (link|db push|functions deploy)|flutterflow.*(publish|deploy))' \
  tool --glob '!test_phase_5e_local.sh'
then
  echo 'Refusing Phase 5E gate: executable tooling contains an external deployment command.' >&2
  exit 1
fi

.flutterflow/sdk/flutter/bin/dart \
  --packages=.flutterflow/sdk/flutterflow_ai/.dart_tool/package_config.json \
  .flutterflow/sdk/flutterflow_ai/bin/flutterflow_ai.dart test

git diff --check

echo 'PASS: Phase 5E documentation and local operational-readiness gate is green.'

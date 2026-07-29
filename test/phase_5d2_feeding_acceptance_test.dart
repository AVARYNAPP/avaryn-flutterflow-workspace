import 'dart:io';

import 'package:test/test.dart';

void main() {
  late String runtime;
  late String edit;
  late String migration;
  late String sql;
  late String runner;

  setUpAll(() {
    runtime = File('dsl/avaryn_operational_runtime.dart').readAsStringSync();
    edit = File('dsl/edit.dart').readAsStringSync();
    migration =
        File(
          'supabase/migrations/'
          '202607280004_phase_5d2_feeding_atomic_flow.sql',
        ).readAsStringSync();
    sql =
        File(
          'supabase/tests/phase_5d2_feeding_alpha_acceptance.sql',
        ).readAsStringSync();
    runner = File('tool/test_phase_5d2_local.sh').readAsStringSync();
  });

  test('active edit flow includes the Phase 5D.2 feeding slice', () {
    expect(edit, contains('buildAvarynPhase5D2,'));
    expect(edit, contains('void buildAvarynPhase5D2(App app)'));
    expect(edit, contains("name: 'FeedingOverviewPage'"));
    expect(edit, contains("name: 'FeedingRoundExecutionPage'"));
  });

  test('plan and first version are one atomic durable workflow', () {
    expect(runtime, contains("operation: 'create_feeding_plan_with_version'"));
    expect(runtime, contains("'version_request_id': _uuid.v4()"));
    expect(runtime, contains("'p_create_request_id': requestId"));
    expect(
      runtime,
      contains("'p_version_request_id': replayValues['version_request_id']"),
    );
    expect(
      migration,
      contains(
        'create or replace function public.'
        'create_feeding_plan_with_version(',
      ),
    );
    expect(migration, contains('security definer'));
    expect(migration, contains("set search_path = ''"));
    expect(migration, contains('public.create_feeding_plan('));
    expect(migration, contains('public.create_feeding_plan_version('));
    expect(
      migration,
      contains(
        'grant execute on function public.create_feeding_plan_with_version',
      ),
    );
  });

  test('feeding lifecycle exposes versions items overrides and activation', () {
    for (final operation in const [
      'create_feeding_plan_version',
      'upsert_feeding_plan_item_v2',
      'approve_feeding_plan_version',
      'activate_feeding_plan_version',
      'retire_feeding_plan',
    ]) {
      expect(runtime, contains("operation: '$operation'"));
    }
    expect(runtime, contains("value: 'temporary'"));
    expect(runtime, contains('List<String> get _activeStandardOverrideKeys'));
    expect(runtime, contains("labelText: 'Te vervangen standaardvoerslot'"));
    expect(runtime, contains("labelText: 'Unieke voerslotsleutel'"));
    expect(runtime, contains("'p_expected_row_version':"));
    expect(runtime, contains("'p_through_local_date':"));
    expect(runtime, contains("versionStatus == 'draft'"));
    expect(runtime, contains("versionStatus == 'approved'"));
  });

  test('feeding writes replay exact values and fail closed after a dialog', () {
    final itemUpsert = runtime.substring(
      runtime.indexOf('Future<void> _upsertFeedingItem('),
      runtime.indexOf('Future<Map<String, String>?> _showFeedingItemDialog('),
    );
    expect(runtime, contains('_runDurableIdempotentRpc('));
    expect(runtime, contains('scopePreflight: scopePreflight'));
    expect(itemUpsert, contains('scopePreflight: scopePreflight'));
    expect(runtime, contains('_planningScopeMatches('));
    expect(runtime, contains('_assertPlanningScopeCurrent('));
    expect(runtime, contains('_sensitivePlanningDialogContext'));
    expect(runtime, contains('_dismissSensitiveDialogs();'));
    expect(
      runtime,
      contains("'actual_quantity': details['actual_quantity'].toString()"),
    );
    expect(runtime, contains("'corrects_execution_id': originalExecutionId"));
    expect(
      runtime,
      contains(
        "'p_corrects_execution_id': replayValues['corrects_execution_id']",
      ),
    );
  });

  test('completed feeding execution supports append-only correction', () {
    expect(runtime, contains('Future<void> _correctFeedingExecution('));
    expect(runtime, contains("title: 'Correctie registreren'"));
    expect(runtime, contains("'p_note': 'Append-only correctie'"));
    expect(runtime, contains('_showCompletedExecutionActions(item)'));
    expect(runtime, contains("item['item_kind'] == 'feeding'"));
    expect(
      runtime,
      isNot(
        contains(
          "_operationalString(item['item_kind']) == 'feeding' ||\n"
          "            _operationalString(item['state']) != 'completed'",
        ),
      ),
    );
  });

  test('SQL proves replay exact override assignment correction and denial', () {
    expect(sql, contains('Atomic feeding plan replay was not idempotent'));
    expect(
      sql,
      contains('Temporary plan replaced a non-matching override slot'),
    );
    expect(sql, contains('Matching standard slots were not replaced exactly'));
    expect(sql, contains('Non-matching standard slots were not preserved'));
    expect(
      sql,
      contains('Assigned groom saw more or fewer than one total feeding task'),
    );
    expect(
      sql,
      contains('Assigned groom did not receive the exact feeding task'),
    );
    expect(sql, contains('Feeding correction replay was not idempotent'));
    expect(sql, contains('Feeding correction did not remain append-only'));
    expect(sql, contains('Cross-stable owner read feeding plan from stable A'));
    expect(sql, contains('Revoked user retained feeding-plan visibility'));
    expect(sql, contains('Revoked user mutated a feeding execution'));
  });

  test('local runner is reset-guarded and repeats feeding races', () {
    expect(runner, contains("'--confirm-local-reset'"));
    expect(runner, contains("expected_label='avaryn-flutterflow-workspace'"));
    expect(
      runner,
      contains('provisioner failure was not the allowed final 502'),
    );
    expect(runner, contains('unexpected status[[:space:]]+502'));
    expect(runner, contains('phase_5d2_feeding_alpha_acceptance.sql'));
    expect(
      RegExp('phase_4c4_feeding_concurrency\\.rb').allMatches(runner).length,
      2,
    );
    expect(runner, contains('flutterflow_ai.dart test'));
  });
}

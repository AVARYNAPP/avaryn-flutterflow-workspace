import 'dart:io';

import 'package:test/test.dart';

void main() {
  late String runtime;
  late String edit;
  late String migration;
  late String sql;

  setUpAll(() {
    runtime = File('dsl/avaryn_operational_runtime.dart').readAsStringSync();
    edit = File('dsl/edit.dart').readAsStringSync();
    migration =
        File(
          'supabase/migrations/'
          '202607290001_phase_5_alpha_product_recovery.sql',
        ).readAsStringSync();
    sql =
        File(
          'supabase/tests/phase_5d1_planning_alpha_acceptance.sql',
        ).readAsStringSync();
  });

  test(
    'active edit flow includes the Phase 5D.1 planning acceptance slice',
    () {
      expect(edit, contains('buildAvarynPhase5D2,'));
      expect(edit, contains('void buildAvarynPhase5D1(App app)'));
      expect(edit, contains('_applyPhase4C7OperationalRuntimeResource(app);'));
    },
  );

  test(
    'day week and month navigation drive one authoritative calendar RPC',
    () {
      expect(runtime, contains('DateTime? _scheduleDate;'));
      expect(runtime, contains("'p_from_local_date':"));
      expect(runtime, contains("'p_through_local_date':"));
      expect(runtime, contains("message: 'Vorige periode'"));
      expect(runtime, contains("message: 'Volgende periode'"));
      expect(runtime, contains("child: const Text('Vandaag')"));
      expect(runtime, contains("value: 'day'"));
      expect(runtime, contains("value: 'week'"));
      expect(runtime, contains("value: 'month'"));
    },
  );

  test('recurring routines use one atomic durable server workflow', () {
    expect(
      runtime,
      contains("operation: 'create_schedule_series_with_occurrences_v2'"),
    );
    expect(runtime, contains('_runDurableIdempotentRpc('));
    expect(runtime, contains("'p_frequency': replayValues['frequency']"));
    expect(runtime, contains("'p_generation_horizon_days': 30"));
    expect(runtime, contains("'p_status': 'active'"));
    expect(runtime, contains('add(const Duration(days: 12))'));
    expect(runtime, contains("'p_materialize_request_id':"));
    expect(runtime, contains("label: const Text('Activiteit toevoegen')"));
    expect(
      migration,
      contains(
        'create or replace function public.'
        'create_schedule_series_with_occurrences_v2(',
      ),
    );
    expect(migration, contains('public.materialize_schedule_occurrences('));
  });

  test('one-off task and assignment are one atomic durable workflow', () {
    expect(
      runtime,
      contains(".select('id,display_name,function_title,status')"),
    );
    expect(runtime, contains("labelText: 'Verantwoordelijke'"));
    expect(
      runtime,
      contains("operation: 'create_schedule_task_with_assignment_v2'"),
    );
    expect(runtime, contains("'stable_member_id': memberId"));
    expect(runtime, contains("'assignment_request_id': _uuid.v4()"));
    expect(runtime, contains('if (selectedHour == 23)'));
    expect(runtime, contains('selectedMinute = 45;'));
    expect(migration, contains('public.assign_schedule_item('));
  });

  test('planning dialogs are purged and stale confirmations cannot mutate', () {
    expect(runtime, contains('_sensitivePlanningDialogContext'));
    expect(runtime, contains('_sensitivePlanningDialogRoute'));
    expect(runtime, contains('void _dismissSensitiveDialogs()'));
    expect(runtime, contains('planningRoute.isActive'));
    expect(runtime, contains('_planningScopeMatches('));
    expect(runtime, contains('_assertPlanningScopeCurrent('));
    expect(runtime, contains("StateError('STALE_PLANNING_CONFIRMATION')"));
    expect(runtime, contains('_client.auth.currentUser?.id == actorUserId'));
    expect(runtime, contains('_stableId == stableId'));

    final purgeStart = runtime.indexOf('Future<bool> _purgeOperationalState(');
    final purgeEnd = runtime.indexOf('void _clearDecryptedState()', purgeStart);
    final purge = runtime.substring(purgeStart, purgeEnd);
    expect(
      purge.indexOf('_dismissSensitiveDialogs();'),
      lessThan(purge.indexOf('_clearDecryptedState();')),
    );
  });

  test('offline daysets are bound to the exact current stable date', () {
    expect(runtime, contains("'local_date': localDate"));
    expect(runtime, contains('localDate: localDate'));
    expect(
      sql,
      contains('Daily routine materialization horizon is off by one'),
    );
  });

  test('planning roster is fetched only in Planning mode', () {
    expect(runtime, contains("widget.mode == 'planning'"));
    expect(
      runtime,
      contains("Future<dynamic>.value(const <Map<String, dynamic>>[])"),
    );
  });

  test(
    'current Flutter SDK build blockers use compatible package versions',
    () {
      expect(edit, contains("name: 'font_awesome_flutter'"));
      expect(edit, contains("newVersion: '10.7.0'"));
      expect(edit, contains("name: 'page_transition'"));
      expect(edit, contains("newVersion: '2.2.2'"));
    },
  );

  test('SQL proves replay, minimal assignment scope and revoked denial', () {
    expect(
      sql,
      contains('Atomic routine same-request replay was not idempotent'),
    );
    expect(sql, contains('Atomic task same-request replay was not idempotent'));
    expect(
      sql,
      contains('Assigned rider received more than the assigned task'),
    );
    expect(
      sql,
      contains('Assigned rider directly accessed an unassigned task'),
    );
    expect(sql, contains('Revoked user retained direct task access'));
    expect(sql, contains('Revoked user retained direct task mutation access'));
  });

  test('new planning controls stay unavailable offline or while busy', () {
    expect(
      RegExp(r'_offline \|\| _busy').allMatches(runtime).length,
      greaterThanOrEqualTo(5),
    );
    expect(runtime, isNot(contains("label: const Text('Routine aanmaken')")));
    expect(runtime, contains('_offline || _busy ? null : _createScheduleItem'));
    expect(runtime, contains('bool get _selectedScheduleDateIsToday'));
    expect(
      runtime,
      contains('_offline || _busy || !_selectedScheduleDateIsToday'),
    );
    expect(runtime, contains('Offline dagset alleen voor vandaag'));
  });
}

import 'dart:io';

import 'package:test/test.dart';

void main() {
  late String runtime;
  late String migration;

  setUpAll(() {
    runtime = File('dsl/avaryn_operational_runtime.dart').readAsStringSync();
    migration =
        File(
          'supabase/migrations/'
          '202607290001_phase_5_alpha_product_recovery.sql',
        ).readAsStringSync();
  });

  test('recovery migration is forward-only and preserves existing records', () {
    expect(migration, contains('add column if not exists item_category'));
    expect(migration.toLowerCase(), isNot(contains('drop table')));
    expect(migration.toLowerCase(), isNot(contains('truncate')));
    expect(migration.toLowerCase(), isNot(contains('delete from')));
  });

  test('calendar exposes day week month and all requested filters', () {
    for (final value in const [
      "value: 'day'",
      "value: 'week'",
      "value: 'month'",
      "labelText: 'Paard'",
      "labelText: 'Gebruiker'",
      "labelText: 'Categorie'",
      "labelText: 'Overzicht'",
    ]) {
      expect(runtime, contains(value));
    }
    expect(
      runtime,
      contains("operation: 'create_schedule_task_with_assignment_v2'"),
    );
    expect(
      runtime,
      contains("operation: 'create_schedule_series_with_occurrences_v2'"),
    );
  });

  test('calendar mutations preserve one record and recurrence scopes', () {
    expect(runtime, contains("operation: 'update_schedule_item'"));
    expect(
      runtime,
      contains("operation: 'update_schedule_series_scope_materialized'"),
    );
    expect(runtime, contains("final occurrenceScope = scope == 'occurrence';"));
    expect(runtime, contains("scope: 'future'"));
    expect(runtime, contains("child: const Text('Deze en volgende')"));
    expect(runtime, contains("p_execution_status': 'skipped'"));
  });

  test('calendar projection remains authority filtered and chronological', () {
    expect(migration, contains('private.schedule_item_access_level(item.id)'));
    expect(migration, contains("item.access_level in ('full', 'assigned')"));
    expect(migration, contains('order by item.scheduled_start_at, item.id'));
    expect(migration, contains('responsible_stable_member_id uuid'));
    expect(migration, contains('series_row_version bigint'));
  });

  test('feeding covers all five types and temporary overrides', () {
    for (final category in const [
      "'feed'",
      "'supplement'",
      "'hay'",
      "'water'",
      "'medication'",
    ]) {
      expect(runtime, contains(category));
      expect(migration, contains(category));
    }
    expect(runtime, contains("labelText: 'Te vervangen standaardvoerslot'"));
    expect(runtime, contains("operation: 'upsert_feeding_plan_item_v2'"));
  });

  test('feeding execution records planned actual deviation and notes', () {
    for (final field in const [
      "'p_actual_quantity'",
      "'p_remaining_quantity'",
      "'p_deviation_code'",
      "'p_observation'",
      "'p_note'",
    ]) {
      expect(runtime, contains(field));
    }
    expect(runtime, contains("labelText: 'Observatie'"));
    expect(runtime, contains("labelText: 'Opmerking'"));
    expect(runtime, contains("'comments': comments.text.trim()"));
    expect(runtime, contains("'observation': observation.text.trim()"));
  });

  test('feeding Today instructions and horse history are product routes', () {
    expect(runtime, contains('Future<void> _showFeedingOccurrenceDetails('));
    expect(runtime, contains("child: const Text('Uitvoeren')"));
    expect(runtime, contains("'Historie per paard'"));
    expect(runtime, contains("'Gepland:"));
    expect(runtime, contains("'Werkelijk:"));
    expect(migration, contains('feeding_execution_details'));
  });

  test('the legacy local prototype is not reactivated', () {
    expect(runtime, contains("widget.mode == 'planning'"));
    expect(runtime, contains("'list_schedule_calendar'"));
    expect(runtime, isNot(contains('FFAppState().activities.add')));
    expect(runtime, isNot(contains('FFAppState().feedingPlans.add')));
  });
}

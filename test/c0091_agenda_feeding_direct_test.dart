import 'dart:io';

import 'package:test/test.dart';

void main() {
  final runtime =
      File('dsl/avaryn_horse_account_runtime.dart').readAsStringSync();
  final migration =
      File(
        'supabase/migrations/202608110001_c0091_atomic_feeding_round.sql',
      ).readAsStringSync();
  final singletonMigration =
      File(
        'supabase/migrations/202608110002_c0091_single_standard_feeding_plan.sql',
      ).readAsStringSync();
  final sqlTest =
      File('supabase/tests/c0091_atomic_feeding_round.sql').readAsStringSync();

  test(
    'one forward-only migration adds bale across durable unit constraints',
    () {
      expect(migration.trimLeft(), startsWith('begin;'));
      expect(migration.trimRight(), endsWith('commit;'));
      expect(
        RegExp("'bale'").allMatches(migration).length,
        greaterThanOrEqualTo(4),
      );
      for (final constraint in const [
        'feeding_plan_items_unit_code_check',
        'feeding_occurrences_unit_code_check',
        'feeding_execution_details_unit_code_check',
      ]) {
        expect(migration, contains(constraint));
      }
      expect(runtime, contains("'bale' => 'baal'"));
      expect(runtime, contains("value: 'bale', child: Text('baal')"));
    },
  );

  test('atomic Feeding RPC validates all products before durable writes', () {
    expect(
      migration,
      contains('function public.save_canonical_horse_feeding_round('),
    );
    expect(migration, contains("security definer\nset search_path = ''"));
    expect(migration, contains('private.c003c_actor_profile_id()'));
    expect(
      migration,
      contains(
        "private.c003c_require_permission(actor_profile,p_horse_id,'horse.edit')",
      ),
    );
    expect(migration, contains('for product in select value'));
    expect(
      migration.indexOf('for product in select value'),
      lessThan(migration.indexOf('insert into public.feeding_plans(')),
    );
    expect(migration, contains("message='HORSE_FEEDING_UNAVAILABLE'"));
    expect(migration, contains("message='STALE_FEEDING_PLAN_VERSION'"));
    expect(migration, contains("'save_canonical_horse_feeding_round'"));
    expect(migration, contains('private.feeding_receipt_result('));
    expect(migration, contains('pg_advisory_xact_lock'));
  });

  test('contract test covers rollback replay authority and compatibility', () {
    for (final proof in const [
      'invalid product left partial Feeding data',
      'atomic multi-product or bale save failed',
      'atomic Feeding replay duplicated data',
      'round edit lost data or created duplicates',
      'standard plan identity was not reused',
      'invalid temporary request left durable data',
      'unauthorized horse write succeeded',
      'cross-horse plan ID succeeded',
      'existing loose Feeding RPC stopped working',
    ]) {
      expect(sqlTest, contains(proof));
    }
    expect(sqlTest, contains('rollback;'));
  });

  test(
    'standard Feeding identity is reused under the canonical horse lock',
    () {
      expect(singletonMigration.trimLeft(), startsWith('begin;'));
      expect(singletonMigration.trimRight(), endsWith('commit;'));
      expect(
        singletonMigration,
        contains('rename to save_canonical_horse_feeding_round_v1'),
      );
      expect(singletonMigration, contains('set schema private'));
      expect(singletonMigration, contains('pg_advisory_xact_lock'));
      expect(singletonMigration, contains("p_plan_type='standard'"));
      expect(singletonMigration, contains('plan.status<>\'retired\''));
      expect(
        singletonMigration,
        contains('private.save_canonical_horse_feeding_round_v1('),
      );
      expect(singletonMigration, contains('to authenticated'));
    },
  );

  test(
    'agenda merges authorized sources and removes duplicate schedule IDs',
    () {
      expect(runtime, contains("'list_my_canonical_horse_schedule'"));
      expect(runtime, contains("'list_canonical_horse_schedule'"));
      expect(
        runtime,
        contains('List<Map<String, dynamic>> _mergedScheduleItems()'),
      );
      expect(
        runtime,
        contains("final byId = <String, Map<String, dynamic>>{}"),
      );
      expect(runtime, contains('byId[id] = {...?byId[id], ...row};'));
      expect(runtime, contains("raw['state']?.toString() == 'cancelled'"));
      expect(runtime, contains('_agendaMonthPicker('));
      expect(runtime, contains('_agendaDayTimeline(dayRows)'));
      expect(runtime, contains('· Vrij'));
    },
  );

  test('one planner owns Start End agenda and 24-hour selection', () {
    final editorStart = runtime.indexOf('Future<void> _showScheduleEditor');
    final editorEnd = runtime.indexOf(
      'Widget _scheduleRangeEditor',
      editorStart,
    );
    final editor = runtime.substring(editorStart, editorEnd);
    expect(editor, contains('_scheduleRangeEditor('));
    expect(editor, isNot(contains('_dateTimeEditor(')));
    expect(editor, isNot(contains('_showScheduleAgenda(')));
    expect(editor, contains('if (end.isBefore(start))'));
    expect(editor, contains('De eindtijd mag niet vóór de starttijd liggen.'));
    expect(
      runtime,
      contains('_showScheduleRangePlanner(start: start, end: end)'),
    );
    expect(runtime, contains("Text('Meerdere dagen')"));
    expect(
      runtime,
      contains("label: Text('Van · \${_timeLabel(selectedStart)}')"),
    );
    expect(
      runtime,
      contains("label: Text('Tot · \${_timeLabel(selectedEnd)}')"),
    );
    expect(runtime, contains('selectedEnd = selectedStart.add(safeDuration)'));
    expect(runtime, contains("padLeft(2, '0')"));
  });

  test('planner summary is compact for single and multi-day ranges', () {
    final summaryStart = runtime.indexOf('String _scheduleRangeSummary');
    final summaryEnd = runtime.indexOf(
      'Future<TimeOfDay?> _pickTime24',
      summaryStart,
    );
    final summary = runtime.substring(summaryStart, summaryEnd);
    expect(
      summary,
      contains(
        "return '\$startDay · \${_timeLabel(start)} – \${_timeLabel(end)}';",
      ),
    );
    expect(
      summary,
      contains(
        "return '\$startDay \${_timeLabel(start)} → \$endDay \${_timeLabel(end)}';",
      ),
    );
    expect(summary, contains("'aug'"));

    final editorStart = runtime.indexOf('Widget _scheduleRangeEditor');
    final editorEnd = runtime.indexOf(
      'Future<TimeOfDay?> _pickTime24',
      editorStart,
    );
    final editor = runtime.substring(editorStart, editorEnd);
    expect(editor, contains('_scheduleRangeSummary(start, end)'));
    expect(
      editor,
      contains('_showScheduleRangePlanner(start: start, end: end)'),
    );
    expect(editor, isNot(contains("'Planning\\n'")));
    expect(editor, isNot(contains("'Start ·")));
    expect(editor, isNot(contains("'Einde ·")));
  });

  test(
    'agenda sheet has one primary vertical scroll and content-sized day rows',
    () {
      final plannerStart = runtime.indexOf(
        'Future<_ScheduleRangeSelection?> _showScheduleRangePlanner',
      );
      final plannerEnd = runtime.indexOf(
        'Widget _agendaMonthPicker',
        plannerStart,
      );
      final planner = runtime.substring(plannerStart, plannerEnd);
      expect(planner, contains('child: ListView('));
      expect(planner, isNot(contains('Expanded(child: _agendaDayTimeline')));

      final timelineStart = runtime.indexOf('Widget _agendaDayTimeline');
      final timelineEnd = runtime.indexOf(
        'Widget _agendaFreeBlock',
        timelineStart,
      );
      final timeline = runtime.substring(timelineStart, timelineEnd);
      expect(timeline, contains('return Column('));
      expect(timeline, isNot(contains('ListView.separated(')));
    },
  );

  test('direct Feeding form exposes exact product types units and rows', () {
    for (final label in const [
      'Brok',
      'Muesli',
      'Mash',
      'Hooi / ruwvoer',
      'Supplement',
      'Medicatie',
      'Olie',
      'Anders',
      'gram',
      'kilogram',
      'milliliter',
      'liter',
      'maatschep',
      'portie',
      'stuk',
      'baal',
    ]) {
      expect(runtime, contains("Text('$label')"));
    }
    expect(runtime, contains("Text('Nog een product toevoegen')"));
    expect(runtime, contains("'Merk / productomschrijving'"));
    expect(runtime, contains("labelText: 'Hoeveelheid *'"));
    expect(runtime, contains("'p_products': ["));
  });

  test('basis and temporary saves use only the atomic client route', () {
    final tabStart = runtime.indexOf('Widget _feedingTab');
    final legacyStart = runtime.indexOf(
      'Future<void> _showFeedingPlanEditor',
      tabStart,
    );
    final activeRuntime = runtime.substring(tabStart, legacyStart);
    expect(activeRuntime, contains('_showFeedingRoundEditor('));
    expect(activeRuntime, contains("'save_canonical_horse_feeding_round'"));
    expect(
      activeRuntime,
      isNot(contains("'create_canonical_horse_feeding_plan'")),
    );
    expect(
      activeRuntime,
      isNot(contains("'upsert_canonical_horse_feeding_item'")),
    );
    expect(activeRuntime, contains("planType: 'temporary'"));
    expect(activeRuntime, contains("label: 'Geldig van'"));
    expect(activeRuntime, contains("label: 'Geldig tot en met'"));
  });

  test('basis and temporary input share one primary vertical scroll', () {
    final editorStart = runtime.indexOf('Future<void> _showFeedingRoundEditor');
    final editorEnd = runtime.indexOf(
      'List<_FeedingProductDraft> _feedingDraftsForRound',
      editorStart,
    );
    final editor = runtime.substring(editorStart, editorEnd);
    expect(editor, contains('child: ListView('));
    expect(RegExp(r'child: ListView\(').allMatches(editor).length, equals(1));
    expect(
      editor,
      isNot(
        contains('Expanded(\n                            child: ListView('),
      ),
    );
    expect(editor, contains("label: 'Geldig van'"));
    expect(editor, contains("label: 'Geldig tot en met'"));
    expect(editor, contains("labelText: 'Dagdeel'"));
    expect(editor, contains("Text('Nog een product toevoegen')"));
    expect(editor, contains("child: Text('Annuleren')"));
    expect(editor, contains("child: Text(saving ? 'Opslaan…' : 'Opslaan')"));
  });

  test('temporary plans expose edit early-end and confirmed removal', () {
    final cardStart = runtime.indexOf('Widget _feedingPlanCard');
    final cardEnd = runtime.indexOf('Widget _feedingRoundCard', cardStart);
    final card = runtime.substring(cardStart, cardEnd);
    expect(card, contains("label: Text('Wijzigen')"));
    expect(card, contains("label: Text('Eerder beëindigen')"));
    expect(card, contains("label: Text('Verwijderen')"));
    expect(card, contains('_showTemporaryPlanEndEditor(plan)'));
    expect(card, contains('_confirmRemoveTemporaryPlan(plan)'));

    final endStart = runtime.indexOf(
      'Future<void> _showTemporaryPlanEndEditor',
    );
    final endEnd = runtime.indexOf(
      'Future<void> _confirmRemoveTemporaryPlan',
      endStart,
    );
    final endFlow = runtime.substring(endStart, endEnd);
    expect(endFlow, contains("label: Text('Vandaag stoppen')"));
    expect(endFlow, contains("label: 'Laatste dag tijdelijk schema'"));
    expect(endFlow, contains('_saveFeedingRound('));
    expect(endFlow, contains("planType: 'temporary'"));

    final removeStart = runtime.indexOf(
      'Future<void> _confirmRemoveTemporaryPlan',
    );
    final removeEnd = runtime.indexOf(
      'static const _feedingKnownUnits',
      removeStart,
    );
    final removeFlow = runtime.substring(removeStart, removeEnd);
    expect(removeFlow, contains("Text('Tijdelijk schema verwijderen?')"));
    expect(removeFlow, contains("child: Text('Verwijderen')"));
    expect(removeFlow, contains('await _retireFeedingPlan(plan)'));
  });

  test('feeding mutations reload and immediately recompute active schema', () {
    final tabStart = runtime.indexOf('Widget _feedingTab');
    final tabEnd = runtime.indexOf(
      'Map<String, dynamic>? _preferredFeedingPlan',
      tabStart,
    );
    final tab = runtime.substring(tabStart, tabEnd);
    expect(tab, contains('final active = _activeFeedingPlan('));
    expect(tab, contains('_activeFeedingSummary(active)'));

    final saveStart = runtime.indexOf('Future<void> _saveFeedingRound');
    final saveEnd = runtime.indexOf(
      'Future<void> _showTemporaryPlanEndEditor',
      saveStart,
    );
    expect(
      runtime.substring(saveStart, saveEnd),
      contains('await _load(selectHorseId: horseId)'),
    );

    final retireStart = runtime.indexOf('Future<void> _retireFeedingPlan');
    final retireEnd = runtime.indexOf('Widget _domainEmptyCard', retireStart);
    final retire = runtime.substring(retireStart, retireEnd);
    expect(retire, contains("'retire_canonical_horse_feeding_plan'"));
    expect(retire, contains('await _load(selectHorseId: horseId)'));
    expect(runtime, contains("plan['status']?.toString() != 'retired'"));
  });

  test('three dayparts are independently displayed and editable', () {
    expect(
      runtime,
      contains(
        "for (final round in const ['morning', 'afternoon', 'evening'])",
      ),
    );
    expect(runtime, contains('Widget _feedingRoundCard({'));
    expect(runtime, contains("items.isEmpty ? 'Toevoegen' : 'Bewerken'"));
    expect(runtime, contains("'morning' => 'Ochtend'"));
    expect(runtime, contains("'afternoon' => 'Middag'"));
    expect(runtime, contains("'evening' => 'Avond'"));
  });

  test('one functional Basisvoeding drives active content and editing', () {
    final tabStart = runtime.indexOf('Widget _feedingTab');
    final cardStart = runtime.indexOf('Widget _feedingPlanCard', tabStart);
    final tab = runtime.substring(tabStart, cardStart);
    expect(tab, contains('final standardPlan = _preferredFeedingPlan'));
    expect(tab, contains('_activeFeedingPlan('));
    expect(tab, contains('_feedingPlanCard(standardPlan'));
    expect(tab, isNot(contains("for (final plan in plans.where")));
    expect(runtime, contains("plan['status']?.toString() != 'active'"));
    expect(runtime, contains('_feedingPlanItems(standardPlan).isNotEmpty'));
    expect(runtime, contains("Text('Geen producten'"));
  });

  test('save failure and swipe dismiss never update a disposed sheet', () {
    expect(
      RegExp(
        r'catch \(caught\) \{\s+if \(!sheetContext\.mounted\) return;',
      ).allMatches(runtime).length,
      greaterThanOrEqualTo(2),
    );
    expect(
      runtime,
      contains('Deze Alpha-omgeving mist nog de beveiligde voedingsupdate.'),
    );
    expect(runtime, contains('if (sheetContext.mounted)'));
  });
}

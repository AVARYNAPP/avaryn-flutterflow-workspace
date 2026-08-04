import 'dart:io';

import 'package:test/test.dart';

void main() {
  late String runtime;
  late String stableRuntime;
  late String migration;
  late String interactionMigration;
  late String horseIdentityMigration;
  late String editFlow;

  setUpAll(() {
    runtime = File('dsl/avaryn_operational_runtime.dart').readAsStringSync();
    stableRuntime = File('dsl/avaryn_stable_runtime.dart').readAsStringSync();
    editFlow = File('dsl/edit.dart').readAsStringSync();
    migration =
        File(
          'supabase/migrations/'
          '202607290001_phase_5_alpha_product_recovery.sql',
        ).readAsStringSync();
    interactionMigration =
        File(
          'supabase/migrations/'
          '202607300001_phase_5_alpha_interaction_recovery.sql',
        ).readAsStringSync();
    horseIdentityMigration =
        File(
          'supabase/migrations/'
          '202607270002_phase_4c2b_horse_identity_relationships.sql',
        ).readAsStringSync();
  });

  test('recovery migration is forward-only and preserves existing records', () {
    expect(migration, contains('add column if not exists item_category'));
    expect(migration.toLowerCase(), isNot(contains('drop table')));
    expect(migration.toLowerCase(), isNot(contains('truncate')));
    expect(migration.toLowerCase(), isNot(contains('delete from')));
  });

  test('calendar exposes day week month without the removed main filters', () {
    for (final value in const [
      "value: 'day'",
      "value: 'week'",
      "value: 'month'",
    ]) {
      expect(runtime, contains(value));
    }
    final calendarControls = runtime.substring(
      runtime.indexOf('Widget _calendarControls('),
      runtime.indexOf('Future<void> _createFeedingPlan('),
    );
    expect(calendarControls, isNot(contains("labelText: 'Paard'")));
    expect(calendarControls, isNot(contains("labelText: 'Gebruiker'")));
    expect(calendarControls, isNot(contains("labelText: 'Categorie'")));
    expect(runtime, isNot(contains('Widget _planningListFilters(')));
    expect(runtime, contains('childAspectRatio: compact ? 0.72 : 0.88'));
    expect(runtime, isNot(contains('child: SizedBox(width: 720')));
    expect(
      runtime,
      contains("operation: 'create_schedule_task_with_assignment_v2'"),
    );
    expect(
      runtime,
      contains("operation: 'create_schedule_series_with_occurrences_v2'"),
    );
  });

  test('visible dates use Dutch day-month-year notation', () {
    expect(runtime, contains('String _operationalDisplayDate(dynamic value)'));
    expect(runtime, contains('DD-MM-JJJJ'));
    expect(runtime, contains('_stableDateTimeLabel('));
    expect(
      runtime,
      contains("_operationalDisplayDate(item['source_local_date'])"),
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

  test('Alpha recovery restores the visible product routes', () {
    for (final marker in const [
      "'Vandaag geregeld'",
      "'Start mijn dag'",
      "'Voeding vandaag'",
      "'Snel vastleggen'",
      'Widget _dayCalendar(',
      'Widget _weekCalendar(',
      'Widget _monthCalendar(',
      "'Dagvorm & aandacht'",
      "'Historie per paard'",
    ]) {
      expect(runtime, contains(marker));
    }
    expect(runtime, contains('const AvarynOrionPhoto('));
  });

  test('normal Alpha UX does not expose technical authority messages', () {
    expect(runtime, isNot(contains('serverbeleid is leidend')));
    expect(runtime, isNot(contains('OS-backed sleutelopslag is verplicht')));
    expect(runtime, isNot(contains("'Immutable'")));
  });

  test('operational shell keeps a bounded desktop content canvas', () {
    expect(editFlow, contains("name: 'Phase4C7OperationalColumnBounds'"));
    expect(
      editFlow,
      contains(
        "name: 'Phase4C7OperationalColumnBounds',\n"
        '        width: double.infinity,\n'
        '        height: double.infinity,',
      ),
    );
    expect(editFlow, contains("name: 'Phase4C7OperationalRuntime'"));
  });

  test('desktop product rows do not stretch into unbounded scroll height', () {
    expect(
      runtime,
      isNot(
        contains(
          'return Row(\n'
          '              crossAxisAlignment: CrossAxisAlignment.stretch,',
        ),
      ),
    );
    expect(
      RegExp(
        r'return Row\(\s+crossAxisAlignment: CrossAxisAlignment\.start,',
      ).allMatches(runtime).length,
      greaterThanOrEqualTo(2),
    );
  });

  test('route context is initialized after inherited dependencies exist', () {
    final initState = stableRuntime.substring(
      stableRuntime.indexOf('void initState()'),
      stableRuntime.indexOf('void didChangeDependencies()'),
    );
    expect(initState, isNot(contains('_readTransientToken()')));
    expect(stableRuntime, contains('void didChangeDependencies()'));
    expect(stableRuntime, contains('addPostFrameCallback'));
    expect(stableRuntime, contains('if (mounted) unawaited(_load())'));
  });

  test('opening a task is read-only and exposes explicit outcomes', () {
    final openItem = runtime.substring(
      runtime.indexOf('void _openScheduleItem('),
      runtime.indexOf('Widget _horsesContent('),
    );
    expect(openItem, isNot(contains('_completeSchedule(item)')));
    expect(openItem, contains('_showScheduleItemActions(item)'));
    expect(runtime, contains("label: const Text('Start')"));
    expect(runtime, contains("label: const Text('Voltooien')"));
    expect(runtime, contains("child: const Text('Afwijking')"));
    expect(runtime, contains("'Taak gestart via taakdetail.'"));
    expect(runtime, contains("'Niet toegewezen'"));
    expect(runtime, contains("'Niet opgegeven'"));
  });

  test('Start mijn dag advances only after an explicit completion', () {
    expect(runtime, contains('void _startMyDay()'));
    expect(runtime, contains('Future<void> _offerNextGuidedTask()'));
    expect(runtime, contains("'Volgende taak openen'"));
    expect(runtime, contains("'Alles afgerond'"));
    expect(
      runtime.indexOf('await _offerNextGuidedTask();'),
      greaterThan(
        runtime.indexOf("_notice = 'Uitvoering veilig geregistreerd.'"),
      ),
    );
  });

  test('Horse profile photos reuse private same-horse media safely', () {
    expect(runtime, contains("'profile_media_asset_id'"));
    expect(runtime, contains("operation: 'set_horse_profile_media'"));
    expect(runtime, contains("imagesOnly: true"));
    expect(runtime, contains("'variant': 'thumbnail'"));
    expect(runtime, contains('Widget _horsePhoto('));
    expect(
      interactionMigration,
      contains('private.media_actor_has_capability'),
    );
    expect(interactionMigration, contains('target_asset.mime_type not in'));
    expect(
      interactionMigration,
      contains("array['profile_media_asset_id']::text[]"),
    );
    expect(interactionMigration.toLowerCase(), isNot(contains('drop table')));
    expect(interactionMigration.toLowerCase(), isNot(contains('truncate')));
  });

  test('Horse profile tabs switch content without hidden navigation', () {
    expect(runtime, contains("value: 'overview'"));
    expect(runtime, contains("value: 'planning'"));
    expect(runtime, contains("value: 'feeding'"));
    expect(runtime, contains("_horseProfileTab == 'overview'"));
    expect(runtime, contains("_horseProfileTab == 'planning'"));
    expect(runtime, contains("_horseProfileTab == 'feeding'"));
  });

  test('Horse selection is compact searchable and refreshes the profile', () {
    expect(runtime, contains('Future<void> _showHorseSelector()'));
    expect(runtime, contains("'Zoek op roepnaam of officiële naam'"));
    expect(runtime, contains('displayName.contains(normalizedQuery)'));
    expect(runtime, contains('officialName.contains(normalizedQuery)'));
    expect(runtime, contains('_horseProfileTab = \'overview\';'));
    expect(runtime, contains('await _load(quiet: true);'));
    final horseOverview = runtime.substring(
      runtime.indexOf('Widget _horsesContent('),
      runtime.indexOf('Widget _selectedHorseManagement('),
    );
    expect(horseOverview, isNot(contains('..._horses.map(')));
    expect(horseOverview, contains('Icons.keyboard_arrow_down'));
  });

  test('Horse profile is one photo hero with chips and edit actions', () {
    expect(runtime, contains('String _horseAgeLabel('));
    expect(runtime, contains("horse['birth_date']"));
    expect(runtime, contains("horse['best_performance']"));
    expect(runtime, contains('gradient: LinearGradient('));
    expect(runtime, contains("'PAARDPROFIEL'"));
    expect(runtime, contains("'Activiteit toevoegen'"));
    expect(runtime, contains("'Bewerken'"));
    expect(
      runtime,
      contains('Future<Map<String, dynamic>?> _showHorseProfilePage('),
    );
    expect(runtime, contains('fullscreenDialog: true'));
    expect(runtime, contains("'Foto kiezen'"));
    expect(runtime, contains("'Foto vervangen'"));
    expect(runtime, contains("'Profielfoto verwijderen'"));
  });

  test('Horse create and edit use one simple three-step mobile page', () {
    for (final marker in const [
      "'Gegevens paard'",
      "'Identificatie'",
      "'Team en profielfoto'",
      "'Roepnaam'",
      "'Officiële naam'",
      "'Geslacht'",
      "'Ras'",
      "'Discipline'",
      "'Dressuur'",
      "'Springen'",
      "'Eventing'",
      "'Hobby'",
      "'Eigenaar toevoegen'",
      "'Trainer toevoegen'",
      "'Ruiter toevoegen'",
    ]) {
      expect(runtime, contains(marker));
    }
    expect(runtime, isNot(contains('_showHorseProfileDialog(')));
    expect(runtime, contains('MaterialPageRoute('));
    expect(runtime, contains('showDatePicker('));
    expect(runtime, contains("'Kies vervaldatum'"));
    expect(
      runtime,
      contains('horse == null ? null : (_selectedHorse ?? horse)'),
    );
    expect(runtime, contains('value: 0'));
    expect(runtime, contains('value: 1'));
    expect(runtime, contains('value: 2'));
    expect(runtime, contains('_addHorseRelationshipsFromProfile('));
  });

  test('selected horse management is visible without an expansion menu', () {
    expect(runtime, contains('_selectedHorseManagementTools(theme)'));
    expect(runtime, isNot(contains("title: const Text('Beheer en toegang')")));
  });

  test('Horse identity is separately protected and warns before expiry', () {
    expect(runtime, contains("operation: 'upsert_horse_identifier'"));
    expect(runtime, contains("'passport_number'"));
    expect(runtime, contains("'chip_number'"));
    expect(runtime, contains("'passport_expires_on'"));
    expect(runtime, contains("'Paspoort vernieuwen'"));
    expect(
      runtime,
      contains('DateTime(today.year, today.month + 3, today.day)'),
    );
    expect(
      horseIdentityMigration,
      contains('create table public.horse_identifiers'),
    );
    expect(
      horseIdentityMigration,
      contains(
        "private.has_horse_capability(horse_id, 'horse.identity', 'view')",
      ),
    );
    expect(
      horseIdentityMigration,
      contains('create or replace function public.upsert_horse_identifier('),
    );
    expect(horseIdentityMigration.toLowerCase(), isNot(contains('drop table')));
    expect(horseIdentityMigration.toLowerCase(), isNot(contains('truncate')));
    expect(
      horseIdentityMigration.toLowerCase(),
      isNot(contains('delete from')),
    );
  });

  test('Operational controls use the AVARYN rose-gold selection theme', () {
    expect(runtime, contains('primary: theme.secondary'));
    expect(runtime, contains('backgroundColor: theme.secondary'));
    expect(runtime, contains('const roseGold = Color(0xFFC98980)'));
    expect(
      runtime,
      contains('segmentedButtonTheme: SegmentedButtonThemeData('),
    );
  });

  test('planning restores list agenda grouping and five activity types', () {
    expect(runtime, contains("value: 'list'"));
    expect(runtime, contains("value: 'calendar'"));
    expect(runtime, contains("'Activiteiten'"));
    expect(runtime, contains("'Activiteit toevoegen'"));
    expect(runtime, contains("'Mijn taken'"));
    expect(runtime, contains("'Alle stal'"));
    expect(runtime, isNot(contains("label: const Text('Routine aanmaken')")));
    for (final type in const [
      "'Training'",
      "'Verzorging'",
      "'Hoefsmid'",
      "'Dierenarts'",
      "'Wedstrijd'",
    ]) {
      expect(runtime, contains(type));
    }
    expect(runtime, contains("'all_day': allDay.toString()"));
    expect(runtime, contains("labelText: 'Einduur'"));
  });

  test(
    'planning period controls drive both list and visual calendar modes',
    () {
      final scheduleContent = runtime.substring(
        runtime.indexOf('Widget _scheduleContent('),
        runtime.indexOf('Widget _feedingContent('),
      );
      expect(
        scheduleContent.lastIndexOf('_calendarControls(theme)'),
        lessThan(scheduleContent.lastIndexOf('_scheduleDateControls(theme)')),
      );
      expect(scheduleContent, isNot(contains('_planningListFilters()')));
      expect(runtime, contains("'Vorige'"));
      expect(runtime, contains("'Vandaag'"));
      expect(runtime, contains("'Volgende'"));
      expect(
        runtime,
        contains("'Activiteiten op \${_operationalDisplayDate(selected)}'"),
      );
      expect(runtime, contains('for (var hour = startHour;'));
      expect(
        runtime,
        contains('_scheduleVisualCard(theme, item, planning: true'),
      );
    },
  );
}

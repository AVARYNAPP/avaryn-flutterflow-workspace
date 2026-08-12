import 'dart:io';

import 'package:test/test.dart';

void main() {
  final migration =
      File(
        'supabase/migrations/202608080003_c0091_canonical_media_hardening.sql',
      ).readAsStringSync();
  final security =
      File(
        'supabase/tests/c0091_canonical_media_hardening.sql',
      ).readAsStringSync();
  final concurrency =
      File(
        'supabase/tests/c0091_canonical_media_concurrency.rb',
      ).readAsStringSync();
  final edge =
      File('supabase/functions/media-assets/index.ts').readAsStringSync();
  final runtime =
      File('dsl/avaryn_horse_account_runtime.dart').readAsStringSync();
  final domainMigration =
      File(
        'supabase/migrations/202608100001_c0091_canonical_horse_planning_feeding_rescope.sql',
      ).readAsStringSync();
  final domainSecurity =
      File(
        'supabase/tests/c0091_canonical_planning_feeding_rescope.sql',
      ).readAsStringSync();
  final domainConcurrency =
      File(
        'supabase/tests/c0091_canonical_planning_feeding_concurrency.rb',
      ).readAsStringSync();
  final activityContract =
      File(
        'supabase/migrations/202608100002_c0091_planning_activity_contract.sql',
      ).readAsStringSync();

  test('canonical horse is the media scope and stable remains optional', () {
    expect(migration, contains('media_assets_canonical_horse_fk'));
    expect(migration, contains('alter column stable_id drop not null'));
    expect(
      migration,
      contains("coalesce(compatibility_stable_id::text, 'canonical')"),
    );
    expect(migration, isNot(contains('insert into public.stables')));
    expect(security, contains('canonical upload idempotency failed'));
    expect(
      security,
      contains('canonical upload fabricated legacy stable context'),
    );
  });

  test('private Edge lifecycle has distinct canonical actions', () {
    for (final action in const [
      'canonical_create',
      'canonical_finalize',
      'canonical_download',
    ]) {
      expect(edge, contains("action === '$action'"));
      expect(runtime, contains("'action': '$action'"));
    }
    expect(runtime, contains(".from('horse-media')"));
    expect(runtime, contains('.uploadBinaryToSignedUrl('));
    expect(runtime, isNot(contains('getPublicUrl')));
  });

  test('all canonical media operations remain server-authorized', () {
    for (final operation in const [
      'create_canonical_media_upload_session',
      'get_canonical_media_upload_session',
      'finalize_canonical_media_asset',
      'authorize_canonical_media_asset_download',
      'archive_canonical_media_asset',
      'set_canonical_horse_profile_media',
    ]) {
      expect(migration, contains(operation));
    }
    expect(migration, contains('private.c003c_profile_has_horse_permission'));
    expect(migration, contains("'horse.view'"));
    expect(migration, contains("'horse.edit'"));
    expect(security, contains('outsider created media for another horse'));
    expect(security, contains('cross-horse profile media selection succeeded'));
  });

  test('profile photo selection is CAS, idempotent and audited', () {
    expect(migration, contains('p_expected_row_version'));
    expect(migration, contains('STALE_HORSE_VERSION'));
    expect(migration, contains('private.lock_media_request'));
    expect(migration, contains("'set_canonical_horse_profile_media'"));
    expect(migration, contains("'profile_media_asset_id'"));
    expect(security, contains('same-horse selection or idempotency'));
    expect(security, contains('same-horse profile media audit failed'));
    expect(security, contains('stale profile media writer succeeded'));
    expect(concurrency, contains('one create request converged'));
    expect(concurrency, contains('one profile media writer won'));
  });

  test('photo client keeps durable request ids but no signed material', () {
    expect(runtime, contains("'create_request_id'"));
    expect(runtime, contains("'finalize_request_id'"));
    expect(runtime, contains("'select_request_id'"));
    expect(runtime, contains('FlutterSecureStorage'));
    final durableStart = runtime.indexOf(
      'Future<Map<String, String>> _durablePhotoRequest',
    );
    final durableEnd = runtime.indexOf(
      'Future<void> _setCanonicalProfilePhoto',
      durableStart,
    );
    final durable = runtime.substring(durableStart, durableEnd);
    for (final forbidden in const [
      'signed_upload_url',
      'signed_download_url',
      'upload_token',
      'object_path',
    ]) {
      expect(durable, isNot(contains(forbidden)));
    }
  });

  test('horse creation is minimal and protected against duplicate submit', () {
    expect(runtime, contains('Alleen de roepnaam is nodig'));
    expect(runtime, contains("'p_display_name': displayName.text.trim()"));
    expect(runtime, contains("'p_official_name': _optional(officialName)"));
    expect(runtime, contains('if (_busy) return'));
    expect(
      runtime,
      contains('saving\n                                  ? null'),
    );
    expect(
      runtime,
      contains('Paard toegevoegd. Je kunt het profiel nu verder aanvullen.'),
    );
  });

  test('profile view hides empty facts and uses human terminology', () {
    expect(
      runtime,
      contains("facts.where((fact) => fact.\$2.trim().isNotEmpty)"),
    );
    expect(runtime, contains("'Betrokkenen & locatie'"));
    expect(runtime, contains("'Beheer van het paard'"));
    expect(runtime, contains("'Hoofdbeheerder'"));
    expect(runtime, isNot(contains("_fact('Geboortedatum'")));
    expect(runtime, isNot(contains("'Geen officiële naam'")));
  });

  test('editing is sectioned and does not replay the creation flow', () {
    for (final section in const [
      'Basis',
      'Identificatie',
      'Gezondheid & documenten',
      'Betrokkenen & locatie',
    ]) {
      expect(runtime, contains("'$section'"));
    }
    expect(runtime, contains('initialSection'));
    expect(runtime, contains('Wijzigingen niet opslaan?'));
    expect(runtime, contains("'p_status': status"));
    expect(runtime, isNot(contains("'p_lifecycle_status':")));
  });

  test('date entry is localized, year-first and timezone stable', () {
    expect(runtime, contains("locale: const Locale('nl')"));
    expect(runtime, contains('initialDatePickerMode: DatePickerMode.year'));
    expect(runtime, contains('DateTime.utc('));
    expect(runtime, contains("value?.toString().split('-')"));
    expect(runtime, contains("cancelText: 'Annuleren'"));
  });

  test('overview and profile retain responsive states and product tabs', () {
    expect(runtime, contains('SliverList.builder'));
    expect(
      runtime,
      contains('constraints: const BoxConstraints(maxWidth: 1080)'),
    );
    expect(runtime, contains("'Paarden'"));
    expect(runtime, contains("'Paard toevoegen'"));
    expect(runtime, contains('_loadingSkeleton'));
    expect(runtime, contains("'Opnieuw proberen'"));
    expect(runtime, isNot(contains("context.pushNamed('PlanningPage')")));
    expect(
      runtime,
      isNot(contains("context.pushNamed('FeedingOverviewPage')")),
    );
    expect(runtime, contains('_profileTabIndex'));
    expect(runtime, contains('_planningTab(horse)'));
    expect(runtime, contains('_feedingTab(horse)'));
    expect(runtime, contains('maxHeight:'));
    expect(runtime, contains('MediaQuery.sizeOf(context).height -'));
    expect(runtime, contains("'list_my_canonical_horse_schedule'"));
    expect(runtime, contains("'Geen aandachtspunt'"));
    expect(runtime, contains("'Nog geen activiteit gepland'"));
    expect(runtime, contains('const AvarynOrionPhoto('));
    expect(
      File('dsl/edit.dart').readAsStringSync(),
      contains('assets/orion-mobile-hero.jpg'),
    );
    expect(runtime, contains('constraints.maxWidth < 620'));
  });

  test('profile defaults to horse Planning with the agreed tab order', () {
    expect(runtime, contains('int _profileTabIndex = 0'));
    final navigation = runtime.substring(
      runtime.indexOf('Widget _profileNavigation()'),
      runtime.indexOf('Widget _profileTab({'),
    );
    expect(
      navigation.indexOf("label: 'Planning'"),
      lessThan(navigation.indexOf("label: 'Voeding'")),
    );
    expect(
      navigation.indexOf("label: 'Voeding'"),
      lessThan(navigation.indexOf("label: 'Overzicht'")),
    );
    expect(runtime, contains('compactIdentity: _profileTabIndex != 2'));
  });

  test('activity editor is titleless, complete and uses a 24-hour wheel', () {
    final editor = runtime.substring(
      runtime.indexOf('Future<void> _showScheduleEditor('),
      runtime.indexOf('Widget _scheduleRangeEditor('),
    );
    final kindSelector = editor.substring(
      editor.indexOf('DropdownButtonFormField<String>('),
      editor.indexOf('onChanged:'),
    );
    expect(kindSelector, contains('items: ['));
    expect(kindSelector, isNot(contains('items: const [')));
    expect(kindSelector, contains("if (item?['item_kind'] == 'feeding')"));
    expect(kindSelector, contains("value: 'feeding'"));
    expect(kindSelector, contains("child: Text('Voeding (bestaand)')"));
    for (final label in const [
      'Training',
      'Taak',
      'Verzorging',
      'Hoefsmid',
      'Dierenarts',
      'Wedstrijd',
      'Transport',
      'Overig',
    ]) {
      expect(runtime, contains("child: Text('$label')"));
    }
    expect(runtime, isNot(contains("_field(title, 'Titel'")));
    expect(runtime, contains("'Notitie (optioneel)'"));
    expect(runtime, contains("title: _scheduleKindLabel(kind)"));
    expect(runtime, contains('ListWheelScrollView.useDelegate'));
    expect(runtime, contains('count: 24'));
    expect(runtime, contains('count: 60'));
    expect(
      runtime,
      contains('_showScheduleRangePlanner(start: start, end: end)'),
    );
    expect(runtime, contains('_scheduleRangeSummary(start, end)'));
    expect(runtime, isNot(contains("'Planning\\n'")));
    expect(runtime, isNot(contains('final time = await showTimePicker(')));
    for (final kind in const [
      'farrier',
      'veterinary',
      'competition',
      'transport',
    ]) {
      expect(activityContract, contains("'$kind'"));
    }
  });

  test(
    'normal Feeding UX is simple while lifecycle methods remain internal',
    () {
      expect(runtime, contains("child: Text('Ochtend')"));
      expect(runtime, contains("child: Text('Middag')"));
      expect(runtime, contains("child: Text('Avond')"));
      expect(runtime, isNot(contains("child: Text('Extra voerbeurt')")));
      expect(
        runtime,
        isNot(contains("child: Text('Ter goedkeuring afronden')")),
      );
      expect(runtime, isNot(contains("child: Text('Activeren')")));
      expect(runtime, isNot(contains("child: Text('Schema beëindigen')")));
      expect(runtime, contains("child: Text('Opslaan')"));
      expect(runtime, contains('transition_canonical_horse_feeding_version'));
      expect(runtime, contains('retire_canonical_horse_feeding_plan'));
    },
  );

  test(
    'canonical Planning and Feeding are horse-scoped and server-authorized',
    () {
      for (final operation in const [
        'list_canonical_horse_schedule',
        'upsert_canonical_horse_schedule_item',
        'get_canonical_horse_feeding',
        'create_canonical_horse_feeding_plan',
        'upsert_canonical_horse_feeding_item',
        'transition_canonical_horse_feeding_version',
        'retire_canonical_horse_feeding_plan',
      ]) {
        expect(domainMigration, contains(operation));
        expect(runtime, contains("'$operation'"));
      }
      expect(domainMigration, contains("'horse.view'"));
      expect(domainMigration, contains("'horse.edit'"));
      expect(runtime, contains('periodStart.add(const Duration(days: 730))'));
      expect(runtime, isNot(contains('DateTime.utc(now.year + 2')));
      expect(
        domainSecurity,
        contains('metadata does not influence Horse Authority'),
      );
      expect(
        File('supabase/tests/phase_4c3_planning_tasks.sql').readAsStringSync(),
        contains('canonical horse access is never inherited from stable'),
      );
      expect(
        File('supabase/tests/phase_4c4_feeding.sql').readAsStringSync(),
        contains('without deriving horse access'),
      );
      expect(
        domainConcurrency,
        contains('one schedule winner and one stale writer'),
      );
    },
  );

  test('horse domain editors are keyboard-aware and date-safe', () {
    expect(runtime, contains('showModalBottomSheet<void>'));
    expect(runtime, contains('isScrollControlled: true'));
    expect(runtime, contains('MediaQuery.viewInsetsOf'));
    expect(runtime, contains('scrollPadding: EdgeInsets.only'));
    expect(runtime, contains('final today = DateTime.now()'));
    expect(runtime, isNot(contains('initialDate: value ?? lastDate')));
  });

  test('horse experience uses the approved premium AVARYN hierarchy', () {
    for (final token in const [
      '0xFF141215',
      '0xFF211E22',
      '0xFFC98980',
      '0xFFF0B9AF',
    ]) {
      expect(runtime, contains(token));
    }
    expect(runtime, contains("'PAARDPROFIEL'"));
    expect(runtime, contains("'A V A R Y N'"));
    expect(runtime, contains("'Profiel bewerken'"));
    expect(runtime, contains("'Foto wijzigen'"));
    expect(runtime, contains("'Dagelijks ritme'"));
    expect(runtime, contains("'Beheer & toegang'"));
    expect(runtime, contains('_AvarynHorseHeadPainter'));
    expect(runtime, contains('_lightCanvas'));
    expect(runtime, contains('brightness: base.brightness'));
    expect(runtime, contains("variant: 'original'"));
    expect(runtime, isNot(contains('Dagvorm 86%')));
  });

  test('editor categories wrap and retain direct section editing', () {
    expect(runtime, contains('Wrap('));
    expect(runtime, contains("(2, 'Gezondheid')"));
    expect(runtime, contains("(3, 'Betrokkenen')"));
    expect(runtime, contains('initialSection'));
    expect(runtime, contains("'Werk één logisch onderdeel tegelijk bij.'"));
    expect(runtime, isNot(contains('scrollDirection: Axis.horizontal')));
  });
}

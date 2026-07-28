import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('Horse Alpha runtime uses cloud RPCs and optimistic concurrency', () {
    final source =
        File('dsl/avaryn_operational_runtime.dart').readAsStringSync();

    for (final rpc in const [
      'get_horse_capabilities',
      'create_horse',
      'update_horse_profile',
      'archive_horse',
      'grant_horse_access',
      'revoke_horse_access',
      'add_horse_relationship',
      'end_horse_relationship',
    ]) {
      expect(source, contains("'$rpc'"));
    }
    expect(source, contains("'p_expected_row_version': rowVersion"));
    expect(source, contains('_runDurableIdempotentRpc('));
    expect(source, contains(') => jsonEncode(['));
    expect(source, contains(".from('horses')"));
    expect(source, isNot(contains('FFAppState().horses.add')));
    expect(source, isNot(contains('UpdateAppState.add')));
  });

  test('Horse grants remain separate from semantic team relationships', () {
    final source =
        File('dsl/avaryn_operational_runtime.dart').readAsStringSync();
    final migration =
        File(
          'supabase/migrations/202607280001_phase_5b2_horse_alpha.sql',
        ).readAsStringSync();

    expect(
      source,
      contains(
        'Deze relaties beschrijven samenwerking en geven op zichzelf geen toegang.',
      ),
    );
    expect(source, contains("'p_category': grant['category']"));
    expect(source, contains("'p_stable_member_id':"));
    expect(migration, contains('private.has_horse_capability('));
    expect(migration, contains('private.can_manage_horse_grants('));
    expect(
      migration,
      isNot(contains('insert into public.horse_access_grants')),
    );
    expect(migration, isNot(contains('update public.horse_access_grants')));
  });

  test('Phase 5B.2 hard-redirects every legacy local Horse route', () {
    final source = File('dsl/edit.dart').readAsStringSync();
    final phase5B2 = source.substring(
      source.indexOf('void buildAvarynPhase5B2(App app)'),
      source.indexOf('String _loadPhase4BStableRuntimeWidgetCode()'),
    );

    expect(
      phase5B2,
      contains('_applyPhase4C7OperationalRuntimeResource(app);'),
    );
    for (final page in const [
      'ff.Pages.horseFormPage',
      'ff.Pages.horseEditPage',
      'ff.Pages.orionProfilePage',
    ]) {
      expect(phase5B2, contains(page));
    }
    expect(phase5B2, contains('app.editPageOnLoad(legacyPage'));
    expect(phase5B2, contains('_phase5B2LegacyHorseRedirectBody()'));
    expect(phase5B2, contains('allowBack: false'));
    expect(phase5B2, contains('replaceRoute: true'));
    expect(phase5B2, contains("name: 'HorsesOverviewPage'"));
    expect(source, contains("name: 'Phase5B2LegacyHorseRedirectBody'"));
    expect(source, contains('buildAvarynPhase5B2,'));
  });

  test('ambiguous Horse requests survive widget and app restart safely', () {
    final source =
        File('dsl/avaryn_operational_runtime.dart').readAsStringSync();
    final durableStart = source.indexOf(
      'Future<dynamic> _runDurableIdempotentRpc',
    );
    final durableEnd = source.indexOf(
      'Future<Map<String, dynamic>?> _showFeedingExecutionDialog',
      durableStart,
    );
    final durable = source.substring(durableStart, durableEnd);

    expect(durable, contains('sha256'));
    expect(durable, contains("_storageKey('request.\$digest')"));
    expect(durable, contains('await _secureStorage.write('));
    expect(durable, contains('encodedRecord != persistedValue'));
    expect(
      durable,
      contains('!phase5B2DurableStorageIsAbsent(persistedValue)'),
    );
    expect(
      durable.indexOf('await _secureStorage.write('),
      lessThan(durable.indexOf('final result = await _client.rpc(')),
    );
    expect(durable, contains('phase5B2ResolveDurableRequestRecord('));
    expect(durable, contains('initialReplayValues'));
    expect(durable, contains("RegExp(r'^[0-9A-Z]{5}\$')"));
    expect(
      source,
      contains("throw StateError('DURABLE_REQUEST_STORAGE_REQUIRED')"),
    );
    expect(source, contains("'p_valid_from': replayValues['valid_from']!"));
    expect(source, contains("'p_valid_until': replayValues['valid_until']!"));
  });
}

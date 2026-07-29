import 'dart:io';

import 'package:test/test.dart';

void main() {
  late String runtime;
  late String edit;
  late String migration;

  setUpAll(() {
    runtime = File('dsl/avaryn_operational_runtime.dart').readAsStringSync();
    edit = File('dsl/edit.dart').readAsStringSync();
    migration =
        File(
          'supabase/migrations/202607270006_phase_4c6_realtime_offline_sync.sql',
        ).readAsStringSync();
  });

  test('Phase 5B.5 exposes only bounded server-version conflict recovery', () {
    expect(runtime, contains('Future<void> _resolveSyncConflict('));
    expect(runtime, contains("entityType != 'horse_basic_noncritical'"));
    for (final field in const [
      'display_name',
      'official_name',
      'birth_date',
      'sex',
      'breed',
      'discipline',
      'level',
    ]) {
      expect(runtime, contains("'$field'"));
    }
    expect(runtime, contains("'resolution': 'resolved_server'"));
    expect(runtime, contains("'p_resolution': replayValues['resolution']"));
    expect(runtime, isNot(contains("'resolution': 'resolved_client'")));
    expect(runtime, isNot(contains("'resolution': 'resolved_merged'")));
    expect(runtime, contains('De serverversie blijft actief. Je kunt dit'));
    expect(runtime, contains('conflict sluiten en de lokale wijziging later'));
  });

  test('conflict resolution is explicit, durable and idempotent', () {
    final resolverStart = runtime.indexOf('Future<void> _resolveSyncConflict(');
    final resolverEnd = runtime.indexOf(
      'Future<void> _createHorse()',
      resolverStart,
    );
    final resolver = runtime.substring(resolverStart, resolverEnd);

    expect(resolver, contains("labelText: 'Reden (verplicht)'"));
    expect(resolver, contains('normalized.length > 500'));
    expect(resolver, contains("operation: 'resolve_sync_conflict'"));
    expect(resolver, contains('initialReplayValues: {'));
    expect(resolver, contains("'reason': normalizedReason"));
    expect(resolver, contains("'p_request_id': requestId"));
    expect(
      resolver,
      contains("sha256.convert(utf8.encode(normalizedReason)).toString()"),
    );
    expect(resolver, contains('scopePreflight: () {'));
    expect(
      resolver.indexOf("operation: 'resolve_sync_conflict'"),
      lessThan(resolver.indexOf('await _load(quiet: true)')),
    );

    final helperStart = runtime.indexOf(
      'Future<dynamic> _runDurableIdempotentRpc(',
    );
    final helperEnd = runtime.indexOf(
      'String _mediaFailureCode(Object error)',
      helperStart,
    );
    final helper = runtime.substring(helperStart, helperEnd);
    final firstPreflight = helper.indexOf('scopePreflight?.call();');
    final persistedRead = helper.indexOf(
      'await _secureStorage.read(key: storageKey)',
    );
    final verificationRead = helper.indexOf(
      'await _secureStorage.read(key: storageKey)',
      persistedRead + 1,
    );
    final secondPreflight = helper.indexOf(
      'scopePreflight?.call();',
      firstPreflight + 1,
    );
    final staleDelete = helper.indexOf(
      'await _secureStorage.delete(key: storageKey)',
      secondPreflight,
    );
    final staleRethrow = helper.indexOf('rethrow;', staleDelete);
    final rpc = helper.indexOf('await _client.rpc(');
    expect(firstPreflight, greaterThanOrEqualTo(0));
    expect(firstPreflight, lessThan(persistedRead));
    expect(verificationRead, greaterThan(persistedRead));
    expect(secondPreflight, greaterThan(verificationRead));
    expect(staleDelete, greaterThan(secondPreflight));
    expect(staleRethrow, greaterThan(staleDelete));
    expect(staleRethrow, lessThan(rpc));
    expect(secondPreflight, lessThan(rpc));

    final scopeStart = resolver.indexOf('scopePreflight: () {');
    final scopeEnd = resolver.indexOf('buildParams:', scopeStart);
    final scopePreflight = resolver.substring(scopeStart, scopeEnd);
    expect(
      scopePreflight,
      contains('sensitiveStateGeneration != _sensitiveStateGeneration'),
    );
    expect(
      scopePreflight,
      contains('_client.auth.currentUser?.id != actorUserId'),
    );
    expect(scopePreflight, contains('_stableId != stableId'));
    expect(
      scopePreflight,
      contains("throw StateError('STALE_CONFLICT_CONFIRMATION')"),
    );
  });

  test('sensitive conflict state is dismissed before every purge', () {
    expect(runtime, contains('Route<dynamic>? _sensitiveConflictDialogRoute;'));
    expect(runtime, contains(').removeRoute(conflictRoute)'));
    expect(
      runtime,
      contains('sensitiveStateGeneration != _sensitiveStateGeneration'),
    );
    expect(runtime, contains('_client.auth.currentUser?.id != actorUserId'));
    expect(runtime, contains('_stableId != stableId'));

    final purgeStart = runtime.indexOf('Future<bool> _purgeOperationalState(');
    final purgeEnd = runtime.indexOf('void _clearDecryptedState()', purgeStart);
    final purge = runtime.substring(purgeStart, purgeEnd);
    expect(
      purge.indexOf('_dismissSensitiveDialogs();'),
      lessThan(purge.indexOf('_clearDecryptedState();')),
    );
  });

  test('conflict entry point is visible online and fail-closed offline', () {
    expect(runtime, contains('Icons.sync_problem_outlined'));
    expect(runtime, contains('_resolveSyncConflict(_conflicts.first)'));
    expect(runtime, contains('_offline || _busy'));
    expect(runtime, contains("'list_sync_conflicts'"));
    expect(runtime, contains("RealtimeChannelConfig(private: true)"));
    expect(runtime, contains("event: 'change_available'"));
    expect(runtime, contains("if (kIsWeb) return;"));
    expect(
      runtime,
      contains("throw StateError('OFFLINE_REQUIRES_OS_KEYSTORE')"),
    );
  });

  test('server authority and active edit flow remain bound', () {
    expect(edit, contains('buildAvarynPhase5D2,'));
    expect(edit, contains('void buildAvarynPhase5B5(App app)'));
    expect(edit, contains('void buildAvarynPhase5D1(App app)'));
    expect(edit, contains('_applyPhase4C7OperationalRuntimeResource(app);'));
    expect(migration, contains('create table public.sync_conflicts'));
    expect(migration, contains("entity_type in ('horse_basic_noncritical')"));
    expect(migration, contains('pg_column_size(client_patch) <= 4096'));
    expect(
      migration,
      contains('create or replace function public.resolve_sync_conflict('),
    );
    expect(migration, contains('and conflict.actor_user_id = auth.uid()'));
    expect(
      migration,
      contains('revoke execute on function public.resolve_sync_conflict('),
    );
  });
}

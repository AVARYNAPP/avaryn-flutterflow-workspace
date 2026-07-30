import 'dart:io';

import 'package:test/test.dart';

void main() {
  late String migration;
  late String sql;
  late String browserFixture;
  late String runner;
  late String fixtureRunner;
  late String runtime;

  setUpAll(() {
    migration =
        File(
          'supabase/migrations/'
          '202607280005_phase_5d3_realtime_policy_handshake.sql',
        ).readAsStringSync();
    sql =
        File(
          'supabase/tests/phase_5d3_realtime_browser_acceptance.sql',
        ).readAsStringSync();
    browserFixture =
        File('supabase/tests/phase_5d3_browser_fixture.sql').readAsStringSync();
    runner = File('tool/test_phase_5d3_local.sh').readAsStringSync();
    fixtureRunner =
        File('tool/prepare_phase_5d3_browser_local.sh').readAsStringSync();
    runtime = File('dsl/avaryn_operational_runtime.dart').readAsStringSync();
  });

  test(
    'private Realtime join policy is topic-authorized and handshake-safe',
    () {
      expect(
        migration,
        contains('create or replace function private.rotate_sync_authority()'),
      );
      expect(migration, contains('jsonb_build_object('));
      expect(migration, contains("'authority_version', next_version"));
      expect(migration, contains("'id', wake_id"));
      expect(migration, contains("'change_available'"));
      expect(migration, contains('topic_row.topic_token::text'));
      expect(migration, contains("message = 'REALTIME_WAKE_FAILED'"));
      expect(
        migration,
        contains('private.can_join_realtime_topic(realtime.topic())'),
      );
      expect(migration, isNot(contains("extension = 'broadcast'")));
      expect(migration, isNot(contains('and private is true')));
      expect(
        migration,
        contains(
          'grant execute on function private.can_join_realtime_topic(text)',
        ),
      );
      expect(migration, contains('to authenticated'));
      expect(migration, contains('from public, anon'));
    },
  );

  test(
    'SQL proves authenticated-only ACL isolation and authority rotation',
    () {
      expect(
        sql,
        contains('Realtime topic function ACL is not authenticated-only'),
      );
      expect(sql, contains('Realtime join policy is not handshake-compatible'));
      expect(
        sql,
        contains('Cross-stable owner joined stable A Realtime topic'),
      );
      expect(
        sql,
        contains('Revoked fixture user joined stable A Realtime topic'),
      );
      expect(
        sql,
        contains('Rotated topic remained valid after membership suspend'),
      );
      expect(
        sql,
        contains('Authority rotation did not wake prior private topics'),
      );
      expect(
        sql,
        contains(
          "message.payload = jsonb_build_object(\n"
          "        'authority_version',\n"
          "        message.payload->'authority_version',\n"
          "        'id',",
        ),
      );
      expect(
        sql,
        contains('Suspended groom received replacement Realtime topics'),
      );
      expect(
        sql,
        contains('Anonymous client executed private topic authorization'),
      );
    },
  );

  test(
    'browser fixture accepts credentials only through a secure environment',
    () {
      expect(
        browserFixture,
        contains(r'\getenv test_password AVARYN_BROWSER_TEST_PASSWORD'),
      );
      expect(browserFixture, contains(r'\unset test_password'));
      expect(browserFixture, isNot(contains('test-owner-a@example.invalid')));
      expect(fixtureRunner, contains("'600'"));
      expect(
        fixtureRunner,
        contains('-e AVARYN_BROWSER_TEST_PASSWORD="\$browser_password"'),
      );
      expect(fixtureRunner, contains('unset browser_password'));
      expect(fixtureRunner, isNot(contains('echo "\$browser_password"')));
    },
  );

  test('local runner repeats full 4C.6 SQL concurrency and workspace gate', () {
    expect(runner, contains("'--confirm-local-reset'"));
    expect(runner, contains("expected_label='avaryn-flutterflow-workspace'"));
    expect(runner, contains('phase_4c6_realtime_offline_sync.sql'));
    expect(runner, contains('ITERATIONS=50'));
    expect(runner, contains('phase_5d3_realtime_browser_acceptance.sql'));
    expect(runner, contains('db_started_after'));
    expect(runner, contains('fixture_user_count'));
    expect(
      runner,
      contains(
        'Refusing recovery: local stack or migration state is not exact.',
      ),
    );
    expect(runner, contains('flutterflow_ai.dart test'));
  });

  test('web stays fail-closed offline and private channels remain opaque', () {
    expect(runtime, contains('RealtimeChannelConfig(private: true)'));
    expect(runtime, contains("event: 'change_available'"));
    expect(runtime, contains('status == RealtimeSubscribeStatus.channelError'));
    expect(runtime, contains('status == RealtimeSubscribeStatus.timedOut'));
    expect(runtime, contains('_scheduleWakeRefresh();'));
    expect(runtime, contains('if (kIsWeb) return;'));
    expect(
      runtime,
      contains("throw StateError('OFFLINE_REQUIRES_OS_KEYSTORE')"),
    );
    expect(
      runtime,
      isNot(
        contains('Offline dagsets zijn bewust uitgeschakeld in de webapp:'),
      ),
    );
    expect(runtime, isNot(contains('OS-backed sleutelopslag is verplicht.')));
  });
}

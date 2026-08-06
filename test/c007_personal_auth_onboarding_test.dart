import 'dart:io';

import 'package:test/test.dart';

void main() {
  late String runtime;
  late String edit;
  late String migration;

  setUpAll(() {
    runtime = File('dsl/avaryn_account_runtime.dart').readAsStringSync();
    edit = File('dsl/edit.dart').readAsStringSync();
    migration =
        File(
          'supabase/migrations/202608060001_c007_personal_auth_onboarding.sql',
        ).readAsStringSync();
  });

  test('profile bootstrap is server projected and fail closed', () {
    expect(runtime, contains("rpc('get_current_account_profile')"));
    expect(runtime, contains("profile.profileStatus != 'active'"));
    expect(runtime, contains("throw StateError('ACTIVE_PROFILE_REQUIRED')"));
    expect(runtime, isNot(contains(".from('profiles')")));
    expect(runtime, isNot(contains("onConflict: 'id'")));
    expect(runtime, isNot(contains('user.userMetadata')));
  });

  test('profile and onboarding writes use actorless CAS RPC', () {
    expect(runtime, contains("rpc(\n      'update_current_account_profile'"));
    expect(runtime, contains("'p_expected_row_version': _profileRowVersion"));
    expect(runtime, contains("'p_correlation_id': const Uuid().v4()"));
    expect(runtime, isNot(contains("'p_profile_id'")));
    expect(runtime, isNot(contains("'p_actor_profile_id'")));
    expect(
      migration,
      contains('actor_profile_id := private.require_current_profile_id()'),
    );
    expect(
      migration,
      contains("errcode = '40001', message = 'PROFILE_VERSION_STALE'"),
    );
  });

  test('personal projection is memory-only and carries server versions', () {
    expect(edit, contains("void buildAvarynC007(App app)"));
    expect(edit, contains("name: 'authProfileCaches'"));
    expect(
      edit,
      contains(
        "'Ephemeral profile cache scoped by auth UUID; no sensitive profile projection persists locally.'",
      ),
    );
    expect(edit, contains("'profileId'"));
    expect(edit, contains("'profileStatus'"));
    expect(edit, contains("'accessVersion'"));
    expect(edit, contains("'rowVersion'"));
    expect(
      runtime,
      contains("profileId: _phase4ANullableString(data['profile_id'])"),
    );
    expect(runtime, contains("data['row_version'] is num"));
  });

  test('avatar reference and object cleanup cannot create authority gaps', () {
    final persist = runtime.indexOf(
      "await _c007PersistProfile(\n        user,\n        completeOnboarding: false,\n        avatarObjectPath: '',",
    );
    final remove = runtime.indexOf(
      "await _client.storage.from('avatars').remove([path]);",
      persist,
    );
    expect(persist, greaterThanOrEqualTo(0));
    expect(remove, greaterThan(persist));
    expect(migration, contains('profiles_avatar_object_path_owner_check'));
    expect(migration, contains("message = 'AVATAR_PATH_NOT_OWNED'"));
  });

  test('C-007 changes only personal auth and profile page trees', () {
    final start = edit.indexOf('void buildAvarynC007(App app)');
    final end = edit.indexOf('const bool _agendaFunctionCheckpointOnly', start);
    final c007 = edit.substring(start, end);
    expect(c007, contains('AuthGatePage'));
    expect(c007, contains('OnboardingPage'));
    expect(c007, contains('personalProfilePage'));
    expect(c007, isNot(contains('stablePages')));
    expect(c007, isNot(contains('operationalPages')));
    expect(c007, isNot(contains('HorsesOverviewPage')));
  });
}

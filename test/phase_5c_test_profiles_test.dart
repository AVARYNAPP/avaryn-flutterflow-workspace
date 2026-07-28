import 'dart:io';

import 'package:test/test.dart';

void main() {
  late String fixture;
  late String verification;
  late String provisioner;
  late String resetter;
  late String runner;

  setUpAll(() {
    fixture =
        File('supabase/fixtures/phase_5c_test_profile.sql').readAsStringSync();
    verification =
        File(
          'supabase/tests/phase_5c_test_profile_verification.sql',
        ).readAsStringSync();
    provisioner =
        File('tool/provision_phase_5c_profile_local.sh').readAsStringSync();
    resetter = File('tool/reset_phase_5c_local.sh').readAsStringSync();
    runner = File('tool/test_phase_5c_local.sh').readAsStringSync();
  });

  test('provisioning is explicit, local-only and never an automatic seed', () {
    expect(provisioner, contains('supabase_db_avaryn-flutterflow-workspace'));
    expect(
      provisioner,
      contains('project_id = "avaryn-flutterflow-workspace"'),
    );
    expect(provisioner, contains('grep -q'));
    expect(provisioner, isNot(contains('rg -q')));
    expect(provisioner, contains('--confirm-local-reset'));
    expect(provisioner, contains('docker context inspect'));
    expect(provisioner, contains(r'${DOCKER_HOST:-}'));
    expect(provisioner, contains('unix://'));
    expect(provisioner, contains('com.supabase.cli.project'));
    expect(provisioner, contains('supabase db reset --local'));
    expect(provisioner, isNot(contains('db push')));
    expect(provisioner, isNot(contains('supabase link')));
    expect(resetter, contains('--confirm-local-reset'));
    expect(resetter, contains('docker context inspect'));
    expect(resetter, contains(r'${DOCKER_HOST:-}'));
    expect(resetter, contains('com.supabase.cli.project'));
    expect(resetter, contains('supabase db reset --local'));
    expect(fixture, contains(r'\set ON_ERROR_STOP on'));
    expect(verification, contains(r'\set ON_ERROR_STOP on'));
    expect(fixture, contains('select 1 / 0;'));
    expect(runner, contains(r"${1:-}"));
    expect(runner, contains('--confirm-local-reset'));
  });

  test('all profiles use documented deterministic test volumes', () {
    expect(provisioner, contains('horse_count=3'));
    expect(provisioner, contains('horse_count=8'));
    expect(provisioner, contains('horse_count=15'));
    expect(provisioner, contains('AVARYN_CUSTOM_HORSES'));
    for (final profile in const ['basis', 'medium', 'extreme', 'custom']) {
      expect(runner, contains(profile));
    }
    expect(runner, contains('flutterflow ai test'));
  });

  test('fixtures contain roles, isolation and lifecycle scenarios', () {
    for (final role in const [
      'Ruiter Een',
      'Ruiter Twee',
      'Ruiter Drie',
      'Groom Een',
      'Groom Twee',
      'Trainer',
      'Beperkte Eigenaar',
      'Ingetrokken',
      'Buitenstaander',
    ]) {
      expect(fixture, contains(role));
    }
    expect(fixture, contains("'horse.nutrition'"));
    expect(fixture, contains("'horse.media'"));
    expect(fixture, contains('public.schedule_series'));
    expect(fixture, contains('public.feeding_plans'));
    expect(fixture, contains('public.media_assets'));
    expect(fixture, contains('public.client_sync_devices'));
    expect(fixture, contains('public.sync_conflicts'));
    expect(fixture, isNot(contains('@gmail.')));
    expect(fixture, isNot(contains('@outlook.')));
  });

  test('verification proves exact volumes and negative RLS scopes', () {
    expect(verification, contains('Phase 5C horse count mismatch'));
    expect(verification, contains('Phase 5C routine count mismatch'));
    expect(verification, contains('Phase 5C media count mismatch'));
    expect(verification, contains('Owner B isolation failed'));
    expect(verification, contains('Limited owner scope failed'));
    expect(verification, contains('Owner A saw a cross-stable Horse'));
    expect(verification, contains("id = md5('phase5c:horse:a:1')::uuid"));
    expect(verification, contains("id = md5('phase5c:horse:b:1')::uuid"));
    expect(verification, contains('Revoked user retained Horse access'));
    expect(verification, contains('Outsider reached Horse data'));
    expect(verification, contains('having count(distinct stable_id) = 2'));
  });
}

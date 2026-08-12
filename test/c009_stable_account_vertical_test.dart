import 'dart:io';

import 'package:test/test.dart';

void main() {
  final migration =
      File(
        'supabase/migrations/202608080002_c009_stable_account_vertical.sql',
      ).readAsStringSync();
  final sqlTest =
      File(
        'supabase/tests/c009_stable_account_vertical.sql',
      ).readAsStringSync();
  final runtime =
      File('dsl/avaryn_stable_account_runtime.dart').readAsStringSync();
  final horseRuntime =
      File('dsl/avaryn_horse_account_runtime.dart').readAsStringSync();
  final edit = File('dsl/edit.dart').readAsStringSync();

  test('persons authenticate and stable remains a canonical organization', () {
    expect(migration, contains('public.create_stable_account'));
    expect(migration, contains("'stable',p_name,p_description"));
    expect(migration, contains('primary_admin_profile_id'));
    expect(migration, isNot(contains('auth.create_user')));
    expect(migration, isNot(contains('organization_password')));
    expect(sqlTest, contains('Reimer Dressage'));
    expect(sqlTest, contains('standalone stable account'));
  });

  test('roles are templates and atomic capabilities remain authoritative', () {
    expect(migration, contains("'stable_admin'"));
    expect(migration, contains("'stable_manager'"));
    expect(migration, contains("'stable_worker'"));
    expect(migration, contains("'stable_viewer'"));
    expect(migration, contains('organization.planning.execute'));
    expect(migration, contains('organization.feeding.edit'));
    expect(runtime, contains('set_organization_role_permission'));
    expect(runtime, isNot(contains("role == 'admin'")));
    expect(
      sqlTest,
      contains('worker capability template is over- or under-privileged'),
    );
  });

  test('one-time invitations bind only to the verified identity', () {
    expect(migration, contains('create_stable_invitation_by_role_code'));
    expect(migration, contains('public.create_organization_invitation'));
    expect(runtime, contains('preview_organization_invitation'));
    expect(runtime, contains('respond_stable_invitation'));
    expect(runtime, contains('eenmalig en 7 dagen geldig'));
    expect(sqlTest, contains('wrong invitation recipient accepted token'));
    expect(sqlTest, contains('terminal invitation replay succeeded'));
  });

  test('bilateral link and residency never imply horse access', () {
    expect(migration, contains('organization.horse_links.manage'));
    expect(migration, contains('private.c003c_context_authorized'));
    expect(runtime, contains('propose_organization_horse_link'));
    expect(runtime, contains('respond_organization_horse_link'));
    expect(runtime, contains('switch_horse_residency'));
    expect(runtime, contains('actieve link alleen geeft nul toegang'));
    expect(migration, contains('get_horse_organization_links'));
    expect(horseRuntime, contains('get_horse_organization_links'));
    expect(horseRuntime, contains("'p_initiating_context': 'horse'"));
    expect(horseRuntime, contains('_respondOrganizationLink'));
    expect(
      sqlTest,
      contains('active organization-horse link implied horse access'),
    );
    expect(
      sqlTest,
      contains('residency history was not independent and durable'),
    );
  });

  test('horse grants stay separate and membership revoke closes access', () {
    expect(runtime, contains('grant_horse_organization_role_permission'));
    expect(horseRuntime, contains('grant_horse_organization_role_permission'));
    expect(runtime, contains('p_link_id'));
    expect(
      sqlTest,
      contains(
        'exact horse role grant did not stay within worker, horse and capability scope',
      ),
    );
    expect(
      sqlTest,
      contains(
        'membership revocation left usable organization or horse access',
      ),
    );
  });

  test('Organization Authority transfer reuses the proven C-003E route', () {
    expect(
      migration,
      contains('initiate_organization_authority_transfer_by_email'),
    );
    expect(
      migration,
      contains('public.initiate_organization_authority_transfer'),
    );
    expect(runtime, contains('preview_organization_authority_transfer'));
    expect(runtime, contains('respond_stable_authority_transfer'));
    expect(runtime, contains('revoke_organization_authority_transfer'));
    expect(sqlTest, contains('scalar authority % is not intended recipient %'));
    expect(sqlTest, contains('exactly one active head role'));
  });

  test('C-009 edits bounded stable routes and preserves C-008 operations', () {
    expect(edit, contains('void buildAvarynC009(App app)'));
    expect(edit, contains('buildAvarynC008(app);'));
    expect(edit, contains('AvarynStableAccountRuntime'));
    expect(edit, contains('_c009StableAccountPageBody()'));
    expect(
      edit,
      contains(
        'Planning, Feeding and the broad workspace model remain unchanged',
      ),
    );
  });

  test('C-007 replacement preserves responsive personal profile navigation', () {
    final c007 = edit.substring(
      edit.indexOf('void buildAvarynC007(App app)'),
      edit.indexOf('const bool _agendaFunctionCheckpointOnly'),
    );
    expect(
      c007,
      contains("byPath('PersonalProfilePage.body[0].children[0]')"),
    );
    expect(
      c007,
      contains(
        "byPath('PersonalProfilePage.body[0].children[1].children[1]')",
      ),
    );
    expect(c007, contains('page.mutateNode('));
    expect(c007, contains('phoneHidden: true'));
    expect(c007, contains('desktopHidden: true'));
  });

  test('RPC and private helper ACLs are explicit and fail closed', () {
    expect(migration, contains('from public,anon,authenticated,service_role'));
    expect(migration, contains('to authenticated'));
    expect(migration, contains('private.c009_seed_role_templates'));
    expect(sqlTest, contains('anon listed stable accounts'));
    expect(
      sqlTest,
      contains('service role directly mutated Organization Authority'),
    );
  });
}

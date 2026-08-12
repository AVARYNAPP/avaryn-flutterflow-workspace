import 'dart:io';

import 'package:test/test.dart';

void main() {
  final migration =
      File(
        'supabase/migrations/202608080001_c008_canonical_horse_vertical.sql',
      ).readAsStringSync();
  final sqlTest =
      File(
        'supabase/tests/c008_canonical_horse_vertical.sql',
      ).readAsStringSync();
  final runtime =
      File('dsl/avaryn_horse_account_runtime.dart').readAsStringSync();
  final edit = File('dsl/edit.dart').readAsStringSync();

  test('canonical horse remains independent with exactly one authority', () {
    expect(migration, contains('primary_authority_profile_id'));
    expect(migration, contains('canonical_horse_id'));
    expect(
      migration,
      contains('new.canonical_horse_id := new.id'),
      reason: 'legacy Planning/Feeding must keep the canonical UUID',
    );
    expect(
      migration,
      isNot(
        contains('alter table public.canonical_horses add column stable_id'),
      ),
    );
    expect(sqlTest, contains('standalone canonical creation'));
    expect(sqlTest, contains("column_name='stable_id'"));
  });

  test('profile writes are server-authorized and concurrency protected', () {
    expect(migration, contains('private.c003c_require_permission'));
    expect(migration, contains("'horse.edit'"));
    expect(migration, contains('p_expected_row_version'));
    expect(migration, contains('STALE_HORSE_VERSION'));
    expect(runtime, contains("'p_expected_row_version': horse['row_version']"));
    expect(runtime, contains("raw.contains('STALE_')"));
  });

  test('relationships and ownership never become implicit access', () {
    expect(migration, contains('start_horse_person_relationship_by_email'));
    expect(migration, contains('start_horse_person_ownership_by_email'));
    expect(sqlTest, contains('ownership or relationship implied horse access'));
    expect(runtime, contains('verleent geen toegang'));
    expect(runtime, contains('geen impliciete bevoegdheid'));
  });

  test('delegation is explicit, bounded and cannot include transfer', () {
    expect(migration, contains('grant_horse_delegated_administrator_by_email'));
    expect(runtime, contains("'horse.view', 'horse.edit'"));
    expect(runtime, contains("'horse.manage'"));
    expect(runtime, isNot(contains("permissions.add('horse.transfer')")));
    expect(runtime, contains('maximaal 365'));
    expect(
      sqlTest,
      contains('delegated administrator initiated authority transfer'),
    );
  });

  test('authority transfer is one-time, seven-day and terminal', () {
    expect(migration, contains('initiate_horse_authority_transfer_by_email'));
    expect(runtime, contains('preview_horse_authority_transfer'));
    expect(runtime, contains('respond_horse_authority_transfer'));
    expect(runtime, contains('revoke_horse_authority_transfer'));
    expect(runtime, contains('AVARYN toont hem niet opnieuw'));
    expect(runtime, isNot(contains("write(key: 'authority_transfer")));
    expect(sqlTest, contains("<>interval '7 days'"));
    expect(sqlTest, contains('terminal transfer replay succeeded'));
  });

  test('existing private horse avatars remain signed and memory-only', () {
    expect(migration, contains('profile_media_asset_id'));
    expect(runtime, contains("'action': 'canonical_download'"));
    expect(runtime, contains("'variant': 'thumbnail'"));
    expect(runtime, contains("/storage/v1/object/sign/horse-media/"));
    expect(runtime, isNot(contains('getPublicUrl')));
    expect(runtime, isNot(contains("write(key: 'signed_download_url")));
  });

  test('horse route changes without rebuilding Planning or Feeding', () {
    expect(edit, contains('void buildAvarynC008(App app)'));
    expect(edit, contains('buildAvarynPhase5D2(app);'));
    expect(edit, contains('AvarynHorseAccountRuntime'));
    expect(edit, contains('_c008HorsePageBody()'));
    expect(
      edit,
      contains('Planning and Feeding deliberately retain their existing'),
    );
  });

  test(
    'ACL surface is authenticated-only and private helpers stay private',
    () {
      expect(
        migration,
        contains('from public,anon,authenticated,service_role'),
      );
      expect(migration, contains('to authenticated'));
      expect(migration, contains('private.c008_target_profile_by_email(text)'));
      expect(sqlTest, contains('anon listed canonical horses'));
      expect(
        sqlTest,
        contains('service role directly mutated canonical authority'),
      );
    },
  );
}

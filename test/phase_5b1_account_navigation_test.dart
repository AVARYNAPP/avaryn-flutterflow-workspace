import 'dart:io';

import 'package:test/test.dart';

import '../dsl/phase_5b1_account_navigation_model.dart';

void main() {
  test('account gate orders verification onboarding invite and stable', () {
    Phase5AccountRoute resolve({
      bool session = true,
      bool emailProvider = true,
      bool confirmed = true,
      bool onboarded = true,
      bool invitation = false,
      bool stable = false,
    }) => phase5ResolveAccountRoute(
      hasSession: session,
      emailProvider: emailProvider,
      emailConfirmed: confirmed,
      onboardingCompleted: onboarded,
      hasPendingInvitation: invitation,
      hasSelectedStable: stable,
    );

    expect(resolve(session: false), Phase5AccountRoute.welcome);
    expect(resolve(confirmed: false), Phase5AccountRoute.verifyEmail);
    expect(
      resolve(confirmed: false, emailProvider: false),
      Phase5AccountRoute.stableHandoff,
    );
    expect(resolve(onboarded: false), Phase5AccountRoute.onboarding);
    expect(
      resolve(onboarded: false, invitation: true),
      Phase5AccountRoute.onboarding,
    );
    expect(resolve(invitation: true), Phase5AccountRoute.invitation);
    expect(resolve(), Phase5AccountRoute.stableHandoff);
    expect(resolve(stable: true), Phase5AccountRoute.today);
  });

  test('every account gate outcome maps to one explicit app route', () {
    expect(Phase5AccountRoute.values.map(phase5AccountRouteName).toSet(), {
      'AuthWelcomePage',
      'AuthVerifyEmailPage',
      'OnboardingPage',
      'StableInvitationPage',
      'StableOnboardingHandoffPage',
      'TodayDashboardPage',
    });
  });

  test('password change is authorized only by the Supabase recovery event', () {
    final runtime = File('dsl/avaryn_account_runtime.dart').readAsStringSync();
    expect(runtime, isNot(contains('phase5IsRecoveryCallback')));
    expect(
      runtime,
      contains('state.event == AuthChangeEvent.passwordRecovery'),
    );
    expect(
      runtime,
      contains('_phase5AuthorizePasswordRecovery(state.session)'),
    );
    expect(runtime, contains('_phase5PasswordRecoveryUserId'));
    expect(runtime, contains('_phase5PasswordRecoveryLifetime'));
    expect(runtime, contains('_phase5HasPasswordRecoveryAuthorization('));
    expect(runtime, isNot(contains('_passwordRecoveryAuthorized')));
  });

  test('account deletion is server-authoritative and purges local scope', () {
    final runtime = File('dsl/avaryn_account_runtime.dart').readAsStringSync();
    final edgeFunction =
        File('supabase/functions/delete-account/index.ts').readAsStringSync();
    final mediaEdgeFunction =
        File('supabase/functions/media-assets/index.ts').readAsStringSync();
    final invitationEdgeFunction =
        File('supabase/functions/stable-invitations/index.ts')
            .readAsStringSync();

    expect(runtime, contains("functions.invoke(\n        'delete-account'"));
    expect(runtime, contains("'Content-Type': 'application/json'"));
    expect(runtime, contains("body: '{}'"));
    expect(runtime, contains("code != 'ACCOUNT_DELETED'"));
    expect(runtime, contains('_phase5AccountDeletionCode(error)'));
    expect(runtime, contains('ACTIVE_STABLE_OWNER_REQUIRES_TRANSFER'));
    expect(runtime, contains('ACTIVE_MEMBERSHIPS_REQUIRE_RESOLUTION'));
    expect(runtime, contains('ACCOUNT_HISTORY_REQUIRES_ADMIN_REVIEW'));
    expect(runtime, contains('APPLE_REVOCATION_NOT_CONFIGURED'));
    expect(
      runtime,
      contains('_phase4APurgeOperationalSecureState(authUserId)'),
    );
    expect(runtime, contains('_phase5ClearDeletedAccountState(authUserId)'));
    expect(runtime, contains('scope.authUserId != authUserId'));
    expect(runtime, contains('cache.authUserId != authUserId'));
    expect(runtime, contains('link.authUserId != authUserId'));
    expect(
      runtime,
      contains('await _client.auth.signOut(scope: SignOutScope.local)'),
    );
    expect(runtime, contains('onPressed: _busy ? null : _deleteAccount'));
    expect(runtime, contains('Account permanent verwijderen'));
    expect(
      runtime,
      isNot(contains('Account verwijderen — nog niet beschikbaar')),
    );
    expect(
      edgeFunction,
      contains('authorization, x-client-info, apikey, content-type'),
      reason:
          'Flutter web sends x-client-info during the CORS preflight; the '
          'browser must be allowed to continue with the authenticated POST.',
    );
    expect(
      edgeFunction,
      contains(
        "await serviceClient\n"
        "    .from('stable_memberships')\n"
        "    .select('id,role,status')",
      ),
      reason:
          'Historical memberships hidden by caller RLS must block deletion '
          'before any avatar cleanup starts.',
    );
    expect(
      edgeFunction.indexOf("await serviceClient\n    .from('stable_memberships')"),
      lessThan(edgeFunction.indexOf("serviceClient.storage.from('avatars')")),
    );
    for (final source in [mediaEdgeFunction, invitationEdgeFunction]) {
      expect(
        source,
        contains('authorization, x-client-info, apikey, content-type'),
        reason:
            'Every Flutter web Edge Function preflight must allow the '
            'Supabase client metadata header.',
      );
    }
  });

  test('revoked sessions purge every local scope before offline fallback', () {
    final runtime = File('dsl/avaryn_account_runtime.dart').readAsStringSync();

    expect(runtime, contains('_phase5ValidatedCurrentUser()'));
    expect(
      runtime,
      contains('await _client.auth.getUser(session.accessToken)'),
    );
    expect(runtime, contains("_phase5IsTerminalSessionError(error)"));
    expect(runtime, contains("status == '401'"));
    expect(runtime, contains("status == '403'"));
    expect(runtime, contains("status == '404'"));
    expect(
      runtime,
      contains('await _phase4APurgeOperationalSecureState(session.user.id)'),
    );
    expect(
      runtime,
      contains('_phase5ClearDeletedAccountState(session.user.id)'),
    );
    expect(
      runtime,
      contains('await _client.auth.signOut(scope: SignOutScope.local)'),
    );
    expect(
      runtime,
      contains('final user = await _phase5ValidatedCurrentUser()'),
    );
  });

  test('avatar extension cannot spoof the image signature', () {
    expect(
      phase5ImageSignatureMatches(const [0xFF, 0xD8, 0xFF, 0x00], 'image/jpeg'),
      isTrue,
    );
    expect(
      phase5ImageSignatureMatches(const [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ], 'image/png'),
      isTrue,
    );
    expect(
      phase5ImageSignatureMatches(const [
        0x52,
        0x49,
        0x46,
        0x46,
        0,
        0,
        0,
        0,
        0x57,
        0x45,
        0x42,
        0x50,
      ], 'image/webp'),
      isTrue,
    );
    expect(
      phase5ImageSignatureMatches(const [
        0x3C,
        0x73,
        0x76,
        0x67,
        0x3E,
      ], 'image/png'),
      isFalse,
    );
    expect(
      phase5ImageSignatureMatches(const [0xFF, 0xD8, 0xFF], 'image/webp'),
      isFalse,
    );
    expect(
      File('dsl/avaryn_account_runtime.dart').readAsStringSync(),
      contains("avatar-\${const Uuid().v4()}.\$extension"),
    );
  });

  test('invitation hand-off remains memory-only and exits without dead end', () {
    final edit = File('dsl/edit.dart').readAsStringSync();
    final account = File('dsl/avaryn_account_runtime.dart').readAsStringSync();
    final stable = File('dsl/avaryn_stable_runtime.dart').readAsStringSync();

    expect(edit, contains("name: 'pendingStableInvitationToken'"));
    expect(edit, contains('persisted: false'));
    expect(edit, contains("name: 'pendingStableInvitationId'"));
    expect(edit, contains('server rebinds it to the confirmed email'));
    expect(edit, contains("name: 'pendingStableCreateRequestId'"));
    expect(edit, contains("name: 'pendingStableCreatePayloadKey'"));
    expect(account, contains('pendingStableInvitationToken = \'\';'));
    expect(account, contains('niet-geheime referentie'));
    expect(stable, contains('pendingStableInvitationToken.trim()'));
    expect(stable, contains("'action': 'resume'"));
    expect(stable, contains("'invitation_id': _transientInvitationId"));
    expect(
      stable,
      contains('void _phase5StripInvitationTokenFromLocation('),
    );
    expect(stable, contains('BuildContext context,'));
    final idAssignment = stable.indexOf(
      'FFAppState().pendingStableInvitationId = invitationId;',
    );
    final durableWrite = stable.indexOf(
      'await FFAppState().secureStorage.setString(',
      idAssignment,
    );
    final rawTokenClear = stable.indexOf(
      "FFAppState().pendingStableInvitationToken = '';",
      durableWrite,
    );
    final urlStrip = stable.indexOf(
      '_phase5StripInvitationTokenFromLocation(\n'
      '              context,\n'
      '              invitationId: invitationId,',
      rawTokenClear,
    );
    expect(idAssignment, greaterThanOrEqualTo(0));
    expect(durableWrite, greaterThan(idAssignment));
    expect(rawTokenClear, greaterThan(durableWrite));
    expect(
      urlStrip,
      greaterThan(rawTokenClear),
      reason:
          'The raw fragment is removed only after the server promotes and '
          'durably stores a non-secret invitation ID for the login hand-off.',
    );
    expect(
      stable,
      contains("<String, String>{'invitation_id': safeInvitationId}"),
    );
    expect(stable, contains('final routeUri = GoRouterState.of(context).uri;'));
    expect(
      stable,
      contains("routeUri.queryParameters['invitation_id']"),
    );
    expect(stable, contains('final fragment = routeUri.fragment;'));
    expect(stable, isNot(contains('Uri.base.queryParameters')));
    expect(stable, isNot(contains('Uri.base.fragment')));
    expect(stable, isNot(contains('SystemNavigator.routeInformationUpdated(')));
    expect(
      edit,
      contains('data-avaryn-invite-bootstrap="phase5-v1"'),
      reason:
          'Flutter path routing discards URL fragments before page widgets '
          'mount, so the raw token must be exchanged before Flutter boots.',
    );
    expect(edit, contains("window.location.hash || ''"));
    expect(edit, contains('window.history.replaceState('));
    expect(
      edit,
      contains(
        "'https://ipdovjdtnfslrftvrdrl.supabase.co/functions/v1/"
        "stable-invitations'",
      ),
    );
    expect(edit, contains("credentials: 'omit'"));
    expect(edit, contains("referrerPolicy: 'no-referrer'"));
    expect(edit, contains("cache: 'no-store'"));
    expect(
      edit,
      contains(
        "'/uitnodiging?invitation_id=' + encodeURIComponent(invitationId)",
      ),
    );
    expect(edit, isNot(contains('sb_publishable_')));
    expect(edit, isNot(contains('service_role')));
    expect(stable, contains("accept ? 'StablePickerPage'"));
    expect(stable, contains(": 'StableOnboardingHandoffPage'"));
    expect(stable, contains("'request_id': requestId"));
    expect(
      stable,
      contains(
        'De reactie is nog niet bevestigd. Probeer opnieuw met dezelfde gegevens.',
      ),
    );
    expect(stable, contains("context.pushNamed('StableDetailsPage')"));
    expect(account, contains("'Stal en team beheren'"));
    expect(account, isNot(contains('Bestaande lokale testdata koppelen')));
  });

  test('stable creation activation is reentrancy and retry safe', () {
    final stable = File('dsl/avaryn_stable_runtime.dart').readAsStringSync();
    final createStart = stable.indexOf('Future<void> _createStable');
    final createEnd = stable.indexOf(
      'Future<void> _previewInvitation',
      createStart,
    );
    final create = stable.substring(createStart, createEnd);

    expect(stable, contains('Future<bool> _activateStable('));
    expect(
      create,
      contains('final payloadKey = _phase5DeterministicRequestId('),
    );
    expect(create, contains("'create-stable-payload'"));
    expect(create, contains('state.pendingStableCreateRequestId'));
    expect(create, contains("'p_creation_request_id': requestId"));
    expect(create, contains('if (await _activateStable(membership))'));
    expect(create, contains("state.pendingStableCreateRequestId = '';"));
    expect(create, isNot(contains('await _switchStable(membership)')));
    expect(
      stable,
      contains("accessStatus: 'signed_out'"),
      reason: 'signed-out activation must fail closed',
    );
  });

  test(
    'server preference is authoritative and member leave stays reachable',
    () {
      final account =
          File('dsl/avaryn_account_runtime.dart').readAsStringSync();
      final stable = File('dsl/avaryn_stable_runtime.dart').readAsStringSync();

      expect(account, contains('_hydrateSelectedStableFromServer(user)'));
      expect(account, contains("from('account_workspace_preferences')"));
      expect(account, contains("'last_selected_stable_id'"));
      expect(account, contains("from('stable_memberships')"));
      expect(account, contains('_hasFreshCachedMembership(user.id'));
      expect(
        account,
        contains('_phase5AccountInvalidateMembershipAuthority(user.id)'),
      );
      expect(
        account,
        contains('state.localAccountScopes = localAccountScopes'),
      );
      expect(
        account,
        contains('state.phase4BAccountOperationalBackups = operationalBackups'),
      );
      expect(stable, contains('_phase5InvalidateMembershipAuthority(user.id)'));
      expect(stable, contains('state.localAccountScopes = localAccountScopes'));
      expect(
        stable,
        contains('state.phase4BAccountOperationalBackups = operationalBackups'),
      );
      expect(stable, contains("scope.selectedCloudStableId = '';"));
      expect(stable, contains('cache.authUserId != authUserId'));
      expect(stable, contains("child: const Text('Zelf deze stal verlaten')"));
      expect(stable, isNot(contains('Lokale stal expliciet koppelen')));
    },
  );

  test('invitation RPC infrastructure failures remain retryable', () {
    final edge =
        File(
          'supabase/functions/stable-invitations/index.ts',
        ).readAsStringSync();
    final stable = File('dsl/avaryn_stable_runtime.dart').readAsStringSync();
    final runner = File('tool/test_phase_5b1_local.sh').readAsStringSync();

    expect(edge, contains("return 'SERVER_UNAVAILABLE'"));
    expect(edge, contains("if (code === 'SERVER_UNAVAILABLE') return 503"));
    expect(edge, contains("code === 'CONFIRMED_ACCOUNT_REQUIRED'"));
    expect(edge, contains("code === 'DISPLAY_NAME_REQUIRED'"));
    expect(edge, contains('return 412'));
    expect(
      edge,
      contains(
        "if (error) return response(503, { code: 'SERVER_UNAVAILABLE' })",
      ),
    );
    expect(stable, contains('error.status == 412'));
    expect(stable, contains('uitnodigingsreferentie blijft behouden'));
    expect(runner, contains(r'status_file=$(mktemp)'));
    expect(runner, isNot(contains(r'mktemp /')));
  });

  test('Alpha navigation hides outside-scope dead items and stale footer', () {
    final edit = File('dsl/edit.dart').readAsStringSync();
    final mobileStart = edit.indexOf('DslWidget _mobileNavigationBody');
    final mobileEnd = edit.indexOf('DslWidget _mobileNavItem', mobileStart);
    final desktopStart = edit.indexOf('DslWidget _desktopNavigationBody');
    final desktopEnd = edit.indexOf('DslWidget _desktopNavItem', desktopStart);
    final alphaNavigation =
        edit.substring(mobileStart, mobileEnd) +
        edit.substring(desktopStart, desktopEnd);

    expect(alphaNavigation, isNot(contains("'Wedstrijden'")));
    expect(alphaNavigation, isNot(contains('Local prototype')));
    expect(alphaNavigation, isNot(contains('Sample data only')));
    expect(alphaNavigation, contains('Besloten Alpha'));
    expect(alphaNavigation, contains('Geen productie'));
    for (final page in const [
      'orionProfilePage',
      'activityDetailPage',
      'horseNutritionPage',
      'feedingRoundSettingsPage',
    ]) {
      expect(edit, contains('page: ff.Pages.$page'));
    }
  });

  test('local SQL acceptance fixture is guarded and always rolled back', () {
    final fixture =
        File(
          'supabase/tests/phase_5b1_account_team_acceptance.sql',
        ).readAsStringSync();

    expect(fixture, contains(r'\if :{?avaryn_local_test}'));
    expect(fixture, contains(":'avaryn_local_test' = '1'"));
    expect(fixture, contains('example.invalid'));
    expect(fixture, contains('begin;'));
    expect(fixture.trimRight(), endsWith('rollback;'));
    expect(fixture, contains('Incomplete account bypassed onboarding'));
    expect(fixture, contains('Owner Alpha crossed the stable boundary'));
    expect(fixture, contains('Removed member retained team visibility'));
    expect(fixture, contains('resume_stable_invitation('));
    expect(fixture, contains('accept_stable_invitation_by_id('));
    expect(
      File('tool/test_phase_5b1_local.sh').readAsStringSync(),
      contains('phase_5b1_account_team_acceptance.sql'),
    );
  });

  test('nullable warning policy is semantic rather than a sentinel date', () {
    final edit = File('dsl/edit.dart').readAsStringSync();
    final stable = File('dsl/avaryn_stable_runtime.dart').readAsStringSync();

    expect(
      edit,
      contains(
        "removeAppStateField(project, name: 'lastMembershipValidatedAt')",
      ),
    );
    expect(stable, isNot(contains('lastMembershipValidatedAt')));
    expect(
      stable,
      contains('!now.difference(cache.lastValidatedAt!).isNegative'),
    );
    final account = File('dsl/avaryn_account_runtime.dart').readAsStringSync();
    expect(account, contains('!age.isNegative'));
    for (final state in const [
      'activityDraftStartDate',
      'activityDraftEndDate',
      'activityDraftStartTime',
      'activityDraftEndTime',
    ]) {
      expect(edit, contains("'$state'"));
      expect(
        edit,
        isNot(contains("'$state',\n      dateTimeType,\n      defaultValue:")),
      );
    }
  });
}

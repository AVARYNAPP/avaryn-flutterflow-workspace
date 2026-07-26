import 'dart:async';

import 'package:test/test.dart';

import '../dsl/phase_4b_management_model.dart';

final class _Call {
  const _Call(this.name, this.parameters);

  final String name;
  final Map<String, Object?> parameters;
}

final class _FakeGateway implements Phase4BManagementGateway {
  final calls = <_Call>[];
  int refreshes = 0;
  int clears = 0;
  Object? nextError;
  Map<String, Object?> invitationResult = const {};
  Completer<void>? blocker;

  @override
  void clearSensitiveAuthority() => clears++;

  @override
  Future<Map<String, Object?>> invitation(
    String action,
    Map<String, Object?> parameters,
  ) async {
    calls.add(_Call('invitation:$action', parameters));
    if (blocker != null) await blocker!.future;
    if (nextError case final Object error) throw error;
    return invitationResult;
  }

  @override
  Future<void> refreshAuthority() async => refreshes++;

  @override
  Future<Object?> rpc(String name, Map<String, Object?> parameters) async {
    calls.add(_Call(name, parameters));
    if (blocker != null) await blocker!.future;
    if (nextError case final Object error) throw error;
    return true;
  }
}

Phase4BManagementController _controller(
  _FakeGateway gateway, {
  Phase4BRole role = Phase4BRole.owner,
  bool online = true,
  bool personal = false,
}) => Phase4BManagementController(
  gateway: gateway,
  actorRole: role,
  online: online,
  personalWorkspace: personal,
);

void main() {
  test('owner role change sends exact RPC values and refreshes', () async {
    final gateway = _FakeGateway();
    final controller = _controller(gateway);
    expect(
      await controller.changeRole(
        membershipId: 'membership-1',
        targetRole: Phase4BRole.admin,
        newRole: Phase4BRole.viewer,
        requestId: 'request-1',
      ),
      isTrue,
    );
    expect(gateway.calls.single.name, 'change_stable_member_role');
    expect(gateway.calls.single.parameters, {
      'p_membership_id': 'membership-1',
      'p_new_role': 'viewer',
      'p_request_id': 'request-1',
    });
    expect(gateway.refreshes, 1);
  });

  test('admin cannot manage admin and member/viewer cannot mutate', () async {
    final adminGateway = _FakeGateway();
    final admin = _controller(adminGateway, role: Phase4BRole.admin);
    expect(
      await admin.remove(
        membershipId: 'admin-target',
        targetRole: Phase4BRole.admin,
        requestId: 'request',
      ),
      isFalse,
    );
    final memberGateway = _FakeGateway();
    final member = _controller(memberGateway, role: Phase4BRole.member);
    expect(
      await member.suspend(
        membershipId: 'viewer-target',
        targetRole: Phase4BRole.viewer,
        requestId: 'request',
      ),
      isFalse,
    );
    expect(adminGateway.calls, isEmpty);
    expect(memberGateway.calls, isEmpty);
  });

  test('suspend, remove, leave and link use existing RPCs', () async {
    final gateway = _FakeGateway();
    final owner = _controller(gateway);
    await owner.suspend(
      membershipId: 'member-1',
      targetRole: Phase4BRole.member,
      requestId: 'suspend-1',
    );
    await owner.remove(
      membershipId: 'member-2',
      targetRole: Phase4BRole.viewer,
      requestId: 'remove-1',
    );
    await owner.linkAccountToMember(
      membershipId: 'member-3',
      stableMemberId: 'roster-3',
      targetRole: Phase4BRole.member,
      requestId: 'link-1',
    );
    final member = _controller(gateway, role: Phase4BRole.member);
    await member.leave(stableId: 'stable-1', requestId: 'leave-1');
    expect(gateway.calls.map((call) => call.name), [
      'suspend_stable_membership',
      'remove_stable_membership',
      'link_account_to_stable_member',
      'leave_stable',
    ]);
    expect(gateway.refreshes, 4);
  });

  test('ownership transfer is separate, owner-only and confirmed', () async {
    final gateway = _FakeGateway();
    final owner = _controller(gateway);
    expect(
      await owner.transferOwnership(
        stableId: 'stable-1',
        targetMembershipId: 'membership-2',
        requestId: 'transfer-1',
        confirmed: false,
      ),
      isFalse,
    );
    expect(gateway.calls, isEmpty);
    expect(
      await owner.transferOwnership(
        stableId: 'stable-1',
        targetMembershipId: 'membership-2',
        requestId: 'transfer-1',
        confirmed: true,
      ),
      isTrue,
    );
    expect(gateway.calls.single.name, 'transfer_stable_ownership');
    expect(
      gateway.calls.single.parameters['p_target_membership_id'],
      'membership-2',
    );
  });

  test('stable update and confirmed owner archive invoke exact RPCs', () async {
    final gateway = _FakeGateway();
    final controller = _controller(gateway);
    await controller.updateStable(
      stableId: 'stable-1',
      name: 'Nieuwe naam',
      timezone: 'Europe/Amsterdam',
      locale: 'nl',
      requestId: 'update-1',
    );
    expect(
      await controller.archiveStable(
        stableId: 'stable-1',
        requestId: 'archive-1',
        confirmed: true,
      ),
      isTrue,
    );
    expect(gateway.calls.map((call) => call.name), [
      'update_stable',
      'archive_stable',
    ]);
  });

  test('invitation role matrix reaches route with selected role', () async {
    final ownerGateway =
        _FakeGateway()
          ..invitationResult = {
            'invitation_url': 'http://127.0.0.1/#token=transient',
          };
    final owner = _controller(ownerGateway);
    expect(owner.allowedInvitationRoles, [
      Phase4BRole.admin,
      Phase4BRole.member,
      Phase4BRole.viewer,
    ]);
    expect(
      await owner.createInvitation(
        stableId: 'stable-1',
        email: 'local@example.test',
        role: Phase4BRole.admin,
        requestId: 'invite-1',
      ),
      isTrue,
    );
    expect(ownerGateway.calls.single.name, 'invitation:create');
    expect(ownerGateway.calls.single.parameters['role'], 'admin');
    expect(owner.takeTransientInvitationLink(), contains('#token='));
    expect(owner.takeTransientInvitationLink(), isEmpty);

    final admin = _controller(_FakeGateway(), role: Phase4BRole.admin);
    expect(admin.allowedInvitationRoles, [
      Phase4BRole.member,
      Phase4BRole.viewer,
    ]);
    expect(
      await admin.createInvitation(
        stableId: 'stable-1',
        email: 'blocked@example.test',
        role: Phase4BRole.admin,
        requestId: 'blocked',
      ),
      isFalse,
    );
  });

  test('resend and revoke refresh and return transient link once', () async {
    final gateway =
        _FakeGateway()
          ..invitationResult = {
            'invitation_url': 'http://127.0.0.1/#token=rotated',
          };
    final controller = _controller(gateway);
    await controller.resendInvitation(
      invitationId: 'invite-1',
      requestId: 'resend-1',
    );
    expect(controller.takeTransientInvitationLink(), contains('rotated'));
    await controller.revokeInvitation(
      invitationId: 'invite-1',
      requestId: 'revoke-1',
    );
    expect(gateway.calls.map((call) => call.name), [
      'invitation:resend',
      'invitation:revoke',
    ]);
    expect(gateway.refreshes, 2);
  });

  test('offline, personal and double submit never mutate', () async {
    final offlineGateway = _FakeGateway();
    final offline = _controller(offlineGateway, online: false);
    expect(
      await offline.updateStable(
        stableId: 'stable',
        name: 'Naam',
        timezone: 'UTC',
        locale: 'nl',
        requestId: 'request',
      ),
      isFalse,
    );
    expect(offlineGateway.calls, isEmpty);

    final personalGateway = _FakeGateway();
    final personal = _controller(personalGateway, personal: true);
    expect(personal.allowedInvitationRoles, isEmpty);
    expect(
      await personal.resendInvitation(
        invitationId: 'invite',
        requestId: 'request',
      ),
      isFalse,
    );

    final busyGateway = _FakeGateway()..blocker = Completer<void>();
    final busy = _controller(busyGateway);
    final first = busy.updateStable(
      stableId: 'stable',
      name: 'Naam',
      timezone: 'UTC',
      locale: 'nl',
      requestId: 'first',
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      await busy.archiveStable(
        stableId: 'stable',
        requestId: 'second',
        confirmed: true,
      ),
      isFalse,
    );
    busyGateway.blocker!.complete();
    expect(await first, isTrue);
    expect(busyGateway.calls, hasLength(1));
  });

  test(
    'server errors keep authority unchanged and 401 clears context',
    () async {
      final deniedGateway =
          _FakeGateway()..nextError = const Phase4BServerException('403');
      final denied = _controller(deniedGateway);
      expect(
        await denied.updateStable(
          stableId: 'stable',
          name: 'Naam',
          timezone: 'UTC',
          locale: 'nl',
          requestId: 'request',
        ),
        isFalse,
      );
      expect(denied.actorRole, Phase4BRole.owner);
      expect(deniedGateway.clears, 1);
      expect(deniedGateway.refreshes, 0);
      expect(denied.error, isNotEmpty);
    },
  );

  test(
    'route state covers loading empty error retry and offline read-only',
    () {
      expect(
        const Phase4BRouteState(
          loading: true,
          itemCount: 0,
          error: '',
          offline: false,
        ).showsLoading,
        isTrue,
      );
      expect(
        const Phase4BRouteState(
          loading: false,
          itemCount: 0,
          error: '',
          offline: false,
        ).showsEmpty,
        isTrue,
      );
      const failed = Phase4BRouteState(
        loading: false,
        itemCount: 0,
        error: 'safe error',
        offline: false,
      );
      expect(failed.showsError, isTrue);
      expect(failed.canRetry, isTrue);
      expect(
        const Phase4BRouteState(
          loading: false,
          itemCount: 3,
          error: '',
          offline: true,
        ).authorityReadOnly,
        isTrue,
      );
    },
  );

  test('responsive management contract separates 390 and 1024 pixels', () {
    expect(phase4BLayoutForWidth(390), Phase4BLayout.compact);
    expect(phase4BLayoutForWidth(1024), Phase4BLayout.desktop);
  });
}

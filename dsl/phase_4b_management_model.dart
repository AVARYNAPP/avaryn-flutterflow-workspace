enum Phase4BRole { owner, admin, member, viewer }

enum Phase4BMemberStatus { active, suspended, removed, left }

enum Phase4BLayout { compact, desktop }

Phase4BLayout phase4BLayoutForWidth(double width) =>
    width < 700 ? Phase4BLayout.compact : Phase4BLayout.desktop;

final class Phase4BRouteState {
  const Phase4BRouteState({
    required this.loading,
    required this.itemCount,
    required this.error,
    required this.offline,
  });

  final bool loading;
  final int itemCount;
  final String error;
  final bool offline;

  bool get showsLoading => loading;
  bool get showsEmpty => !loading && error.isEmpty && itemCount == 0;
  bool get showsError => !loading && error.isNotEmpty;
  bool get canRetry => !loading && error.isNotEmpty;
  bool get authorityReadOnly => offline;
}

final class Phase4BServerException implements Exception {
  const Phase4BServerException(this.code);

  final String code;
}

abstract interface class Phase4BManagementGateway {
  Future<Object?> rpc(String name, Map<String, Object?> parameters);

  Future<Map<String, Object?>> invitation(
    String action,
    Map<String, Object?> parameters,
  );

  Future<void> refreshAuthority();

  void clearSensitiveAuthority();
}

final class Phase4BManagementController {
  Phase4BManagementController({
    required this.gateway,
    required this.actorRole,
    required this.online,
    required this.personalWorkspace,
  });

  final Phase4BManagementGateway gateway;
  Phase4BRole actorRole;
  bool online;
  bool personalWorkspace;
  bool busy = false;
  String error = '';
  String notice = '';
  String _transientInvitationLink = '';

  bool get canManage =>
      actorRole == Phase4BRole.owner || actorRole == Phase4BRole.admin;

  List<Phase4BRole> get allowedInvitationRoles {
    if (!online || personalWorkspace) return const [];
    return switch (actorRole) {
      Phase4BRole.owner => const [
        Phase4BRole.admin,
        Phase4BRole.member,
        Phase4BRole.viewer,
      ],
      Phase4BRole.admin => const [Phase4BRole.member, Phase4BRole.viewer],
      Phase4BRole.member || Phase4BRole.viewer => const [],
    };
  }

  List<Phase4BRole> allowedReplacementRoles(Phase4BRole targetRole) {
    if (!online || targetRole == Phase4BRole.owner) return const [];
    return switch (actorRole) {
      Phase4BRole.owner => const [
        Phase4BRole.admin,
        Phase4BRole.member,
        Phase4BRole.viewer,
      ],
      Phase4BRole.admin
          when targetRole == Phase4BRole.member ||
              targetRole == Phase4BRole.viewer =>
        const [Phase4BRole.member, Phase4BRole.viewer],
      _ => const [],
    };
  }

  bool canManageTarget(Phase4BRole targetRole) =>
      allowedReplacementRoles(targetRole).isNotEmpty;

  String takeTransientInvitationLink() {
    final value = _transientInvitationLink;
    _transientInvitationLink = '';
    return value;
  }

  Future<bool> changeRole({
    required String membershipId,
    required Phase4BRole targetRole,
    required Phase4BRole newRole,
    required String requestId,
  }) {
    if (!allowedReplacementRoles(targetRole).contains(newRole)) {
      return Future.value(false);
    }
    return _mutate(
      () => gateway.rpc('change_stable_member_role', {
        'p_membership_id': membershipId,
        'p_new_role': newRole.name,
        'p_request_id': requestId,
      }),
      success: 'Rol bijgewerkt.',
    );
  }

  Future<bool> suspend({
    required String membershipId,
    required Phase4BRole targetRole,
    required String requestId,
  }) {
    if (!canManageTarget(targetRole)) return Future.value(false);
    return _mutate(
      () => gateway.rpc('suspend_stable_membership', {
        'p_membership_id': membershipId,
        'p_request_id': requestId,
      }),
      success: 'Lid geschorst.',
    );
  }

  Future<bool> remove({
    required String membershipId,
    required Phase4BRole targetRole,
    required String requestId,
  }) {
    if (!canManageTarget(targetRole)) return Future.value(false);
    return _mutate(
      () => gateway.rpc('remove_stable_membership', {
        'p_membership_id': membershipId,
        'p_request_id': requestId,
      }),
      success: 'Lid verwijderd.',
    );
  }

  Future<bool> leave({required String stableId, required String requestId}) {
    if (actorRole == Phase4BRole.owner) return Future.value(false);
    return _mutate(
      () => gateway.rpc('leave_stable', {
        'p_stable_id': stableId,
        'p_request_id': requestId,
      }),
      success: 'Je hebt de stal verlaten.',
    );
  }

  Future<bool> transferOwnership({
    required String stableId,
    required String targetMembershipId,
    required String requestId,
    required bool confirmed,
  }) {
    if (actorRole != Phase4BRole.owner || !confirmed) {
      return Future.value(false);
    }
    return _mutate(
      () => gateway.rpc('transfer_stable_ownership', {
        'p_stable_id': stableId,
        'p_target_membership_id': targetMembershipId,
        'p_request_id': requestId,
      }),
      success: 'Eigendom veilig overgedragen.',
    );
  }

  Future<bool> linkAccountToMember({
    required String membershipId,
    required String stableMemberId,
    required Phase4BRole targetRole,
    required String requestId,
  }) {
    if (!canManageTarget(targetRole)) return Future.value(false);
    return _mutate(
      () => gateway.rpc('link_account_to_stable_member', {
        'p_membership_id': membershipId,
        'p_stable_member_id': stableMemberId,
        'p_request_id': requestId,
      }),
      success: 'Account en medewerker gekoppeld.',
    );
  }

  Future<bool> updateStable({
    required String stableId,
    required String name,
    required String timezone,
    required String locale,
    required String requestId,
  }) {
    if (!canManage || name.trim().isEmpty || timezone.trim().isEmpty) {
      return Future.value(false);
    }
    return _mutate(
      () => gateway.rpc('update_stable', {
        'p_stable_id': stableId,
        'p_name': name.trim(),
        'p_timezone': timezone.trim(),
        'p_locale': locale,
        'p_request_id': requestId,
      }),
      success: 'Stalgegevens bijgewerkt.',
    );
  }

  Future<bool> archiveStable({
    required String stableId,
    required String requestId,
    required bool confirmed,
  }) {
    if (actorRole != Phase4BRole.owner || !confirmed) {
      return Future.value(false);
    }
    return _mutate(
      () => gateway.rpc('archive_stable', {
        'p_stable_id': stableId,
        'p_request_id': requestId,
      }),
      success: 'Stal gearchiveerd.',
    );
  }

  Future<bool> createInvitation({
    required String stableId,
    required String email,
    required Phase4BRole role,
    required String requestId,
    String? targetStableMemberId,
  }) async {
    if (!allowedInvitationRoles.contains(role) || email.trim().isEmpty) {
      return false;
    }
    return _invitationMutation('create', {
      'stable_id': stableId,
      'email': email.trim(),
      'role': role.name,
      'request_id': requestId,
      'target_stable_member_id': targetStableMemberId,
    }, success: 'Uitnodigingslink veilig aangemaakt.');
  }

  Future<bool> resendInvitation({
    required String invitationId,
    required String requestId,
  }) {
    if (!canManage || personalWorkspace) return Future.value(false);
    return _invitationMutation('resend', {
      'invitation_id': invitationId,
      'request_id': requestId,
    }, success: 'Nieuwe uitnodigingslink veilig aangemaakt.');
  }

  Future<bool> revokeInvitation({
    required String invitationId,
    required String requestId,
  }) {
    if (!canManage || personalWorkspace) return Future.value(false);
    return _invitationMutation('revoke', {
      'invitation_id': invitationId,
      'request_id': requestId,
    }, success: 'Uitnodiging ingetrokken.');
  }

  Future<bool> _invitationMutation(
    String action,
    Map<String, Object?> parameters, {
    required String success,
  }) {
    return _mutate(() async {
      final result = await gateway.invitation(action, parameters);
      final invitationUrl = result['invitation_url'];
      if (invitationUrl is String && invitationUrl.isNotEmpty) {
        _transientInvitationLink = invitationUrl;
      }
      return null;
    }, success: success);
  }

  Future<bool> _mutate(
    Future<Object?> Function() operation, {
    required String success,
  }) async {
    if (!online || busy) return false;
    busy = true;
    error = '';
    notice = '';
    try {
      await operation();
      await gateway.refreshAuthority();
      notice = success;
      return true;
    } on Phase4BServerException catch (serverError) {
      if (serverError.code == '401' ||
          serverError.code == '403' ||
          serverError.code == '42501') {
        gateway.clearSensitiveAuthority();
      }
      error = _safeError(serverError.code);
      return false;
    } catch (_) {
      error = 'De actie kon niet veilig worden voltooid.';
      return false;
    } finally {
      busy = false;
    }
  }

  String _safeError(String code) => switch (code) {
    'INVITATION_COOLDOWN' =>
      'Wacht minimaal 60 seconden voordat je opnieuw verzendt.',
    'INVITATION_RATE_LIMITED' =>
      'De uitnodigingslimiet is bereikt. Probeer later opnieuw.',
    'PERSONAL_INVITATIONS_DISABLED' =>
      'Persoonlijke workspaces ondersteunen geen uitnodigingen.',
    '401' ||
    '403' ||
    '42501' => 'Je toegang is gewijzigd. De stalcontext is veilig gewist.',
    _ => 'De server heeft de actie veilig geweigerd.',
  };
}

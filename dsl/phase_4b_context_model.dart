enum StableRole { owner, admin, member, viewer }

enum MembershipStatus { active, suspended, removed, left }

final class MembershipSnapshot {
  const MembershipSnapshot({
    required this.authUserId,
    required this.cloudStableId,
    required this.role,
    required this.status,
  });

  final String authUserId;
  final String cloudStableId;
  final StableRole role;
  final MembershipStatus status;
}

final class LocalStableCloudLink {
  const LocalStableCloudLink({
    required this.authUserId,
    required this.cloudStableId,
    required this.localStableId,
    this.selectedHorseId,
    required this.confirmed,
  });

  final String authUserId;
  final String cloudStableId;
  final String localStableId;
  final int? selectedHorseId;
  final bool confirmed;
}

final class LocalOperationalRecord {
  const LocalOperationalRecord({required this.id, required this.localStableId});

  final String id;
  final String localStableId;
}

final class StableContextResult {
  const StableContextResult({
    required this.cloudStableId,
    required this.localStableId,
    required this.records,
    required this.selectedHorseId,
    required this.readOnly,
    required this.accessStatus,
  });

  factory StableContextResult.empty(String status) => StableContextResult(
    cloudStableId: '',
    localStableId: '',
    records: const [],
    selectedHorseId: null,
    readOnly: true,
    accessStatus: status,
  );

  final String cloudStableId;
  final String localStableId;
  final List<LocalOperationalRecord> records;
  final int? selectedHorseId;
  final bool readOnly;
  final String accessStatus;
}

final class StableContextCoordinator {
  const StableContextCoordinator();

  StableContextResult switchContext({
    required String authUserId,
    required String cloudStableId,
    required MembershipSnapshot? validatedMembership,
    required List<LocalStableCloudLink> links,
    required List<LocalOperationalRecord> accountRecords,
    required bool online,
  }) {
    if (!online) return StableContextResult.empty('offline_read_only');
    if (validatedMembership == null ||
        validatedMembership.authUserId != authUserId ||
        validatedMembership.cloudStableId != cloudStableId) {
      return StableContextResult.empty('access_denied');
    }
    if (validatedMembership.status == MembershipStatus.suspended) {
      return StableContextResult.empty('suspended');
    }
    if (validatedMembership.status != MembershipStatus.active) {
      return StableContextResult.empty('removed');
    }

    LocalStableCloudLink? link;
    for (final candidate in links) {
      if (candidate.authUserId == authUserId &&
          candidate.cloudStableId == cloudStableId &&
          candidate.confirmed) {
        link = candidate;
        break;
      }
    }
    if (link == null) return StableContextResult.empty('unlinked');

    return StableContextResult(
      cloudStableId: cloudStableId,
      localStableId: link.localStableId,
      records: accountRecords
          .where((record) => record.localStableId == link!.localStableId)
          .toList(growable: false),
      selectedHorseId: link.selectedHorseId,
      readOnly: false,
      accessStatus: 'active',
    );
  }
}

bool canInviteRole(StableRole actor, StableRole offered) => switch (actor) {
  StableRole.owner => offered != StableRole.owner,
  StableRole.admin =>
    offered == StableRole.member || offered == StableRole.viewer,
  StableRole.member || StableRole.viewer => false,
};

bool canManageRole(
  StableRole actor,
  StableRole target,
  StableRole replacement,
) => switch (actor) {
  StableRole.owner =>
    target != StableRole.owner && replacement != StableRole.owner,
  StableRole.admin =>
    (target == StableRole.member || target == StableRole.viewer) &&
        (replacement == StableRole.member || replacement == StableRole.viewer),
  StableRole.member || StableRole.viewer => false,
};

final class AccountOperationalMaster {
  const AccountOperationalMaster({
    required this.authUserId,
    required this.records,
    required this.selectedHorseByLocalStable,
    required this.legacyIds,
    required this.legacyBackup,
    this.currentLocalStableId = '',
    this.selectedCloudStableId = '',
    this.nextHorseId = 1,
    this.nextHorseIndex = 0,
    this.horseSeedVersion = 1,
    this.passportPrototypeVersion = 1,
    this.nextActivityId = 1,
    this.nextFeedingItemId = 1,
    this.nextTemporaryFeedingScheduleId = 1,
    this.nextFeedingAssignmentExceptionId = 1,
    this.nextFeedingExecutionRecordId = 1,
    this.schemaVersion = 2,
  });

  final String authUserId;
  final List<LocalOperationalRecord> records;
  final Map<String, int?> selectedHorseByLocalStable;
  final List<String> legacyIds;
  final String legacyBackup;
  final String currentLocalStableId;
  final String selectedCloudStableId;
  final int nextHorseId;
  final int nextHorseIndex;
  final int horseSeedVersion;
  final int passportPrototypeVersion;
  final int nextActivityId;
  final int nextFeedingItemId;
  final int nextTemporaryFeedingScheduleId;
  final int nextFeedingAssignmentExceptionId;
  final int nextFeedingExecutionRecordId;
  final int schemaVersion;

  Map<String, dynamic> toSerializableMap() => {
    'authUserId': authUserId,
    'horses': const <Map<String, dynamic>>[],
    'selectedHorse': const <String, dynamic>{},
    'selectedHorseIndex': 0,
    'nextHorseId': nextHorseId,
    'nextHorseIndex': nextHorseIndex,
    'horseSeedVersion': horseSeedVersion,
    'passportPrototypeVersion': passportPrototypeVersion,
    'activities':
        records
            .map(
              (record) => {'id': record.id, 'stableId': record.localStableId},
            )
            .toList(),
    'nextActivityId': nextActivityId,
    'currentLocalUserId': 'local-current-user',
    'currentLocalStableId': currentLocalStableId,
    'horseFeedingPlans': const <Map<String, dynamic>>[],
    'temporaryFeedingSchedules': const <Map<String, dynamic>>[],
    'nextFeedingItemId': nextFeedingItemId,
    'nextTemporaryFeedingScheduleId': nextTemporaryFeedingScheduleId,
    'feedingRoundConfigs': const <Map<String, dynamic>>[],
    'feedingAssignmentExceptions': const <Map<String, dynamic>>[],
    'feedingExecutionRecords': const <Map<String, dynamic>>[],
    'nextFeedingAssignmentExceptionId': nextFeedingAssignmentExceptionId,
    'nextFeedingExecutionRecordId': nextFeedingExecutionRecordId,
    'selectedCloudStableId': selectedCloudStableId,
    'localStableCloudLinks': const <Map<String, dynamic>>[],
    'stableMembershipCaches': const <Map<String, dynamic>>[],
    'schemaVersion': schemaVersion,
    'updatedAt': 'runtime-test-snapshot',
    'selectedHorseByLocalStable': selectedHorseByLocalStable,
    'legacyIds': legacyIds,
    'legacyBackup': legacyBackup,
  };

  static AccountOperationalMaster fromSerializableMap(
    Map<String, dynamic> data,
  ) {
    final records = _phase4BSerializableList(data['activities'])
        .map(_phase4BSerializableMap)
        .map(
          (record) => LocalOperationalRecord(
            id: _phase4BSerializableString(record['id']),
            localStableId: _phase4BSerializableString(record['stableId']),
          ),
        )
        .toList(growable: false);
    final selectedHorseByLocalStable = _phase4BSerializableMap(
      data['selectedHorseByLocalStable'],
    ).map((key, value) => MapEntry(key, value is num ? value.toInt() : null));
    int integer(String key, int fallback) =>
        data[key] is num ? (data[key] as num).toInt() : fallback;
    return AccountOperationalMaster(
      authUserId: _phase4BSerializableString(data['authUserId']),
      records: records,
      selectedHorseByLocalStable: selectedHorseByLocalStable,
      legacyIds: _phase4BSerializableList(
        data['legacyIds'],
      ).map((value) => value.toString()).toList(growable: false),
      legacyBackup: _phase4BSerializableString(data['legacyBackup']),
      currentLocalStableId: _phase4BSerializableString(
        data['currentLocalStableId'],
      ),
      selectedCloudStableId: _phase4BSerializableString(
        data['selectedCloudStableId'],
      ),
      nextHorseId: integer('nextHorseId', 1),
      nextHorseIndex: integer('nextHorseIndex', 0),
      horseSeedVersion: integer('horseSeedVersion', 1),
      passportPrototypeVersion: integer('passportPrototypeVersion', 1),
      nextActivityId: integer('nextActivityId', 1),
      nextFeedingItemId: integer('nextFeedingItemId', 1),
      nextTemporaryFeedingScheduleId: integer(
        'nextTemporaryFeedingScheduleId',
        1,
      ),
      nextFeedingAssignmentExceptionId: integer(
        'nextFeedingAssignmentExceptionId',
        1,
      ),
      nextFeedingExecutionRecordId: integer('nextFeedingExecutionRecordId', 1),
      schemaVersion: integer('schemaVersion', 2),
    );
  }
}

enum Phase4BMasterSaveKind {
  createLinked,
  mergeLinked,
  preserveUnlinked,
  emptyUnlinked,
}

final class Phase4BMasterSavePlan<T> {
  const Phase4BMasterSavePlan({
    required this.kind,
    required this.master,
    required this.shouldPersist,
  });

  final Phase4BMasterSaveKind kind;
  final T master;
  final bool shouldPersist;
}

Phase4BMasterSavePlan<T> phase4BPlanOperationalMasterSave<T>({
  required T current,
  required T? existing,
  required String currentLocalStableId,
  required T Function(T existing, T current) mergeLinkedScope,
}) {
  if (currentLocalStableId.trim().isEmpty) {
    return Phase4BMasterSavePlan(
      kind:
          existing == null
              ? Phase4BMasterSaveKind.emptyUnlinked
              : Phase4BMasterSaveKind.preserveUnlinked,
      master: existing ?? current,
      shouldPersist: false,
    );
  }
  return Phase4BMasterSavePlan(
    kind:
        existing == null
            ? Phase4BMasterSaveKind.createLinked
            : Phase4BMasterSaveKind.mergeLinked,
    master: existing == null ? current : mergeLinkedScope(existing, current),
    shouldPersist: true,
  );
}

const Set<String> phase4BOperationalScopedCollectionKeys = {
  'horses',
  'activities',
  'horseFeedingPlans',
  'temporaryFeedingSchedules',
  'feedingRoundConfigs',
  'feedingAssignmentExceptions',
  'feedingExecutionRecords',
};

dynamic _phase4BCloneSerializableValue(dynamic value) {
  if (value is Map) {
    return value.map(
      (key, nested) =>
          MapEntry(key.toString(), _phase4BCloneSerializableValue(nested)),
    );
  }
  if (value is Iterable) {
    return value.map(_phase4BCloneSerializableValue).toList();
  }
  return value;
}

Map<String, dynamic> _phase4BSerializableMap(dynamic value) =>
    value is Map ? value.cast<String, dynamic>() : const {};

String _phase4BSerializableString(dynamic value) =>
    value is String ? value.trim() : '';

List<dynamic> _phase4BSerializableList(dynamic value) =>
    value is Iterable ? value.toList(growable: false) : const [];

String _phase4BScopedRecordStableId({
  required String collectionKey,
  required dynamic record,
  required String horseFallbackStableId,
}) {
  final data = _phase4BSerializableMap(record);
  final stableId = _phase4BSerializableString(data['stableId']);
  if (collectionKey == 'horses' && stableId.isEmpty) {
    return horseFallbackStableId;
  }
  return stableId;
}

Map<String, dynamic> phase4BMergeOperationalMasterMaps({
  required Map<String, dynamic> master,
  required Map<String, dynamic> current,
}) {
  final masterAuthUserId = _phase4BSerializableString(master['authUserId']);
  final currentAuthUserId = _phase4BSerializableString(current['authUserId']);
  if (masterAuthUserId.isNotEmpty &&
      currentAuthUserId.isNotEmpty &&
      masterAuthUserId != currentAuthUserId) {
    throw StateError('Cross-account operational master merge refused.');
  }

  final localStableId = _phase4BSerializableString(
    current['currentLocalStableId'],
  );
  if (localStableId.isEmpty) {
    throw StateError('A linked operational merge requires a local stable ID.');
  }
  final selectedCloudStableId = _phase4BSerializableString(
    current['selectedCloudStableId'],
  );
  if (selectedCloudStableId.isNotEmpty &&
      selectedCloudStableId == localStableId) {
    throw StateError('A cloud stable UUID cannot become a local stable ID.');
  }

  final merged = _phase4BCloneSerializableValue(master).cast<String, dynamic>();

  // Every non-scoped field comes from the current working snapshot. This keeps
  // counters, schema/seed versions and future scalar master fields in lockstep
  // for logout, account switches and stable switches.
  for (final entry in current.entries) {
    if (!phase4BOperationalScopedCollectionKeys.contains(entry.key)) {
      merged[entry.key] = _phase4BCloneSerializableValue(entry.value);
    }
  }

  final masterHorseFallback = _phase4BSerializableString(
    master['currentLocalStableId'],
  );
  for (final collectionKey in phase4BOperationalScopedCollectionKeys) {
    final retained = _phase4BSerializableList(master[collectionKey])
        .where(
          (record) =>
              _phase4BScopedRecordStableId(
                collectionKey: collectionKey,
                record: record,
                horseFallbackStableId: masterHorseFallback,
              ) !=
              localStableId,
        )
        .map(_phase4BCloneSerializableValue);
    final replacement = _phase4BSerializableList(
      current[collectionKey],
    ).map(_phase4BCloneSerializableValue);
    merged[collectionKey] = [...retained, ...replacement];
  }
  return merged;
}

Phase4BMasterSavePlan<T> phase4BPlanSerializedOperationalMasterSave<T>({
  required T current,
  required T? existing,
  required Map<String, dynamic> Function(T value) toSerializableMap,
  required T Function(Map<String, dynamic> value) fromSerializableMap,
}) {
  final currentMap = toSerializableMap(current);
  final currentLocalStableId = _phase4BSerializableString(
    currentMap['currentLocalStableId'],
  );
  if (currentLocalStableId.isEmpty) {
    return Phase4BMasterSavePlan(
      kind:
          existing == null
              ? Phase4BMasterSaveKind.emptyUnlinked
              : Phase4BMasterSaveKind.preserveUnlinked,
      master: existing ?? current,
      shouldPersist: false,
    );
  }
  if (existing == null) {
    final selectedCloudStableId = _phase4BSerializableString(
      currentMap['selectedCloudStableId'],
    );
    if (selectedCloudStableId.isNotEmpty &&
        selectedCloudStableId == currentLocalStableId) {
      throw StateError('A cloud stable UUID cannot become a local stable ID.');
    }
    return Phase4BMasterSavePlan(
      kind: Phase4BMasterSaveKind.createLinked,
      master: current,
      shouldPersist: true,
    );
  }
  return Phase4BMasterSavePlan(
    kind: Phase4BMasterSaveKind.mergeLinked,
    master: fromSerializableMap(
      phase4BMergeOperationalMasterMaps(
        master: toSerializableMap(existing),
        current: currentMap,
      ),
    ),
    shouldPersist: true,
  );
}

final class Phase4BMemberCandidate {
  const Phase4BMemberCandidate({
    required this.stableId,
    required this.stableMemberId,
  });

  final String stableId;
  final String stableMemberId;
}

final class Phase4BMemberDetailRoute {
  const Phase4BMemberDetailRoute({
    required this.pageName,
    required this.stableMemberId,
  });

  final String pageName;
  final String stableMemberId;

  Map<String, String> get parameters => {'stableMemberId': stableMemberId};
}

final class Phase4BMemberSelectionCoordinator {
  Phase4BMemberSelectionCoordinator({
    String initialStableMemberId = '',
    required this.requireExplicitSelection,
  }) : _intendedStableMemberId = initialStableMemberId.trim();

  final bool requireExplicitSelection;
  String _intendedStableMemberId;
  String selectedStableMemberId = '';
  String error = '';

  String get intendedStableMemberId => _intendedStableMemberId;

  Phase4BMemberDetailRoute detailRoute(String stableMemberId) {
    final value = stableMemberId.trim();
    if (value.isEmpty) {
      throw ArgumentError.value(
        stableMemberId,
        'stableMemberId',
        'A detail route requires an explicit stable member ID.',
      );
    }
    return Phase4BMemberDetailRoute(
      pageName: 'StableMemberDetailsPage',
      stableMemberId: value,
    );
  }

  void choose(String stableMemberId) {
    _intendedStableMemberId = stableMemberId.trim();
    selectedStableMemberId = '';
    error = '';
  }

  void resolve({
    required String selectedStableId,
    required List<Phase4BMemberCandidate> candidates,
  }) {
    final inSelectedStable = candidates
        .where((candidate) => candidate.stableId == selectedStableId)
        .toList(growable: false);
    if (_intendedStableMemberId.isEmpty) {
      if (requireExplicitSelection) {
        selectedStableMemberId = '';
        error = 'member_not_selected';
        return;
      }
      selectedStableMemberId =
          inSelectedStable.isEmpty ? '' : inSelectedStable.first.stableMemberId;
      error = inSelectedStable.isEmpty ? 'member_not_found' : '';
      _intendedStableMemberId = selectedStableMemberId;
      return;
    }
    final matches = inSelectedStable
        .where(
          (candidate) => candidate.stableMemberId == _intendedStableMemberId,
        )
        .toList(growable: false);
    if (matches.length != 1) {
      selectedStableMemberId = '';
      error = 'member_not_found';
      return;
    }
    selectedStableMemberId = matches.single.stableMemberId;
    error = '';
  }
}

abstract interface class AccountOperationalStore {
  AccountOperationalMaster? read(String authUserId);

  void write(AccountOperationalMaster master);
}

final class StableContextSession {
  StableContextSession({required this.store});

  final AccountOperationalStore store;
  String authUserId = '';
  String cloudStableId = '';
  String currentLocalStableId = '';
  List<LocalOperationalRecord> records = const [];
  int? selectedHorseId;
  int nextHorseId = 1;
  int nextHorseIndex = 0;
  int horseSeedVersion = 1;
  int passportPrototypeVersion = 1;
  int nextActivityId = 1;
  int nextFeedingItemId = 1;
  int nextTemporaryFeedingScheduleId = 1;
  int nextFeedingAssignmentExceptionId = 1;
  int nextFeedingExecutionRecordId = 1;
  int schemaVersion = 2;
  String accessStatus = 'empty';

  void seed({
    required String accountId,
    required String cloudId,
    required String localStableId,
    required List<LocalOperationalRecord> operationalRecords,
    required int? horseId,
    int nextHorseId = 1,
    int nextHorseIndex = 0,
    int horseSeedVersion = 1,
    int passportPrototypeVersion = 1,
    int nextActivityId = 1,
    int nextFeedingItemId = 1,
    int nextTemporaryFeedingScheduleId = 1,
    int nextFeedingAssignmentExceptionId = 1,
    int nextFeedingExecutionRecordId = 1,
    int schemaVersion = 2,
  }) {
    authUserId = accountId;
    cloudStableId = cloudId;
    currentLocalStableId = localStableId;
    records = List.of(operationalRecords);
    selectedHorseId = horseId;
    this.nextHorseId = nextHorseId;
    this.nextHorseIndex = nextHorseIndex;
    this.horseSeedVersion = horseSeedVersion;
    this.passportPrototypeVersion = passportPrototypeVersion;
    this.nextActivityId = nextActivityId;
    this.nextFeedingItemId = nextFeedingItemId;
    this.nextTemporaryFeedingScheduleId = nextTemporaryFeedingScheduleId;
    this.nextFeedingAssignmentExceptionId = nextFeedingAssignmentExceptionId;
    this.nextFeedingExecutionRecordId = nextFeedingExecutionRecordId;
    this.schemaVersion = schemaVersion;
    accessStatus = 'active';
  }

  Future<bool> switchTo({
    required String targetAuthUserId,
    required String targetCloudStableId,
    required MembershipSnapshot? membership,
    required List<LocalStableCloudLink> links,
  }) async {
    try {
      _saveCurrent();
    } catch (_) {
      accessStatus = 'storage_error';
      return false;
    }

    _clear(status: 'validating');
    if (membership == null ||
        membership.authUserId != targetAuthUserId ||
        membership.cloudStableId != targetCloudStableId) {
      accessStatus = 'access_denied';
      return false;
    }
    if (membership.status != MembershipStatus.active) {
      accessStatus =
          membership.status == MembershipStatus.suspended
              ? 'suspended'
              : 'removed';
      return false;
    }
    LocalStableCloudLink? link;
    for (final candidate in links) {
      if (candidate.authUserId == targetAuthUserId &&
          candidate.cloudStableId == targetCloudStableId &&
          candidate.confirmed) {
        link = candidate;
        break;
      }
    }
    if (link == null || link.localStableId.isEmpty) {
      authUserId = targetAuthUserId;
      cloudStableId = targetCloudStableId;
      accessStatus = 'unlinked';
      return true;
    }
    final master = store.read(targetAuthUserId);
    authUserId = targetAuthUserId;
    cloudStableId = targetCloudStableId;
    currentLocalStableId = link.localStableId;
    records =
        master?.records
            .where((record) => record.localStableId == link!.localStableId)
            .toList(growable: false) ??
        const [];
    selectedHorseId =
        master?.selectedHorseByLocalStable[link.localStableId] ??
        link.selectedHorseId;
    if (master != null) _loadPersistentFields(master);
    accessStatus = 'active';
    return true;
  }

  void logout() {
    _saveCurrent();
    authUserId = '';
    cloudStableId = '';
    _clear(status: 'signed_out');
  }

  void _saveCurrent() {
    if (authUserId.isEmpty) return;
    final existing = store.read(authUserId);
    final current = AccountOperationalMaster(
      authUserId: authUserId,
      records: List.of(records),
      selectedHorseByLocalStable:
          currentLocalStableId.isEmpty
              ? const {}
              : {
                ...?existing?.selectedHorseByLocalStable,
                currentLocalStableId: selectedHorseId,
              },
      legacyIds: existing?.legacyIds ?? const [],
      legacyBackup: existing?.legacyBackup ?? '',
      currentLocalStableId: currentLocalStableId,
      selectedCloudStableId: cloudStableId,
      nextHorseId: nextHorseId,
      nextHorseIndex: nextHorseIndex,
      horseSeedVersion: horseSeedVersion,
      passportPrototypeVersion: passportPrototypeVersion,
      nextActivityId: nextActivityId,
      nextFeedingItemId: nextFeedingItemId,
      nextTemporaryFeedingScheduleId: nextTemporaryFeedingScheduleId,
      nextFeedingAssignmentExceptionId: nextFeedingAssignmentExceptionId,
      nextFeedingExecutionRecordId: nextFeedingExecutionRecordId,
      schemaVersion: schemaVersion,
    );
    final plan = phase4BPlanSerializedOperationalMasterSave(
      current: current,
      existing: existing,
      toSerializableMap: (master) => master.toSerializableMap(),
      fromSerializableMap: AccountOperationalMaster.fromSerializableMap,
    );
    if (plan.shouldPersist) {
      store.write(plan.master);
    }
  }

  void _loadPersistentFields(AccountOperationalMaster master) {
    nextHorseId = master.nextHorseId;
    nextHorseIndex = master.nextHorseIndex;
    horseSeedVersion = master.horseSeedVersion;
    passportPrototypeVersion = master.passportPrototypeVersion;
    nextActivityId = master.nextActivityId;
    nextFeedingItemId = master.nextFeedingItemId;
    nextTemporaryFeedingScheduleId = master.nextTemporaryFeedingScheduleId;
    nextFeedingAssignmentExceptionId = master.nextFeedingAssignmentExceptionId;
    nextFeedingExecutionRecordId = master.nextFeedingExecutionRecordId;
    schemaVersion = master.schemaVersion;
  }

  void _clear({required String status}) {
    currentLocalStableId = '';
    records = const [];
    selectedHorseId = null;
    accessStatus = status;
  }
}

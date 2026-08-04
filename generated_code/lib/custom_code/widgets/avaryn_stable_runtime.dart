// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/app_state.dart';
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

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
) =>
    switch (actor) {
      StableRole.owner =>
        target != StableRole.owner && replacement != StableRole.owner,
      StableRole.admin =>
        (target == StableRole.member || target == StableRole.viewer) &&
            (replacement == StableRole.member ||
                replacement == StableRole.viewer),
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
        'activities': records
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
      kind: existing == null
          ? Phase4BMasterSaveKind.emptyUnlinked
          : Phase4BMasterSaveKind.preserveUnlinked,
      master: existing ?? current,
      shouldPersist: false,
    );
  }
  return Phase4BMasterSavePlan(
    kind: existing == null
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
      kind: existing == null
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
      accessStatus = membership.status == MembershipStatus.suspended
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
    records = master?.records
            .where((record) => record.localStableId == link!.localStableId)
            .toList(growable: false) ??
        const [];
    selectedHorseId = master?.selectedHorseByLocalStable[link.localStableId] ??
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
      selectedHorseByLocalStable: currentLocalStableId.isEmpty
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
    return _invitationMutation(
        'create',
        {
          'stable_id': stableId,
          'email': email.trim(),
          'role': role.name,
          'request_id': requestId,
          'target_stable_member_id': targetStableMemberId,
        },
        success: 'Uitnodigingslink veilig aangemaakt.');
  }

  Future<bool> resendInvitation({
    required String invitationId,
    required String requestId,
  }) {
    if (!canManage || personalWorkspace) return Future.value(false);
    return _invitationMutation(
        'resend',
        {
          'invitation_id': invitationId,
          'request_id': requestId,
        },
        success: 'Nieuwe uitnodigingslink veilig aangemaakt.');
  }

  Future<bool> revokeInvitation({
    required String invitationId,
    required String requestId,
  }) {
    if (!canManage || personalWorkspace) return Future.value(false);
    return _invitationMutation(
        'revoke',
        {
          'invitation_id': invitationId,
          'request_id': requestId,
        },
        success: 'Uitnodiging ingetrokken.');
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
        '42501' =>
          'Je toegang is gewijzigd. De stalcontext is veilig gewist.',
        _ => 'De server heeft de actie veilig geweigerd.',
      };
}

const int _phase4BLocalScopeSchemaVersion = 2;
const Duration _phase4BOfflineAuthorityMaximumAge = Duration(hours: 24);

String _phase4BString(dynamic value) => value is String ? value.trim() : '';
DateTime? _phase4BDate(dynamic value) => value is DateTime
    ? value
    : value is String
        ? DateTime.tryParse(value)
        : null;

void _phase5StripInvitationTokenFromLocation(
  BuildContext context, {
  String invitationId = '',
}) {
  if (!kIsWeb || !context.mounted) return;
  final fragment = GoRouterState.of(context).uri.fragment;
  if (fragment.isEmpty || !fragment.contains('token=')) return;
  // Read and replace through the active GoRouter state. Uri.base reflects the
  // document base in Flutter web and can omit route query/fragment data.
  final safeInvitationId = invitationId.trim();
  context.replace(
    Uri(
      path: '/uitnodiging',
      queryParameters: safeInvitationId.isEmpty
          ? null
          : <String, String>{'invitation_id': safeInvitationId},
    ).toString(),
  );
}

String _phase5DeterministicRequestId(
  String actorId,
  String operation,
  Object payload,
) =>
    const Uuid().v5(
      Uuid.NAMESPACE_URL,
      jsonEncode(['avaryn-phase5-v1', actorId, operation, payload]),
    );

List<T> _phase4BCopyStructList<T extends BaseStruct>(
  Iterable<T> values,
  T Function(Map<String, dynamic>) decode,
) =>
    values
        .map(
          (value) =>
              decode(jsonDecode(value.serialize()) as Map<String, dynamic>),
        )
        .toList();

LocalAccountScopeDataStruct _phase4BCaptureOperationalScope(String authUserId) {
  final state = FFAppState();
  return LocalAccountScopeDataStruct(
    authUserId: authUserId,
    horses: _phase4BCopyStructList(
      state.horses,
      HorseProfileDataStruct.fromSerializableMap,
    ),
    selectedHorse: HorseProfileDataStruct.fromSerializableMap(
      jsonDecode(state.selectedHorse.serialize()) as Map<String, dynamic>,
    ),
    selectedHorseIndex: state.selectedHorseIndex,
    nextHorseId: state.nextHorseId,
    nextHorseIndex: state.nextHorseIndex,
    horseSeedVersion: state.horseSeedVersion,
    passportPrototypeVersion: state.passportPrototypeVersion,
    activities: _phase4BCopyStructList(
      state.activities,
      ActivityDataStruct.fromSerializableMap,
    ),
    nextActivityId: state.nextActivityId,
    currentLocalUserId: state.currentLocalUserId,
    currentLocalStableId: state.currentLocalStableId,
    horseFeedingPlans: _phase4BCopyStructList(
      state.horseFeedingPlans,
      HorseFeedingPlanDataStruct.fromSerializableMap,
    ),
    temporaryFeedingSchedules: _phase4BCopyStructList(
      state.temporaryFeedingSchedules,
      TemporaryFeedingScheduleDataStruct.fromSerializableMap,
    ),
    nextFeedingItemId: state.nextFeedingItemId,
    nextTemporaryFeedingScheduleId: state.nextTemporaryFeedingScheduleId,
    feedingRoundConfigs: _phase4BCopyStructList(
      state.feedingRoundConfigs,
      FeedingRoundConfigDataStruct.fromSerializableMap,
    ),
    feedingAssignmentExceptions: _phase4BCopyStructList(
      state.feedingAssignmentExceptions,
      FeedingAssignmentExceptionDataStruct.fromSerializableMap,
    ),
    feedingExecutionRecords: _phase4BCopyStructList(
      state.feedingExecutionRecords,
      FeedingExecutionRecordDataStruct.fromSerializableMap,
    ),
    nextFeedingAssignmentExceptionId: state.nextFeedingAssignmentExceptionId,
    nextFeedingExecutionRecordId: state.nextFeedingExecutionRecordId,
    selectedCloudStableId: state.selectedCloudStableId,
    localStableCloudLinks: _phase4BCopyStructList(
      state.localStableCloudLinks,
      LocalStableCloudLinkDataStruct.fromSerializableMap,
    ),
    stableMembershipCaches: _phase4BCopyStructList(
      state.stableMembershipCaches,
      StableMembershipCacheDataStruct.fromSerializableMap,
    ),
    schemaVersion: _phase4BLocalScopeSchemaVersion,
    updatedAt: DateTime.now().toUtc(),
  );
}

void _phase4BClearSensitiveWorkingSet({String accessStatus = ''}) {
  final state = FFAppState();
  state.update(() {
    state.horses = <HorseProfileDataStruct>[];
    state.selectedHorse = HorseProfileDataStruct();
    state.selectedHorseIndex = 0;
    state.activities = <ActivityDataStruct>[];
    state.selectedActivity = ActivityDataStruct();
    state.selectedActivityIndex = 0;
    state.horseFeedingPlans = <HorseFeedingPlanDataStruct>[];
    state.temporaryFeedingSchedules = <TemporaryFeedingScheduleDataStruct>[];
    state.feedingRoundConfigs = <FeedingRoundConfigDataStruct>[];
    state.feedingAssignmentExceptions =
        <FeedingAssignmentExceptionDataStruct>[];
    state.feedingExecutionRecords = <FeedingExecutionRecordDataStruct>[];
    state.currentLocalStableId = '';
    state.selectedFeedingDateKey = '';
    state.selectedFeedingRoundId = 'morning';
    state.activityDraftHorseId = 0;
    state.activityDraftAssigneeUserIds = <String>[];
    state.activityDraftStartDate = null;
    state.activityDraftEndDate = null;
    state.activityDraftStartTime = null;
    state.activityDraftEndTime = null;
    state.activityDraftAllDay = false;
    state.activityDraftDurationMinutes = 0;
    state.activityDraftLocationType = '';
    state.activityDraftPendingType = '';
    state.activitySaveInProgress = false;
    state.stableAccessStatus = accessStatus;
  });
}

void _phase5InvalidateMembershipAuthority(String authUserId) {
  final state = FFAppState();
  final localAccountScopes = List<LocalAccountScopeDataStruct>.from(
    state.localAccountScopes,
  );
  final operationalBackups = List<LocalAccountScopeDataStruct>.from(
    state.phase4BAccountOperationalBackups,
  );

  void sanitizeScopes(List<LocalAccountScopeDataStruct> scopes) {
    for (final scope in scopes) {
      if (scope.authUserId != authUserId) continue;
      scope.selectedCloudStableId = '';
      scope.stableMembershipCaches = scope.stableMembershipCaches
          .where((cache) => cache.authUserId != authUserId)
          .toList();
    }
  }

  sanitizeScopes(localAccountScopes);
  sanitizeScopes(operationalBackups);
  state.update(() {
    state.stableMembershipCaches = state.stableMembershipCaches
        .where((cache) => cache.authUserId != authUserId)
        .toList();
    state.selectedCloudStableId = '';
    state.localAccountScopes = localAccountScopes;
    state.phase4BAccountOperationalBackups = operationalBackups;
  });
}

LocalAccountScopeDataStruct? _phase4BMasterScope(String authUserId) {
  for (final scope in FFAppState().phase4BAccountOperationalBackups) {
    if (scope.authUserId == authUserId) return scope;
  }
  return null;
}

void _phase4BSaveMasterScope(LocalAccountScopeDataStruct scope) {
  final scopes = List<LocalAccountScopeDataStruct>.from(
    FFAppState().phase4BAccountOperationalBackups,
  )..removeWhere((candidate) => candidate.authUserId == scope.authUserId);
  scopes.add(scope);
  FFAppState().phase4BAccountOperationalBackups = scopes;
}

LocalAccountScopeDataStruct _phase4BSaveCurrentOperationalScope(
  String authUserId,
) {
  final selectedCloudStableId = FFAppState().selectedCloudStableId;
  if (selectedCloudStableId.isNotEmpty) {
    final links = List<LocalStableCloudLinkDataStruct>.from(
      FFAppState().localStableCloudLinks,
    );
    for (final link in links) {
      if (link.authUserId == authUserId &&
          link.cloudStableId == selectedCloudStableId &&
          link.confirmed) {
        link.selectedHorseId = FFAppState().selectedHorse.id;
      }
    }
    FFAppState().localStableCloudLinks = links;
  }
  final current = _phase4BCaptureOperationalScope(authUserId);
  final existing = _phase4BMasterScope(authUserId);
  final plan = phase4BPlanSerializedOperationalMasterSave(
    current: current,
    existing: existing,
    toSerializableMap: (scope) =>
        jsonDecode(scope.serialize()) as Map<String, dynamic>,
    fromSerializableMap: LocalAccountScopeDataStruct.fromSerializableMap,
  );
  if (plan.shouldPersist) _phase4BSaveMasterScope(plan.master);
  return plan.master;
}

String _phase4BStableIdForHorse(
  HorseProfileDataStruct horse,
  String fallback,
) =>
    horse.stableId.trim().isEmpty ? fallback : horse.stableId;

LocalStableCloudLinkDataStruct? _phase4BLinkFor(
  String authUserId,
  String cloudStableId,
) {
  for (final link in FFAppState().localStableCloudLinks) {
    if (link.authUserId == authUserId &&
        link.cloudStableId == cloudStableId &&
        link.confirmed) {
      return link;
    }
  }
  return null;
}

void _phase4BLoadLinkedOperationalContext(
  LocalAccountScopeDataStruct master,
  LocalStableCloudLinkDataStruct? link,
) {
  if (link == null || link.localStableId.trim().isEmpty) {
    _phase4BClearSensitiveWorkingSet(accessStatus: 'unlinked');
    return;
  }
  final localStableId = link.localStableId;
  final horses = master.horses
      .where(
        (horse) =>
            _phase4BStableIdForHorse(horse, master.currentLocalStableId) ==
            localStableId,
      )
      .toList();
  HorseProfileDataStruct selected = HorseProfileDataStruct();
  var selectedIndex = 0;
  for (var index = 0; index < horses.length; index++) {
    if (horses[index].id == link.selectedHorseId) {
      selected = horses[index];
      selectedIndex = index;
      break;
    }
  }
  if (selected.id == 0 && horses.isNotEmpty) selected = horses.first;

  final state = FFAppState();
  state.update(() {
    // The local stable identifier remains local and is never replaced by a
    // cloud UUID.
    state.currentLocalStableId = localStableId;
    state.horses = horses;
    state.selectedHorse = selected;
    state.selectedHorseIndex = selectedIndex;
    state.activities = master.activities
        .where((item) => item.stableId == localStableId)
        .toList();
    state.horseFeedingPlans = master.horseFeedingPlans
        .where((item) => item.stableId == localStableId)
        .toList();
    state.temporaryFeedingSchedules = master.temporaryFeedingSchedules
        .where((item) => item.stableId == localStableId)
        .toList();
    state.feedingRoundConfigs = master.feedingRoundConfigs
        .where((item) => item.stableId == localStableId)
        .toList();
    state.feedingAssignmentExceptions = master.feedingAssignmentExceptions
        .where((item) => item.stableId == localStableId)
        .toList();
    state.feedingExecutionRecords = master.feedingExecutionRecords
        .where((item) => item.stableId == localStableId)
        .toList();
    state.stableAccessStatus = 'active';
  });
}

class AvarynStableRuntime extends StatefulWidget {
  const AvarynStableRuntime({
    super.key,
    this.width,
    this.height,
    required this.mode,
    this.initialStableMemberId = '',
  });

  final double? width;
  final double? height;
  final String mode;
  final String? initialStableMemberId;

  @override
  State<AvarynStableRuntime> createState() => _AvarynStableRuntimeState();
}

class _AvarynStableRuntimeState extends State<AvarynStableRuntime>
    implements Phase4BManagementGateway {
  final _client = Supabase.instance.client;
  final _name = TextEditingController();
  final _timezone = TextEditingController(text: 'Europe/Amsterdam');
  final _email = TextEditingController();
  final _displayName = TextEditingController();
  final _functionTitle = TextEditingController();
  final _localStableId = TextEditingController();
  final _stableName = TextEditingController();
  final _stableTimezone = TextEditingController();

  bool _busy = false;
  bool _loading = true;
  bool _offline = false;
  String _error = '';
  String _notice = '';
  String _transientInvitationToken = '';
  String _transientInvitationId = '';
  String _transientShareLink = '';
  List<Map<String, dynamic>> _memberships = const [];
  List<Map<String, dynamic>> _directory = const [];
  List<Map<String, dynamic>> _invitations = const [];
  List<Map<String, dynamic>> _managementMembers = const [];
  Map<String, dynamic>? _invitationPreview;
  String _selectedManagementMemberId = '';
  String _memberSelectionError = '';
  String _linkMembershipId = '';
  Phase4BRole _selectedInviteRole = Phase4BRole.member;
  Phase4BRole _selectedReplacementRole = Phase4BRole.member;
  late final Phase4BManagementController _management;
  late final Phase4BMemberSelectionCoordinator _memberSelection;
  bool _dependenciesInitialized = false;

  @override
  void initState() {
    super.initState();
    _management = Phase4BManagementController(
      gateway: this,
      actorRole: Phase4BRole.viewer,
      online: true,
      personalWorkspace: false,
    );
    _memberSelection = Phase4BMemberSelectionCoordinator(
      initialStableMemberId: widget.initialStableMemberId ?? '',
      requireExplicitSelection: widget.mode == 'memberDetails',
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesInitialized) return;
    _dependenciesInitialized = true;
    _readTransientToken();
    _transientInvitationId = FFAppState().pendingStableInvitationId.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  @override
  void dispose() {
    _transientInvitationToken = '';
    _transientInvitationId = '';
    _transientShareLink = '';
    _name.dispose();
    _timezone.dispose();
    _email.dispose();
    _displayName.dispose();
    _functionTitle.dispose();
    _localStableId.dispose();
    _stableName.dispose();
    _stableTimezone.dispose();
    super.dispose();
  }

  void _readTransientToken() {
    final routeUri = GoRouterState.of(context).uri;
    final invitationIdFromUri =
        routeUri.queryParameters['invitation_id']?.trim() ?? '';
    if (RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-'
      r'[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(invitationIdFromUri)) {
      FFAppState().pendingStableInvitationId = invitationIdFromUri;
    }
    final fragment = routeUri.fragment;
    final query = fragment.contains('?')
        ? fragment.substring(fragment.indexOf('?') + 1)
        : fragment;
    final tokenFromUri = Uri.splitQueryString(query)['token'] ?? '';
    final token = tokenFromUri.isNotEmpty
        ? tokenFromUri
        : FFAppState().pendingStableInvitationToken.trim();
    if (token.length >= 40 && token.length <= 128) {
      _transientInvitationToken = token;
      FFAppState().pendingStableInvitationToken = token;
    } else if (tokenFromUri.isNotEmpty) {
      FFAppState().pendingStableInvitationToken = '';
      _phase5StripInvitationTokenFromLocation(context);
    }
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final user = _client.auth.currentUser;
    if (user == null) {
      if (widget.mode == 'invitation') await _previewInvitation();
      _loading = false;
      if (mounted) setState(() {});
      return;
    }
    _displayName.text =
        FFAppState().currentAuthProfile.displayName.trim().isEmpty
            ? 'AVARYN-gebruiker'
            : FFAppState().currentAuthProfile.displayName;
    try {
      final rows = await _client
          .from('stable_memberships')
          .select(
            'id,stable_id,stable_member_id,role,status,row_version,'
            'stables!inner(id,name,kind,status,timezone,locale)',
          )
          .eq('status', 'active');
      _memberships = List<Map<String, dynamic>>.from(rows);
      _offline = false;
      _cacheMemberships(user.id, _memberships);
      if (FFAppState().selectedCloudStableId.isNotEmpty &&
          !_memberships.any(
            (row) => row['stable_id'] == FFAppState().selectedCloudStableId,
          )) {
        _phase4BClearSensitiveWorkingSet(accessStatus: 'removed');
        FFAppState().selectedCloudStableId = '';
      }
      if (widget.mode == 'members') await _loadDirectory();
      if (widget.mode == 'pendingInvitations') await _loadInvitations();
      if (widget.mode == 'invitation') await _previewInvitation();
      if (const {
        'stableDetails',
        'members',
        'memberDetails',
        'roles',
        'invite',
      }.contains(widget.mode)) {
        await _loadManagementMembers();
      }
    } on PostgrestException catch (error) {
      final denied =
          error.code == '401' || error.code == '403' || error.code == '42501';
      if (denied) {
        _phase4BClearSensitiveWorkingSet(accessStatus: 'access_denied');
        _phase5InvalidateMembershipAuthority(user.id);
        _memberships = const [];
      } else {
        _memberships = _validCachedMemberships(user.id);
      }
      _offline = true;
      _error = denied || _memberships.isEmpty
          ? 'Je staltoegang kon niet veilig worden gecontroleerd.'
          : 'Offline: stalgegevens zijn tijdelijk alleen-lezen.';
    } catch (_) {
      _offline = true;
      _memberships = _validCachedMemberships(user.id);
      _error = 'Geen verbinding. Autoriteitswijzigingen zijn uitgeschakeld.';
    }
    _syncManagementController();
    _loading = false;
    if (mounted) setState(() {});
  }

  void _cacheMemberships(String authUserId, List<Map<String, dynamic>> rows) {
    final caches = rows.map((row) {
      final stable = Map<String, dynamic>.from(row['stables'] as Map);
      return StableMembershipCacheDataStruct(
        authUserId: authUserId,
        stableId: _phase4BString(row['stable_id']),
        stableName: _phase4BString(stable['name']),
        stableKind: _phase4BString(stable['kind']),
        membershipId: _phase4BString(row['id']),
        stableMemberId: _phase4BString(row['stable_member_id']),
        role: _phase4BString(row['role']),
        status: _phase4BString(row['status']),
        lastValidatedAt: DateTime.now().toUtc(),
      );
    }).toList();
    FFAppState().stableMembershipCaches = [
      ...FFAppState().stableMembershipCaches.where(
            (cache) => cache.authUserId != authUserId,
          ),
      ...caches,
    ];
  }

  List<Map<String, dynamic>> _validCachedMemberships(String authUserId) {
    final now = DateTime.now().toUtc();
    return FFAppState()
        .stableMembershipCaches
        .where(
          (cache) =>
              cache.authUserId == authUserId &&
              cache.status == 'active' &&
              cache.lastValidatedAt != null &&
              !now.difference(cache.lastValidatedAt!).isNegative &&
              now.difference(cache.lastValidatedAt!) <=
                  _phase4BOfflineAuthorityMaximumAge,
        )
        .map(
          (cache) => {
            'id': cache.membershipId,
            'stable_id': cache.stableId,
            'stable_member_id': cache.stableMemberId,
            'role': cache.role,
            'status': cache.status,
            'stables': {
              'id': cache.stableId,
              'name': cache.stableName,
              'kind': cache.stableKind,
              'status': 'active',
            },
          },
        )
        .toList();
  }

  Map<String, dynamic>? get _selectedMembership {
    final selected = FFAppState().selectedCloudStableId;
    for (final membership in _memberships) {
      if (membership['stable_id'] == selected) return membership;
    }
    return null;
  }

  String get _selectedRole => _phase4BString(_selectedMembership?['role']);
  bool get _isManager => _selectedRole == 'owner' || _selectedRole == 'admin';
  bool get _isOwner => _selectedRole == 'owner';
  bool get _canMutateAuthority => !_offline && _isManager;
  bool get _isPersonalWorkspace =>
      (_selectedMembership?['stables'] as Map?)?['kind'] == 'personal';

  Phase4BRole _role(String? value) => Phase4BRole.values.firstWhere(
        (role) => role.name == value,
        orElse: () => Phase4BRole.viewer,
      );

  Map<String, dynamic>? get _selectedManagementMember {
    for (final member in _managementMembers) {
      if (member['stable_member_id'] == _selectedManagementMemberId) {
        return member;
      }
    }
    return null;
  }

  void _syncManagementController() {
    _management
      ..actorRole = _role(_selectedRole)
      ..online = !_offline
      ..personalWorkspace = _isPersonalWorkspace;
    final allowedInvites = _management.allowedInvitationRoles;
    if (!allowedInvites.contains(_selectedInviteRole) &&
        allowedInvites.isNotEmpty) {
      _selectedInviteRole = allowedInvites.first;
    }
  }

  void _applyManagementFeedback() {
    _busy = _management.busy;
    _error = _management.error;
    _notice = _management.notice;
    final transientLink = _management.takeTransientInvitationLink();
    if (transientLink.isNotEmpty) _transientShareLink = transientLink;
    _syncManagementController();
    if (mounted) setState(() {});
  }

  Future<void> _switchStable(Map<String, dynamic> membership) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await _activateStable(membership);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _activateStable(Map<String, dynamic> membership) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      _phase4BClearSensitiveWorkingSet(accessStatus: 'signed_out');
      return false;
    }

    final authId = user.id;
    late LocalAccountScopeDataStruct master;
    try {
      // Persist the current filtered working set into the account master before
      // every switch. An existing master is merged, never silently reused.
      master = _phase4BSaveCurrentOperationalScope(authId);
    } catch (_) {
      _error =
          'De huidige lokale stal kon niet veilig worden opgeslagen. Wisselen is gestopt.';
      return false;
    }
    // Clear before network validation so a previous stable can never flash.
    _phase4BClearSensitiveWorkingSet(accessStatus: 'validating');
    final stableId = _phase4BString(membership['stable_id']);
    try {
      final validation = await _client
          .from('stable_memberships')
          .select('id,status,role')
          .eq('stable_id', stableId)
          .eq('user_id', authId)
          .eq('status', 'active')
          .maybeSingle();
      if (validation == null) {
        throw const PostgrestException(message: 'ACCESS_REMOVED', code: '403');
      }
      await _client.rpc(
        'set_selected_stable',
        params: {
          'p_stable_id': stableId,
          'p_workspace_mode':
              (membership['stables'] as Map?)?['kind'] == 'personal'
                  ? 'personal'
                  : 'stable',
        },
      );
      FFAppState().selectedCloudStableId = stableId;
      final link = _phase4BLinkFor(authId, stableId);
      _phase4BLoadLinkedOperationalContext(master, link);
      if (mounted) context.goNamed('TodayDashboardPage');
      return true;
    } on PostgrestException catch (error) {
      final denied =
          error.code == '401' || error.code == '403' || error.code == '42501';
      _phase4BClearSensitiveWorkingSet(
        accessStatus: denied ? 'access_denied' : 'offline',
      );
      if (denied) FFAppState().selectedCloudStableId = '';
      _error = denied
          ? 'Je toegang tot deze stal is verwijderd of geschorst.'
          : 'Stalwisselen vereist een online lidmaatschapscontrole.';
      return false;
    } catch (_) {
      _phase4BClearSensitiveWorkingSet(accessStatus: 'offline');
      _error =
          'De stal kon niet veilig worden geactiveerd. Controleer je verbinding.';
      return false;
    }
  }

  Future<void> _createStable({required bool personal}) async {
    if (_busy || _offline) return;
    final actorId = _client.auth.currentUser?.id ?? '';
    if (actorId.isEmpty) {
      setState(() => _error = 'Log opnieuw in om een workspace aan te maken.');
      return;
    }
    final name = _name.text.trim();
    if (name.isEmpty || _timezone.text.trim().isEmpty) {
      setState(() => _error = 'Vul een naam en tijdzone in.');
      return;
    }
    final payload = [
      personal ? 'personal' : 'organization',
      name,
      _timezone.text.trim(),
      _displayName.text.trim(),
    ];
    final payloadKey = _phase5DeterministicRequestId(
      actorId,
      'create-stable-payload',
      payload,
    );
    final state = FFAppState();
    if (state.pendingStableCreateRequestId.trim().isEmpty ||
        state.pendingStableCreatePayloadKey != payloadKey) {
      state.pendingStableCreateRequestId = const Uuid().v4();
      state.pendingStableCreatePayloadKey = payloadKey;
    }
    final requestId = state.pendingStableCreateRequestId;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final result = await _client.rpc(
        'create_stable',
        params: {
          'p_name': name,
          'p_timezone': _timezone.text.trim(),
          'p_kind': personal ? 'personal' : 'organization',
          'p_locale': 'nl',
          'p_creation_request_id': requestId,
          'p_owner_display_name': _displayName.text.trim(),
          'p_owner_function_title': null,
        },
      );
      final stableId = _phase4BString(result['stable_id']);
      await _load();
      Map<String, dynamic>? membership;
      for (final row in _memberships) {
        if (row['stable_id'] == stableId) {
          membership = row;
          break;
        }
      }
      if (membership == null) {
        _error =
            'De workspace is aangemaakt, maar nog niet geladen. Probeer opnieuw.';
        return;
      }
      if (await _activateStable(membership)) {
        state.pendingStableCreateRequestId = '';
        state.pendingStableCreatePayloadKey = '';
      }
    } on PostgrestException catch (error) {
      _error = error.code == '42501'
          ? 'Je sessie is verlopen. Log opnieuw in.'
          : 'De workspace kon niet veilig worden aangemaakt.';
    } catch (_) {
      _error =
          'De workspace kon niet veilig worden aangemaakt. Probeer opnieuw.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _previewInvitation() async {
    if (_transientInvitationToken.isEmpty && _transientInvitationId.isEmpty) {
      return;
    }
    if (_transientInvitationToken.isEmpty && _client.auth.currentUser == null) {
      _invitationPreview = {'status': 'authentication_required'};
      if (mounted) setState(() {});
      return;
    }
    final useToken = _transientInvitationToken.isNotEmpty;
    try {
      final response = await _client.functions.invoke(
        'stable-invitations',
        body: useToken
            ? {'action': 'preview', 'token': _transientInvitationToken}
            : {'action': 'resume', 'invitation_id': _transientInvitationId},
      );
      _invitationPreview = Map<String, dynamic>.from(response.data as Map);
      final status = _phase4BString(_invitationPreview?['status']);
      if (status == 'pending') {
        final invitationId = _phase4BString(
          _invitationPreview?['invitation_id'],
        );
        if (invitationId.isNotEmpty) {
          _transientInvitationId = invitationId;
          FFAppState().pendingStableInvitationId = invitationId;
          // The generated setter persists asynchronously. Complete the
          // non-secret hand-off before replacing the browser route, which can
          // rebuild this widget immediately.
          try {
            await FFAppState().secureStorage.setString(
                  'ff_pendingStableInvitationId',
                  invitationId,
                );
          } catch (_) {
            // The non-secret ID remains in singleton memory for the current
            // SPA auth flow. A redirect that cannot persist it fails closed
            // and requires the invitation link again.
          }
          FFAppState().pendingStableInvitationToken = '';
          _transientInvitationToken = '';
          if (useToken) {
            _phase5StripInvitationTokenFromLocation(
              context,
              invitationId: invitationId,
            );
          }
        }
      } else if (status == 'accepted') {
        final stableId = _phase4BString(_invitationPreview?['stable_id']);
        if (useToken) _phase5StripInvitationTokenFromLocation(context);
        _transientInvitationToken = '';
        _transientInvitationId = '';
        FFAppState().pendingStableInvitationToken = '';
        FFAppState().pendingStableInvitationId = '';
        if (stableId.isNotEmpty) {
          FFAppState().selectedCloudStableId = stableId;
        }
        if (mounted) context.goNamed('StablePickerPage');
      } else if (status == 'declined') {
        if (useToken) _phase5StripInvitationTokenFromLocation(context);
        _transientInvitationToken = '';
        _transientInvitationId = '';
        FFAppState().pendingStableInvitationToken = '';
        FFAppState().pendingStableInvitationId = '';
        if (mounted) context.goNamed('StableOnboardingHandoffPage');
      } else {
        if (useToken) _phase5StripInvitationTokenFromLocation(context);
        _transientInvitationToken = '';
        _transientInvitationId = '';
        FFAppState().pendingStableInvitationToken = '';
        FFAppState().pendingStableInvitationId = '';
      }
    } catch (_) {
      if (useToken) _phase5StripInvitationTokenFromLocation(context);
      _transientInvitationToken = '';
      _transientInvitationId = '';
      FFAppState().pendingStableInvitationToken = '';
      FFAppState().pendingStableInvitationId = '';
      _invitationPreview = {'status': 'unavailable'};
    }
    if (mounted) setState(() {});
  }

  Future<void> _respondInvitation(bool accept) async {
    if (_busy ||
        _offline ||
        (_transientInvitationToken.isEmpty && _transientInvitationId.isEmpty)) {
      return;
    }
    final actorId = _client.auth.currentUser?.id ?? '';
    if (actorId.isEmpty) return;
    final invitationReference = _transientInvitationToken.isNotEmpty
        ? _transientInvitationToken
        : _transientInvitationId;
    final payload = [
      accept ? 'accept' : 'decline',
      invitationReference,
      _displayName.text.trim(),
      _functionTitle.text.trim(),
    ];
    final requestId = _phase5DeterministicRequestId(
      actorId,
      'respond-invitation',
      payload,
    );
    setState(() => _busy = true);
    try {
      final response = await _client.functions.invoke(
        'stable-invitations',
        body: {
          'action': accept ? 'accept' : 'decline',
          if (_transientInvitationToken.isNotEmpty)
            'token': _transientInvitationToken
          else
            'invitation_id': _transientInvitationId,
          'display_name': _displayName.text.trim(),
          'function_title': _functionTitle.text.trim(),
          'request_id': requestId,
        },
      );
      if (response.status != 200) throw StateError('invite response failed');
      _transientInvitationToken = '';
      _transientInvitationId = '';
      FFAppState().pendingStableInvitationToken = '';
      FFAppState().pendingStableInvitationId = '';
      _notice = accept
          ? 'Uitnodiging geaccepteerd. Kies de stal om verder te gaan.'
          : 'Uitnodiging geweigerd.';
      await _load();
      if (mounted) {
        context.goNamed(
          accept ? 'StablePickerPage' : 'StableOnboardingHandoffPage',
        );
      }
    } on FunctionException catch (error) {
      final definitive = const {
        400,
        403,
        404,
        409,
        410,
        422,
      }.contains(error.status);
      if (definitive) {
        _transientInvitationToken = '';
        _transientInvitationId = '';
        FFAppState().pendingStableInvitationToken = '';
        FFAppState().pendingStableInvitationId = '';
      }
      _error = error.status == 401
          ? 'Je sessie is verlopen. Log opnieuw in; de veilige uitnodigingsreferentie blijft behouden.'
          : error.status == 412
              ? 'Bevestig je account en vul een weergavenaam in. De veilige uitnodigingsreferentie blijft behouden.'
              : definitive
                  ? 'Deze uitnodiging is ongeldig, verlopen, ingetrokken of hoort bij een ander bevestigd account.'
                  : 'De reactie is nog niet bevestigd. Probeer opnieuw met dezelfde gegevens.';
    } catch (_) {
      _error =
          'De reactie is nog niet bevestigd. Probeer opnieuw met dezelfde gegevens.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createInvitation() async {
    await _runManagement(
      () => _management.createInvitation(
        stableId: FFAppState().selectedCloudStableId,
        email: _email.text,
        role: _selectedInviteRole,
        requestId: const Uuid().v4(),
      ),
    );
  }

  Future<void> _copyTransientLink() async {
    if (_transientShareLink.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _transientShareLink));
    if (!mounted) return;
    setState(() {
      _transientShareLink = '';
      _notice =
          'Link gekopieerd en uit het scherm gewist. Deel hem via een veilig kanaal.';
    });
  }

  Future<void> _loadDirectory() async {
    final stableId = FFAppState().selectedCloudStableId;
    if (stableId.isEmpty) return;
    final rows = await _client.rpc(
      'list_stable_member_directory',
      params: {'p_stable_id': stableId},
    );
    _directory = List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> _loadInvitations() async {
    if (!_isManager) return;
    final rows = await _client
        .from('stable_invitations')
        .select('id,offered_role,status,expires_at,last_sent_at,resend_count')
        .eq('stable_id', FFAppState().selectedCloudStableId)
        .eq('status', 'pending');
    _invitations = List<Map<String, dynamic>>.from(rows);
  }

  Future<void> _loadManagementMembers() async {
    final stableId = FFAppState().selectedCloudStableId;
    final selected = _selectedMembership;
    if (stableId.isEmpty || selected == null) {
      _managementMembers = const [];
      return;
    }
    final stable = Map<String, dynamic>.from(selected['stables'] as Map);
    _stableName.text = _phase4BString(stable['name']);
    _stableTimezone.text = _phase4BString(stable['timezone']).isEmpty
        ? 'Europe/Amsterdam'
        : _phase4BString(stable['timezone']);
    if (!_isManager) {
      _managementMembers = const [];
      return;
    }
    final rosterRows = List<Map<String, dynamic>>.from(
      await _client
          .from('stable_members')
          .select('id,display_name,function_title,status')
          .eq('stable_id', stableId),
    );
    final membershipRows = List<Map<String, dynamic>>.from(
      await _client
          .from('stable_memberships')
          .select('id,user_id,stable_member_id,role,status,row_version')
          .eq('stable_id', stableId),
    );
    _managementMembers = rosterRows.map((member) {
      Map<String, dynamic>? membership;
      for (final candidate in membershipRows) {
        if (candidate['stable_member_id'] == member['id']) {
          membership = candidate;
          break;
        }
      }
      return {
        'stable_id': stableId,
        'stable_member_id': member['id'],
        'display_name': member['display_name'],
        'function_title': member['function_title'],
        'member_status': member['status'],
        'membership_id': membership?['id'],
        'user_id': membership?['user_id'],
        'role': membership?['role'],
        'membership_status': membership?['status'],
        'row_version': membership?['row_version'],
      };
    }).toList();
    _memberSelection.resolve(
      selectedStableId: stableId,
      candidates: _managementMembers
          .map(
            (member) => Phase4BMemberCandidate(
              stableId: _phase4BString(member['stable_id']),
              stableMemberId: _phase4BString(member['stable_member_id']),
            ),
          )
          .toList(growable: false),
    );
    _selectedManagementMemberId = _memberSelection.selectedStableMemberId;
    _memberSelectionError = _memberSelection.error;
  }

  void _confirmLocalLink() {
    final user = _client.auth.currentUser;
    final cloudStableId = FFAppState().selectedCloudStableId;
    final localStableId = _localStableId.text.trim();
    if (user == null || cloudStableId.isEmpty || localStableId.isEmpty) {
      setState(() => _error = 'Kies eerst een cloudstal en lokale stal.');
      return;
    }
    final links = List<LocalStableCloudLinkDataStruct>.from(
      FFAppState().localStableCloudLinks,
    )..removeWhere(
        (link) =>
            link.authUserId == user.id && link.cloudStableId == cloudStableId,
      );
    links.add(
      LocalStableCloudLinkDataStruct(
        authUserId: user.id,
        cloudStableId: cloudStableId,
        localStableId: localStableId,
        selectedHorseId: 0,
        confirmed: true,
        linkedAt: DateTime.now().toUtc(),
      ),
    );
    FFAppState().localStableCloudLinks = links;
    final master = _phase4BMasterScope(user.id) ??
        _phase4BCaptureOperationalScope(user.id);
    _phase4BSaveMasterScope(master);
    _phase4BLoadLinkedOperationalContext(master, links.last);
    setState(() => _notice = 'Lokale stal expliciet gekoppeld.');
  }

  @override
  Future<Object?> rpc(String name, Map<String, Object?> parameters) async {
    try {
      return await _client.rpc(name, params: parameters);
    } on PostgrestException catch (error) {
      throw Phase4BServerException(error.code ?? 'SERVER_REJECTED');
    }
  }

  @override
  Future<Map<String, Object?>> invitation(
    String action,
    Map<String, Object?> parameters,
  ) async {
    try {
      final response = await _client.functions.invoke(
        'stable-invitations',
        body: {'action': action, ...parameters},
      );
      final data = response.data is Map
          ? Map<String, Object?>.from(response.data as Map)
          : <String, Object?>{};
      if (response.status != 200) {
        throw Phase4BServerException(
          _phase4BString(data['code']).isEmpty
              ? 'SERVER_REJECTED'
              : _phase4BString(data['code']),
        );
      }
      return data;
    } on FunctionException catch (error) {
      final details = error.details is Map
          ? Map<String, dynamic>.from(error.details as Map)
          : const <String, dynamic>{};
      throw Phase4BServerException(
        _phase4BString(details['code']).isEmpty
            ? '${error.status}'
            : _phase4BString(details['code']),
      );
    }
  }

  @override
  Future<void> refreshAuthority() => _load();

  @override
  void clearSensitiveAuthority() {
    FFAppState().selectedCloudStableId = '';
    _phase4BClearSensitiveWorkingSet(accessStatus: 'access_denied');
  }

  Future<void> _runManagement(Future<bool> Function() action) async {
    if (_management.busy) return;
    setState(() => _busy = true);
    await action();
    _applyManagementFeedback();
  }

  Future<bool> _confirmDestructive(String title, String detail) async {
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(detail),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Annuleren'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Expliciet bevestigen'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _changeSelectedRole() async {
    final target = _selectedManagementMember;
    final membershipId = _phase4BString(target?['membership_id']);
    if (target == null || membershipId.isEmpty) return;
    await _runManagement(
      () => _management.changeRole(
        membershipId: membershipId,
        targetRole: _role(_phase4BString(target['role'])),
        newRole: _selectedReplacementRole,
        requestId: const Uuid().v4(),
      ),
    );
  }

  Future<void> _suspendSelected() async {
    final target = _selectedManagementMember;
    final membershipId = _phase4BString(target?['membership_id']);
    if (target == null || membershipId.isEmpty) return;
    await _runManagement(
      () => _management.suspend(
        membershipId: membershipId,
        targetRole: _role(_phase4BString(target['role'])),
        requestId: const Uuid().v4(),
      ),
    );
  }

  Future<void> _removeSelected() async {
    final target = _selectedManagementMember;
    final membershipId = _phase4BString(target?['membership_id']);
    if (target == null || membershipId.isEmpty) return;
    final confirmed = await _confirmDestructive(
      'Lid verwijderen?',
      'Toegang wordt beëindigd. Terugkeer kan alleen via een nieuwe uitnodiging.',
    );
    if (!confirmed) return;
    await _runManagement(
      () => _management.remove(
        membershipId: membershipId,
        targetRole: _role(_phase4BString(target['role'])),
        requestId: const Uuid().v4(),
      ),
    );
  }

  Future<void> _leaveSelectedStable() async {
    final confirmed = await _confirmDestructive(
      'Stal verlaten?',
      'Je actieve toegang tot deze stal wordt beëindigd.',
    );
    if (!confirmed) return;
    await _runManagement(
      () => _management.leave(
        stableId: FFAppState().selectedCloudStableId,
        requestId: const Uuid().v4(),
      ),
    );
  }

  Future<void> _transferToSelected() async {
    final target = _selectedManagementMember;
    final membershipId = _phase4BString(target?['membership_id']);
    if (target == null || membershipId.isEmpty) return;
    final confirmed = await _confirmDestructive(
      'Eigendom overdragen?',
      'De doelgebruiker wordt owner en jij wordt admin. Dit gebeurt transactioneel.',
    );
    await _runManagement(
      () => _management.transferOwnership(
        stableId: FFAppState().selectedCloudStableId,
        targetMembershipId: membershipId,
        requestId: const Uuid().v4(),
        confirmed: confirmed,
      ),
    );
  }

  Future<void> _linkSelectedMember() async {
    final target = _selectedManagementMember;
    if (target == null || _linkMembershipId.isEmpty) return;
    Map<String, dynamic>? membershipTarget;
    for (final candidate in _managementMembers) {
      if (candidate['membership_id'] == _linkMembershipId) {
        membershipTarget = candidate;
        break;
      }
    }
    if (membershipTarget == null) return;
    await _runManagement(
      () => _management.linkAccountToMember(
        membershipId: _linkMembershipId,
        stableMemberId: _phase4BString(target!['stable_member_id']),
        targetRole: _role(_phase4BString(membershipTarget!['role'])),
        requestId: const Uuid().v4(),
      ),
    );
  }

  Future<void> _updateSelectedStable() async {
    await _runManagement(
      () => _management.updateStable(
        stableId: FFAppState().selectedCloudStableId,
        name: _stableName.text,
        timezone: _stableTimezone.text,
        locale: 'nl',
        requestId: const Uuid().v4(),
      ),
    );
  }

  Future<void> _archiveSelectedStable() async {
    final confirmed = await _confirmDestructive(
      'Stal archiveren?',
      'De stal wordt read-only en kan niet via de app worden hersteld.',
    );
    await _runManagement(
      () => _management.archiveStable(
        stableId: FFAppState().selectedCloudStableId,
        requestId: const Uuid().v4(),
        confirmed: confirmed,
      ),
    );
  }

  Future<void> _resendInvitation(String invitationId) async {
    await _runManagement(
      () => _management.resendInvitation(
        invitationId: invitationId,
        requestId: const Uuid().v4(),
      ),
    );
  }

  Future<void> _revokeInvitation(String invitationId) async {
    final confirmed = await _confirmDestructive(
      'Uitnodiging intrekken?',
      'De huidige uitnodigingslink wordt onmiddellijk ongeldig.',
    );
    if (!confirmed) return;
    await _runManagement(
      () => _management.revokeInvitation(
        invitationId: invitationId,
        requestId: const Uuid().v4(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    if (widget.mode == 'selector') return _selectorBar(theme);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = phase4BLayoutForWidth(constraints.maxWidth) ==
            Phase4BLayout.compact;
        final content = _content(theme, compact);
        return ColoredBox(
          color: theme.primaryBackground,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 20 : 40,
                vertical: compact ? 24 : 36,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: content,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _selectorBar(FlutterFlowTheme theme) {
    final membership = _selectedMembership ??
        (_memberships.isEmpty ? null : _memberships.first);
    final stable = membership == null
        ? null
        : Map<String, dynamic>.from(membership['stables'] as Map);
    final title = _loading ? 'A V A R Y N' : 'A V A R Y N';
    final subtitle = stable == null
        ? (_client.auth.currentUser == null
            ? 'Meld aan om een stal te kiezen'
            : 'Open stalkeuze of onboarding')
        : '${_offline ? 'OFFLINE' : 'STAL ONLINE'} · '
            '${_phase4BString(membership!['role']).toUpperCase()}';
    final canOpenPicker =
        !_loading && _client.auth.currentUser != null && !_busy;
    return Material(
      color: theme.primary,
      child: InkWell(
        onTap:
            canOpenPicker ? () => context.pushNamed('StablePickerPage') : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: theme.secondary.withOpacity(0.9)),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  'A',
                  style: theme.titleMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.titleMedium.copyWith(color: Colors.white),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.bodySmall.copyWith(
                        color: Colors.white.withOpacity(0.72),
                      ),
                    ),
                  ],
                ),
              ),
              if (_loading || _busy)
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else if (canOpenPicker && stable != null)
                IconButton(
                  tooltip: 'Stal en team beheren',
                  onPressed: () => context.pushNamed('StableDetailsPage'),
                  icon: const Icon(Icons.settings_outlined),
                  color: Colors.white,
                )
              else if (canOpenPicker)
                const Icon(Icons.expand_more, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(FlutterFlowTheme theme, bool compact) {
    final title = switch (widget.mode) {
      'handoff' => 'Kies hoe je AVARYN wilt gebruiken',
      'createStable' => 'Nieuwe stal aanmaken',
      'personalWorkspace' => 'Persoonlijke workspace',
      'invitation' => 'Uitnodiging',
      'stablePicker' => 'Stal kiezen',
      'stableDetails' => 'Staldetails',
      'members' => 'Leden en medewerkers',
      'memberDetails' => 'Medewerker',
      'invite' => 'Iemand uitnodigen',
      'pendingInvitations' => 'Openstaande uitnodigingen',
      'roles' => 'Rollen beheren',
      'access' => 'Staltoegang',
      'linkLocalStable' => 'Lokale stal koppelen',
      _ => 'Stalbeheer',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: theme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          _offline
              ? 'Offline · autoriteitsgegevens zijn alleen-lezen'
              : 'Veilige stalcontext · rollen komen uitsluitend uit Supabase',
          style: theme.bodyMedium.copyWith(color: theme.secondaryText),
        ),
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 16),
          _message(theme, _error, error: true),
        ],
        if (_notice.isNotEmpty) ...[
          const SizedBox(height: 16),
          _message(theme, _notice),
        ],
        const SizedBox(height: 24),
        _modeBody(theme, compact),
      ],
    );
  }

  Widget _modeBody(FlutterFlowTheme theme, bool compact) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return switch (widget.mode) {
      'handoff' => _handoff(theme, compact),
      'createStable' => _createForm(theme, personal: false),
      'personalWorkspace' => _createForm(theme, personal: true),
      'invitation' => _invitation(theme),
      'stablePicker' => _selector(theme, compact: compact),
      'stableDetails' => _stableDetails(theme),
      'members' => _memberList(theme),
      'memberDetails' => _memberDetails(theme),
      'invite' => _inviteForm(theme),
      'pendingInvitations' => _pendingList(theme),
      'roles' => _roles(theme),
      'access' => _access(theme),
      'linkLocalStable' => _linkForm(theme),
      _ => _stableDetails(theme),
    };
  }

  Widget _handoff(FlutterFlowTheme theme, bool compact) {
    final cards = [
      _actionCard(
        theme,
        'Een stal starten',
        'Maak na bevestiging een organisatie, owner-medewerker en lidmaatschap.',
        Icons.add_business_outlined,
        () => context.pushNamed('CreateStablePage'),
      ),
      _actionCard(
        theme,
        'Uitnodiging openen',
        'Accepteer nooit automatisch; een geldige link is vereist.',
        Icons.mark_email_unread_outlined,
        () => context.pushNamed('StableInvitationPage'),
      ),
      _actionCard(
        theme,
        'Alleen mijn paarden',
        'Maak expliciet een private workspace. Er wordt geen paard aangemaakt.',
        Icons.person_outline,
        () => context.pushNamed('PersonalWorkspacePage'),
      ),
    ];
    return compact
        ? Column(children: cards)
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: cards
                .map((card) => Expanded(child: card))
                .toList(growable: false),
          );
  }

  Widget _createForm(FlutterFlowTheme theme, {required bool personal}) {
    if (personal && _name.text.isEmpty) _name.text = 'Mijn paarden';
    return _panel(
      theme,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Naam'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _timezone,
            decoration: const InputDecoration(labelText: 'Tijdzone'),
          ),
          const SizedBox(height: 16),
          Text(
            personal
                ? 'Uitnodigingen blijven uitgeschakeld. Er wordt geen paard of legacykoppeling gemaakt.'
                : 'Na aanmaken kies je afzonderlijk of een lokale stal gekoppeld mag worden.',
            style: theme.bodyMedium,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy || _offline
                ? null
                : () => _createStable(personal: personal),
            child: Text(_busy ? 'Bezig…' : 'Bevestigen en aanmaken'),
          ),
        ],
      ),
    );
  }

  Widget _invitation(FlutterFlowTheme theme) {
    final preview = _invitationPreview;
    if (_transientInvitationToken.isEmpty && _transientInvitationId.isEmpty) {
      return _empty(
        theme,
        'Je hebt een uitnodigingslink nodig om bij een stal te komen.',
      );
    }
    if (preview == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (preview['status'] == 'authentication_required') {
      return _panel(
        theme,
        Column(
          children: [
            const Text(
              'Log veilig in om deze uitnodiging opnieuw te controleren.',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.goNamed('AuthWelcomePage'),
              child: const Text('Veilig inloggen'),
            ),
          ],
        ),
      );
    }
    if (preview['status'] == 'unavailable') {
      return _empty(
        theme,
        'De uitnodiging kon niet veilig worden gecontroleerd. Probeer opnieuw.',
      );
    }
    if (preview['status'] != 'pending') {
      return _empty(
        theme,
        'Deze uitnodiging is ongeldig, verlopen, ingetrokken of al gebruikt.',
      );
    }
    if (_client.auth.currentUser == null) {
      return _panel(
        theme,
        Column(
          children: [
            Text(
              '${preview['stable_name']} · rol ${preview['offered_role']}',
              style: theme.titleLarge,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.goNamed('AuthWelcomePage'),
              child: const Text('Eerst veilig inloggen'),
            ),
          ],
        ),
      );
    }
    return _panel(
      theme,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_phase4BString(preview['stable_name']), style: theme.titleLarge),
          Text('Aangeboden rol: ${preview['offered_role']}'),
          const SizedBox(height: 12),
          TextField(
            controller: _displayName,
            decoration: const InputDecoration(labelText: 'Naam in deze stal'),
          ),
          TextField(
            controller: _functionTitle,
            decoration: const InputDecoration(
              labelText: 'Operationele functietitel (optioneel)',
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy || _offline
                      ? null
                      : () => _respondInvitation(false),
                  child: const Text('Weigeren'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed:
                      _busy || _offline ? null : () => _respondInvitation(true),
                  child: const Text('Accepteren'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _selector(FlutterFlowTheme theme, {required bool compact}) {
    if (_memberships.isEmpty) {
      return _empty(theme, 'Nog geen actieve stal. Open onboarding.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _memberships.map((membership) {
        final stable = Map<String, dynamic>.from(
          membership['stables'] as Map,
        );
        final selected =
            membership['stable_id'] == FFAppState().selectedCloudStableId;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            selected: selected,
            tileColor: selected ? theme.accent2 : theme.secondaryBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: Icon(
              stable['kind'] == 'personal'
                  ? Icons.person_outline
                  : Icons.home_work_outlined,
            ),
            title: Text(_phase4BString(stable['name'])),
            subtitle: Text(
              '${membership['role']}${_offline ? ' · offline lezen' : ''}',
            ),
            trailing: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _busy || _offline ? null : () => _switchStable(membership),
          ),
        );
      }).toList(),
    );
  }

  Widget _stableDetails(FlutterFlowTheme theme) {
    final membership = _selectedMembership;
    if (membership == null)
      return _empty(theme, 'Kies eerst een actieve stal.');
    final stable = Map<String, dynamic>.from(membership['stables'] as Map);
    return _panel(
      theme,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_phase4BString(stable['name']), style: theme.titleLarge),
          Text('Type: ${stable['kind']} · jouw rol: ${membership['role']}'),
          const SizedBox(height: 16),
          if (_isManager) ...[
            TextField(
              controller: _stableName,
              decoration: const InputDecoration(labelText: 'Stalnaam'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _stableTimezone,
              decoration: const InputDecoration(labelText: 'Tijdzone'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed:
                  _management.busy || _offline ? null : _updateSelectedStable,
              child: const Text('Stalgegevens opslaan'),
            ),
          ],
          OutlinedButton(
            onPressed: () => context.pushNamed('StableMembersPage'),
            child: const Text('Leden en medewerkers'),
          ),
          if (_isManager) ...[
            OutlinedButton(
              onPressed: () => context.pushNamed('ManageStableRolesPage'),
              child: const Text('Rollen en toegang beheren'),
            ),
            if (!_isPersonalWorkspace)
              OutlinedButton(
                onPressed: () => context.pushNamed('InviteStableMemberPage'),
                child: const Text('Medewerker uitnodigen'),
              ),
            if (!_isPersonalWorkspace)
              OutlinedButton(
                onPressed: () =>
                    context.pushNamed('PendingStableInvitationsPage'),
                child: const Text('Openstaande uitnodigingen'),
              ),
          ] else if (!_isOwner)
            OutlinedButton(
              onPressed:
                  _offline || _management.busy ? null : _leaveSelectedStable,
              child: const Text('Zelf deze stal verlaten'),
            ),
          if (_isOwner)
            OutlinedButton(
              onPressed:
                  _management.busy || _offline ? null : _archiveSelectedStable,
              child: const Text('Stal archiveren'),
            ),
        ],
      ),
    );
  }

  Widget _memberList(FlutterFlowTheme theme) {
    if (_directory.isEmpty) {
      return _empty(theme, 'Geen actieve operationele medewerkers gevonden.');
    }
    return Column(
      children: _directory
          .map(
            (member) => ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.person_outline),
              ),
              title: Text(_phase4BString(member['display_name'])),
              subtitle: Text(
                _phase4BString(member['function_title']).isEmpty
                    ? 'Geen functietitel'
                    : _phase4BString(member['function_title']),
              ),
              onTap: _isManager
                  ? () {
                      final route = _memberSelection.detailRoute(
                        _phase4BString(member['stable_member_id']),
                      );
                      context.pushNamed(
                        route.pageName,
                        queryParameters: {
                          'stableMemberId': serializeParam(
                            route.stableMemberId,
                            ParamType.String,
                          ),
                        }.withoutNulls,
                      );
                    }
                  : null,
            ),
          )
          .toList(),
    );
  }

  Widget _memberDetails(FlutterFlowTheme theme) {
    if (_memberSelectionError.isNotEmpty) {
      return _empty(
        theme,
        'Deze medewerker bestaat niet (meer) binnen de geselecteerde stal.',
      );
    }
    return _managementPanel(theme, includeLeave: false);
  }

  Widget _inviteForm(FlutterFlowTheme theme) => _panel(
        theme,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-mailadres'),
            ),
            const SizedBox(height: 12),
            Text(
              _selectedRole == 'admin'
                  ? 'Als admin kun je member of viewer uitnodigen.'
                  : 'Als owner kun je admin, member of viewer beheren.',
            ),
            if (_management.allowedInvitationRoles.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<Phase4BRole>(
                value: _selectedInviteRole,
                decoration: const InputDecoration(labelText: 'Aangeboden rol'),
                items: _management.allowedInvitationRoles
                    .map(
                      (role) =>
                          DropdownMenuItem(value: role, child: Text(role.name)),
                    )
                    .toList(),
                onChanged: _offline
                    ? null
                    : (role) {
                        if (role != null) {
                          setState(() => _selectedInviteRole = role);
                        }
                      },
              ),
            ],
            const SizedBox(height: 16),
            if (_management.allowedInvitationRoles.isNotEmpty)
              FilledButton(
                onPressed:
                    _canMutateAuthority && !_busy ? _createInvitation : null,
                child: const Text('Veilige uitnodigingslink maken'),
              )
            else
              Text(
                _isPersonalWorkspace
                    ? 'Persoonlijke workspaces hebben geen uitnodigingsbeheer.'
                    : 'Je rol heeft geen uitnodigingsrechten.',
              ),
            if (_transientShareLink.isNotEmpty) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _copyTransientLink,
                icon: const Icon(Icons.copy),
                label: const Text('Eenmalig kopiëren en wissen'),
              ),
            ],
          ],
        ),
      );

  Widget _pendingList(FlutterFlowTheme theme) {
    if (!_isManager) return _empty(theme, 'Alleen owner/admin heeft toegang.');
    if (_invitations.isEmpty) {
      return _empty(theme, 'Geen openstaande uitnodigingen.');
    }
    return Column(
      children: [
        ..._invitations.map(
          (invitation) => ListTile(
            leading: const Icon(Icons.schedule_send_outlined),
            title: Text('Rol ${invitation['offered_role']}'),
            subtitle: Text(
              'Verloopt ${_phase4BDate(invitation['expires_at']) ?? ''}',
            ),
            trailing: PopupMenuButton<String>(
              enabled: !_offline && !_management.busy,
              onSelected: (action) {
                final id = _phase4BString(invitation['id']);
                if (action == 'resend') _resendInvitation(id);
                if (action == 'revoke') _revokeInvitation(id);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'resend',
                  child: Text('Nieuwe link maken'),
                ),
                PopupMenuItem(value: 'revoke', child: Text('Intrekken')),
              ],
            ),
          ),
        ),
        if (_transientShareLink.isNotEmpty)
          OutlinedButton.icon(
            onPressed: _copyTransientLink,
            icon: const Icon(Icons.copy),
            label: const Text('Nieuwe link eenmalig kopiëren en wissen'),
          ),
      ],
    );
  }

  Widget _roles(FlutterFlowTheme theme) =>
      _managementPanel(theme, includeLeave: true);

  Widget _managementPanel(
    FlutterFlowTheme theme, {
    required bool includeLeave,
  }) {
    if (!_isManager && !includeLeave) {
      return _empty(theme, 'Je hebt geen beheerrechten voor medewerkers.');
    }
    if (_managementMembers.isEmpty) {
      return _empty(theme, 'Geen beheerbare medewerkers gevonden.');
    }
    final selected = _selectedManagementMember ?? _managementMembers.first;
    final targetRole = _role(_phase4BString(selected['role']));
    final replacementRoles = _management.allowedReplacementRoles(targetRole);
    if (replacementRoles.isNotEmpty &&
        !replacementRoles.contains(_selectedReplacementRole)) {
      _selectedReplacementRole = replacementRoles.first;
    }
    final membershipId = _phase4BString(selected['membership_id']);
    final activeMembership = selected['membership_status'] == 'active';
    final canManageTarget =
        activeMembership && _management.canManageTarget(targetRole);
    final linkableMemberships = _managementMembers
        .where(
          (candidate) =>
              _phase4BString(candidate['membership_id']).isNotEmpty &&
              candidate['membership_status'] == 'active' &&
              candidate['stable_member_id'] != selected['stable_member_id'],
        )
        .toList();
    return _panel(
      theme,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            value: _phase4BString(selected['stable_member_id']),
            decoration: const InputDecoration(labelText: 'Medewerker'),
            items: _managementMembers
                .map(
                  (member) => DropdownMenuItem(
                    value: _phase4BString(member['stable_member_id']),
                    child: Text(_phase4BString(member['display_name'])),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() {
              _memberSelection.choose(value ?? '');
              _memberSelection.resolve(
                selectedStableId: FFAppState().selectedCloudStableId,
                candidates: _managementMembers
                    .map(
                      (member) => Phase4BMemberCandidate(
                        stableId: _phase4BString(member['stable_id']),
                        stableMemberId: _phase4BString(
                          member['stable_member_id'],
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
              _selectedManagementMemberId =
                  _memberSelection.selectedStableMemberId;
              _memberSelectionError = _memberSelection.error;
            }),
          ),
          const SizedBox(height: 12),
          Text(
            _phase4BString(selected['display_name']),
            style: theme.titleLarge,
          ),
          Text(
            'Functie: ${_phase4BString(selected['function_title']).isEmpty ? 'niet ingevuld' : selected['function_title']}',
          ),
          Text(
            membershipId.isEmpty
                ? 'Geen account gekoppeld'
                : 'Rol: ${selected['role']} · status: ${selected['membership_status']}',
          ),
          if (replacementRoles.isNotEmpty && canManageTarget) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<Phase4BRole>(
              value: _selectedReplacementRole,
              decoration: const InputDecoration(labelText: 'Nieuwe rol'),
              items: replacementRoles
                  .map(
                    (role) => DropdownMenuItem(
                      value: role,
                      child: Text(role.name),
                    ),
                  )
                  .toList(),
              onChanged: _offline
                  ? null
                  : (role) {
                      if (role != null) {
                        setState(() => _selectedReplacementRole = role);
                      }
                    },
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed:
                  _offline || _management.busy ? null : _changeSelectedRole,
              child: const Text('Rol wijzigen'),
            ),
            OutlinedButton(
              onPressed: _offline || _management.busy ? null : _suspendSelected,
              child: const Text('Lid schorsen'),
            ),
            OutlinedButton(
              onPressed: _offline || _management.busy ? null : _removeSelected,
              child: const Text('Lid verwijderen'),
            ),
          ],
          if (_isOwner &&
              activeMembership &&
              membershipId.isNotEmpty &&
              targetRole != Phase4BRole.owner)
            OutlinedButton(
              onPressed:
                  _offline || _management.busy ? null : _transferToSelected,
              child: const Text('Eigendom expliciet overdragen'),
            ),
          if (membershipId.isEmpty &&
              _isManager &&
              linkableMemberships.isNotEmpty) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: linkableMemberships.any(
                (candidate) => candidate['membership_id'] == _linkMembershipId,
              )
                  ? _linkMembershipId
                  : null,
              decoration: const InputDecoration(
                labelText: 'Accountmembership koppelen',
              ),
              items: linkableMemberships
                  .map(
                    (candidate) => DropdownMenuItem(
                      value: _phase4BString(candidate['membership_id']),
                      child: Text(
                        '${candidate['display_name']} (${candidate['role']})',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _offline
                  ? null
                  : (value) => setState(() => _linkMembershipId = value ?? ''),
            ),
            FilledButton(
              onPressed:
                  _offline || _management.busy || _linkMembershipId.isEmpty
                      ? null
                      : _linkSelectedMember,
              child: const Text('Account aan medewerker koppelen'),
            ),
          ],
          if (includeLeave && !_isOwner) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed:
                  _offline || _management.busy ? null : _leaveSelectedStable,
              child: const Text('Zelf deze stal verlaten'),
            ),
          ],
          if (_offline)
            Text(
              'Offline read-only: beheeracties zijn niet beschikbaar.',
              style: theme.bodySmall,
            ),
        ],
      ),
    );
  }

  Widget _access(FlutterFlowTheme theme) {
    final status = FFAppState().stableAccessStatus;
    return _empty(
      theme,
      status == 'suspended'
          ? 'Je toegang is geschorst. Lokale autoriteitsmutaties zijn geblokkeerd.'
          : 'Je toegang is verwijderd of kon niet veilig worden gevalideerd.',
    );
  }

  Widget _linkForm(FlutterFlowTheme theme) => _panel(
        theme,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Deze keuze koppelt uitsluitend IDs. Legacydata wordt niet automatisch aan de owner toegewezen.',
              style: theme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _localStableId,
              decoration: const InputDecoration(
                labelText: 'Bestaande lokale stal-ID',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _confirmLocalLink,
              child: const Text('Expliciet bevestigen'),
            ),
          ],
        ),
      );

  Widget _actionCard(
    FlutterFlowTheme theme,
    String title,
    String detail,
    IconData icon,
    VoidCallback onTap,
  ) =>
      Padding(
        padding: const EdgeInsets.all(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: _panel(
            theme,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: theme.secondary, size: 30),
                const SizedBox(height: 16),
                Text(title, style: theme.titleMedium),
                const SizedBox(height: 8),
                Text(detail, style: theme.bodyMedium),
              ],
            ),
          ),
        ),
      );

  Widget _panel(FlutterFlowTheme theme, Widget child) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.secondaryBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.alternate),
        ),
        child: child,
      );

  Widget _empty(FlutterFlowTheme theme, String text) => _panel(
        theme,
        Column(
          children: [
            Icon(Icons.info_outline, color: theme.secondary, size: 34),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: theme.bodyLarge),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Opnieuw proberen')),
          ],
        ),
      );

  Widget _message(FlutterFlowTheme theme, String text, {bool error = false}) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: error ? theme.error.withValues(alpha: 0.10) : theme.accent2,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          style: theme.bodyMedium.copyWith(
            color: error ? theme.error : theme.primaryText,
          ),
        ),
      );
}

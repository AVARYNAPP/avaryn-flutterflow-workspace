import 'package:test/test.dart';

import '../dsl/phase_4b_context_model.dart';

final class _MemoryOperationalStore implements AccountOperationalStore {
  final values = <String, AccountOperationalMaster>{};
  bool failWrites = false;

  @override
  AccountOperationalMaster? read(String authUserId) => values[authUserId];

  @override
  void write(AccountOperationalMaster master) {
    if (failWrites) throw StateError('local storage unavailable');
    values[master.authUserId] = master;
  }
}

Map<String, dynamic> _record(String id, String stableId) => {
  'id': id,
  'stableId': stableId,
};

Map<String, dynamic> _fullOperationalScope({
  required String authUserId,
  required String localStableId,
  required String cloudStableId,
  required String marker,
  required int counterBase,
}) => {
  'authUserId': authUserId,
  for (final key in phase4BOperationalScopedCollectionKeys)
    key: [_record('$key-$marker', localStableId)],
  'selectedHorse': _record('selected-$marker', localStableId),
  'selectedHorseIndex': counterBase + 1,
  'nextHorseId': counterBase + 2,
  'nextHorseIndex': counterBase + 3,
  'horseSeedVersion': counterBase + 4,
  'passportPrototypeVersion': counterBase + 5,
  'nextActivityId': counterBase + 6,
  'currentLocalUserId': 'local-user-$marker',
  'currentLocalStableId': localStableId,
  'nextFeedingItemId': counterBase + 7,
  'nextTemporaryFeedingScheduleId': counterBase + 8,
  'nextFeedingAssignmentExceptionId': counterBase + 9,
  'nextFeedingExecutionRecordId': counterBase + 10,
  'selectedCloudStableId': cloudStableId,
  'localStableCloudLinks': [
    {
      'authUserId': authUserId,
      'cloudStableId': cloudStableId,
      'localStableId': localStableId,
    },
  ],
  'stableMembershipCaches': [
    {'authUserId': authUserId, 'stableId': cloudStableId, 'status': 'active'},
  ],
  'schemaVersion': counterBase + 11,
  'updatedAt': 'snapshot-$marker',
  'futureScalarField': 'future-$marker',
  'legacyIds': ['legacy-$authUserId'],
  'legacyBackup': 'backup-$authUserId',
};

Map<String, dynamic> _combineStableScopes(
  Map<String, dynamic> first,
  Map<String, dynamic> second,
) {
  final combined = Map<String, dynamic>.from(first);
  for (final key in phase4BOperationalScopedCollectionKeys) {
    combined[key] = [...(first[key] as List), ...(second[key] as List)];
  }
  return combined;
}

Phase4BMasterSavePlan<Map<String, dynamic>> _saveMapScope({
  required Map<String, dynamic> current,
  required Map<String, dynamic>? existing,
}) => phase4BPlanSerializedOperationalMasterSave(
  current: current,
  existing: existing,
  toSerializableMap: (value) => value,
  fromSerializableMap: (value) => value,
);

void main() {
  const coordinator = StableContextCoordinator();
  const userA = 'auth-a';
  const userB = 'auth-b';
  const cloudA = 'cloud-a';
  const cloudB = 'cloud-b';
  const records = [
    LocalOperationalRecord(id: 'horse-local-1', localStableId: 'local-a'),
    LocalOperationalRecord(id: 'activity-local-2', localStableId: 'local-a'),
    LocalOperationalRecord(id: 'horse-local-3', localStableId: 'local-b'),
  ];
  const links = [
    LocalStableCloudLink(
      authUserId: userA,
      cloudStableId: cloudA,
      localStableId: 'local-a',
      selectedHorseId: 1,
      confirmed: true,
    ),
    LocalStableCloudLink(
      authUserId: userA,
      cloudStableId: cloudB,
      localStableId: 'local-b',
      selectedHorseId: 3,
      confirmed: true,
    ),
    LocalStableCloudLink(
      authUserId: userB,
      cloudStableId: cloudA,
      localStableId: 'local-b',
      selectedHorseId: 3,
      confirmed: true,
    ),
  ];

  test('stable switch filters every local record through explicit mapping', () {
    final result = coordinator.switchContext(
      authUserId: userA,
      cloudStableId: cloudA,
      validatedMembership: const MembershipSnapshot(
        authUserId: userA,
        cloudStableId: cloudA,
        role: StableRole.member,
        status: MembershipStatus.active,
      ),
      links: links,
      accountRecords: records,
      online: true,
    );
    expect(result.localStableId, 'local-a');
    expect(result.records.map((record) => record.id), [
      'horse-local-1',
      'activity-local-2',
    ]);
    expect(result.selectedHorseId, 1);
  });

  test('missing explicit mapping yields an empty non-flashing context', () {
    final result = coordinator.switchContext(
      authUserId: userA,
      cloudStableId: 'cloud-unlinked',
      validatedMembership: const MembershipSnapshot(
        authUserId: userA,
        cloudStableId: 'cloud-unlinked',
        role: StableRole.viewer,
        status: MembershipStatus.active,
      ),
      links: links,
      accountRecords: records,
      online: true,
    );
    expect(result.records, isEmpty);
    expect(result.accessStatus, 'unlinked');
  });

  test('account A cannot consume account B local mapping', () {
    final result = coordinator.switchContext(
      authUserId: userA,
      cloudStableId: cloudA,
      validatedMembership: const MembershipSnapshot(
        authUserId: userB,
        cloudStableId: cloudA,
        role: StableRole.owner,
        status: MembershipStatus.active,
      ),
      links: links,
      accountRecords: records,
      online: true,
    );
    expect(result.records, isEmpty);
    expect(result.accessStatus, 'access_denied');
  });

  test('removed and suspended access clear the operational context', () {
    for (final status in [
      MembershipStatus.removed,
      MembershipStatus.suspended,
      MembershipStatus.left,
    ]) {
      final result = coordinator.switchContext(
        authUserId: userA,
        cloudStableId: cloudA,
        validatedMembership: MembershipSnapshot(
          authUserId: userA,
          cloudStableId: cloudA,
          role: StableRole.member,
          status: status,
        ),
        links: links,
        accountRecords: records,
        online: true,
      );
      expect(result.records, isEmpty);
      expect(result.readOnly, isTrue);
    }
  });

  test('offline authority is read-only and never switches working data', () {
    final result = coordinator.switchContext(
      authUserId: userA,
      cloudStableId: cloudA,
      validatedMembership: const MembershipSnapshot(
        authUserId: userA,
        cloudStableId: cloudA,
        role: StableRole.owner,
        status: MembershipStatus.active,
      ),
      links: links,
      accountRecords: records,
      online: false,
    );
    expect(result.records, isEmpty);
    expect(result.readOnly, isTrue);
    expect(result.accessStatus, 'offline_read_only');
  });

  test('role matrix preserves owner and admin boundaries', () {
    expect(canInviteRole(StableRole.owner, StableRole.admin), isTrue);
    expect(canInviteRole(StableRole.owner, StableRole.owner), isFalse);
    expect(canInviteRole(StableRole.admin, StableRole.admin), isFalse);
    expect(canInviteRole(StableRole.admin, StableRole.member), isTrue);
    expect(canInviteRole(StableRole.member, StableRole.viewer), isFalse);
    expect(
      canManageRole(StableRole.admin, StableRole.admin, StableRole.viewer),
      isFalse,
    );
    expect(
      canManageRole(StableRole.admin, StableRole.viewer, StableRole.member),
      isTrue,
    );
  });

  test('unlinked master plan preserves existing product master', () {
    const existing = AccountOperationalMaster(
      authUserId: userA,
      records: records,
      selectedHorseByLocalStable: {'local-a': 1, 'local-b': 3},
      legacyIds: ['legacy-1'],
      legacyBackup: 'legacy-backup',
    );
    const emptyCurrent = AccountOperationalMaster(
      authUserId: userA,
      records: [],
      selectedHorseByLocalStable: {},
      legacyIds: [],
      legacyBackup: '',
    );
    final plan = phase4BPlanOperationalMasterSave(
      current: emptyCurrent,
      existing: existing,
      currentLocalStableId: '',
      mergeLinkedScope: (_, current) => current,
    );
    expect(plan.kind, Phase4BMasterSaveKind.preserveUnlinked);
    expect(plan.shouldPersist, isFalse);
    expect(plan.master, same(existing));
  });

  test(
    'linked empty scope is a real persisted replacement for that stable',
    () {
      const existing = AccountOperationalMaster(
        authUserId: userA,
        records: records,
        selectedHorseByLocalStable: {'local-a': 1, 'local-b': 3},
        legacyIds: ['legacy-1'],
        legacyBackup: 'legacy-backup',
      );
      const emptyLinked = AccountOperationalMaster(
        authUserId: userA,
        records: [],
        selectedHorseByLocalStable: {'local-a': null},
        legacyIds: ['legacy-1'],
        legacyBackup: 'legacy-backup',
      );
      final plan = phase4BPlanOperationalMasterSave(
        current: emptyLinked,
        existing: existing,
        currentLocalStableId: 'local-a',
        mergeLinkedScope:
            (master, current) => AccountOperationalMaster(
              authUserId: userA,
              records: [
                ...master.records.where(
                  (record) => record.localStableId != 'local-a',
                ),
                ...current.records,
              ],
              selectedHorseByLocalStable: {
                ...master.selectedHorseByLocalStable,
                'local-a': null,
              },
              legacyIds: master.legacyIds,
              legacyBackup: master.legacyBackup,
            ),
      );
      expect(plan.kind, Phase4BMasterSaveKind.mergeLinked);
      expect(plan.shouldPersist, isTrue);
      expect(
        plan.master.records.map((record) => record.localStableId).toSet(),
        {'local-b'},
      );
      expect(plan.master.legacyBackup, 'legacy-backup');
    },
  );

  test('all three product routes share one full serialized merge contract', () {
    final stableAOld = _fullOperationalScope(
      authUserId: userA,
      localStableId: 'local-a',
      cloudStableId: cloudA,
      marker: 'a-old',
      counterBase: 10,
    );
    final stableB = _fullOperationalScope(
      authUserId: userA,
      localStableId: 'local-b',
      cloudStableId: cloudB,
      marker: 'b-keep',
      counterBase: 20,
    );
    final master = _combineStableScopes(stableAOld, stableB);
    final current = _fullOperationalScope(
      authUserId: userA,
      localStableId: 'local-a',
      cloudStableId: cloudA,
      marker: 'a-current',
      counterBase: 100,
    );

    final results = {
      for (final route in ['logout', 'account-switch', 'stable-switch'])
        route: _saveMapScope(current: current, existing: master).master,
    };
    expect(results['account-switch'], equals(results['logout']));
    expect(results['stable-switch'], equals(results['logout']));

    final saved = results['logout']!;
    for (final key in phase4BOperationalScopedCollectionKeys) {
      expect(
        (saved[key] as List).map((record) => (record as Map)['id']).toSet(),
        {'$key-a-current', '$key-b-keep'},
        reason: key,
      );
    }
    for (final key in [
      'selectedHorseIndex',
      'nextHorseId',
      'nextHorseIndex',
      'horseSeedVersion',
      'passportPrototypeVersion',
      'nextActivityId',
      'nextFeedingItemId',
      'nextTemporaryFeedingScheduleId',
      'nextFeedingAssignmentExceptionId',
      'nextFeedingExecutionRecordId',
      'schemaVersion',
      'updatedAt',
      'futureScalarField',
    ]) {
      expect(saved[key], current[key], reason: key);
    }
    expect(saved['legacyIds'], current['legacyIds']);
    expect(saved['legacyBackup'], current['legacyBackup']);
  });

  test('save reload preserves every counter and prevents ID reuse', () {
    final master = _fullOperationalScope(
      authUserId: userA,
      localStableId: 'local-a',
      cloudStableId: cloudA,
      marker: 'old',
      counterBase: 10,
    );
    final current = _fullOperationalScope(
      authUserId: userA,
      localStableId: 'local-a',
      cloudStableId: cloudA,
      marker: 'current',
      counterBase: 1000,
    );
    final serialized = _saveMapScope(current: current, existing: master).master;
    final reloaded = Map<String, dynamic>.from(serialized);

    for (final key in [
      'nextHorseId',
      'nextHorseIndex',
      'horseSeedVersion',
      'passportPrototypeVersion',
      'nextActivityId',
      'nextFeedingItemId',
      'nextTemporaryFeedingScheduleId',
      'nextFeedingAssignmentExceptionId',
      'nextFeedingExecutionRecordId',
      'schemaVersion',
    ]) {
      expect(reloaded[key], current[key], reason: key);
    }

    for (final key in [
      'nextHorseId',
      'nextActivityId',
      'nextFeedingItemId',
      'nextTemporaryFeedingScheduleId',
      'nextFeedingAssignmentExceptionId',
      'nextFeedingExecutionRecordId',
    ]) {
      final existingId = (current[key] as int) - 1;
      final firstCreatedId = reloaded[key] as int;
      final secondCreatedId = firstCreatedId + 1;
      expect(firstCreatedId, greaterThan(existingId), reason: key);
      expect(secondCreatedId, isNot(firstCreatedId), reason: key);
    }
  });

  test(
    'linked empty differs from unlinked preservation for every collection',
    () {
      final stableA = _fullOperationalScope(
        authUserId: userA,
        localStableId: 'local-a',
        cloudStableId: cloudA,
        marker: 'a',
        counterBase: 10,
      );
      final stableB = _fullOperationalScope(
        authUserId: userA,
        localStableId: 'local-b',
        cloudStableId: cloudB,
        marker: 'b',
        counterBase: 20,
      );
      final master = _combineStableScopes(stableA, stableB);
      final emptyLinked = _fullOperationalScope(
        authUserId: userA,
        localStableId: 'local-a',
        cloudStableId: cloudA,
        marker: 'empty',
        counterBase: 100,
      );
      for (final key in phase4BOperationalScopedCollectionKeys) {
        emptyLinked[key] = <Map<String, dynamic>>[];
      }
      final linkedPlan = _saveMapScope(current: emptyLinked, existing: master);
      expect(linkedPlan.shouldPersist, isTrue);
      for (final key in phase4BOperationalScopedCollectionKeys) {
        expect(
          (linkedPlan.master[key] as List).map(
            (record) => (record as Map)['id'],
          ),
          ['$key-b'],
          reason: key,
        );
      }

      final unlinked = Map<String, dynamic>.from(emptyLinked)
        ..['currentLocalStableId'] = '';
      final unlinkedPlan = _saveMapScope(current: unlinked, existing: master);
      expect(unlinkedPlan.shouldPersist, isFalse);
      expect(unlinkedPlan.master, same(master));
    },
  );

  test('cross-account and cloud-as-local merges fail closed', () {
    final master = _fullOperationalScope(
      authUserId: userA,
      localStableId: 'local-a',
      cloudStableId: cloudA,
      marker: 'master',
      counterBase: 10,
    );
    final crossAccount = _fullOperationalScope(
      authUserId: userB,
      localStableId: 'local-b',
      cloudStableId: cloudB,
      marker: 'cross',
      counterBase: 20,
    );
    expect(
      () => _saveMapScope(current: crossAccount, existing: master),
      throwsStateError,
    );

    final cloudAsLocal = _fullOperationalScope(
      authUserId: userA,
      localStableId: cloudA,
      cloudStableId: cloudA,
      marker: 'invalid',
      counterBase: 30,
    );
    expect(
      () => _saveMapScope(current: cloudAsLocal, existing: master),
      throwsStateError,
    );
    expect(
      () => _saveMapScope(current: cloudAsLocal, existing: null),
      throwsStateError,
    );
  });

  test(
    'logout account switch and stable switch persist identical masters',
    () async {
      Future<AccountOperationalMaster> saveThrough(String route) async {
        final store = _MemoryOperationalStore();
        store.values[userA] = const AccountOperationalMaster(
          authUserId: userA,
          records: [
            LocalOperationalRecord(id: 'a-old', localStableId: 'local-a'),
            LocalOperationalRecord(id: 'b-keep', localStableId: 'local-b'),
          ],
          selectedHorseByLocalStable: {'local-a': 1, 'local-b': 2},
          legacyIds: ['legacy-a'],
          legacyBackup: 'backup-a',
          currentLocalStableId: 'local-b',
          selectedCloudStableId: cloudB,
          nextHorseId: 10,
          nextHorseIndex: 11,
          horseSeedVersion: 12,
          passportPrototypeVersion: 13,
          nextActivityId: 14,
          nextFeedingItemId: 15,
          nextTemporaryFeedingScheduleId: 16,
          nextFeedingAssignmentExceptionId: 17,
          nextFeedingExecutionRecordId: 18,
          schemaVersion: 19,
        );
        store.values[userB] = const AccountOperationalMaster(
          authUserId: userB,
          records: [
            LocalOperationalRecord(id: 'account-b', localStableId: 'local-b'),
          ],
          selectedHorseByLocalStable: {'local-b': 9},
          legacyIds: ['legacy-b'],
          legacyBackup: 'backup-b',
          currentLocalStableId: 'local-b',
        );
        final session = StableContextSession(store: store)..seed(
          accountId: userA,
          cloudId: cloudA,
          localStableId: 'local-a',
          operationalRecords: const [
            LocalOperationalRecord(id: 'a-current', localStableId: 'local-a'),
          ],
          horseId: 101,
          nextHorseId: 102,
          nextHorseIndex: 103,
          horseSeedVersion: 104,
          passportPrototypeVersion: 105,
          nextActivityId: 106,
          nextFeedingItemId: 107,
          nextTemporaryFeedingScheduleId: 108,
          nextFeedingAssignmentExceptionId: 109,
          nextFeedingExecutionRecordId: 110,
          schemaVersion: 111,
        );
        switch (route) {
          case 'logout':
            session.logout();
            break;
          case 'account-switch':
            expect(
              await session.switchTo(
                targetAuthUserId: userB,
                targetCloudStableId: cloudA,
                membership: const MembershipSnapshot(
                  authUserId: userB,
                  cloudStableId: cloudA,
                  role: StableRole.member,
                  status: MembershipStatus.active,
                ),
                links: links,
              ),
              isTrue,
            );
            break;
          case 'stable-switch':
            expect(
              await session.switchTo(
                targetAuthUserId: userA,
                targetCloudStableId: cloudB,
                membership: const MembershipSnapshot(
                  authUserId: userA,
                  cloudStableId: cloudB,
                  role: StableRole.member,
                  status: MembershipStatus.active,
                ),
                links: links,
              ),
              isTrue,
            );
            break;
          default:
            fail('Unknown route: $route');
        }
        return store.values[userA]!;
      }

      final logout = await saveThrough('logout');
      final accountSwitch = await saveThrough('account-switch');
      final stableSwitch = await saveThrough('stable-switch');
      expect(
        accountSwitch.toSerializableMap(),
        equals(logout.toSerializableMap()),
      );
      expect(
        stableSwitch.toSerializableMap(),
        equals(logout.toSerializableMap()),
      );
      expect(logout.records.map((record) => record.id).toSet(), {
        'a-current',
        'b-keep',
      });
      expect(logout.legacyIds, ['legacy-a']);
      expect(logout.legacyBackup, 'backup-a');
    },
  );

  test(
    'logout login reloads counters and allocates collision-free IDs',
    () async {
      final store = _MemoryOperationalStore();
      final session = StableContextSession(store: store)..seed(
        accountId: userA,
        cloudId: cloudA,
        localStableId: 'local-a',
        operationalRecords: const [
          LocalOperationalRecord(id: 'existing-499', localStableId: 'local-a'),
        ],
        horseId: 499,
        nextHorseId: 500,
        nextHorseIndex: 501,
        horseSeedVersion: 502,
        passportPrototypeVersion: 503,
        nextActivityId: 504,
        nextFeedingItemId: 505,
        nextTemporaryFeedingScheduleId: 506,
        nextFeedingAssignmentExceptionId: 507,
        nextFeedingExecutionRecordId: 508,
        schemaVersion: 509,
      );
      session.logout();

      final reloaded = StableContextSession(store: store);
      expect(
        await reloaded.switchTo(
          targetAuthUserId: userA,
          targetCloudStableId: cloudA,
          membership: const MembershipSnapshot(
            authUserId: userA,
            cloudStableId: cloudA,
            role: StableRole.owner,
            status: MembershipStatus.active,
          ),
          links: links,
        ),
        isTrue,
      );
      expect(reloaded.nextHorseId, 500);
      expect(reloaded.nextHorseIndex, 501);
      expect(reloaded.horseSeedVersion, 502);
      expect(reloaded.passportPrototypeVersion, 503);
      expect(reloaded.nextActivityId, 504);
      expect(reloaded.nextFeedingItemId, 505);
      expect(reloaded.nextTemporaryFeedingScheduleId, 506);
      expect(reloaded.nextFeedingAssignmentExceptionId, 507);
      expect(reloaded.nextFeedingExecutionRecordId, 508);
      expect(reloaded.schemaVersion, 509);

      for (final firstId in [
        reloaded.nextHorseId,
        reloaded.nextActivityId,
        reloaded.nextFeedingItemId,
        reloaded.nextTemporaryFeedingScheduleId,
        reloaded.nextFeedingAssignmentExceptionId,
        reloaded.nextFeedingExecutionRecordId,
      ]) {
        expect(firstId, isNot(499));
        expect(firstId + 1, isNot(firstId));
      }
    },
  );

  test('save failures block logout stable switch and account switch', () async {
    StableContextSession failingSession() => StableContextSession(
      store: _MemoryOperationalStore()..failWrites = true,
    )..seed(
      accountId: userA,
      cloudId: cloudA,
      localStableId: 'local-a',
      operationalRecords: records,
      horseId: 1,
    );

    final logout = failingSession();
    expect(logout.logout, throwsStateError);
    expect(logout.authUserId, userA);
    expect(logout.currentLocalStableId, 'local-a');
    expect(logout.records, records);

    for (final targetAccount in [userA, userB]) {
      final switching = failingSession();
      expect(
        await switching.switchTo(
          targetAuthUserId: targetAccount,
          targetCloudStableId: cloudB,
          membership: MembershipSnapshot(
            authUserId: targetAccount,
            cloudStableId: cloudB,
            role: StableRole.member,
            status: MembershipStatus.active,
          ),
          links: links,
        ),
        isFalse,
      );
      expect(switching.authUserId, userA);
      expect(switching.cloudStableId, cloudA);
      expect(switching.currentLocalStableId, 'local-a');
      expect(switching.records, records);
      expect(switching.accessStatus, 'storage_error');
    }
  });

  test('unlinked logout avoids storage writes and preserves master', () {
    final store = _MemoryOperationalStore()..failWrites = true;
    const master = AccountOperationalMaster(
      authUserId: userA,
      records: records,
      selectedHorseByLocalStable: {'local-a': 1, 'local-b': 3},
      legacyIds: ['legacy'],
      legacyBackup: 'backup',
      currentLocalStableId: 'local-a',
      nextHorseId: 42,
    );
    store.values[userA] = master;
    final session = StableContextSession(store: store)..seed(
      accountId: userA,
      cloudId: 'cloud-unlinked',
      localStableId: '',
      operationalRecords: const [],
      horseId: null,
    );
    session.logout();
    expect(store.values[userA], same(master));
    expect(session.accessStatus, 'signed_out');
  });

  test('member route passes second member into a fresh detail runtime', () {
    final listRuntime = Phase4BMemberSelectionCoordinator(
      requireExplicitSelection: false,
    );
    final route = listRuntime.detailRoute('member-a2');
    expect(route.pageName, 'StableMemberDetailsPage');
    expect(route.parameters, {'stableMemberId': 'member-a2'});

    final detailRuntime = Phase4BMemberSelectionCoordinator(
      initialStableMemberId: route.parameters['stableMemberId']!,
      requireExplicitSelection: true,
    );
    detailRuntime.resolve(
      selectedStableId: 'stable-a',
      candidates: const [
        Phase4BMemberCandidate(
          stableId: 'stable-a',
          stableMemberId: 'member-a1',
        ),
        Phase4BMemberCandidate(
          stableId: 'stable-a',
          stableMemberId: 'member-a2',
        ),
        Phase4BMemberCandidate(
          stableId: 'stable-a',
          stableMemberId: 'member-a3',
        ),
      ],
    );
    expect(detailRuntime.selectedStableMemberId, 'member-a2');
    expect(detailRuntime.error, isEmpty);
  });

  test('member detail fails closed for unknown and cross-stable IDs', () {
    const candidates = [
      Phase4BMemberCandidate(stableId: 'stable-a', stableMemberId: 'member-a1'),
      Phase4BMemberCandidate(stableId: 'stable-b', stableMemberId: 'member-b1'),
    ];
    for (final invalidId in ['unknown', 'member-b1']) {
      final detailRuntime = Phase4BMemberSelectionCoordinator(
        initialStableMemberId: invalidId,
        requireExplicitSelection: true,
      );
      detailRuntime.resolve(
        selectedStableId: 'stable-a',
        candidates: candidates,
      );
      expect(detailRuntime.selectedStableMemberId, isEmpty);
      expect(detailRuntime.error, 'member_not_found');
    }
  });

  test('changes survive repeated A to B to A switches', () async {
    final store = _MemoryOperationalStore();
    store.values[userA] = const AccountOperationalMaster(
      authUserId: userA,
      records: [
        LocalOperationalRecord(id: 'a-original', localStableId: 'local-a'),
        LocalOperationalRecord(id: 'b-original', localStableId: 'local-b'),
      ],
      selectedHorseByLocalStable: {'local-a': 1, 'local-b': 3},
      legacyIds: ['legacy-horse-1'],
      legacyBackup: 'backup-preserved',
    );
    final session = StableContextSession(store: store)..seed(
      accountId: userA,
      cloudId: cloudA,
      localStableId: 'local-a',
      operationalRecords: const [
        LocalOperationalRecord(id: 'a-changed-1', localStableId: 'local-a'),
      ],
      horseId: 11,
    );
    expect(
      await session.switchTo(
        targetAuthUserId: userA,
        targetCloudStableId: cloudB,
        membership: const MembershipSnapshot(
          authUserId: userA,
          cloudStableId: cloudB,
          role: StableRole.member,
          status: MembershipStatus.active,
        ),
        links: links,
      ),
      isTrue,
    );
    session.records = const [
      LocalOperationalRecord(id: 'b-changed-1', localStableId: 'local-b'),
      LocalOperationalRecord(id: 'b-changed-2', localStableId: 'local-b'),
    ];
    session.selectedHorseId = 33;
    await session.switchTo(
      targetAuthUserId: userA,
      targetCloudStableId: cloudA,
      membership: const MembershipSnapshot(
        authUserId: userA,
        cloudStableId: cloudA,
        role: StableRole.member,
        status: MembershipStatus.active,
      ),
      links: links,
    );
    expect(session.records.map((record) => record.id), ['a-changed-1']);
    expect(session.selectedHorseId, 11);
    session.records = const [
      LocalOperationalRecord(id: 'a-changed-2', localStableId: 'local-a'),
    ];
    await session.switchTo(
      targetAuthUserId: userA,
      targetCloudStableId: cloudB,
      membership: const MembershipSnapshot(
        authUserId: userA,
        cloudStableId: cloudB,
        role: StableRole.viewer,
        status: MembershipStatus.active,
      ),
      links: links,
    );
    expect(session.records.map((record) => record.id), [
      'b-changed-1',
      'b-changed-2',
    ]);
    expect(session.selectedHorseId, 33);
    expect(store.values[userA]!.legacyIds, ['legacy-horse-1']);
    expect(store.values[userA]!.legacyBackup, 'backup-preserved');
  });

  test(
    'unlinked target is completely empty including local stable ID',
    () async {
      final store = _MemoryOperationalStore();
      final session = StableContextSession(store: store)..seed(
        accountId: userA,
        cloudId: cloudA,
        localStableId: 'local-a',
        operationalRecords: records,
        horseId: 1,
      );
      await session.switchTo(
        targetAuthUserId: userA,
        targetCloudStableId: 'unlinked-cloud',
        membership: const MembershipSnapshot(
          authUserId: userA,
          cloudStableId: 'unlinked-cloud',
          role: StableRole.owner,
          status: MembershipStatus.active,
        ),
        links: links,
      );
      expect(session.currentLocalStableId, isEmpty);
      expect(session.records, isEmpty);
      expect(session.selectedHorseId, isNull);
      expect(session.accessStatus, 'unlinked');
    },
  );

  test('account A and B masters remain isolated across switches', () async {
    final store = _MemoryOperationalStore();
    store.values[userB] = const AccountOperationalMaster(
      authUserId: userB,
      records: [
        LocalOperationalRecord(
          id: 'b-account-record',
          localStableId: 'local-b',
        ),
      ],
      selectedHorseByLocalStable: {'local-b': 9},
      legacyIds: [],
      legacyBackup: '',
    );
    final session = StableContextSession(store: store)..seed(
      accountId: userA,
      cloudId: cloudA,
      localStableId: 'local-a',
      operationalRecords: const [
        LocalOperationalRecord(
          id: 'a-account-record',
          localStableId: 'local-a',
        ),
      ],
      horseId: 1,
    );
    await session.switchTo(
      targetAuthUserId: userB,
      targetCloudStableId: cloudA,
      membership: const MembershipSnapshot(
        authUserId: userB,
        cloudStableId: cloudA,
        role: StableRole.member,
        status: MembershipStatus.active,
      ),
      links: links,
    );
    expect(session.records.map((record) => record.id), ['b-account-record']);
    await session.switchTo(
      targetAuthUserId: userA,
      targetCloudStableId: cloudA,
      membership: const MembershipSnapshot(
        authUserId: userA,
        cloudStableId: cloudA,
        role: StableRole.member,
        status: MembershipStatus.active,
      ),
      links: links,
    );
    expect(session.records.map((record) => record.id), ['a-account-record']);
  });

  test('storage failure stops switch without exposing target data', () async {
    final store = _MemoryOperationalStore()..failWrites = true;
    final session = StableContextSession(store: store)..seed(
      accountId: userA,
      cloudId: cloudA,
      localStableId: 'local-a',
      operationalRecords: records,
      horseId: 1,
    );
    expect(
      await session.switchTo(
        targetAuthUserId: userA,
        targetCloudStableId: cloudB,
        membership: const MembershipSnapshot(
          authUserId: userA,
          cloudStableId: cloudB,
          role: StableRole.owner,
          status: MembershipStatus.active,
        ),
        links: links,
      ),
      isFalse,
    );
    expect(session.cloudStableId, cloudA);
    expect(session.currentLocalStableId, 'local-a');
    expect(session.accessStatus, 'storage_error');
  });

  test('removed and suspended switches clear every active reference', () async {
    for (final status in [
      MembershipStatus.removed,
      MembershipStatus.suspended,
      MembershipStatus.left,
    ]) {
      final session = StableContextSession(store: _MemoryOperationalStore())
        ..seed(
          accountId: userA,
          cloudId: cloudA,
          localStableId: 'local-a',
          operationalRecords: records,
          horseId: 1,
        );
      expect(
        await session.switchTo(
          targetAuthUserId: userA,
          targetCloudStableId: cloudB,
          membership: MembershipSnapshot(
            authUserId: userA,
            cloudStableId: cloudB,
            role: StableRole.member,
            status: status,
          ),
          links: links,
        ),
        isFalse,
      );
      expect(session.currentLocalStableId, isEmpty);
      expect(session.records, isEmpty);
      expect(session.selectedHorseId, isNull);
    }
  });

  test('logout stores current edits and clears the full context', () {
    final store = _MemoryOperationalStore();
    final session = StableContextSession(store: store)..seed(
      accountId: userA,
      cloudId: cloudA,
      localStableId: 'local-a',
      operationalRecords: const [
        LocalOperationalRecord(id: 'saved-at-logout', localStableId: 'local-a'),
      ],
      horseId: 7,
    );
    session.logout();
    expect(store.values[userA]!.records.single.id, 'saved-at-logout');
    expect(session.authUserId, isEmpty);
    expect(session.currentLocalStableId, isEmpty);
    expect(session.records, isEmpty);
    expect(session.accessStatus, 'signed_out');
  });

  test(
    'linked to unlinked logout preserves both account master scopes',
    () async {
      final store = _MemoryOperationalStore();
      store.values[userA] = const AccountOperationalMaster(
        authUserId: userA,
        records: [
          LocalOperationalRecord(id: 'a-master', localStableId: 'local-a'),
          LocalOperationalRecord(id: 'b-master', localStableId: 'local-b'),
        ],
        selectedHorseByLocalStable: {'local-a': 1, 'local-b': 3},
        legacyIds: ['legacy-a'],
        legacyBackup: 'legacy-backup-a',
      );
      final session = StableContextSession(store: store)..seed(
        accountId: userA,
        cloudId: cloudA,
        localStableId: 'local-a',
        operationalRecords: const [
          LocalOperationalRecord(id: 'a-latest', localStableId: 'local-a'),
        ],
        horseId: 11,
      );
      await session.switchTo(
        targetAuthUserId: userA,
        targetCloudStableId: 'cloud-unlinked',
        membership: const MembershipSnapshot(
          authUserId: userA,
          cloudStableId: 'cloud-unlinked',
          role: StableRole.member,
          status: MembershipStatus.active,
        ),
        links: links,
      );
      expect(session.currentLocalStableId, isEmpty);
      expect(session.records, isEmpty);
      expect(session.selectedHorseId, isNull);
      session.logout();

      final preserved = store.values[userA]!;
      expect(preserved.records.map((record) => record.id).toSet(), {
        'a-latest',
        'b-master',
      });
      expect(preserved.selectedHorseByLocalStable, {
        'local-a': 11,
        'local-b': 3,
      });
      expect(preserved.legacyIds, ['legacy-a']);
      expect(preserved.legacyBackup, 'legacy-backup-a');

      final relogged = StableContextSession(store: store);
      await relogged.switchTo(
        targetAuthUserId: userA,
        targetCloudStableId: cloudA,
        membership: const MembershipSnapshot(
          authUserId: userA,
          cloudStableId: cloudA,
          role: StableRole.member,
          status: MembershipStatus.active,
        ),
        links: links,
      );
      expect(relogged.records.single.id, 'a-latest');
      await relogged.switchTo(
        targetAuthUserId: userA,
        targetCloudStableId: cloudB,
        membership: const MembershipSnapshot(
          authUserId: userA,
          cloudStableId: cloudB,
          role: StableRole.member,
          status: MembershipStatus.active,
        ),
        links: links,
      );
      expect(relogged.records.single.id, 'b-master');
    },
  );

  test(
    'unlinked account switch preserves A and never flashes A into B',
    () async {
      final store = _MemoryOperationalStore();
      store.values[userA] = const AccountOperationalMaster(
        authUserId: userA,
        records: [
          LocalOperationalRecord(id: 'a-one', localStableId: 'local-a'),
          LocalOperationalRecord(id: 'a-two', localStableId: 'local-b'),
        ],
        selectedHorseByLocalStable: {'local-a': 1, 'local-b': 2},
        legacyIds: ['legacy-a'],
        legacyBackup: 'backup-a',
      );
      store.values[userB] = const AccountOperationalMaster(
        authUserId: userB,
        records: [
          LocalOperationalRecord(id: 'b-only', localStableId: 'local-b'),
        ],
        selectedHorseByLocalStable: {'local-b': 9},
        legacyIds: ['legacy-b'],
        legacyBackup: 'backup-b',
      );
      final session = StableContextSession(store: store)..seed(
        accountId: userA,
        cloudId: cloudA,
        localStableId: 'local-a',
        operationalRecords: const [
          LocalOperationalRecord(id: 'a-latest', localStableId: 'local-a'),
        ],
        horseId: 7,
      );
      await session.switchTo(
        targetAuthUserId: userA,
        targetCloudStableId: 'cloud-unlinked',
        membership: const MembershipSnapshot(
          authUserId: userA,
          cloudStableId: 'cloud-unlinked',
          role: StableRole.viewer,
          status: MembershipStatus.active,
        ),
        links: links,
      );
      expect(session.records, isEmpty);
      await session.switchTo(
        targetAuthUserId: userB,
        targetCloudStableId: cloudA,
        membership: const MembershipSnapshot(
          authUserId: userB,
          cloudStableId: cloudA,
          role: StableRole.member,
          status: MembershipStatus.active,
        ),
        links: links,
      );
      expect(session.records.map((record) => record.id), ['b-only']);
      expect(
        session.records.any((record) => record.id.startsWith('a-')),
        isFalse,
      );
      expect(store.values[userA]!.records.map((record) => record.id).toSet(), {
        'a-latest',
        'a-two',
      });
      expect(store.values[userB]!.legacyBackup, 'backup-b');
    },
  );

  test(
    'repeated linked unlinked account switches retain every account scope',
    () async {
      final store = _MemoryOperationalStore();
      store.values[userA] = const AccountOperationalMaster(
        authUserId: userA,
        records: [
          LocalOperationalRecord(id: 'a-a', localStableId: 'local-a'),
          LocalOperationalRecord(id: 'a-b', localStableId: 'local-b'),
        ],
        selectedHorseByLocalStable: {'local-a': 1, 'local-b': 3},
        legacyIds: [],
        legacyBackup: 'backup-a',
      );
      store.values[userB] = const AccountOperationalMaster(
        authUserId: userB,
        records: [LocalOperationalRecord(id: 'b-b', localStableId: 'local-b')],
        selectedHorseByLocalStable: {'local-b': 8},
        legacyIds: [],
        legacyBackup: 'backup-b',
      );
      final session = StableContextSession(store: store)..seed(
        accountId: userA,
        cloudId: cloudA,
        localStableId: 'local-a',
        operationalRecords: const [
          LocalOperationalRecord(id: 'a-a-v2', localStableId: 'local-a'),
        ],
        horseId: 2,
      );
      for (var index = 0; index < 3; index++) {
        await session.switchTo(
          targetAuthUserId: userA,
          targetCloudStableId: 'cloud-unlinked',
          membership: const MembershipSnapshot(
            authUserId: userA,
            cloudStableId: 'cloud-unlinked',
            role: StableRole.viewer,
            status: MembershipStatus.active,
          ),
          links: links,
        );
        await session.switchTo(
          targetAuthUserId: userB,
          targetCloudStableId: cloudA,
          membership: const MembershipSnapshot(
            authUserId: userB,
            cloudStableId: cloudA,
            role: StableRole.member,
            status: MembershipStatus.active,
          ),
          links: links,
        );
        await session.switchTo(
          targetAuthUserId: userA,
          targetCloudStableId: cloudA,
          membership: const MembershipSnapshot(
            authUserId: userA,
            cloudStableId: cloudA,
            role: StableRole.member,
            status: MembershipStatus.active,
          ),
          links: links,
        );
      }
      expect(session.records.single.id, 'a-a-v2');
      expect(store.values[userA]!.records.map((record) => record.id).toSet(), {
        'a-a-v2',
        'a-b',
      });
      expect(store.values[userB]!.records.single.id, 'b-b');
    },
  );

  test('linked empty working set persists while other stable survives', () {
    final store = _MemoryOperationalStore();
    store.values[userA] = const AccountOperationalMaster(
      authUserId: userA,
      records: [
        LocalOperationalRecord(id: 'remove-me', localStableId: 'local-a'),
        LocalOperationalRecord(id: 'keep-me', localStableId: 'local-b'),
      ],
      selectedHorseByLocalStable: {'local-a': 1, 'local-b': 3},
      legacyIds: ['legacy'],
      legacyBackup: 'backup',
    );
    final session = StableContextSession(store: store)..seed(
      accountId: userA,
      cloudId: cloudA,
      localStableId: 'local-a',
      operationalRecords: const [],
      horseId: null,
    );
    session.logout();
    expect(store.values[userA]!.records.single.id, 'keep-me');
    expect(store.values[userA]!.selectedHorseByLocalStable['local-a'], isNull);
    expect(store.values[userA]!.legacyBackup, 'backup');
  });

  test('third member route never falls back to first across refresh', () {
    const candidates = [
      Phase4BMemberCandidate(stableId: 'stable-a', stableMemberId: 'member-a1'),
      Phase4BMemberCandidate(stableId: 'stable-a', stableMemberId: 'member-a2'),
      Phase4BMemberCandidate(stableId: 'stable-a', stableMemberId: 'member-a3'),
    ];
    final listRuntime = Phase4BMemberSelectionCoordinator(
      requireExplicitSelection: false,
    );
    final route = listRuntime.detailRoute('member-a3');
    final detailRuntime = Phase4BMemberSelectionCoordinator(
      initialStableMemberId: route.stableMemberId,
      requireExplicitSelection: true,
    );
    expect(detailRuntime.intendedStableMemberId, 'member-a3');
    detailRuntime.resolve(
      selectedStableId: 'stable-a',
      candidates: candidates.reversed.toList(),
    );
    expect(detailRuntime.selectedStableMemberId, 'member-a3');
    detailRuntime.resolve(selectedStableId: 'stable-a', candidates: candidates);
    expect(detailRuntime.selectedStableMemberId, 'member-a3');
    expect(detailRuntime.error, isEmpty);
  });
}

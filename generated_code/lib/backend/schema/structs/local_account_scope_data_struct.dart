// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// Account-scoped snapshot of existing local prototype state; stable and
/// operational user identifiers remain unchanged.
class LocalAccountScopeDataStruct extends BaseStruct {
  LocalAccountScopeDataStruct({
    /// Immutable Supabase Auth UUID that owns this local namespace.
    String? authUserId,

    /// Account-scoped local horse records.
    List<HorseProfileDataStruct>? horses,

    /// Account-scoped currently selected horse.
    HorseProfileDataStruct? selectedHorse,

    /// Account-scoped selected horse index.
    int? selectedHorseIndex,

    /// Existing monotonic local horse ID source.
    int? nextHorseId,

    /// Existing local horse ordering source.
    int? nextHorseIndex,

    /// Legacy sample-seed guard retained per account.
    int? horseSeedVersion,

    /// Legacy passport migration guard retained per account.
    int? passportPrototypeVersion,

    /// Account-scoped local Planning activities.
    List<ActivityDataStruct>? activities,

    /// Existing monotonic local activity ID source.
    int? nextActivityId,

    /// Legacy Phase 1–3 operational performer ID; never rewritten to the auth
    /// UUID.
    String? currentLocalUserId,

    /// Selected legacy local stable identifier.
    String? currentLocalStableId,

    /// Account-scoped Phase 1 standard feeding plans.
    List<HorseFeedingPlanDataStruct>? horseFeedingPlans,

    /// Account-scoped Phase 1 temporary feeding plans.
    List<TemporaryFeedingScheduleDataStruct>? temporaryFeedingSchedules,

    /// Existing monotonic feeding-item ID source.
    int? nextFeedingItemId,

    /// Existing monotonic temporary-plan ID source.
    int? nextTemporaryFeedingScheduleId,

    /// Account-scoped Phase 2 round settings.
    List<FeedingRoundConfigDataStruct>? feedingRoundConfigs,

    /// Account-scoped Phase 2 assignment exceptions.
    List<FeedingAssignmentExceptionDataStruct>? feedingAssignmentExceptions,

    /// Account-scoped immutable feeding history.
    List<FeedingExecutionRecordDataStruct>? feedingExecutionRecords,

    /// Existing monotonic assignment-exception ID source.
    int? nextFeedingAssignmentExceptionId,

    /// Existing monotonic execution-record ID source.
    int? nextFeedingExecutionRecordId,

    /// Additive local account-scope schema version.
    int? schemaVersion,

    /// Local snapshot update timestamp.
    DateTime? updatedAt,

    /// Last selected cloud stable UUID; never overwrites currentLocalStableId.
    String? selectedCloudStableId,

    /// Explicit local-to-cloud stable mappings for this account scope.
    List<LocalStableCloudLinkDataStruct>? localStableCloudLinks,

    /// Read-only last-validated membership cache for this account scope.
    List<StableMembershipCacheDataStruct>? stableMembershipCaches,
  })  : _authUserId = authUserId,
        _horses = horses,
        _selectedHorse = selectedHorse,
        _selectedHorseIndex = selectedHorseIndex,
        _nextHorseId = nextHorseId,
        _nextHorseIndex = nextHorseIndex,
        _horseSeedVersion = horseSeedVersion,
        _passportPrototypeVersion = passportPrototypeVersion,
        _activities = activities,
        _nextActivityId = nextActivityId,
        _currentLocalUserId = currentLocalUserId,
        _currentLocalStableId = currentLocalStableId,
        _horseFeedingPlans = horseFeedingPlans,
        _temporaryFeedingSchedules = temporaryFeedingSchedules,
        _nextFeedingItemId = nextFeedingItemId,
        _nextTemporaryFeedingScheduleId = nextTemporaryFeedingScheduleId,
        _feedingRoundConfigs = feedingRoundConfigs,
        _feedingAssignmentExceptions = feedingAssignmentExceptions,
        _feedingExecutionRecords = feedingExecutionRecords,
        _nextFeedingAssignmentExceptionId = nextFeedingAssignmentExceptionId,
        _nextFeedingExecutionRecordId = nextFeedingExecutionRecordId,
        _schemaVersion = schemaVersion,
        _updatedAt = updatedAt,
        _selectedCloudStableId = selectedCloudStableId,
        _localStableCloudLinks = localStableCloudLinks,
        _stableMembershipCaches = stableMembershipCaches;

  // "authUserId" field.
  String? _authUserId;
  String get authUserId => _authUserId ?? '';
  set authUserId(String? val) => _authUserId = val;

  bool hasAuthUserId() => _authUserId != null;

  // "horses" field.
  List<HorseProfileDataStruct>? _horses;
  List<HorseProfileDataStruct> get horses => _horses ?? const [];
  set horses(List<HorseProfileDataStruct>? val) => _horses = val;

  void updateHorses(Function(List<HorseProfileDataStruct>) updateFn) {
    updateFn(_horses ??= []);
  }

  bool hasHorses() => _horses != null;

  // "selectedHorse" field.
  HorseProfileDataStruct? _selectedHorse;
  HorseProfileDataStruct get selectedHorse =>
      _selectedHorse ?? HorseProfileDataStruct();
  set selectedHorse(HorseProfileDataStruct? val) => _selectedHorse = val;

  void updateSelectedHorse(Function(HorseProfileDataStruct) updateFn) {
    updateFn(_selectedHorse ??= HorseProfileDataStruct());
  }

  bool hasSelectedHorse() => _selectedHorse != null;

  // "selectedHorseIndex" field.
  int? _selectedHorseIndex;
  int get selectedHorseIndex => _selectedHorseIndex ?? 0;
  set selectedHorseIndex(int? val) => _selectedHorseIndex = val;

  void incrementSelectedHorseIndex(int amount) =>
      selectedHorseIndex = selectedHorseIndex + amount;

  bool hasSelectedHorseIndex() => _selectedHorseIndex != null;

  // "nextHorseId" field.
  int? _nextHorseId;
  int get nextHorseId => _nextHorseId ?? 0;
  set nextHorseId(int? val) => _nextHorseId = val;

  void incrementNextHorseId(int amount) => nextHorseId = nextHorseId + amount;

  bool hasNextHorseId() => _nextHorseId != null;

  // "nextHorseIndex" field.
  int? _nextHorseIndex;
  int get nextHorseIndex => _nextHorseIndex ?? 0;
  set nextHorseIndex(int? val) => _nextHorseIndex = val;

  void incrementNextHorseIndex(int amount) =>
      nextHorseIndex = nextHorseIndex + amount;

  bool hasNextHorseIndex() => _nextHorseIndex != null;

  // "horseSeedVersion" field.
  int? _horseSeedVersion;
  int get horseSeedVersion => _horseSeedVersion ?? 0;
  set horseSeedVersion(int? val) => _horseSeedVersion = val;

  void incrementHorseSeedVersion(int amount) =>
      horseSeedVersion = horseSeedVersion + amount;

  bool hasHorseSeedVersion() => _horseSeedVersion != null;

  // "passportPrototypeVersion" field.
  int? _passportPrototypeVersion;
  int get passportPrototypeVersion => _passportPrototypeVersion ?? 0;
  set passportPrototypeVersion(int? val) => _passportPrototypeVersion = val;

  void incrementPassportPrototypeVersion(int amount) =>
      passportPrototypeVersion = passportPrototypeVersion + amount;

  bool hasPassportPrototypeVersion() => _passportPrototypeVersion != null;

  // "activities" field.
  List<ActivityDataStruct>? _activities;
  List<ActivityDataStruct> get activities => _activities ?? const [];
  set activities(List<ActivityDataStruct>? val) => _activities = val;

  void updateActivities(Function(List<ActivityDataStruct>) updateFn) {
    updateFn(_activities ??= []);
  }

  bool hasActivities() => _activities != null;

  // "nextActivityId" field.
  int? _nextActivityId;
  int get nextActivityId => _nextActivityId ?? 0;
  set nextActivityId(int? val) => _nextActivityId = val;

  void incrementNextActivityId(int amount) =>
      nextActivityId = nextActivityId + amount;

  bool hasNextActivityId() => _nextActivityId != null;

  // "currentLocalUserId" field.
  String? _currentLocalUserId;
  String get currentLocalUserId => _currentLocalUserId ?? '';
  set currentLocalUserId(String? val) => _currentLocalUserId = val;

  bool hasCurrentLocalUserId() => _currentLocalUserId != null;

  // "currentLocalStableId" field.
  String? _currentLocalStableId;
  String get currentLocalStableId => _currentLocalStableId ?? '';
  set currentLocalStableId(String? val) => _currentLocalStableId = val;

  bool hasCurrentLocalStableId() => _currentLocalStableId != null;

  // "horseFeedingPlans" field.
  List<HorseFeedingPlanDataStruct>? _horseFeedingPlans;
  List<HorseFeedingPlanDataStruct> get horseFeedingPlans =>
      _horseFeedingPlans ?? const [];
  set horseFeedingPlans(List<HorseFeedingPlanDataStruct>? val) =>
      _horseFeedingPlans = val;

  void updateHorseFeedingPlans(
      Function(List<HorseFeedingPlanDataStruct>) updateFn) {
    updateFn(_horseFeedingPlans ??= []);
  }

  bool hasHorseFeedingPlans() => _horseFeedingPlans != null;

  // "temporaryFeedingSchedules" field.
  List<TemporaryFeedingScheduleDataStruct>? _temporaryFeedingSchedules;
  List<TemporaryFeedingScheduleDataStruct> get temporaryFeedingSchedules =>
      _temporaryFeedingSchedules ?? const [];
  set temporaryFeedingSchedules(
          List<TemporaryFeedingScheduleDataStruct>? val) =>
      _temporaryFeedingSchedules = val;

  void updateTemporaryFeedingSchedules(
      Function(List<TemporaryFeedingScheduleDataStruct>) updateFn) {
    updateFn(_temporaryFeedingSchedules ??= []);
  }

  bool hasTemporaryFeedingSchedules() => _temporaryFeedingSchedules != null;

  // "nextFeedingItemId" field.
  int? _nextFeedingItemId;
  int get nextFeedingItemId => _nextFeedingItemId ?? 0;
  set nextFeedingItemId(int? val) => _nextFeedingItemId = val;

  void incrementNextFeedingItemId(int amount) =>
      nextFeedingItemId = nextFeedingItemId + amount;

  bool hasNextFeedingItemId() => _nextFeedingItemId != null;

  // "nextTemporaryFeedingScheduleId" field.
  int? _nextTemporaryFeedingScheduleId;
  int get nextTemporaryFeedingScheduleId =>
      _nextTemporaryFeedingScheduleId ?? 0;
  set nextTemporaryFeedingScheduleId(int? val) =>
      _nextTemporaryFeedingScheduleId = val;

  void incrementNextTemporaryFeedingScheduleId(int amount) =>
      nextTemporaryFeedingScheduleId = nextTemporaryFeedingScheduleId + amount;

  bool hasNextTemporaryFeedingScheduleId() =>
      _nextTemporaryFeedingScheduleId != null;

  // "feedingRoundConfigs" field.
  List<FeedingRoundConfigDataStruct>? _feedingRoundConfigs;
  List<FeedingRoundConfigDataStruct> get feedingRoundConfigs =>
      _feedingRoundConfigs ?? const [];
  set feedingRoundConfigs(List<FeedingRoundConfigDataStruct>? val) =>
      _feedingRoundConfigs = val;

  void updateFeedingRoundConfigs(
      Function(List<FeedingRoundConfigDataStruct>) updateFn) {
    updateFn(_feedingRoundConfigs ??= []);
  }

  bool hasFeedingRoundConfigs() => _feedingRoundConfigs != null;

  // "feedingAssignmentExceptions" field.
  List<FeedingAssignmentExceptionDataStruct>? _feedingAssignmentExceptions;
  List<FeedingAssignmentExceptionDataStruct> get feedingAssignmentExceptions =>
      _feedingAssignmentExceptions ?? const [];
  set feedingAssignmentExceptions(
          List<FeedingAssignmentExceptionDataStruct>? val) =>
      _feedingAssignmentExceptions = val;

  void updateFeedingAssignmentExceptions(
      Function(List<FeedingAssignmentExceptionDataStruct>) updateFn) {
    updateFn(_feedingAssignmentExceptions ??= []);
  }

  bool hasFeedingAssignmentExceptions() => _feedingAssignmentExceptions != null;

  // "feedingExecutionRecords" field.
  List<FeedingExecutionRecordDataStruct>? _feedingExecutionRecords;
  List<FeedingExecutionRecordDataStruct> get feedingExecutionRecords =>
      _feedingExecutionRecords ?? const [];
  set feedingExecutionRecords(List<FeedingExecutionRecordDataStruct>? val) =>
      _feedingExecutionRecords = val;

  void updateFeedingExecutionRecords(
      Function(List<FeedingExecutionRecordDataStruct>) updateFn) {
    updateFn(_feedingExecutionRecords ??= []);
  }

  bool hasFeedingExecutionRecords() => _feedingExecutionRecords != null;

  // "nextFeedingAssignmentExceptionId" field.
  int? _nextFeedingAssignmentExceptionId;
  int get nextFeedingAssignmentExceptionId =>
      _nextFeedingAssignmentExceptionId ?? 0;
  set nextFeedingAssignmentExceptionId(int? val) =>
      _nextFeedingAssignmentExceptionId = val;

  void incrementNextFeedingAssignmentExceptionId(int amount) =>
      nextFeedingAssignmentExceptionId =
          nextFeedingAssignmentExceptionId + amount;

  bool hasNextFeedingAssignmentExceptionId() =>
      _nextFeedingAssignmentExceptionId != null;

  // "nextFeedingExecutionRecordId" field.
  int? _nextFeedingExecutionRecordId;
  int get nextFeedingExecutionRecordId => _nextFeedingExecutionRecordId ?? 0;
  set nextFeedingExecutionRecordId(int? val) =>
      _nextFeedingExecutionRecordId = val;

  void incrementNextFeedingExecutionRecordId(int amount) =>
      nextFeedingExecutionRecordId = nextFeedingExecutionRecordId + amount;

  bool hasNextFeedingExecutionRecordId() =>
      _nextFeedingExecutionRecordId != null;

  // "schemaVersion" field.
  int? _schemaVersion;
  int get schemaVersion => _schemaVersion ?? 0;
  set schemaVersion(int? val) => _schemaVersion = val;

  void incrementSchemaVersion(int amount) =>
      schemaVersion = schemaVersion + amount;

  bool hasSchemaVersion() => _schemaVersion != null;

  // "updatedAt" field.
  DateTime? _updatedAt;
  DateTime? get updatedAt => _updatedAt;
  set updatedAt(DateTime? val) => _updatedAt = val;

  bool hasUpdatedAt() => _updatedAt != null;

  // "selectedCloudStableId" field.
  String? _selectedCloudStableId;
  String get selectedCloudStableId => _selectedCloudStableId ?? '';
  set selectedCloudStableId(String? val) => _selectedCloudStableId = val;

  bool hasSelectedCloudStableId() => _selectedCloudStableId != null;

  // "localStableCloudLinks" field.
  List<LocalStableCloudLinkDataStruct>? _localStableCloudLinks;
  List<LocalStableCloudLinkDataStruct> get localStableCloudLinks =>
      _localStableCloudLinks ?? const [];
  set localStableCloudLinks(List<LocalStableCloudLinkDataStruct>? val) =>
      _localStableCloudLinks = val;

  void updateLocalStableCloudLinks(
      Function(List<LocalStableCloudLinkDataStruct>) updateFn) {
    updateFn(_localStableCloudLinks ??= []);
  }

  bool hasLocalStableCloudLinks() => _localStableCloudLinks != null;

  // "stableMembershipCaches" field.
  List<StableMembershipCacheDataStruct>? _stableMembershipCaches;
  List<StableMembershipCacheDataStruct> get stableMembershipCaches =>
      _stableMembershipCaches ?? const [];
  set stableMembershipCaches(List<StableMembershipCacheDataStruct>? val) =>
      _stableMembershipCaches = val;

  void updateStableMembershipCaches(
      Function(List<StableMembershipCacheDataStruct>) updateFn) {
    updateFn(_stableMembershipCaches ??= []);
  }

  bool hasStableMembershipCaches() => _stableMembershipCaches != null;

  static LocalAccountScopeDataStruct fromMap(Map<String, dynamic> data) =>
      LocalAccountScopeDataStruct(
        authUserId: data['authUserId'] as String?,
        horses: getStructList(
          data['horses'],
          HorseProfileDataStruct.fromMap,
        ),
        selectedHorse: data['selectedHorse'] is HorseProfileDataStruct
            ? data['selectedHorse']
            : HorseProfileDataStruct.maybeFromMap(data['selectedHorse']),
        selectedHorseIndex: castToType<int>(data['selectedHorseIndex']),
        nextHorseId: castToType<int>(data['nextHorseId']),
        nextHorseIndex: castToType<int>(data['nextHorseIndex']),
        horseSeedVersion: castToType<int>(data['horseSeedVersion']),
        passportPrototypeVersion:
            castToType<int>(data['passportPrototypeVersion']),
        activities: getStructList(
          data['activities'],
          ActivityDataStruct.fromMap,
        ),
        nextActivityId: castToType<int>(data['nextActivityId']),
        currentLocalUserId: data['currentLocalUserId'] as String?,
        currentLocalStableId: data['currentLocalStableId'] as String?,
        horseFeedingPlans: getStructList(
          data['horseFeedingPlans'],
          HorseFeedingPlanDataStruct.fromMap,
        ),
        temporaryFeedingSchedules: getStructList(
          data['temporaryFeedingSchedules'],
          TemporaryFeedingScheduleDataStruct.fromMap,
        ),
        nextFeedingItemId: castToType<int>(data['nextFeedingItemId']),
        nextTemporaryFeedingScheduleId:
            castToType<int>(data['nextTemporaryFeedingScheduleId']),
        feedingRoundConfigs: getStructList(
          data['feedingRoundConfigs'],
          FeedingRoundConfigDataStruct.fromMap,
        ),
        feedingAssignmentExceptions: getStructList(
          data['feedingAssignmentExceptions'],
          FeedingAssignmentExceptionDataStruct.fromMap,
        ),
        feedingExecutionRecords: getStructList(
          data['feedingExecutionRecords'],
          FeedingExecutionRecordDataStruct.fromMap,
        ),
        nextFeedingAssignmentExceptionId:
            castToType<int>(data['nextFeedingAssignmentExceptionId']),
        nextFeedingExecutionRecordId:
            castToType<int>(data['nextFeedingExecutionRecordId']),
        schemaVersion: castToType<int>(data['schemaVersion']),
        updatedAt: data['updatedAt'] as DateTime?,
        selectedCloudStableId: data['selectedCloudStableId'] as String?,
        localStableCloudLinks: getStructList(
          data['localStableCloudLinks'],
          LocalStableCloudLinkDataStruct.fromMap,
        ),
        stableMembershipCaches: getStructList(
          data['stableMembershipCaches'],
          StableMembershipCacheDataStruct.fromMap,
        ),
      );

  static LocalAccountScopeDataStruct? maybeFromMap(dynamic data) => data is Map
      ? LocalAccountScopeDataStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'authUserId': _authUserId,
        'horses': _horses?.map((e) => e.toMap()).toList(),
        'selectedHorse': _selectedHorse?.toMap(),
        'selectedHorseIndex': _selectedHorseIndex,
        'nextHorseId': _nextHorseId,
        'nextHorseIndex': _nextHorseIndex,
        'horseSeedVersion': _horseSeedVersion,
        'passportPrototypeVersion': _passportPrototypeVersion,
        'activities': _activities?.map((e) => e.toMap()).toList(),
        'nextActivityId': _nextActivityId,
        'currentLocalUserId': _currentLocalUserId,
        'currentLocalStableId': _currentLocalStableId,
        'horseFeedingPlans': _horseFeedingPlans?.map((e) => e.toMap()).toList(),
        'temporaryFeedingSchedules':
            _temporaryFeedingSchedules?.map((e) => e.toMap()).toList(),
        'nextFeedingItemId': _nextFeedingItemId,
        'nextTemporaryFeedingScheduleId': _nextTemporaryFeedingScheduleId,
        'feedingRoundConfigs':
            _feedingRoundConfigs?.map((e) => e.toMap()).toList(),
        'feedingAssignmentExceptions':
            _feedingAssignmentExceptions?.map((e) => e.toMap()).toList(),
        'feedingExecutionRecords':
            _feedingExecutionRecords?.map((e) => e.toMap()).toList(),
        'nextFeedingAssignmentExceptionId': _nextFeedingAssignmentExceptionId,
        'nextFeedingExecutionRecordId': _nextFeedingExecutionRecordId,
        'schemaVersion': _schemaVersion,
        'updatedAt': _updatedAt,
        'selectedCloudStableId': _selectedCloudStableId,
        'localStableCloudLinks':
            _localStableCloudLinks?.map((e) => e.toMap()).toList(),
        'stableMembershipCaches':
            _stableMembershipCaches?.map((e) => e.toMap()).toList(),
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'authUserId': serializeParam(
          _authUserId,
          ParamType.String,
        ),
        'horses': serializeParam(
          _horses,
          ParamType.DataStruct,
          isList: true,
        ),
        'selectedHorse': serializeParam(
          _selectedHorse,
          ParamType.DataStruct,
        ),
        'selectedHorseIndex': serializeParam(
          _selectedHorseIndex,
          ParamType.int,
        ),
        'nextHorseId': serializeParam(
          _nextHorseId,
          ParamType.int,
        ),
        'nextHorseIndex': serializeParam(
          _nextHorseIndex,
          ParamType.int,
        ),
        'horseSeedVersion': serializeParam(
          _horseSeedVersion,
          ParamType.int,
        ),
        'passportPrototypeVersion': serializeParam(
          _passportPrototypeVersion,
          ParamType.int,
        ),
        'activities': serializeParam(
          _activities,
          ParamType.DataStruct,
          isList: true,
        ),
        'nextActivityId': serializeParam(
          _nextActivityId,
          ParamType.int,
        ),
        'currentLocalUserId': serializeParam(
          _currentLocalUserId,
          ParamType.String,
        ),
        'currentLocalStableId': serializeParam(
          _currentLocalStableId,
          ParamType.String,
        ),
        'horseFeedingPlans': serializeParam(
          _horseFeedingPlans,
          ParamType.DataStruct,
          isList: true,
        ),
        'temporaryFeedingSchedules': serializeParam(
          _temporaryFeedingSchedules,
          ParamType.DataStruct,
          isList: true,
        ),
        'nextFeedingItemId': serializeParam(
          _nextFeedingItemId,
          ParamType.int,
        ),
        'nextTemporaryFeedingScheduleId': serializeParam(
          _nextTemporaryFeedingScheduleId,
          ParamType.int,
        ),
        'feedingRoundConfigs': serializeParam(
          _feedingRoundConfigs,
          ParamType.DataStruct,
          isList: true,
        ),
        'feedingAssignmentExceptions': serializeParam(
          _feedingAssignmentExceptions,
          ParamType.DataStruct,
          isList: true,
        ),
        'feedingExecutionRecords': serializeParam(
          _feedingExecutionRecords,
          ParamType.DataStruct,
          isList: true,
        ),
        'nextFeedingAssignmentExceptionId': serializeParam(
          _nextFeedingAssignmentExceptionId,
          ParamType.int,
        ),
        'nextFeedingExecutionRecordId': serializeParam(
          _nextFeedingExecutionRecordId,
          ParamType.int,
        ),
        'schemaVersion': serializeParam(
          _schemaVersion,
          ParamType.int,
        ),
        'updatedAt': serializeParam(
          _updatedAt,
          ParamType.DateTime,
        ),
        'selectedCloudStableId': serializeParam(
          _selectedCloudStableId,
          ParamType.String,
        ),
        'localStableCloudLinks': serializeParam(
          _localStableCloudLinks,
          ParamType.DataStruct,
          isList: true,
        ),
        'stableMembershipCaches': serializeParam(
          _stableMembershipCaches,
          ParamType.DataStruct,
          isList: true,
        ),
      }.withoutNulls;

  static LocalAccountScopeDataStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      LocalAccountScopeDataStruct(
        authUserId: deserializeParam(
          data['authUserId'],
          ParamType.String,
          false,
        ),
        horses: deserializeStructParam<HorseProfileDataStruct>(
          data['horses'],
          ParamType.DataStruct,
          true,
          structBuilder: HorseProfileDataStruct.fromSerializableMap,
        ),
        selectedHorse: deserializeStructParam(
          data['selectedHorse'],
          ParamType.DataStruct,
          false,
          structBuilder: HorseProfileDataStruct.fromSerializableMap,
        ),
        selectedHorseIndex: deserializeParam(
          data['selectedHorseIndex'],
          ParamType.int,
          false,
        ),
        nextHorseId: deserializeParam(
          data['nextHorseId'],
          ParamType.int,
          false,
        ),
        nextHorseIndex: deserializeParam(
          data['nextHorseIndex'],
          ParamType.int,
          false,
        ),
        horseSeedVersion: deserializeParam(
          data['horseSeedVersion'],
          ParamType.int,
          false,
        ),
        passportPrototypeVersion: deserializeParam(
          data['passportPrototypeVersion'],
          ParamType.int,
          false,
        ),
        activities: deserializeStructParam<ActivityDataStruct>(
          data['activities'],
          ParamType.DataStruct,
          true,
          structBuilder: ActivityDataStruct.fromSerializableMap,
        ),
        nextActivityId: deserializeParam(
          data['nextActivityId'],
          ParamType.int,
          false,
        ),
        currentLocalUserId: deserializeParam(
          data['currentLocalUserId'],
          ParamType.String,
          false,
        ),
        currentLocalStableId: deserializeParam(
          data['currentLocalStableId'],
          ParamType.String,
          false,
        ),
        horseFeedingPlans: deserializeStructParam<HorseFeedingPlanDataStruct>(
          data['horseFeedingPlans'],
          ParamType.DataStruct,
          true,
          structBuilder: HorseFeedingPlanDataStruct.fromSerializableMap,
        ),
        temporaryFeedingSchedules:
            deserializeStructParam<TemporaryFeedingScheduleDataStruct>(
          data['temporaryFeedingSchedules'],
          ParamType.DataStruct,
          true,
          structBuilder: TemporaryFeedingScheduleDataStruct.fromSerializableMap,
        ),
        nextFeedingItemId: deserializeParam(
          data['nextFeedingItemId'],
          ParamType.int,
          false,
        ),
        nextTemporaryFeedingScheduleId: deserializeParam(
          data['nextTemporaryFeedingScheduleId'],
          ParamType.int,
          false,
        ),
        feedingRoundConfigs:
            deserializeStructParam<FeedingRoundConfigDataStruct>(
          data['feedingRoundConfigs'],
          ParamType.DataStruct,
          true,
          structBuilder: FeedingRoundConfigDataStruct.fromSerializableMap,
        ),
        feedingAssignmentExceptions:
            deserializeStructParam<FeedingAssignmentExceptionDataStruct>(
          data['feedingAssignmentExceptions'],
          ParamType.DataStruct,
          true,
          structBuilder:
              FeedingAssignmentExceptionDataStruct.fromSerializableMap,
        ),
        feedingExecutionRecords:
            deserializeStructParam<FeedingExecutionRecordDataStruct>(
          data['feedingExecutionRecords'],
          ParamType.DataStruct,
          true,
          structBuilder: FeedingExecutionRecordDataStruct.fromSerializableMap,
        ),
        nextFeedingAssignmentExceptionId: deserializeParam(
          data['nextFeedingAssignmentExceptionId'],
          ParamType.int,
          false,
        ),
        nextFeedingExecutionRecordId: deserializeParam(
          data['nextFeedingExecutionRecordId'],
          ParamType.int,
          false,
        ),
        schemaVersion: deserializeParam(
          data['schemaVersion'],
          ParamType.int,
          false,
        ),
        updatedAt: deserializeParam(
          data['updatedAt'],
          ParamType.DateTime,
          false,
        ),
        selectedCloudStableId: deserializeParam(
          data['selectedCloudStableId'],
          ParamType.String,
          false,
        ),
        localStableCloudLinks:
            deserializeStructParam<LocalStableCloudLinkDataStruct>(
          data['localStableCloudLinks'],
          ParamType.DataStruct,
          true,
          structBuilder: LocalStableCloudLinkDataStruct.fromSerializableMap,
        ),
        stableMembershipCaches:
            deserializeStructParam<StableMembershipCacheDataStruct>(
          data['stableMembershipCaches'],
          ParamType.DataStruct,
          true,
          structBuilder: StableMembershipCacheDataStruct.fromSerializableMap,
        ),
      );

  @override
  String toString() => 'LocalAccountScopeDataStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is LocalAccountScopeDataStruct &&
        authUserId == other.authUserId &&
        listEquality.equals(horses, other.horses) &&
        selectedHorse == other.selectedHorse &&
        selectedHorseIndex == other.selectedHorseIndex &&
        nextHorseId == other.nextHorseId &&
        nextHorseIndex == other.nextHorseIndex &&
        horseSeedVersion == other.horseSeedVersion &&
        passportPrototypeVersion == other.passportPrototypeVersion &&
        listEquality.equals(activities, other.activities) &&
        nextActivityId == other.nextActivityId &&
        currentLocalUserId == other.currentLocalUserId &&
        currentLocalStableId == other.currentLocalStableId &&
        listEquality.equals(horseFeedingPlans, other.horseFeedingPlans) &&
        listEquality.equals(
            temporaryFeedingSchedules, other.temporaryFeedingSchedules) &&
        nextFeedingItemId == other.nextFeedingItemId &&
        nextTemporaryFeedingScheduleId ==
            other.nextTemporaryFeedingScheduleId &&
        listEquality.equals(feedingRoundConfigs, other.feedingRoundConfigs) &&
        listEquality.equals(
            feedingAssignmentExceptions, other.feedingAssignmentExceptions) &&
        listEquality.equals(
            feedingExecutionRecords, other.feedingExecutionRecords) &&
        nextFeedingAssignmentExceptionId ==
            other.nextFeedingAssignmentExceptionId &&
        nextFeedingExecutionRecordId == other.nextFeedingExecutionRecordId &&
        schemaVersion == other.schemaVersion &&
        updatedAt == other.updatedAt &&
        selectedCloudStableId == other.selectedCloudStableId &&
        listEquality.equals(
            localStableCloudLinks, other.localStableCloudLinks) &&
        listEquality.equals(
            stableMembershipCaches, other.stableMembershipCaches);
  }

  @override
  int get hashCode => const ListEquality().hash([
        authUserId,
        horses,
        selectedHorse,
        selectedHorseIndex,
        nextHorseId,
        nextHorseIndex,
        horseSeedVersion,
        passportPrototypeVersion,
        activities,
        nextActivityId,
        currentLocalUserId,
        currentLocalStableId,
        horseFeedingPlans,
        temporaryFeedingSchedules,
        nextFeedingItemId,
        nextTemporaryFeedingScheduleId,
        feedingRoundConfigs,
        feedingAssignmentExceptions,
        feedingExecutionRecords,
        nextFeedingAssignmentExceptionId,
        nextFeedingExecutionRecordId,
        schemaVersion,
        updatedAt,
        selectedCloudStableId,
        localStableCloudLinks,
        stableMembershipCaches
      ]);
}

LocalAccountScopeDataStruct createLocalAccountScopeDataStruct({
  String? authUserId,
  HorseProfileDataStruct? selectedHorse,
  int? selectedHorseIndex,
  int? nextHorseId,
  int? nextHorseIndex,
  int? horseSeedVersion,
  int? passportPrototypeVersion,
  int? nextActivityId,
  String? currentLocalUserId,
  String? currentLocalStableId,
  int? nextFeedingItemId,
  int? nextTemporaryFeedingScheduleId,
  int? nextFeedingAssignmentExceptionId,
  int? nextFeedingExecutionRecordId,
  int? schemaVersion,
  DateTime? updatedAt,
  String? selectedCloudStableId,
}) =>
    LocalAccountScopeDataStruct(
      authUserId: authUserId,
      selectedHorse: selectedHorse ?? HorseProfileDataStruct(),
      selectedHorseIndex: selectedHorseIndex,
      nextHorseId: nextHorseId,
      nextHorseIndex: nextHorseIndex,
      horseSeedVersion: horseSeedVersion,
      passportPrototypeVersion: passportPrototypeVersion,
      nextActivityId: nextActivityId,
      currentLocalUserId: currentLocalUserId,
      currentLocalStableId: currentLocalStableId,
      nextFeedingItemId: nextFeedingItemId,
      nextTemporaryFeedingScheduleId: nextTemporaryFeedingScheduleId,
      nextFeedingAssignmentExceptionId: nextFeedingAssignmentExceptionId,
      nextFeedingExecutionRecordId: nextFeedingExecutionRecordId,
      schemaVersion: schemaVersion,
      updatedAt: updatedAt,
      selectedCloudStableId: selectedCloudStableId,
    );

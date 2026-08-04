import 'package:flutter/material.dart';
import '/backend/schema/structs/index.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:csv/csv.dart';
import 'package:synchronized/synchronized.dart';
import 'flutter_flow/flutter_flow_util.dart';

class FFAppState extends ChangeNotifier {
  static FFAppState _instance = FFAppState._internal();

  factory FFAppState() {
    return _instance;
  }

  FFAppState._internal();

  static void reset() {
    _instance = FFAppState._internal();
  }

  Future initializePersistedState() async {
    secureStorage = FlutterSecureStorage();
    await _safeInitAsync(() async {
      _horses = (await secureStorage.getStringList('ff_horses'))
              ?.map((x) {
                try {
                  return HorseProfileDataStruct.fromSerializableMap(
                      jsonDecode(x));
                } catch (e) {
                  print("Can't decode persisted data type. Error: $e.");
                  return null;
                }
              })
              .withoutNulls
              .toList() ??
          _horses;
    });
    await _safeInitAsync(() async {
      if (await secureStorage.read(key: 'ff_selectedHorse') != null) {
        try {
          final serializedData =
              await secureStorage.getString('ff_selectedHorse') ?? '{}';
          _selectedHorse = HorseProfileDataStruct.fromSerializableMap(
              jsonDecode(serializedData));
        } catch (e) {
          print("Can't decode persisted data type. Error: $e.");
        }
      }
    });
    await _safeInitAsync(() async {
      _selectedHorseIndex =
          await secureStorage.getInt('ff_selectedHorseIndex') ??
              _selectedHorseIndex;
    });
    await _safeInitAsync(() async {
      _nextHorseId =
          await secureStorage.getInt('ff_nextHorseId') ?? _nextHorseId;
    });
    await _safeInitAsync(() async {
      _nextHorseIndex =
          await secureStorage.getInt('ff_nextHorseIndex') ?? _nextHorseIndex;
    });
    await _safeInitAsync(() async {
      _horseSeedVersion = await secureStorage.getInt('ff_horseSeedVersion') ??
          _horseSeedVersion;
    });
    await _safeInitAsync(() async {
      _passportPrototypeVersion =
          await secureStorage.getInt('ff_passportPrototypeVersion') ??
              _passportPrototypeVersion;
    });
    await _safeInitAsync(() async {
      _activities = (await secureStorage.getStringList('ff_activities'))
              ?.map((x) {
                try {
                  return ActivityDataStruct.fromSerializableMap(jsonDecode(x));
                } catch (e) {
                  print("Can't decode persisted data type. Error: $e.");
                  return null;
                }
              })
              .withoutNulls
              .toList() ??
          _activities;
    });
    await _safeInitAsync(() async {
      _nextActivityId =
          await secureStorage.getInt('ff_nextActivityId') ?? _nextActivityId;
    });
    await _safeInitAsync(() async {
      _currentLocalUserId =
          await secureStorage.getString('ff_currentLocalUserId') ??
              _currentLocalUserId;
    });
    await _safeInitAsync(() async {
      _currentLocalStableId =
          await secureStorage.getString('ff_currentLocalStableId') ??
              _currentLocalStableId;
    });
    await _safeInitAsync(() async {
      _horseFeedingPlans =
          (await secureStorage.getStringList('ff_horseFeedingPlans'))
                  ?.map((x) {
                    try {
                      return HorseFeedingPlanDataStruct.fromSerializableMap(
                          jsonDecode(x));
                    } catch (e) {
                      print("Can't decode persisted data type. Error: $e.");
                      return null;
                    }
                  })
                  .withoutNulls
                  .toList() ??
              _horseFeedingPlans;
    });
    await _safeInitAsync(() async {
      _temporaryFeedingSchedules =
          (await secureStorage.getStringList('ff_temporaryFeedingSchedules'))
                  ?.map((x) {
                    try {
                      return TemporaryFeedingScheduleDataStruct
                          .fromSerializableMap(jsonDecode(x));
                    } catch (e) {
                      print("Can't decode persisted data type. Error: $e.");
                      return null;
                    }
                  })
                  .withoutNulls
                  .toList() ??
              _temporaryFeedingSchedules;
    });
    await _safeInitAsync(() async {
      _nextFeedingItemId = await secureStorage.getInt('ff_nextFeedingItemId') ??
          _nextFeedingItemId;
    });
    await _safeInitAsync(() async {
      _nextTemporaryFeedingScheduleId =
          await secureStorage.getInt('ff_nextTemporaryFeedingScheduleId') ??
              _nextTemporaryFeedingScheduleId;
    });
    await _safeInitAsync(() async {
      _feedingRoundConfigs =
          (await secureStorage.getStringList('ff_feedingRoundConfigs'))
                  ?.map((x) {
                    try {
                      return FeedingRoundConfigDataStruct.fromSerializableMap(
                          jsonDecode(x));
                    } catch (e) {
                      print("Can't decode persisted data type. Error: $e.");
                      return null;
                    }
                  })
                  .withoutNulls
                  .toList() ??
              _feedingRoundConfigs;
    });
    await _safeInitAsync(() async {
      _feedingAssignmentExceptions =
          (await secureStorage.getStringList('ff_feedingAssignmentExceptions'))
                  ?.map((x) {
                    try {
                      return FeedingAssignmentExceptionDataStruct
                          .fromSerializableMap(jsonDecode(x));
                    } catch (e) {
                      print("Can't decode persisted data type. Error: $e.");
                      return null;
                    }
                  })
                  .withoutNulls
                  .toList() ??
              _feedingAssignmentExceptions;
    });
    await _safeInitAsync(() async {
      _feedingExecutionRecords =
          (await secureStorage.getStringList('ff_feedingExecutionRecords'))
                  ?.map((x) {
                    try {
                      return FeedingExecutionRecordDataStruct
                          .fromSerializableMap(jsonDecode(x));
                    } catch (e) {
                      print("Can't decode persisted data type. Error: $e.");
                      return null;
                    }
                  })
                  .withoutNulls
                  .toList() ??
              _feedingExecutionRecords;
    });
    await _safeInitAsync(() async {
      _nextFeedingAssignmentExceptionId =
          await secureStorage.getInt('ff_nextFeedingAssignmentExceptionId') ??
              _nextFeedingAssignmentExceptionId;
    });
    await _safeInitAsync(() async {
      _nextFeedingExecutionRecordId =
          await secureStorage.getInt('ff_nextFeedingExecutionRecordId') ??
              _nextFeedingExecutionRecordId;
    });
    await _safeInitAsync(() async {
      _authPendingEmail =
          await secureStorage.getString('ff_authPendingEmail') ??
              _authPendingEmail;
    });
    await _safeInitAsync(() async {
      _activeAuthAccountId =
          await secureStorage.getString('ff_activeAuthAccountId') ??
              _activeAuthAccountId;
    });
    await _safeInitAsync(() async {
      _authProfileCaches =
          (await secureStorage.getStringList('ff_authProfileCaches'))
                  ?.map((x) {
                    try {
                      return AuthProfileDataStruct.fromSerializableMap(
                          jsonDecode(x));
                    } catch (e) {
                      print("Can't decode persisted data type. Error: $e.");
                      return null;
                    }
                  })
                  .withoutNulls
                  .toList() ??
              _authProfileCaches;
    });
    await _safeInitAsync(() async {
      _localAccountScopes =
          (await secureStorage.getStringList('ff_localAccountScopes'))
                  ?.map((x) {
                    try {
                      return LocalAccountScopeDataStruct.fromSerializableMap(
                          jsonDecode(x));
                    } catch (e) {
                      print("Can't decode persisted data type. Error: $e.");
                      return null;
                    }
                  })
                  .withoutNulls
                  .toList() ??
              _localAccountScopes;
    });
    await _safeInitAsync(() async {
      if (await secureStorage.read(key: 'ff_legacyLocalDataBackup') != null) {
        try {
          final serializedData =
              await secureStorage.getString('ff_legacyLocalDataBackup') ?? '{}';
          _legacyLocalDataBackup =
              LocalAccountScopeDataStruct.fromSerializableMap(
                  jsonDecode(serializedData));
        } catch (e) {
          print("Can't decode persisted data type. Error: $e.");
        }
      }
    });
    await _safeInitAsync(() async {
      _hasLegacyLocalDataBackup =
          await secureStorage.getBool('ff_hasLegacyLocalDataBackup') ??
              _hasLegacyLocalDataBackup;
    });
    await _safeInitAsync(() async {
      _legacyDataPromptedAuthIds =
          await secureStorage.getStringList('ff_legacyDataPromptedAuthIds') ??
              _legacyDataPromptedAuthIds;
    });
    await _safeInitAsync(() async {
      _selectedCloudStableId =
          await secureStorage.getString('ff_selectedCloudStableId') ??
              _selectedCloudStableId;
    });
    await _safeInitAsync(() async {
      _localStableCloudLinks =
          (await secureStorage.getStringList('ff_localStableCloudLinks'))
                  ?.map((x) {
                    try {
                      return LocalStableCloudLinkDataStruct.fromSerializableMap(
                          jsonDecode(x));
                    } catch (e) {
                      print("Can't decode persisted data type. Error: $e.");
                      return null;
                    }
                  })
                  .withoutNulls
                  .toList() ??
              _localStableCloudLinks;
    });
    await _safeInitAsync(() async {
      _stableMembershipCaches =
          (await secureStorage.getStringList('ff_stableMembershipCaches'))
                  ?.map((x) {
                    try {
                      return StableMembershipCacheDataStruct
                          .fromSerializableMap(jsonDecode(x));
                    } catch (e) {
                      print("Can't decode persisted data type. Error: $e.");
                      return null;
                    }
                  })
                  .withoutNulls
                  .toList() ??
              _stableMembershipCaches;
    });
    await _safeInitAsync(() async {
      _phase4BAccountOperationalBackups = (await secureStorage
                  .getStringList('ff_phase4BAccountOperationalBackups'))
              ?.map((x) {
                try {
                  return LocalAccountScopeDataStruct.fromSerializableMap(
                      jsonDecode(x));
                } catch (e) {
                  print("Can't decode persisted data type. Error: $e.");
                  return null;
                }
              })
              .withoutNulls
              .toList() ??
          _phase4BAccountOperationalBackups;
    });
    await _safeInitAsync(() async {
      _pendingStableInvitationId =
          await secureStorage.getString('ff_pendingStableInvitationId') ??
              _pendingStableInvitationId;
    });
    await _safeInitAsync(() async {
      _pendingStableCreateRequestId =
          await secureStorage.getString('ff_pendingStableCreateRequestId') ??
              _pendingStableCreateRequestId;
    });
    await _safeInitAsync(() async {
      _pendingStableCreatePayloadKey =
          await secureStorage.getString('ff_pendingStableCreatePayloadKey') ??
              _pendingStableCreatePayloadKey;
    });
  }

  void update(VoidCallback callback) {
    callback();
    notifyListeners();
  }

  late FlutterSecureStorage secureStorage;

  /// Locally persisted prototype horses.
  List<HorseProfileDataStruct> _horses = [];
  List<HorseProfileDataStruct> get horses => _horses;
  set horses(List<HorseProfileDataStruct> value) {
    _horses = value;
    secureStorage.setStringList(
        'ff_horses', value.map((x) => x.serialize()).toList());
  }

  void deleteHorses() {
    secureStorage.delete(key: 'ff_horses');
  }

  void addToHorses(HorseProfileDataStruct value) {
    horses.add(value);
    secureStorage.setStringList(
        'ff_horses', _horses.map((x) => x.serialize()).toList());
  }

  void removeFromHorses(HorseProfileDataStruct value) {
    horses.remove(value);
    secureStorage.setStringList(
        'ff_horses', _horses.map((x) => x.serialize()).toList());
  }

  void removeAtIndexFromHorses(int index) {
    horses.removeAt(index);
    secureStorage.setStringList(
        'ff_horses', _horses.map((x) => x.serialize()).toList());
  }

  void updateHorsesAtIndex(
    int index,
    HorseProfileDataStruct Function(HorseProfileDataStruct) updateFn,
  ) {
    horses[index] = updateFn(_horses[index]);
    secureStorage.setStringList(
        'ff_horses', _horses.map((x) => x.serialize()).toList());
  }

  void insertAtIndexInHorses(int index, HorseProfileDataStruct value) {
    horses.insert(index, value);
    secureStorage.setStringList(
        'ff_horses', _horses.map((x) => x.serialize()).toList());
  }

  /// Horse currently rendered by the reusable detail template.
  HorseProfileDataStruct _selectedHorse = HorseProfileDataStruct();
  HorseProfileDataStruct get selectedHorse => _selectedHorse;
  set selectedHorse(HorseProfileDataStruct value) {
    _selectedHorse = value;
    secureStorage.setString('ff_selectedHorse', value.serialize());
  }

  void deleteSelectedHorse() {
    secureStorage.delete(key: 'ff_selectedHorse');
  }

  void updateSelectedHorseStruct(Function(HorseProfileDataStruct) updateFn) {
    updateFn(_selectedHorse);
    secureStorage.setString('ff_selectedHorse', _selectedHorse.serialize());
  }

  /// Index of the selected horse in the local prototype list.
  int _selectedHorseIndex = 0;
  int get selectedHorseIndex => _selectedHorseIndex;
  set selectedHorseIndex(int value) {
    _selectedHorseIndex = value;
    secureStorage.setInt('ff_selectedHorseIndex', value);
  }

  void deleteSelectedHorseIndex() {
    secureStorage.delete(key: 'ff_selectedHorseIndex');
  }

  /// Next unique local prototype horse identifier.
  int _nextHorseId = 4;
  int get nextHorseId => _nextHorseId;
  set nextHorseId(int value) {
    _nextHorseId = value;
    secureStorage.setInt('ff_nextHorseId', value);
  }

  void deleteNextHorseId() {
    secureStorage.delete(key: 'ff_nextHorseId');
  }

  /// Next insertion index for a locally created horse.
  int _nextHorseIndex = 3;
  int get nextHorseIndex => _nextHorseIndex;
  set nextHorseIndex(int value) {
    _nextHorseIndex = value;
    secureStorage.setInt('ff_nextHorseIndex', value);
  }

  void deleteNextHorseIndex() {
    secureStorage.delete(key: 'ff_nextHorseIndex');
  }

  /// One-time version guard for AVARYN sample horses.
  int _horseSeedVersion = 0;
  int get horseSeedVersion => _horseSeedVersion;
  set horseSeedVersion(int value) {
    _horseSeedVersion = value;
    secureStorage.setInt('ff_horseSeedVersion', value);
  }

  void deleteHorseSeedVersion() {
    secureStorage.delete(key: 'ff_horseSeedVersion');
  }

  /// One-time local prototype migration guard for passport expiry sample data.
  int _passportPrototypeVersion = 0;
  int get passportPrototypeVersion => _passportPrototypeVersion;
  set passportPrototypeVersion(int value) {
    _passportPrototypeVersion = value;
    secureStorage.setInt('ff_passportPrototypeVersion', value);
  }

  void deletePassportPrototypeVersion() {
    secureStorage.delete(key: 'ff_passportPrototypeVersion');
  }

  /// Locally persisted AVARYN activities shared by Planning and Vandaag.
  List<ActivityDataStruct> _activities = [];
  List<ActivityDataStruct> get activities => _activities;
  set activities(List<ActivityDataStruct> value) {
    _activities = value;
    secureStorage.setStringList(
        'ff_activities', value.map((x) => x.serialize()).toList());
  }

  void deleteActivities() {
    secureStorage.delete(key: 'ff_activities');
  }

  void addToActivities(ActivityDataStruct value) {
    activities.add(value);
    secureStorage.setStringList(
        'ff_activities', _activities.map((x) => x.serialize()).toList());
  }

  void removeFromActivities(ActivityDataStruct value) {
    activities.remove(value);
    secureStorage.setStringList(
        'ff_activities', _activities.map((x) => x.serialize()).toList());
  }

  void removeAtIndexFromActivities(int index) {
    activities.removeAt(index);
    secureStorage.setStringList(
        'ff_activities', _activities.map((x) => x.serialize()).toList());
  }

  void updateActivitiesAtIndex(
    int index,
    ActivityDataStruct Function(ActivityDataStruct) updateFn,
  ) {
    activities[index] = updateFn(_activities[index]);
    secureStorage.setStringList(
        'ff_activities', _activities.map((x) => x.serialize()).toList());
  }

  void insertAtIndexInActivities(int index, ActivityDataStruct value) {
    activities.insert(index, value);
    secureStorage.setStringList(
        'ff_activities', _activities.map((x) => x.serialize()).toList());
  }

  /// Next unique identifier for a locally stored activity.
  int _nextActivityId = 1;
  int get nextActivityId => _nextActivityId;
  set nextActivityId(int value) {
    _nextActivityId = value;
    secureStorage.setInt('ff_nextActivityId', value);
  }

  void deleteNextActivityId() {
    secureStorage.delete(key: 'ff_nextActivityId');
  }

  /// Activity currently opened in the reusable detail view.
  ActivityDataStruct _selectedActivity = ActivityDataStruct();
  ActivityDataStruct get selectedActivity => _selectedActivity;
  set selectedActivity(ActivityDataStruct value) {
    _selectedActivity = value;
  }

  void updateSelectedActivityStruct(Function(ActivityDataStruct) updateFn) {
    updateFn(_selectedActivity);
  }

  /// Original app-state index of the selected activity.
  int _selectedActivityIndex = 0;
  int get selectedActivityIndex => _selectedActivityIndex;
  set selectedActivityIndex(int value) {
    _selectedActivityIndex = value;
  }

  /// Temporary horse selection shared with the responsive horse picker.
  int _activityDraftHorseId = 0;
  int get activityDraftHorseId => _activityDraftHorseId;
  set activityDraftHorseId(int value) {
    _activityDraftHorseId = value;
  }

  /// Stable identifier for the current locally registered prototype user.
  String _currentLocalUserId = 'local-current-user';
  String get currentLocalUserId => _currentLocalUserId;
  set currentLocalUserId(String value) {
    _currentLocalUserId = value;
    secureStorage.setString('ff_currentLocalUserId', value);
  }

  void deleteCurrentLocalUserId() {
    secureStorage.delete(key: 'ff_currentLocalUserId');
  }

  /// Transient assignee selection shared with the reusable picker.
  List<String> _activityDraftAssigneeUserIds = [];
  List<String> get activityDraftAssigneeUserIds =>
      _activityDraftAssigneeUserIds;
  set activityDraftAssigneeUserIds(List<String> value) {
    _activityDraftAssigneeUserIds = value;
  }

  void addToActivityDraftAssigneeUserIds(String value) {
    activityDraftAssigneeUserIds.add(value);
  }

  void removeFromActivityDraftAssigneeUserIds(String value) {
    activityDraftAssigneeUserIds.remove(value);
  }

  void removeAtIndexFromActivityDraftAssigneeUserIds(int index) {
    activityDraftAssigneeUserIds.removeAt(index);
  }

  void updateActivityDraftAssigneeUserIdsAtIndex(
    int index,
    String Function(String) updateFn,
  ) {
    activityDraftAssigneeUserIds[index] =
        updateFn(_activityDraftAssigneeUserIds[index]);
  }

  void insertAtIndexInActivityDraftAssigneeUserIds(int index, String value) {
    activityDraftAssigneeUserIds.insert(index, value);
  }

  /// Transient agenda start date shared with the reusable picker.
  DateTime? _activityDraftStartDate;
  DateTime? get activityDraftStartDate => _activityDraftStartDate;
  set activityDraftStartDate(DateTime? value) {
    _activityDraftStartDate = value;
  }

  /// Transient agenda end date shared with the reusable picker.
  DateTime? _activityDraftEndDate;
  DateTime? get activityDraftEndDate => _activityDraftEndDate;
  set activityDraftEndDate(DateTime? value) {
    _activityDraftEndDate = value;
  }

  /// Transient agenda start time shared with the reusable picker.
  DateTime? _activityDraftStartTime;
  DateTime? get activityDraftStartTime => _activityDraftStartTime;
  set activityDraftStartTime(DateTime? value) {
    _activityDraftStartTime = value;
  }

  /// Transient agenda end time shared with the reusable picker.
  DateTime? _activityDraftEndTime;
  DateTime? get activityDraftEndTime => _activityDraftEndTime;
  set activityDraftEndTime(DateTime? value) {
    _activityDraftEndTime = value;
  }

  /// Transient all-day selection shared with the reusable picker.
  bool _activityDraftAllDay = false;
  bool get activityDraftAllDay => _activityDraftAllDay;
  set activityDraftAllDay(bool value) {
    _activityDraftAllDay = value;
  }

  /// Transient duration in minutes for the activity form.
  int _activityDraftDurationMinutes = 0;
  int get activityDraftDurationMinutes => _activityDraftDurationMinutes;
  set activityDraftDurationMinutes(int value) {
    _activityDraftDurationMinutes = value;
  }

  /// Transient semantic location selection for the activity form.
  String _activityDraftLocationType = '';
  String get activityDraftLocationType => _activityDraftLocationType;
  set activityDraftLocationType(String value) {
    _activityDraftLocationType = value;
  }

  /// Transient pending activity type used by the loss confirmation flow.
  String _activityDraftPendingType = '';
  String get activityDraftPendingType => _activityDraftPendingType;
  set activityDraftPendingType(String value) {
    _activityDraftPendingType = value;
  }

  /// Transient repeat-tap guard for activity saves.
  bool _activitySaveInProgress = false;
  bool get activitySaveInProgress => _activitySaveInProgress;
  set activitySaveInProgress(bool value) {
    _activitySaveInProgress = value;
  }

  /// Stable identifier for the currently selected local prototype stable.
  String _currentLocalStableId = 'local-stable';
  String get currentLocalStableId => _currentLocalStableId;
  set currentLocalStableId(String value) {
    _currentLocalStableId = value;
    secureStorage.setString('ff_currentLocalStableId', value);
  }

  void deleteCurrentLocalStableId() {
    secureStorage.delete(key: 'ff_currentLocalStableId');
  }

  /// Persisted standard feeding schedules scoped by stable and horse ID.
  List<HorseFeedingPlanDataStruct> _horseFeedingPlans = [];
  List<HorseFeedingPlanDataStruct> get horseFeedingPlans => _horseFeedingPlans;
  set horseFeedingPlans(List<HorseFeedingPlanDataStruct> value) {
    _horseFeedingPlans = value;
    secureStorage.setStringList(
        'ff_horseFeedingPlans', value.map((x) => x.serialize()).toList());
  }

  void deleteHorseFeedingPlans() {
    secureStorage.delete(key: 'ff_horseFeedingPlans');
  }

  void addToHorseFeedingPlans(HorseFeedingPlanDataStruct value) {
    horseFeedingPlans.add(value);
    secureStorage.setStringList('ff_horseFeedingPlans',
        _horseFeedingPlans.map((x) => x.serialize()).toList());
  }

  void removeFromHorseFeedingPlans(HorseFeedingPlanDataStruct value) {
    horseFeedingPlans.remove(value);
    secureStorage.setStringList('ff_horseFeedingPlans',
        _horseFeedingPlans.map((x) => x.serialize()).toList());
  }

  void removeAtIndexFromHorseFeedingPlans(int index) {
    horseFeedingPlans.removeAt(index);
    secureStorage.setStringList('ff_horseFeedingPlans',
        _horseFeedingPlans.map((x) => x.serialize()).toList());
  }

  void updateHorseFeedingPlansAtIndex(
    int index,
    HorseFeedingPlanDataStruct Function(HorseFeedingPlanDataStruct) updateFn,
  ) {
    horseFeedingPlans[index] = updateFn(_horseFeedingPlans[index]);
    secureStorage.setStringList('ff_horseFeedingPlans',
        _horseFeedingPlans.map((x) => x.serialize()).toList());
  }

  void insertAtIndexInHorseFeedingPlans(
      int index, HorseFeedingPlanDataStruct value) {
    horseFeedingPlans.insert(index, value);
    secureStorage.setStringList('ff_horseFeedingPlans',
        _horseFeedingPlans.map((x) => x.serialize()).toList());
  }

  /// Persisted temporary feeding schedule snapshots scoped by stable and horse
  /// ID.
  List<TemporaryFeedingScheduleDataStruct> _temporaryFeedingSchedules = [];
  List<TemporaryFeedingScheduleDataStruct> get temporaryFeedingSchedules =>
      _temporaryFeedingSchedules;
  set temporaryFeedingSchedules(
      List<TemporaryFeedingScheduleDataStruct> value) {
    _temporaryFeedingSchedules = value;
    secureStorage.setStringList('ff_temporaryFeedingSchedules',
        value.map((x) => x.serialize()).toList());
  }

  void deleteTemporaryFeedingSchedules() {
    secureStorage.delete(key: 'ff_temporaryFeedingSchedules');
  }

  void addToTemporaryFeedingSchedules(
      TemporaryFeedingScheduleDataStruct value) {
    temporaryFeedingSchedules.add(value);
    secureStorage.setStringList('ff_temporaryFeedingSchedules',
        _temporaryFeedingSchedules.map((x) => x.serialize()).toList());
  }

  void removeFromTemporaryFeedingSchedules(
      TemporaryFeedingScheduleDataStruct value) {
    temporaryFeedingSchedules.remove(value);
    secureStorage.setStringList('ff_temporaryFeedingSchedules',
        _temporaryFeedingSchedules.map((x) => x.serialize()).toList());
  }

  void removeAtIndexFromTemporaryFeedingSchedules(int index) {
    temporaryFeedingSchedules.removeAt(index);
    secureStorage.setStringList('ff_temporaryFeedingSchedules',
        _temporaryFeedingSchedules.map((x) => x.serialize()).toList());
  }

  void updateTemporaryFeedingSchedulesAtIndex(
    int index,
    TemporaryFeedingScheduleDataStruct Function(
            TemporaryFeedingScheduleDataStruct)
        updateFn,
  ) {
    temporaryFeedingSchedules[index] =
        updateFn(_temporaryFeedingSchedules[index]);
    secureStorage.setStringList('ff_temporaryFeedingSchedules',
        _temporaryFeedingSchedules.map((x) => x.serialize()).toList());
  }

  void insertAtIndexInTemporaryFeedingSchedules(
      int index, TemporaryFeedingScheduleDataStruct value) {
    temporaryFeedingSchedules.insert(index, value);
    secureStorage.setStringList('ff_temporaryFeedingSchedules',
        _temporaryFeedingSchedules.map((x) => x.serialize()).toList());
  }

  /// Monotonic local identifier source for feeding items.
  int _nextFeedingItemId = 1;
  int get nextFeedingItemId => _nextFeedingItemId;
  set nextFeedingItemId(int value) {
    _nextFeedingItemId = value;
    secureStorage.setInt('ff_nextFeedingItemId', value);
  }

  void deleteNextFeedingItemId() {
    secureStorage.delete(key: 'ff_nextFeedingItemId');
  }

  /// Monotonic local identifier source for temporary feeding schedules.
  int _nextTemporaryFeedingScheduleId = 1;
  int get nextTemporaryFeedingScheduleId => _nextTemporaryFeedingScheduleId;
  set nextTemporaryFeedingScheduleId(int value) {
    _nextTemporaryFeedingScheduleId = value;
    secureStorage.setInt('ff_nextTemporaryFeedingScheduleId', value);
  }

  void deleteNextTemporaryFeedingScheduleId() {
    secureStorage.delete(key: 'ff_nextTemporaryFeedingScheduleId');
  }

  /// Persisted stable-scoped feeding-round times and default assignees.
  List<FeedingRoundConfigDataStruct> _feedingRoundConfigs = [];
  List<FeedingRoundConfigDataStruct> get feedingRoundConfigs =>
      _feedingRoundConfigs;
  set feedingRoundConfigs(List<FeedingRoundConfigDataStruct> value) {
    _feedingRoundConfigs = value;
    secureStorage.setStringList(
        'ff_feedingRoundConfigs', value.map((x) => x.serialize()).toList());
  }

  void deleteFeedingRoundConfigs() {
    secureStorage.delete(key: 'ff_feedingRoundConfigs');
  }

  void addToFeedingRoundConfigs(FeedingRoundConfigDataStruct value) {
    feedingRoundConfigs.add(value);
    secureStorage.setStringList('ff_feedingRoundConfigs',
        _feedingRoundConfigs.map((x) => x.serialize()).toList());
  }

  void removeFromFeedingRoundConfigs(FeedingRoundConfigDataStruct value) {
    feedingRoundConfigs.remove(value);
    secureStorage.setStringList('ff_feedingRoundConfigs',
        _feedingRoundConfigs.map((x) => x.serialize()).toList());
  }

  void removeAtIndexFromFeedingRoundConfigs(int index) {
    feedingRoundConfigs.removeAt(index);
    secureStorage.setStringList('ff_feedingRoundConfigs',
        _feedingRoundConfigs.map((x) => x.serialize()).toList());
  }

  void updateFeedingRoundConfigsAtIndex(
    int index,
    FeedingRoundConfigDataStruct Function(FeedingRoundConfigDataStruct)
        updateFn,
  ) {
    feedingRoundConfigs[index] = updateFn(_feedingRoundConfigs[index]);
    secureStorage.setStringList('ff_feedingRoundConfigs',
        _feedingRoundConfigs.map((x) => x.serialize()).toList());
  }

  void insertAtIndexInFeedingRoundConfigs(
      int index, FeedingRoundConfigDataStruct value) {
    feedingRoundConfigs.insert(index, value);
    secureStorage.setStringList('ff_feedingRoundConfigs',
        _feedingRoundConfigs.map((x) => x.serialize()).toList());
  }

  /// Persisted date-specific feeding-round responsibility exceptions.
  List<FeedingAssignmentExceptionDataStruct> _feedingAssignmentExceptions = [];
  List<FeedingAssignmentExceptionDataStruct> get feedingAssignmentExceptions =>
      _feedingAssignmentExceptions;
  set feedingAssignmentExceptions(
      List<FeedingAssignmentExceptionDataStruct> value) {
    _feedingAssignmentExceptions = value;
    secureStorage.setStringList('ff_feedingAssignmentExceptions',
        value.map((x) => x.serialize()).toList());
  }

  void deleteFeedingAssignmentExceptions() {
    secureStorage.delete(key: 'ff_feedingAssignmentExceptions');
  }

  void addToFeedingAssignmentExceptions(
      FeedingAssignmentExceptionDataStruct value) {
    feedingAssignmentExceptions.add(value);
    secureStorage.setStringList('ff_feedingAssignmentExceptions',
        _feedingAssignmentExceptions.map((x) => x.serialize()).toList());
  }

  void removeFromFeedingAssignmentExceptions(
      FeedingAssignmentExceptionDataStruct value) {
    feedingAssignmentExceptions.remove(value);
    secureStorage.setStringList('ff_feedingAssignmentExceptions',
        _feedingAssignmentExceptions.map((x) => x.serialize()).toList());
  }

  void removeAtIndexFromFeedingAssignmentExceptions(int index) {
    feedingAssignmentExceptions.removeAt(index);
    secureStorage.setStringList('ff_feedingAssignmentExceptions',
        _feedingAssignmentExceptions.map((x) => x.serialize()).toList());
  }

  void updateFeedingAssignmentExceptionsAtIndex(
    int index,
    FeedingAssignmentExceptionDataStruct Function(
            FeedingAssignmentExceptionDataStruct)
        updateFn,
  ) {
    feedingAssignmentExceptions[index] =
        updateFn(_feedingAssignmentExceptions[index]);
    secureStorage.setStringList('ff_feedingAssignmentExceptions',
        _feedingAssignmentExceptions.map((x) => x.serialize()).toList());
  }

  void insertAtIndexInFeedingAssignmentExceptions(
      int index, FeedingAssignmentExceptionDataStruct value) {
    feedingAssignmentExceptions.insert(index, value);
    secureStorage.setStringList('ff_feedingAssignmentExceptions',
        _feedingAssignmentExceptions.map((x) => x.serialize()).toList());
  }

  /// Persisted completion and deviation results with immutable schedule
  /// snapshots.
  List<FeedingExecutionRecordDataStruct> _feedingExecutionRecords = [];
  List<FeedingExecutionRecordDataStruct> get feedingExecutionRecords =>
      _feedingExecutionRecords;
  set feedingExecutionRecords(List<FeedingExecutionRecordDataStruct> value) {
    _feedingExecutionRecords = value;
    secureStorage.setStringList(
        'ff_feedingExecutionRecords', value.map((x) => x.serialize()).toList());
  }

  void deleteFeedingExecutionRecords() {
    secureStorage.delete(key: 'ff_feedingExecutionRecords');
  }

  void addToFeedingExecutionRecords(FeedingExecutionRecordDataStruct value) {
    feedingExecutionRecords.add(value);
    secureStorage.setStringList('ff_feedingExecutionRecords',
        _feedingExecutionRecords.map((x) => x.serialize()).toList());
  }

  void removeFromFeedingExecutionRecords(
      FeedingExecutionRecordDataStruct value) {
    feedingExecutionRecords.remove(value);
    secureStorage.setStringList('ff_feedingExecutionRecords',
        _feedingExecutionRecords.map((x) => x.serialize()).toList());
  }

  void removeAtIndexFromFeedingExecutionRecords(int index) {
    feedingExecutionRecords.removeAt(index);
    secureStorage.setStringList('ff_feedingExecutionRecords',
        _feedingExecutionRecords.map((x) => x.serialize()).toList());
  }

  void updateFeedingExecutionRecordsAtIndex(
    int index,
    FeedingExecutionRecordDataStruct Function(FeedingExecutionRecordDataStruct)
        updateFn,
  ) {
    feedingExecutionRecords[index] = updateFn(_feedingExecutionRecords[index]);
    secureStorage.setStringList('ff_feedingExecutionRecords',
        _feedingExecutionRecords.map((x) => x.serialize()).toList());
  }

  void insertAtIndexInFeedingExecutionRecords(
      int index, FeedingExecutionRecordDataStruct value) {
    feedingExecutionRecords.insert(index, value);
    secureStorage.setStringList('ff_feedingExecutionRecords',
        _feedingExecutionRecords.map((x) => x.serialize()).toList());
  }

  /// Monotonic local identifier source for assignment exceptions.
  int _nextFeedingAssignmentExceptionId = 1;
  int get nextFeedingAssignmentExceptionId => _nextFeedingAssignmentExceptionId;
  set nextFeedingAssignmentExceptionId(int value) {
    _nextFeedingAssignmentExceptionId = value;
    secureStorage.setInt('ff_nextFeedingAssignmentExceptionId', value);
  }

  void deleteNextFeedingAssignmentExceptionId() {
    secureStorage.delete(key: 'ff_nextFeedingAssignmentExceptionId');
  }

  /// Monotonic local identifier source for feeding execution results.
  int _nextFeedingExecutionRecordId = 1;
  int get nextFeedingExecutionRecordId => _nextFeedingExecutionRecordId;
  set nextFeedingExecutionRecordId(int value) {
    _nextFeedingExecutionRecordId = value;
    secureStorage.setInt('ff_nextFeedingExecutionRecordId', value);
  }

  void deleteNextFeedingExecutionRecordId() {
    secureStorage.delete(key: 'ff_nextFeedingExecutionRecordId');
  }

  /// Transient normalized yyyy-MM-dd date used between feeding pages.
  String _selectedFeedingDateKey = '';
  String get selectedFeedingDateKey => _selectedFeedingDateKey;
  set selectedFeedingDateKey(String value) {
    _selectedFeedingDateKey = value;
  }

  /// Transient feeding-round identifier used by the execution page.
  String _selectedFeedingRoundId = 'morning';
  String get selectedFeedingRoundId => _selectedFeedingRoundId;
  set selectedFeedingRoundId(String value) {
    _selectedFeedingRoundId = value;
  }

  /// Email address awaiting verification; never used as an account identifier.
  String _authPendingEmail = '';
  String get authPendingEmail => _authPendingEmail;
  set authPendingEmail(String value) {
    _authPendingEmail = value;
    secureStorage.setString('ff_authPendingEmail', value);
  }

  void deleteAuthPendingEmail() {
    secureStorage.delete(key: 'ff_authPendingEmail');
  }

  /// Immutable Supabase Auth UUID of the active local account namespace.
  String _activeAuthAccountId = '';
  String get activeAuthAccountId => _activeAuthAccountId;
  set activeAuthAccountId(String value) {
    _activeAuthAccountId = value;
    secureStorage.setString('ff_activeAuthAccountId', value);
  }

  void deleteActiveAuthAccountId() {
    secureStorage.delete(key: 'ff_activeAuthAccountId');
  }

  /// Offline-safe profile cache scoped by immutable auth UUID.
  List<AuthProfileDataStruct> _authProfileCaches = [];
  List<AuthProfileDataStruct> get authProfileCaches => _authProfileCaches;
  set authProfileCaches(List<AuthProfileDataStruct> value) {
    _authProfileCaches = value;
    secureStorage.setStringList(
        'ff_authProfileCaches', value.map((x) => x.serialize()).toList());
  }

  void deleteAuthProfileCaches() {
    secureStorage.delete(key: 'ff_authProfileCaches');
  }

  void addToAuthProfileCaches(AuthProfileDataStruct value) {
    authProfileCaches.add(value);
    secureStorage.setStringList('ff_authProfileCaches',
        _authProfileCaches.map((x) => x.serialize()).toList());
  }

  void removeFromAuthProfileCaches(AuthProfileDataStruct value) {
    authProfileCaches.remove(value);
    secureStorage.setStringList('ff_authProfileCaches',
        _authProfileCaches.map((x) => x.serialize()).toList());
  }

  void removeAtIndexFromAuthProfileCaches(int index) {
    authProfileCaches.removeAt(index);
    secureStorage.setStringList('ff_authProfileCaches',
        _authProfileCaches.map((x) => x.serialize()).toList());
  }

  void updateAuthProfileCachesAtIndex(
    int index,
    AuthProfileDataStruct Function(AuthProfileDataStruct) updateFn,
  ) {
    authProfileCaches[index] = updateFn(_authProfileCaches[index]);
    secureStorage.setStringList('ff_authProfileCaches',
        _authProfileCaches.map((x) => x.serialize()).toList());
  }

  void insertAtIndexInAuthProfileCaches(
      int index, AuthProfileDataStruct value) {
    authProfileCaches.insert(index, value);
    secureStorage.setStringList('ff_authProfileCaches',
        _authProfileCaches.map((x) => x.serialize()).toList());
  }

  /// Current in-memory personal profile; not an operational stable member.
  AuthProfileDataStruct _currentAuthProfile = AuthProfileDataStruct();
  AuthProfileDataStruct get currentAuthProfile => _currentAuthProfile;
  set currentAuthProfile(AuthProfileDataStruct value) {
    _currentAuthProfile = value;
  }

  void updateCurrentAuthProfileStruct(
      Function(AuthProfileDataStruct) updateFn) {
    updateFn(_currentAuthProfile);
  }

  /// Persisted local prototype namespaces keyed only by auth UUID.
  List<LocalAccountScopeDataStruct> _localAccountScopes = [];
  List<LocalAccountScopeDataStruct> get localAccountScopes =>
      _localAccountScopes;
  set localAccountScopes(List<LocalAccountScopeDataStruct> value) {
    _localAccountScopes = value;
    secureStorage.setStringList(
        'ff_localAccountScopes', value.map((x) => x.serialize()).toList());
  }

  void deleteLocalAccountScopes() {
    secureStorage.delete(key: 'ff_localAccountScopes');
  }

  void addToLocalAccountScopes(LocalAccountScopeDataStruct value) {
    localAccountScopes.add(value);
    secureStorage.setStringList('ff_localAccountScopes',
        _localAccountScopes.map((x) => x.serialize()).toList());
  }

  void removeFromLocalAccountScopes(LocalAccountScopeDataStruct value) {
    localAccountScopes.remove(value);
    secureStorage.setStringList('ff_localAccountScopes',
        _localAccountScopes.map((x) => x.serialize()).toList());
  }

  void removeAtIndexFromLocalAccountScopes(int index) {
    localAccountScopes.removeAt(index);
    secureStorage.setStringList('ff_localAccountScopes',
        _localAccountScopes.map((x) => x.serialize()).toList());
  }

  void updateLocalAccountScopesAtIndex(
    int index,
    LocalAccountScopeDataStruct Function(LocalAccountScopeDataStruct) updateFn,
  ) {
    localAccountScopes[index] = updateFn(_localAccountScopes[index]);
    secureStorage.setStringList('ff_localAccountScopes',
        _localAccountScopes.map((x) => x.serialize()).toList());
  }

  void insertAtIndexInLocalAccountScopes(
      int index, LocalAccountScopeDataStruct value) {
    localAccountScopes.insert(index, value);
    secureStorage.setStringList('ff_localAccountScopes',
        _localAccountScopes.map((x) => x.serialize()).toList());
  }

  /// Rollback-safe backup of the legacy unscoped local prototype data.
  LocalAccountScopeDataStruct _legacyLocalDataBackup =
      LocalAccountScopeDataStruct();
  LocalAccountScopeDataStruct get legacyLocalDataBackup =>
      _legacyLocalDataBackup;
  set legacyLocalDataBackup(LocalAccountScopeDataStruct value) {
    _legacyLocalDataBackup = value;
    secureStorage.setString('ff_legacyLocalDataBackup', value.serialize());
  }

  void deleteLegacyLocalDataBackup() {
    secureStorage.delete(key: 'ff_legacyLocalDataBackup');
  }

  void updateLegacyLocalDataBackupStruct(
      Function(LocalAccountScopeDataStruct) updateFn) {
    updateFn(_legacyLocalDataBackup);
    secureStorage.setString(
        'ff_legacyLocalDataBackup', _legacyLocalDataBackup.serialize());
  }

  /// Whether a recoverable legacy local-data backup has been captured.
  bool _hasLegacyLocalDataBackup = false;
  bool get hasLegacyLocalDataBackup => _hasLegacyLocalDataBackup;
  set hasLegacyLocalDataBackup(bool value) {
    _hasLegacyLocalDataBackup = value;
    secureStorage.setBool('ff_hasLegacyLocalDataBackup', value);
  }

  void deleteHasLegacyLocalDataBackup() {
    secureStorage.delete(key: 'ff_hasLegacyLocalDataBackup');
  }

  /// Auth UUIDs for which the explicit legacy-data ownership choice was shown.
  List<String> _legacyDataPromptedAuthIds = [];
  List<String> get legacyDataPromptedAuthIds => _legacyDataPromptedAuthIds;
  set legacyDataPromptedAuthIds(List<String> value) {
    _legacyDataPromptedAuthIds = value;
    secureStorage.setStringList('ff_legacyDataPromptedAuthIds', value);
  }

  void deleteLegacyDataPromptedAuthIds() {
    secureStorage.delete(key: 'ff_legacyDataPromptedAuthIds');
  }

  void addToLegacyDataPromptedAuthIds(String value) {
    legacyDataPromptedAuthIds.add(value);
    secureStorage.setStringList(
        'ff_legacyDataPromptedAuthIds', _legacyDataPromptedAuthIds);
  }

  void removeFromLegacyDataPromptedAuthIds(String value) {
    legacyDataPromptedAuthIds.remove(value);
    secureStorage.setStringList(
        'ff_legacyDataPromptedAuthIds', _legacyDataPromptedAuthIds);
  }

  void removeAtIndexFromLegacyDataPromptedAuthIds(int index) {
    legacyDataPromptedAuthIds.removeAt(index);
    secureStorage.setStringList(
        'ff_legacyDataPromptedAuthIds', _legacyDataPromptedAuthIds);
  }

  void updateLegacyDataPromptedAuthIdsAtIndex(
    int index,
    String Function(String) updateFn,
  ) {
    legacyDataPromptedAuthIds[index] =
        updateFn(_legacyDataPromptedAuthIds[index]);
    secureStorage.setStringList(
        'ff_legacyDataPromptedAuthIds', _legacyDataPromptedAuthIds);
  }

  void insertAtIndexInLegacyDataPromptedAuthIds(int index, String value) {
    legacyDataPromptedAuthIds.insert(index, value);
    secureStorage.setStringList(
        'ff_legacyDataPromptedAuthIds', _legacyDataPromptedAuthIds);
  }

  /// Selected cloud stable UUID, separate from currentLocalStableId.
  String _selectedCloudStableId = '';
  String get selectedCloudStableId => _selectedCloudStableId;
  set selectedCloudStableId(String value) {
    _selectedCloudStableId = value;
    secureStorage.setString('ff_selectedCloudStableId', value);
  }

  void deleteSelectedCloudStableId() {
    secureStorage.delete(key: 'ff_selectedCloudStableId');
  }

  /// Explicit account-scoped local-to-cloud stable mappings.
  List<LocalStableCloudLinkDataStruct> _localStableCloudLinks = [];
  List<LocalStableCloudLinkDataStruct> get localStableCloudLinks =>
      _localStableCloudLinks;
  set localStableCloudLinks(List<LocalStableCloudLinkDataStruct> value) {
    _localStableCloudLinks = value;
    secureStorage.setStringList(
        'ff_localStableCloudLinks', value.map((x) => x.serialize()).toList());
  }

  void deleteLocalStableCloudLinks() {
    secureStorage.delete(key: 'ff_localStableCloudLinks');
  }

  void addToLocalStableCloudLinks(LocalStableCloudLinkDataStruct value) {
    localStableCloudLinks.add(value);
    secureStorage.setStringList('ff_localStableCloudLinks',
        _localStableCloudLinks.map((x) => x.serialize()).toList());
  }

  void removeFromLocalStableCloudLinks(LocalStableCloudLinkDataStruct value) {
    localStableCloudLinks.remove(value);
    secureStorage.setStringList('ff_localStableCloudLinks',
        _localStableCloudLinks.map((x) => x.serialize()).toList());
  }

  void removeAtIndexFromLocalStableCloudLinks(int index) {
    localStableCloudLinks.removeAt(index);
    secureStorage.setStringList('ff_localStableCloudLinks',
        _localStableCloudLinks.map((x) => x.serialize()).toList());
  }

  void updateLocalStableCloudLinksAtIndex(
    int index,
    LocalStableCloudLinkDataStruct Function(LocalStableCloudLinkDataStruct)
        updateFn,
  ) {
    localStableCloudLinks[index] = updateFn(_localStableCloudLinks[index]);
    secureStorage.setStringList('ff_localStableCloudLinks',
        _localStableCloudLinks.map((x) => x.serialize()).toList());
  }

  void insertAtIndexInLocalStableCloudLinks(
      int index, LocalStableCloudLinkDataStruct value) {
    localStableCloudLinks.insert(index, value);
    secureStorage.setStringList('ff_localStableCloudLinks',
        _localStableCloudLinks.map((x) => x.serialize()).toList());
  }

  /// Offline read-only membership cache; never authorizes mutations.
  List<StableMembershipCacheDataStruct> _stableMembershipCaches = [];
  List<StableMembershipCacheDataStruct> get stableMembershipCaches =>
      _stableMembershipCaches;
  set stableMembershipCaches(List<StableMembershipCacheDataStruct> value) {
    _stableMembershipCaches = value;
    secureStorage.setStringList(
        'ff_stableMembershipCaches', value.map((x) => x.serialize()).toList());
  }

  void deleteStableMembershipCaches() {
    secureStorage.delete(key: 'ff_stableMembershipCaches');
  }

  void addToStableMembershipCaches(StableMembershipCacheDataStruct value) {
    stableMembershipCaches.add(value);
    secureStorage.setStringList('ff_stableMembershipCaches',
        _stableMembershipCaches.map((x) => x.serialize()).toList());
  }

  void removeFromStableMembershipCaches(StableMembershipCacheDataStruct value) {
    stableMembershipCaches.remove(value);
    secureStorage.setStringList('ff_stableMembershipCaches',
        _stableMembershipCaches.map((x) => x.serialize()).toList());
  }

  void removeAtIndexFromStableMembershipCaches(int index) {
    stableMembershipCaches.removeAt(index);
    secureStorage.setStringList('ff_stableMembershipCaches',
        _stableMembershipCaches.map((x) => x.serialize()).toList());
  }

  void updateStableMembershipCachesAtIndex(
    int index,
    StableMembershipCacheDataStruct Function(StableMembershipCacheDataStruct)
        updateFn,
  ) {
    stableMembershipCaches[index] = updateFn(_stableMembershipCaches[index]);
    secureStorage.setStringList('ff_stableMembershipCaches',
        _stableMembershipCaches.map((x) => x.serialize()).toList());
  }

  void insertAtIndexInStableMembershipCaches(
      int index, StableMembershipCacheDataStruct value) {
    stableMembershipCaches.insert(index, value);
    secureStorage.setStringList('ff_stableMembershipCaches',
        _stableMembershipCaches.map((x) => x.serialize()).toList());
  }

  /// Rollback-safe account masters used to filter local operations by explicit
  /// stable link.
  List<LocalAccountScopeDataStruct> _phase4BAccountOperationalBackups = [];
  List<LocalAccountScopeDataStruct> get phase4BAccountOperationalBackups =>
      _phase4BAccountOperationalBackups;
  set phase4BAccountOperationalBackups(
      List<LocalAccountScopeDataStruct> value) {
    _phase4BAccountOperationalBackups = value;
    secureStorage.setStringList('ff_phase4BAccountOperationalBackups',
        value.map((x) => x.serialize()).toList());
  }

  void deletePhase4BAccountOperationalBackups() {
    secureStorage.delete(key: 'ff_phase4BAccountOperationalBackups');
  }

  void addToPhase4BAccountOperationalBackups(
      LocalAccountScopeDataStruct value) {
    phase4BAccountOperationalBackups.add(value);
    secureStorage.setStringList('ff_phase4BAccountOperationalBackups',
        _phase4BAccountOperationalBackups.map((x) => x.serialize()).toList());
  }

  void removeFromPhase4BAccountOperationalBackups(
      LocalAccountScopeDataStruct value) {
    phase4BAccountOperationalBackups.remove(value);
    secureStorage.setStringList('ff_phase4BAccountOperationalBackups',
        _phase4BAccountOperationalBackups.map((x) => x.serialize()).toList());
  }

  void removeAtIndexFromPhase4BAccountOperationalBackups(int index) {
    phase4BAccountOperationalBackups.removeAt(index);
    secureStorage.setStringList('ff_phase4BAccountOperationalBackups',
        _phase4BAccountOperationalBackups.map((x) => x.serialize()).toList());
  }

  void updatePhase4BAccountOperationalBackupsAtIndex(
    int index,
    LocalAccountScopeDataStruct Function(LocalAccountScopeDataStruct) updateFn,
  ) {
    phase4BAccountOperationalBackups[index] =
        updateFn(_phase4BAccountOperationalBackups[index]);
    secureStorage.setStringList('ff_phase4BAccountOperationalBackups',
        _phase4BAccountOperationalBackups.map((x) => x.serialize()).toList());
  }

  void insertAtIndexInPhase4BAccountOperationalBackups(
      int index, LocalAccountScopeDataStruct value) {
    phase4BAccountOperationalBackups.insert(index, value);
    secureStorage.setStringList('ff_phase4BAccountOperationalBackups',
        _phase4BAccountOperationalBackups.map((x) => x.serialize()).toList());
  }

  /// In-memory active, validating, unlinked, removed, suspended or denied
  /// state.
  String _stableAccessStatus = '';
  String get stableAccessStatus => _stableAccessStatus;
  set stableAccessStatus(String value) {
    _stableAccessStatus = value;
  }

  /// Ephemeral one-time invitation hand-off across auth and onboarding; never
  /// persisted.
  String _pendingStableInvitationToken = '';
  String get pendingStableInvitationToken => _pendingStableInvitationToken;
  set pendingStableInvitationToken(String value) {
    _pendingStableInvitationToken = value;
  }

  /// Non-secret invitation UUID used to resume safely after an auth redirect;
  /// server rebinds it to the confirmed email.
  String _pendingStableInvitationId = '';
  String get pendingStableInvitationId => _pendingStableInvitationId;
  set pendingStableInvitationId(String value) {
    _pendingStableInvitationId = value;
    secureStorage.setString('ff_pendingStableInvitationId', value);
  }

  void deletePendingStableInvitationId() {
    secureStorage.delete(key: 'ff_pendingStableInvitationId');
  }

  /// Non-secret create-stable idempotency UUID retained across an ambiguous
  /// reload and cleared only after activation succeeds.
  String _pendingStableCreateRequestId = '';
  String get pendingStableCreateRequestId => _pendingStableCreateRequestId;
  set pendingStableCreateRequestId(String value) {
    _pendingStableCreateRequestId = value;
    secureStorage.setString('ff_pendingStableCreateRequestId', value);
  }

  void deletePendingStableCreateRequestId() {
    secureStorage.delete(key: 'ff_pendingStableCreateRequestId');
  }

  /// Deterministic non-plaintext key binding the retained create-stable request
  /// UUID to one actor and exact payload.
  String _pendingStableCreatePayloadKey = '';
  String get pendingStableCreatePayloadKey => _pendingStableCreatePayloadKey;
  set pendingStableCreatePayloadKey(String value) {
    _pendingStableCreatePayloadKey = value;
    secureStorage.setString('ff_pendingStableCreatePayloadKey', value);
  }

  void deletePendingStableCreatePayloadKey() {
    secureStorage.delete(key: 'ff_pendingStableCreatePayloadKey');
  }
}

void _safeInit(Function() initializeField) {
  try {
    initializeField();
  } catch (_) {}
}

Future _safeInitAsync(Function() initializeField) async {
  try {
    await initializeField();
  } catch (_) {}
}

extension FlutterSecureStorageExtensions on FlutterSecureStorage {
  static final _lock = Lock();

  Future<void> writeSync({required String key, String? value}) async =>
      await _lock.synchronized(() async {
        await write(key: key, value: value);
      });

  void remove(String key) => delete(key: key);

  Future<String?> getString(String key) async => await read(key: key);
  Future<void> setString(String key, String value) async =>
      await writeSync(key: key, value: value);

  Future<bool?> getBool(String key) async => (await read(key: key)) == 'true';
  Future<void> setBool(String key, bool value) async =>
      await writeSync(key: key, value: value.toString());

  Future<int?> getInt(String key) async =>
      int.tryParse(await read(key: key) ?? '');
  Future<void> setInt(String key, int value) async =>
      await writeSync(key: key, value: value.toString());

  Future<double?> getDouble(String key) async =>
      double.tryParse(await read(key: key) ?? '');
  Future<void> setDouble(String key, double value) async =>
      await writeSync(key: key, value: value.toString());

  Future<List<String>?> getStringList(String key) async =>
      await read(key: key).then((result) {
        if (result == null || result.isEmpty) {
          return null;
        }
        return CsvToListConverter()
            .convert(result)
            .first
            .map((e) => e.toString())
            .toList();
      });
  Future<void> setStringList(String key, List<String> value) async =>
      await writeSync(key: key, value: ListToCsvConverter().convert([value]));
}

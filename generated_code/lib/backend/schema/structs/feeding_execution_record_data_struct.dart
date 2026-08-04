// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// One immutable-snapshot execution result per stable, horse, local date and
/// round.
class FeedingExecutionRecordDataStruct extends BaseStruct {
  FeedingExecutionRecordDataStruct({
    /// Stable logical execution-record identifier.
    String? id,

    /// Stable identifier that owns this execution result.
    String? stableId,

    /// Existing horse identifier processed in this round.
    int? horseId,

    /// Normalized local feeding date.
    DateTime? feedingDate,

    /// Stable feeding-round identifier.
    String? roundId,

    /// Persisted result status: completed or deviation.
    String? resultStatus,

    /// Actual local user who recorded this result.
    String? performedByUserId,

    /// Exact local timestamp when the result was recorded.
    DateTime? performedAt,

    /// Responsible user resolved at execution time; may be empty.
    String? resolvedResponsibleUserId,

    /// Effective schedule source: standard or temporary.
    String? scheduleSource,

    /// Applicable temporary schedule ID, empty for standard schedules.
    String? temporaryScheduleId,

    /// Immutable snapshot of every feeding instruction shown at execution.
    List<FeedingItemDataStruct>? scheduleItems,

    /// Optional normalized deviation type.
    String? deviationType,

    /// Optional user-entered deviation note.
    String? deviationNote,

    /// Whether this logical result was explicitly reopened or undone.
    bool? isReopened,

    /// Local timestamp of the explicit reopen action.
    DateTime? reopenedAt,

    /// Actual local user who reopened this logical result.
    String? reopenedByUserId,

    /// Local timestamp when this logical result was created.
    DateTime? createdAt,

    /// Local timestamp of the most recent explicit state change.
    DateTime? updatedAt,

    /// Additive local Phase 2 schema version.
    int? schemaVersion,
  })  : _id = id,
        _stableId = stableId,
        _horseId = horseId,
        _feedingDate = feedingDate,
        _roundId = roundId,
        _resultStatus = resultStatus,
        _performedByUserId = performedByUserId,
        _performedAt = performedAt,
        _resolvedResponsibleUserId = resolvedResponsibleUserId,
        _scheduleSource = scheduleSource,
        _temporaryScheduleId = temporaryScheduleId,
        _scheduleItems = scheduleItems,
        _deviationType = deviationType,
        _deviationNote = deviationNote,
        _isReopened = isReopened,
        _reopenedAt = reopenedAt,
        _reopenedByUserId = reopenedByUserId,
        _createdAt = createdAt,
        _updatedAt = updatedAt,
        _schemaVersion = schemaVersion;

  // "id" field.
  String? _id;
  String get id => _id ?? '';
  set id(String? val) => _id = val;

  bool hasId() => _id != null;

  // "stableId" field.
  String? _stableId;
  String get stableId => _stableId ?? '';
  set stableId(String? val) => _stableId = val;

  bool hasStableId() => _stableId != null;

  // "horseId" field.
  int? _horseId;
  int get horseId => _horseId ?? 0;
  set horseId(int? val) => _horseId = val;

  void incrementHorseId(int amount) => horseId = horseId + amount;

  bool hasHorseId() => _horseId != null;

  // "feedingDate" field.
  DateTime? _feedingDate;
  DateTime? get feedingDate => _feedingDate;
  set feedingDate(DateTime? val) => _feedingDate = val;

  bool hasFeedingDate() => _feedingDate != null;

  // "roundId" field.
  String? _roundId;
  String get roundId => _roundId ?? '';
  set roundId(String? val) => _roundId = val;

  bool hasRoundId() => _roundId != null;

  // "resultStatus" field.
  String? _resultStatus;
  String get resultStatus => _resultStatus ?? '';
  set resultStatus(String? val) => _resultStatus = val;

  bool hasResultStatus() => _resultStatus != null;

  // "performedByUserId" field.
  String? _performedByUserId;
  String get performedByUserId => _performedByUserId ?? '';
  set performedByUserId(String? val) => _performedByUserId = val;

  bool hasPerformedByUserId() => _performedByUserId != null;

  // "performedAt" field.
  DateTime? _performedAt;
  DateTime? get performedAt => _performedAt;
  set performedAt(DateTime? val) => _performedAt = val;

  bool hasPerformedAt() => _performedAt != null;

  // "resolvedResponsibleUserId" field.
  String? _resolvedResponsibleUserId;
  String get resolvedResponsibleUserId => _resolvedResponsibleUserId ?? '';
  set resolvedResponsibleUserId(String? val) =>
      _resolvedResponsibleUserId = val;

  bool hasResolvedResponsibleUserId() => _resolvedResponsibleUserId != null;

  // "scheduleSource" field.
  String? _scheduleSource;
  String get scheduleSource => _scheduleSource ?? '';
  set scheduleSource(String? val) => _scheduleSource = val;

  bool hasScheduleSource() => _scheduleSource != null;

  // "temporaryScheduleId" field.
  String? _temporaryScheduleId;
  String get temporaryScheduleId => _temporaryScheduleId ?? '';
  set temporaryScheduleId(String? val) => _temporaryScheduleId = val;

  bool hasTemporaryScheduleId() => _temporaryScheduleId != null;

  // "scheduleItems" field.
  List<FeedingItemDataStruct>? _scheduleItems;
  List<FeedingItemDataStruct> get scheduleItems => _scheduleItems ?? const [];
  set scheduleItems(List<FeedingItemDataStruct>? val) => _scheduleItems = val;

  void updateScheduleItems(Function(List<FeedingItemDataStruct>) updateFn) {
    updateFn(_scheduleItems ??= []);
  }

  bool hasScheduleItems() => _scheduleItems != null;

  // "deviationType" field.
  String? _deviationType;
  String get deviationType => _deviationType ?? '';
  set deviationType(String? val) => _deviationType = val;

  bool hasDeviationType() => _deviationType != null;

  // "deviationNote" field.
  String? _deviationNote;
  String get deviationNote => _deviationNote ?? '';
  set deviationNote(String? val) => _deviationNote = val;

  bool hasDeviationNote() => _deviationNote != null;

  // "isReopened" field.
  bool? _isReopened;
  bool get isReopened => _isReopened ?? false;
  set isReopened(bool? val) => _isReopened = val;

  bool hasIsReopened() => _isReopened != null;

  // "reopenedAt" field.
  DateTime? _reopenedAt;
  DateTime? get reopenedAt => _reopenedAt;
  set reopenedAt(DateTime? val) => _reopenedAt = val;

  bool hasReopenedAt() => _reopenedAt != null;

  // "reopenedByUserId" field.
  String? _reopenedByUserId;
  String get reopenedByUserId => _reopenedByUserId ?? '';
  set reopenedByUserId(String? val) => _reopenedByUserId = val;

  bool hasReopenedByUserId() => _reopenedByUserId != null;

  // "createdAt" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  set createdAt(DateTime? val) => _createdAt = val;

  bool hasCreatedAt() => _createdAt != null;

  // "updatedAt" field.
  DateTime? _updatedAt;
  DateTime? get updatedAt => _updatedAt;
  set updatedAt(DateTime? val) => _updatedAt = val;

  bool hasUpdatedAt() => _updatedAt != null;

  // "schemaVersion" field.
  int? _schemaVersion;
  int get schemaVersion => _schemaVersion ?? 0;
  set schemaVersion(int? val) => _schemaVersion = val;

  void incrementSchemaVersion(int amount) =>
      schemaVersion = schemaVersion + amount;

  bool hasSchemaVersion() => _schemaVersion != null;

  static FeedingExecutionRecordDataStruct fromMap(Map<String, dynamic> data) =>
      FeedingExecutionRecordDataStruct(
        id: data['id'] as String?,
        stableId: data['stableId'] as String?,
        horseId: castToType<int>(data['horseId']),
        feedingDate: data['feedingDate'] as DateTime?,
        roundId: data['roundId'] as String?,
        resultStatus: data['resultStatus'] as String?,
        performedByUserId: data['performedByUserId'] as String?,
        performedAt: data['performedAt'] as DateTime?,
        resolvedResponsibleUserId: data['resolvedResponsibleUserId'] as String?,
        scheduleSource: data['scheduleSource'] as String?,
        temporaryScheduleId: data['temporaryScheduleId'] as String?,
        scheduleItems: getStructList(
          data['scheduleItems'],
          FeedingItemDataStruct.fromMap,
        ),
        deviationType: data['deviationType'] as String?,
        deviationNote: data['deviationNote'] as String?,
        isReopened: data['isReopened'] as bool?,
        reopenedAt: data['reopenedAt'] as DateTime?,
        reopenedByUserId: data['reopenedByUserId'] as String?,
        createdAt: data['createdAt'] as DateTime?,
        updatedAt: data['updatedAt'] as DateTime?,
        schemaVersion: castToType<int>(data['schemaVersion']),
      );

  static FeedingExecutionRecordDataStruct? maybeFromMap(dynamic data) => data
          is Map
      ? FeedingExecutionRecordDataStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'id': _id,
        'stableId': _stableId,
        'horseId': _horseId,
        'feedingDate': _feedingDate,
        'roundId': _roundId,
        'resultStatus': _resultStatus,
        'performedByUserId': _performedByUserId,
        'performedAt': _performedAt,
        'resolvedResponsibleUserId': _resolvedResponsibleUserId,
        'scheduleSource': _scheduleSource,
        'temporaryScheduleId': _temporaryScheduleId,
        'scheduleItems': _scheduleItems?.map((e) => e.toMap()).toList(),
        'deviationType': _deviationType,
        'deviationNote': _deviationNote,
        'isReopened': _isReopened,
        'reopenedAt': _reopenedAt,
        'reopenedByUserId': _reopenedByUserId,
        'createdAt': _createdAt,
        'updatedAt': _updatedAt,
        'schemaVersion': _schemaVersion,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'id': serializeParam(
          _id,
          ParamType.String,
        ),
        'stableId': serializeParam(
          _stableId,
          ParamType.String,
        ),
        'horseId': serializeParam(
          _horseId,
          ParamType.int,
        ),
        'feedingDate': serializeParam(
          _feedingDate,
          ParamType.DateTime,
        ),
        'roundId': serializeParam(
          _roundId,
          ParamType.String,
        ),
        'resultStatus': serializeParam(
          _resultStatus,
          ParamType.String,
        ),
        'performedByUserId': serializeParam(
          _performedByUserId,
          ParamType.String,
        ),
        'performedAt': serializeParam(
          _performedAt,
          ParamType.DateTime,
        ),
        'resolvedResponsibleUserId': serializeParam(
          _resolvedResponsibleUserId,
          ParamType.String,
        ),
        'scheduleSource': serializeParam(
          _scheduleSource,
          ParamType.String,
        ),
        'temporaryScheduleId': serializeParam(
          _temporaryScheduleId,
          ParamType.String,
        ),
        'scheduleItems': serializeParam(
          _scheduleItems,
          ParamType.DataStruct,
          isList: true,
        ),
        'deviationType': serializeParam(
          _deviationType,
          ParamType.String,
        ),
        'deviationNote': serializeParam(
          _deviationNote,
          ParamType.String,
        ),
        'isReopened': serializeParam(
          _isReopened,
          ParamType.bool,
        ),
        'reopenedAt': serializeParam(
          _reopenedAt,
          ParamType.DateTime,
        ),
        'reopenedByUserId': serializeParam(
          _reopenedByUserId,
          ParamType.String,
        ),
        'createdAt': serializeParam(
          _createdAt,
          ParamType.DateTime,
        ),
        'updatedAt': serializeParam(
          _updatedAt,
          ParamType.DateTime,
        ),
        'schemaVersion': serializeParam(
          _schemaVersion,
          ParamType.int,
        ),
      }.withoutNulls;

  static FeedingExecutionRecordDataStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      FeedingExecutionRecordDataStruct(
        id: deserializeParam(
          data['id'],
          ParamType.String,
          false,
        ),
        stableId: deserializeParam(
          data['stableId'],
          ParamType.String,
          false,
        ),
        horseId: deserializeParam(
          data['horseId'],
          ParamType.int,
          false,
        ),
        feedingDate: deserializeParam(
          data['feedingDate'],
          ParamType.DateTime,
          false,
        ),
        roundId: deserializeParam(
          data['roundId'],
          ParamType.String,
          false,
        ),
        resultStatus: deserializeParam(
          data['resultStatus'],
          ParamType.String,
          false,
        ),
        performedByUserId: deserializeParam(
          data['performedByUserId'],
          ParamType.String,
          false,
        ),
        performedAt: deserializeParam(
          data['performedAt'],
          ParamType.DateTime,
          false,
        ),
        resolvedResponsibleUserId: deserializeParam(
          data['resolvedResponsibleUserId'],
          ParamType.String,
          false,
        ),
        scheduleSource: deserializeParam(
          data['scheduleSource'],
          ParamType.String,
          false,
        ),
        temporaryScheduleId: deserializeParam(
          data['temporaryScheduleId'],
          ParamType.String,
          false,
        ),
        scheduleItems: deserializeStructParam<FeedingItemDataStruct>(
          data['scheduleItems'],
          ParamType.DataStruct,
          true,
          structBuilder: FeedingItemDataStruct.fromSerializableMap,
        ),
        deviationType: deserializeParam(
          data['deviationType'],
          ParamType.String,
          false,
        ),
        deviationNote: deserializeParam(
          data['deviationNote'],
          ParamType.String,
          false,
        ),
        isReopened: deserializeParam(
          data['isReopened'],
          ParamType.bool,
          false,
        ),
        reopenedAt: deserializeParam(
          data['reopenedAt'],
          ParamType.DateTime,
          false,
        ),
        reopenedByUserId: deserializeParam(
          data['reopenedByUserId'],
          ParamType.String,
          false,
        ),
        createdAt: deserializeParam(
          data['createdAt'],
          ParamType.DateTime,
          false,
        ),
        updatedAt: deserializeParam(
          data['updatedAt'],
          ParamType.DateTime,
          false,
        ),
        schemaVersion: deserializeParam(
          data['schemaVersion'],
          ParamType.int,
          false,
        ),
      );

  @override
  String toString() => 'FeedingExecutionRecordDataStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is FeedingExecutionRecordDataStruct &&
        id == other.id &&
        stableId == other.stableId &&
        horseId == other.horseId &&
        feedingDate == other.feedingDate &&
        roundId == other.roundId &&
        resultStatus == other.resultStatus &&
        performedByUserId == other.performedByUserId &&
        performedAt == other.performedAt &&
        resolvedResponsibleUserId == other.resolvedResponsibleUserId &&
        scheduleSource == other.scheduleSource &&
        temporaryScheduleId == other.temporaryScheduleId &&
        listEquality.equals(scheduleItems, other.scheduleItems) &&
        deviationType == other.deviationType &&
        deviationNote == other.deviationNote &&
        isReopened == other.isReopened &&
        reopenedAt == other.reopenedAt &&
        reopenedByUserId == other.reopenedByUserId &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt &&
        schemaVersion == other.schemaVersion;
  }

  @override
  int get hashCode => const ListEquality().hash([
        id,
        stableId,
        horseId,
        feedingDate,
        roundId,
        resultStatus,
        performedByUserId,
        performedAt,
        resolvedResponsibleUserId,
        scheduleSource,
        temporaryScheduleId,
        scheduleItems,
        deviationType,
        deviationNote,
        isReopened,
        reopenedAt,
        reopenedByUserId,
        createdAt,
        updatedAt,
        schemaVersion
      ]);
}

FeedingExecutionRecordDataStruct createFeedingExecutionRecordDataStruct({
  String? id,
  String? stableId,
  int? horseId,
  DateTime? feedingDate,
  String? roundId,
  String? resultStatus,
  String? performedByUserId,
  DateTime? performedAt,
  String? resolvedResponsibleUserId,
  String? scheduleSource,
  String? temporaryScheduleId,
  String? deviationType,
  String? deviationNote,
  bool? isReopened,
  DateTime? reopenedAt,
  String? reopenedByUserId,
  DateTime? createdAt,
  DateTime? updatedAt,
  int? schemaVersion,
}) =>
    FeedingExecutionRecordDataStruct(
      id: id,
      stableId: stableId,
      horseId: horseId,
      feedingDate: feedingDate,
      roundId: roundId,
      resultStatus: resultStatus,
      performedByUserId: performedByUserId,
      performedAt: performedAt,
      resolvedResponsibleUserId: resolvedResponsibleUserId,
      scheduleSource: scheduleSource,
      temporaryScheduleId: temporaryScheduleId,
      deviationType: deviationType,
      deviationNote: deviationNote,
      isReopened: isReopened,
      reopenedAt: reopenedAt,
      reopenedByUserId: reopenedByUserId,
      createdAt: createdAt,
      updatedAt: updatedAt,
      schemaVersion: schemaVersion,
    );

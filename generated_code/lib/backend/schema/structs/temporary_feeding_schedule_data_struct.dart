// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// Date-ranged, round-specific feeding overrides stored as independent
/// snapshots.
class TemporaryFeedingScheduleDataStruct extends BaseStruct {
  TemporaryFeedingScheduleDataStruct({
    /// Unique identifier for this temporary schedule.
    String? id,

    /// Stable identifier that owns this temporary schedule.
    String? stableId,

    /// Existing horse identifier affected by this schedule.
    int? horseId,

    /// Inclusive local first date of the temporary schedule.
    DateTime? startDate,

    /// Inclusive local final date of the temporary schedule.
    DateTime? endDate,

    /// Stable identifiers of every feeding round overridden by this schedule.
    List<String>? affectedRoundIds,

    /// Self-contained round snapshots copied and then edited as a draft.
    List<FeedingRoundSnapshotDataStruct>? roundSnapshots,

    /// Optional user-entered reason for the temporary change.
    String? reason,

    /// Optional user-entered note for the temporary change.
    String? note,

    /// Additive local nutrition schema version.
    int? schemaVersion,

    /// Local timestamp when this schedule was first saved.
    DateTime? createdAt,

    /// Local timestamp of the most recent successful save.
    DateTime? updatedAt,
  })  : _id = id,
        _stableId = stableId,
        _horseId = horseId,
        _startDate = startDate,
        _endDate = endDate,
        _affectedRoundIds = affectedRoundIds,
        _roundSnapshots = roundSnapshots,
        _reason = reason,
        _note = note,
        _schemaVersion = schemaVersion,
        _createdAt = createdAt,
        _updatedAt = updatedAt;

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

  // "startDate" field.
  DateTime? _startDate;
  DateTime? get startDate => _startDate;
  set startDate(DateTime? val) => _startDate = val;

  bool hasStartDate() => _startDate != null;

  // "endDate" field.
  DateTime? _endDate;
  DateTime? get endDate => _endDate;
  set endDate(DateTime? val) => _endDate = val;

  bool hasEndDate() => _endDate != null;

  // "affectedRoundIds" field.
  List<String>? _affectedRoundIds;
  List<String> get affectedRoundIds => _affectedRoundIds ?? const [];
  set affectedRoundIds(List<String>? val) => _affectedRoundIds = val;

  void updateAffectedRoundIds(Function(List<String>) updateFn) {
    updateFn(_affectedRoundIds ??= []);
  }

  bool hasAffectedRoundIds() => _affectedRoundIds != null;

  // "roundSnapshots" field.
  List<FeedingRoundSnapshotDataStruct>? _roundSnapshots;
  List<FeedingRoundSnapshotDataStruct> get roundSnapshots =>
      _roundSnapshots ?? const [];
  set roundSnapshots(List<FeedingRoundSnapshotDataStruct>? val) =>
      _roundSnapshots = val;

  void updateRoundSnapshots(
      Function(List<FeedingRoundSnapshotDataStruct>) updateFn) {
    updateFn(_roundSnapshots ??= []);
  }

  bool hasRoundSnapshots() => _roundSnapshots != null;

  // "reason" field.
  String? _reason;
  String get reason => _reason ?? '';
  set reason(String? val) => _reason = val;

  bool hasReason() => _reason != null;

  // "note" field.
  String? _note;
  String get note => _note ?? '';
  set note(String? val) => _note = val;

  bool hasNote() => _note != null;

  // "schemaVersion" field.
  int? _schemaVersion;
  int get schemaVersion => _schemaVersion ?? 0;
  set schemaVersion(int? val) => _schemaVersion = val;

  void incrementSchemaVersion(int amount) =>
      schemaVersion = schemaVersion + amount;

  bool hasSchemaVersion() => _schemaVersion != null;

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

  static TemporaryFeedingScheduleDataStruct fromMap(
          Map<String, dynamic> data) =>
      TemporaryFeedingScheduleDataStruct(
        id: data['id'] as String?,
        stableId: data['stableId'] as String?,
        horseId: castToType<int>(data['horseId']),
        startDate: data['startDate'] as DateTime?,
        endDate: data['endDate'] as DateTime?,
        affectedRoundIds: getDataList(data['affectedRoundIds']),
        roundSnapshots: getStructList(
          data['roundSnapshots'],
          FeedingRoundSnapshotDataStruct.fromMap,
        ),
        reason: data['reason'] as String?,
        note: data['note'] as String?,
        schemaVersion: castToType<int>(data['schemaVersion']),
        createdAt: data['createdAt'] as DateTime?,
        updatedAt: data['updatedAt'] as DateTime?,
      );

  static TemporaryFeedingScheduleDataStruct? maybeFromMap(dynamic data) => data
          is Map
      ? TemporaryFeedingScheduleDataStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'id': _id,
        'stableId': _stableId,
        'horseId': _horseId,
        'startDate': _startDate,
        'endDate': _endDate,
        'affectedRoundIds': _affectedRoundIds,
        'roundSnapshots': _roundSnapshots?.map((e) => e.toMap()).toList(),
        'reason': _reason,
        'note': _note,
        'schemaVersion': _schemaVersion,
        'createdAt': _createdAt,
        'updatedAt': _updatedAt,
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
        'startDate': serializeParam(
          _startDate,
          ParamType.DateTime,
        ),
        'endDate': serializeParam(
          _endDate,
          ParamType.DateTime,
        ),
        'affectedRoundIds': serializeParam(
          _affectedRoundIds,
          ParamType.String,
          isList: true,
        ),
        'roundSnapshots': serializeParam(
          _roundSnapshots,
          ParamType.DataStruct,
          isList: true,
        ),
        'reason': serializeParam(
          _reason,
          ParamType.String,
        ),
        'note': serializeParam(
          _note,
          ParamType.String,
        ),
        'schemaVersion': serializeParam(
          _schemaVersion,
          ParamType.int,
        ),
        'createdAt': serializeParam(
          _createdAt,
          ParamType.DateTime,
        ),
        'updatedAt': serializeParam(
          _updatedAt,
          ParamType.DateTime,
        ),
      }.withoutNulls;

  static TemporaryFeedingScheduleDataStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      TemporaryFeedingScheduleDataStruct(
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
        startDate: deserializeParam(
          data['startDate'],
          ParamType.DateTime,
          false,
        ),
        endDate: deserializeParam(
          data['endDate'],
          ParamType.DateTime,
          false,
        ),
        affectedRoundIds: deserializeParam<String>(
          data['affectedRoundIds'],
          ParamType.String,
          true,
        ),
        roundSnapshots: deserializeStructParam<FeedingRoundSnapshotDataStruct>(
          data['roundSnapshots'],
          ParamType.DataStruct,
          true,
          structBuilder: FeedingRoundSnapshotDataStruct.fromSerializableMap,
        ),
        reason: deserializeParam(
          data['reason'],
          ParamType.String,
          false,
        ),
        note: deserializeParam(
          data['note'],
          ParamType.String,
          false,
        ),
        schemaVersion: deserializeParam(
          data['schemaVersion'],
          ParamType.int,
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
      );

  @override
  String toString() => 'TemporaryFeedingScheduleDataStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is TemporaryFeedingScheduleDataStruct &&
        id == other.id &&
        stableId == other.stableId &&
        horseId == other.horseId &&
        startDate == other.startDate &&
        endDate == other.endDate &&
        listEquality.equals(affectedRoundIds, other.affectedRoundIds) &&
        listEquality.equals(roundSnapshots, other.roundSnapshots) &&
        reason == other.reason &&
        note == other.note &&
        schemaVersion == other.schemaVersion &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt;
  }

  @override
  int get hashCode => const ListEquality().hash([
        id,
        stableId,
        horseId,
        startDate,
        endDate,
        affectedRoundIds,
        roundSnapshots,
        reason,
        note,
        schemaVersion,
        createdAt,
        updatedAt
      ]);
}

TemporaryFeedingScheduleDataStruct createTemporaryFeedingScheduleDataStruct({
  String? id,
  String? stableId,
  int? horseId,
  DateTime? startDate,
  DateTime? endDate,
  String? reason,
  String? note,
  int? schemaVersion,
  DateTime? createdAt,
  DateTime? updatedAt,
}) =>
    TemporaryFeedingScheduleDataStruct(
      id: id,
      stableId: stableId,
      horseId: horseId,
      startDate: startDate,
      endDate: endDate,
      reason: reason,
      note: note,
      schemaVersion: schemaVersion,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// Persisted standard feeding schedule for one horse in one stable.
class HorseFeedingPlanDataStruct extends BaseStruct {
  HorseFeedingPlanDataStruct({
    /// Unique identifier for the horse feeding plan.
    String? id,

    /// Stable identifier that owns this feeding plan.
    String? stableId,

    /// Existing horse identifier that owns this feeding plan.
    int? horseId,

    /// Standard feeding rounds; supports future custom stable rounds.
    List<FeedingRoundSnapshotDataStruct>? rounds,

    /// Additive local nutrition schema version.
    int? schemaVersion,

    /// Local timestamp of the most recent successful save.
    DateTime? updatedAt,
  })  : _id = id,
        _stableId = stableId,
        _horseId = horseId,
        _rounds = rounds,
        _schemaVersion = schemaVersion,
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

  // "rounds" field.
  List<FeedingRoundSnapshotDataStruct>? _rounds;
  List<FeedingRoundSnapshotDataStruct> get rounds => _rounds ?? const [];
  set rounds(List<FeedingRoundSnapshotDataStruct>? val) => _rounds = val;

  void updateRounds(Function(List<FeedingRoundSnapshotDataStruct>) updateFn) {
    updateFn(_rounds ??= []);
  }

  bool hasRounds() => _rounds != null;

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

  static HorseFeedingPlanDataStruct fromMap(Map<String, dynamic> data) =>
      HorseFeedingPlanDataStruct(
        id: data['id'] as String?,
        stableId: data['stableId'] as String?,
        horseId: castToType<int>(data['horseId']),
        rounds: getStructList(
          data['rounds'],
          FeedingRoundSnapshotDataStruct.fromMap,
        ),
        schemaVersion: castToType<int>(data['schemaVersion']),
        updatedAt: data['updatedAt'] as DateTime?,
      );

  static HorseFeedingPlanDataStruct? maybeFromMap(dynamic data) => data is Map
      ? HorseFeedingPlanDataStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'id': _id,
        'stableId': _stableId,
        'horseId': _horseId,
        'rounds': _rounds?.map((e) => e.toMap()).toList(),
        'schemaVersion': _schemaVersion,
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
        'rounds': serializeParam(
          _rounds,
          ParamType.DataStruct,
          isList: true,
        ),
        'schemaVersion': serializeParam(
          _schemaVersion,
          ParamType.int,
        ),
        'updatedAt': serializeParam(
          _updatedAt,
          ParamType.DateTime,
        ),
      }.withoutNulls;

  static HorseFeedingPlanDataStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      HorseFeedingPlanDataStruct(
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
        rounds: deserializeStructParam<FeedingRoundSnapshotDataStruct>(
          data['rounds'],
          ParamType.DataStruct,
          true,
          structBuilder: FeedingRoundSnapshotDataStruct.fromSerializableMap,
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
      );

  @override
  String toString() => 'HorseFeedingPlanDataStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is HorseFeedingPlanDataStruct &&
        id == other.id &&
        stableId == other.stableId &&
        horseId == other.horseId &&
        listEquality.equals(rounds, other.rounds) &&
        schemaVersion == other.schemaVersion &&
        updatedAt == other.updatedAt;
  }

  @override
  int get hashCode => const ListEquality()
      .hash([id, stableId, horseId, rounds, schemaVersion, updatedAt]);
}

HorseFeedingPlanDataStruct createHorseFeedingPlanDataStruct({
  String? id,
  String? stableId,
  int? horseId,
  int? schemaVersion,
  DateTime? updatedAt,
}) =>
    HorseFeedingPlanDataStruct(
      id: id,
      stableId: stableId,
      horseId: horseId,
      schemaVersion: schemaVersion,
      updatedAt: updatedAt,
    );

// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// Stable-scoped time and default responsibility for one feeding round.
class FeedingRoundConfigDataStruct extends BaseStruct {
  FeedingRoundConfigDataStruct({
    /// Stable identifier that owns this round setting.
    String? stableId,

    /// Stable feeding-round identifier: morning, afternoon or evening.
    String? roundId,

    /// Editable Dutch display label for this feeding round.
    String? displayLabel,

    /// Local time-of-day value used to plan and order the round.
    DateTime? plannedTime,

    /// Stable display order; supports later custom rounds.
    int? sortOrder,

    /// Optional primary responsible stable-member user identifier.
    String? defaultResponsibleUserId,

    /// Whether this configured round is active for the selected stable.
    bool? enabled,

    /// Additive local Phase 2 schema version.
    int? schemaVersion,

    /// Local timestamp of the most recent successful save.
    DateTime? updatedAt,
  })  : _stableId = stableId,
        _roundId = roundId,
        _displayLabel = displayLabel,
        _plannedTime = plannedTime,
        _sortOrder = sortOrder,
        _defaultResponsibleUserId = defaultResponsibleUserId,
        _enabled = enabled,
        _schemaVersion = schemaVersion,
        _updatedAt = updatedAt;

  // "stableId" field.
  String? _stableId;
  String get stableId => _stableId ?? '';
  set stableId(String? val) => _stableId = val;

  bool hasStableId() => _stableId != null;

  // "roundId" field.
  String? _roundId;
  String get roundId => _roundId ?? '';
  set roundId(String? val) => _roundId = val;

  bool hasRoundId() => _roundId != null;

  // "displayLabel" field.
  String? _displayLabel;
  String get displayLabel => _displayLabel ?? '';
  set displayLabel(String? val) => _displayLabel = val;

  bool hasDisplayLabel() => _displayLabel != null;

  // "plannedTime" field.
  DateTime? _plannedTime;
  DateTime? get plannedTime => _plannedTime;
  set plannedTime(DateTime? val) => _plannedTime = val;

  bool hasPlannedTime() => _plannedTime != null;

  // "sortOrder" field.
  int? _sortOrder;
  int get sortOrder => _sortOrder ?? 0;
  set sortOrder(int? val) => _sortOrder = val;

  void incrementSortOrder(int amount) => sortOrder = sortOrder + amount;

  bool hasSortOrder() => _sortOrder != null;

  // "defaultResponsibleUserId" field.
  String? _defaultResponsibleUserId;
  String get defaultResponsibleUserId => _defaultResponsibleUserId ?? '';
  set defaultResponsibleUserId(String? val) => _defaultResponsibleUserId = val;

  bool hasDefaultResponsibleUserId() => _defaultResponsibleUserId != null;

  // "enabled" field.
  bool? _enabled;
  bool get enabled => _enabled ?? false;
  set enabled(bool? val) => _enabled = val;

  bool hasEnabled() => _enabled != null;

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

  static FeedingRoundConfigDataStruct fromMap(Map<String, dynamic> data) =>
      FeedingRoundConfigDataStruct(
        stableId: data['stableId'] as String?,
        roundId: data['roundId'] as String?,
        displayLabel: data['displayLabel'] as String?,
        plannedTime: data['plannedTime'] as DateTime?,
        sortOrder: castToType<int>(data['sortOrder']),
        defaultResponsibleUserId: data['defaultResponsibleUserId'] as String?,
        enabled: data['enabled'] as bool?,
        schemaVersion: castToType<int>(data['schemaVersion']),
        updatedAt: data['updatedAt'] as DateTime?,
      );

  static FeedingRoundConfigDataStruct? maybeFromMap(dynamic data) => data is Map
      ? FeedingRoundConfigDataStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'stableId': _stableId,
        'roundId': _roundId,
        'displayLabel': _displayLabel,
        'plannedTime': _plannedTime,
        'sortOrder': _sortOrder,
        'defaultResponsibleUserId': _defaultResponsibleUserId,
        'enabled': _enabled,
        'schemaVersion': _schemaVersion,
        'updatedAt': _updatedAt,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'stableId': serializeParam(
          _stableId,
          ParamType.String,
        ),
        'roundId': serializeParam(
          _roundId,
          ParamType.String,
        ),
        'displayLabel': serializeParam(
          _displayLabel,
          ParamType.String,
        ),
        'plannedTime': serializeParam(
          _plannedTime,
          ParamType.DateTime,
        ),
        'sortOrder': serializeParam(
          _sortOrder,
          ParamType.int,
        ),
        'defaultResponsibleUserId': serializeParam(
          _defaultResponsibleUserId,
          ParamType.String,
        ),
        'enabled': serializeParam(
          _enabled,
          ParamType.bool,
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

  static FeedingRoundConfigDataStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      FeedingRoundConfigDataStruct(
        stableId: deserializeParam(
          data['stableId'],
          ParamType.String,
          false,
        ),
        roundId: deserializeParam(
          data['roundId'],
          ParamType.String,
          false,
        ),
        displayLabel: deserializeParam(
          data['displayLabel'],
          ParamType.String,
          false,
        ),
        plannedTime: deserializeParam(
          data['plannedTime'],
          ParamType.DateTime,
          false,
        ),
        sortOrder: deserializeParam(
          data['sortOrder'],
          ParamType.int,
          false,
        ),
        defaultResponsibleUserId: deserializeParam(
          data['defaultResponsibleUserId'],
          ParamType.String,
          false,
        ),
        enabled: deserializeParam(
          data['enabled'],
          ParamType.bool,
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
      );

  @override
  String toString() => 'FeedingRoundConfigDataStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is FeedingRoundConfigDataStruct &&
        stableId == other.stableId &&
        roundId == other.roundId &&
        displayLabel == other.displayLabel &&
        plannedTime == other.plannedTime &&
        sortOrder == other.sortOrder &&
        defaultResponsibleUserId == other.defaultResponsibleUserId &&
        enabled == other.enabled &&
        schemaVersion == other.schemaVersion &&
        updatedAt == other.updatedAt;
  }

  @override
  int get hashCode => const ListEquality().hash([
        stableId,
        roundId,
        displayLabel,
        plannedTime,
        sortOrder,
        defaultResponsibleUserId,
        enabled,
        schemaVersion,
        updatedAt
      ]);
}

FeedingRoundConfigDataStruct createFeedingRoundConfigDataStruct({
  String? stableId,
  String? roundId,
  String? displayLabel,
  DateTime? plannedTime,
  int? sortOrder,
  String? defaultResponsibleUserId,
  bool? enabled,
  int? schemaVersion,
  DateTime? updatedAt,
}) =>
    FeedingRoundConfigDataStruct(
      stableId: stableId,
      roundId: roundId,
      displayLabel: displayLabel,
      plannedTime: plannedTime,
      sortOrder: sortOrder,
      defaultResponsibleUserId: defaultResponsibleUserId,
      enabled: enabled,
      schemaVersion: schemaVersion,
      updatedAt: updatedAt,
    );

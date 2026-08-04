// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// Immutable result of resolving feeding-round responsibility.
class ResolvedFeedingResponsibleDataStruct extends BaseStruct {
  ResolvedFeedingResponsibleDataStruct({
    /// Stable identifier used for resolution.
    String? stableId,

    /// Normalized local date used for resolution.
    DateTime? date,

    /// Feeding-round identifier used for resolution.
    String? roundId,

    /// Resolved responsible user ID, empty when unassigned.
    String? resolvedUserId,

    /// Resolution source: default, dateException or unassigned.
    String? source,

    /// Applicable exception identifier, empty for default or unassigned fallback.
    String? exceptionId,
  })  : _stableId = stableId,
        _date = date,
        _roundId = roundId,
        _resolvedUserId = resolvedUserId,
        _source = source,
        _exceptionId = exceptionId;

  // "stableId" field.
  String? _stableId;
  String get stableId => _stableId ?? '';
  set stableId(String? val) => _stableId = val;

  bool hasStableId() => _stableId != null;

  // "date" field.
  DateTime? _date;
  DateTime? get date => _date;
  set date(DateTime? val) => _date = val;

  bool hasDate() => _date != null;

  // "roundId" field.
  String? _roundId;
  String get roundId => _roundId ?? '';
  set roundId(String? val) => _roundId = val;

  bool hasRoundId() => _roundId != null;

  // "resolvedUserId" field.
  String? _resolvedUserId;
  String get resolvedUserId => _resolvedUserId ?? '';
  set resolvedUserId(String? val) => _resolvedUserId = val;

  bool hasResolvedUserId() => _resolvedUserId != null;

  // "source" field.
  String? _source;
  String get source => _source ?? '';
  set source(String? val) => _source = val;

  bool hasSource() => _source != null;

  // "exceptionId" field.
  String? _exceptionId;
  String get exceptionId => _exceptionId ?? '';
  set exceptionId(String? val) => _exceptionId = val;

  bool hasExceptionId() => _exceptionId != null;

  static ResolvedFeedingResponsibleDataStruct fromMap(
          Map<String, dynamic> data) =>
      ResolvedFeedingResponsibleDataStruct(
        stableId: data['stableId'] as String?,
        date: data['date'] as DateTime?,
        roundId: data['roundId'] as String?,
        resolvedUserId: data['resolvedUserId'] as String?,
        source: data['source'] as String?,
        exceptionId: data['exceptionId'] as String?,
      );

  static ResolvedFeedingResponsibleDataStruct? maybeFromMap(dynamic data) =>
      data is Map
          ? ResolvedFeedingResponsibleDataStruct.fromMap(
              data.cast<String, dynamic>())
          : null;

  Map<String, dynamic> toMap() => {
        'stableId': _stableId,
        'date': _date,
        'roundId': _roundId,
        'resolvedUserId': _resolvedUserId,
        'source': _source,
        'exceptionId': _exceptionId,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'stableId': serializeParam(
          _stableId,
          ParamType.String,
        ),
        'date': serializeParam(
          _date,
          ParamType.DateTime,
        ),
        'roundId': serializeParam(
          _roundId,
          ParamType.String,
        ),
        'resolvedUserId': serializeParam(
          _resolvedUserId,
          ParamType.String,
        ),
        'source': serializeParam(
          _source,
          ParamType.String,
        ),
        'exceptionId': serializeParam(
          _exceptionId,
          ParamType.String,
        ),
      }.withoutNulls;

  static ResolvedFeedingResponsibleDataStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      ResolvedFeedingResponsibleDataStruct(
        stableId: deserializeParam(
          data['stableId'],
          ParamType.String,
          false,
        ),
        date: deserializeParam(
          data['date'],
          ParamType.DateTime,
          false,
        ),
        roundId: deserializeParam(
          data['roundId'],
          ParamType.String,
          false,
        ),
        resolvedUserId: deserializeParam(
          data['resolvedUserId'],
          ParamType.String,
          false,
        ),
        source: deserializeParam(
          data['source'],
          ParamType.String,
          false,
        ),
        exceptionId: deserializeParam(
          data['exceptionId'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'ResolvedFeedingResponsibleDataStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is ResolvedFeedingResponsibleDataStruct &&
        stableId == other.stableId &&
        date == other.date &&
        roundId == other.roundId &&
        resolvedUserId == other.resolvedUserId &&
        source == other.source &&
        exceptionId == other.exceptionId;
  }

  @override
  int get hashCode => const ListEquality()
      .hash([stableId, date, roundId, resolvedUserId, source, exceptionId]);
}

ResolvedFeedingResponsibleDataStruct
    createResolvedFeedingResponsibleDataStruct({
  String? stableId,
  DateTime? date,
  String? roundId,
  String? resolvedUserId,
  String? source,
  String? exceptionId,
}) =>
        ResolvedFeedingResponsibleDataStruct(
          stableId: stableId,
          date: date,
          roundId: roundId,
          resolvedUserId: resolvedUserId,
          source: source,
          exceptionId: exceptionId,
        );

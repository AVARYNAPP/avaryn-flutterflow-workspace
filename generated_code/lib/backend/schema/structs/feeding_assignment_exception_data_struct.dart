// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// One stable-, date- and round-scoped responsible-person override.
class FeedingAssignmentExceptionDataStruct extends BaseStruct {
  FeedingAssignmentExceptionDataStruct({
    /// Unique local identifier for this assignment exception.
    String? id,

    /// Stable identifier that owns this exception.
    String? stableId,

    /// One normalized inclusive local calendar date.
    DateTime? date,

    /// Stable feeding-round identifier affected on this date.
    String? roundId,

    /// Replacement stable-member user ID; empty when explicitly unassigned.
    String? replacementResponsibleUserId,

    /// Distinguishes an intentional unassigned exception from no exception.
    bool? explicitlyUnassigned,

    /// Optional short explanation for the date-specific change.
    String? note,

    /// Local timestamp when the exception was first saved.
    DateTime? createdAt,

    /// Local timestamp of the most recent successful save.
    DateTime? updatedAt,
  })  : _id = id,
        _stableId = stableId,
        _date = date,
        _roundId = roundId,
        _replacementResponsibleUserId = replacementResponsibleUserId,
        _explicitlyUnassigned = explicitlyUnassigned,
        _note = note,
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

  // "replacementResponsibleUserId" field.
  String? _replacementResponsibleUserId;
  String get replacementResponsibleUserId =>
      _replacementResponsibleUserId ?? '';
  set replacementResponsibleUserId(String? val) =>
      _replacementResponsibleUserId = val;

  bool hasReplacementResponsibleUserId() =>
      _replacementResponsibleUserId != null;

  // "explicitlyUnassigned" field.
  bool? _explicitlyUnassigned;
  bool get explicitlyUnassigned => _explicitlyUnassigned ?? false;
  set explicitlyUnassigned(bool? val) => _explicitlyUnassigned = val;

  bool hasExplicitlyUnassigned() => _explicitlyUnassigned != null;

  // "note" field.
  String? _note;
  String get note => _note ?? '';
  set note(String? val) => _note = val;

  bool hasNote() => _note != null;

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

  static FeedingAssignmentExceptionDataStruct fromMap(
          Map<String, dynamic> data) =>
      FeedingAssignmentExceptionDataStruct(
        id: data['id'] as String?,
        stableId: data['stableId'] as String?,
        date: data['date'] as DateTime?,
        roundId: data['roundId'] as String?,
        replacementResponsibleUserId:
            data['replacementResponsibleUserId'] as String?,
        explicitlyUnassigned: data['explicitlyUnassigned'] as bool?,
        note: data['note'] as String?,
        createdAt: data['createdAt'] as DateTime?,
        updatedAt: data['updatedAt'] as DateTime?,
      );

  static FeedingAssignmentExceptionDataStruct? maybeFromMap(dynamic data) =>
      data is Map
          ? FeedingAssignmentExceptionDataStruct.fromMap(
              data.cast<String, dynamic>())
          : null;

  Map<String, dynamic> toMap() => {
        'id': _id,
        'stableId': _stableId,
        'date': _date,
        'roundId': _roundId,
        'replacementResponsibleUserId': _replacementResponsibleUserId,
        'explicitlyUnassigned': _explicitlyUnassigned,
        'note': _note,
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
        'date': serializeParam(
          _date,
          ParamType.DateTime,
        ),
        'roundId': serializeParam(
          _roundId,
          ParamType.String,
        ),
        'replacementResponsibleUserId': serializeParam(
          _replacementResponsibleUserId,
          ParamType.String,
        ),
        'explicitlyUnassigned': serializeParam(
          _explicitlyUnassigned,
          ParamType.bool,
        ),
        'note': serializeParam(
          _note,
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
      }.withoutNulls;

  static FeedingAssignmentExceptionDataStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      FeedingAssignmentExceptionDataStruct(
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
        replacementResponsibleUserId: deserializeParam(
          data['replacementResponsibleUserId'],
          ParamType.String,
          false,
        ),
        explicitlyUnassigned: deserializeParam(
          data['explicitlyUnassigned'],
          ParamType.bool,
          false,
        ),
        note: deserializeParam(
          data['note'],
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
      );

  @override
  String toString() => 'FeedingAssignmentExceptionDataStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is FeedingAssignmentExceptionDataStruct &&
        id == other.id &&
        stableId == other.stableId &&
        date == other.date &&
        roundId == other.roundId &&
        replacementResponsibleUserId == other.replacementResponsibleUserId &&
        explicitlyUnassigned == other.explicitlyUnassigned &&
        note == other.note &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt;
  }

  @override
  int get hashCode => const ListEquality().hash([
        id,
        stableId,
        date,
        roundId,
        replacementResponsibleUserId,
        explicitlyUnassigned,
        note,
        createdAt,
        updatedAt
      ]);
}

FeedingAssignmentExceptionDataStruct
    createFeedingAssignmentExceptionDataStruct({
  String? id,
  String? stableId,
  DateTime? date,
  String? roundId,
  String? replacementResponsibleUserId,
  bool? explicitlyUnassigned,
  String? note,
  DateTime? createdAt,
  DateTime? updatedAt,
}) =>
        FeedingAssignmentExceptionDataStruct(
          id: id,
          stableId: stableId,
          date: date,
          roundId: roundId,
          replacementResponsibleUserId: replacementResponsibleUserId,
          explicitlyUnassigned: explicitlyUnassigned,
          note: note,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );

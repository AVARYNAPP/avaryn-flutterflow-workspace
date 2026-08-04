// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// Immutable result of resolving one horse, local date and feeding round.
class EffectiveFeedingScheduleDataStruct extends BaseStruct {
  EffectiveFeedingScheduleDataStruct({
    /// Resolution source: standard or temporary.
    String? sourceType,

    /// Applicable temporary schedule identifier, empty for standard fallback.
    String? temporaryScheduleId,

    /// Resolved stable identifier.
    String? stableId,

    /// Resolved horse identifier.
    int? horseId,

    /// Local date used for schedule resolution.
    DateTime? date,

    /// Resolved stable feeding-round identifier.
    String? roundId,

    /// Applicable round items; an empty list remains an intentional override.
    List<FeedingItemDataStruct>? items,
  })  : _sourceType = sourceType,
        _temporaryScheduleId = temporaryScheduleId,
        _stableId = stableId,
        _horseId = horseId,
        _date = date,
        _roundId = roundId,
        _items = items;

  // "sourceType" field.
  String? _sourceType;
  String get sourceType => _sourceType ?? '';
  set sourceType(String? val) => _sourceType = val;

  bool hasSourceType() => _sourceType != null;

  // "temporaryScheduleId" field.
  String? _temporaryScheduleId;
  String get temporaryScheduleId => _temporaryScheduleId ?? '';
  set temporaryScheduleId(String? val) => _temporaryScheduleId = val;

  bool hasTemporaryScheduleId() => _temporaryScheduleId != null;

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

  // "items" field.
  List<FeedingItemDataStruct>? _items;
  List<FeedingItemDataStruct> get items => _items ?? const [];
  set items(List<FeedingItemDataStruct>? val) => _items = val;

  void updateItems(Function(List<FeedingItemDataStruct>) updateFn) {
    updateFn(_items ??= []);
  }

  bool hasItems() => _items != null;

  static EffectiveFeedingScheduleDataStruct fromMap(
          Map<String, dynamic> data) =>
      EffectiveFeedingScheduleDataStruct(
        sourceType: data['sourceType'] as String?,
        temporaryScheduleId: data['temporaryScheduleId'] as String?,
        stableId: data['stableId'] as String?,
        horseId: castToType<int>(data['horseId']),
        date: data['date'] as DateTime?,
        roundId: data['roundId'] as String?,
        items: getStructList(
          data['items'],
          FeedingItemDataStruct.fromMap,
        ),
      );

  static EffectiveFeedingScheduleDataStruct? maybeFromMap(dynamic data) => data
          is Map
      ? EffectiveFeedingScheduleDataStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'sourceType': _sourceType,
        'temporaryScheduleId': _temporaryScheduleId,
        'stableId': _stableId,
        'horseId': _horseId,
        'date': _date,
        'roundId': _roundId,
        'items': _items?.map((e) => e.toMap()).toList(),
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'sourceType': serializeParam(
          _sourceType,
          ParamType.String,
        ),
        'temporaryScheduleId': serializeParam(
          _temporaryScheduleId,
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
        'date': serializeParam(
          _date,
          ParamType.DateTime,
        ),
        'roundId': serializeParam(
          _roundId,
          ParamType.String,
        ),
        'items': serializeParam(
          _items,
          ParamType.DataStruct,
          isList: true,
        ),
      }.withoutNulls;

  static EffectiveFeedingScheduleDataStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      EffectiveFeedingScheduleDataStruct(
        sourceType: deserializeParam(
          data['sourceType'],
          ParamType.String,
          false,
        ),
        temporaryScheduleId: deserializeParam(
          data['temporaryScheduleId'],
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
        items: deserializeStructParam<FeedingItemDataStruct>(
          data['items'],
          ParamType.DataStruct,
          true,
          structBuilder: FeedingItemDataStruct.fromSerializableMap,
        ),
      );

  @override
  String toString() => 'EffectiveFeedingScheduleDataStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is EffectiveFeedingScheduleDataStruct &&
        sourceType == other.sourceType &&
        temporaryScheduleId == other.temporaryScheduleId &&
        stableId == other.stableId &&
        horseId == other.horseId &&
        date == other.date &&
        roundId == other.roundId &&
        listEquality.equals(items, other.items);
  }

  @override
  int get hashCode => const ListEquality().hash([
        sourceType,
        temporaryScheduleId,
        stableId,
        horseId,
        date,
        roundId,
        items
      ]);
}

EffectiveFeedingScheduleDataStruct createEffectiveFeedingScheduleDataStruct({
  String? sourceType,
  String? temporaryScheduleId,
  String? stableId,
  int? horseId,
  DateTime? date,
  String? roundId,
}) =>
    EffectiveFeedingScheduleDataStruct(
      sourceType: sourceType,
      temporaryScheduleId: temporaryScheduleId,
      stableId: stableId,
      horseId: horseId,
      date: date,
      roundId: roundId,
    );

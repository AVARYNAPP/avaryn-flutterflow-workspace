// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// One extensible feeding round and its ordered item snapshot.
class FeedingRoundSnapshotDataStruct extends BaseStruct {
  FeedingRoundSnapshotDataStruct({
    /// Stable feeding-round identifier such as morning, afternoon or evening.
    String? roundId,

    /// Self-contained items for this feeding round, including an intentionally
    /// empty list.
    List<FeedingItemDataStruct>? items,
  })  : _roundId = roundId,
        _items = items;

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

  static FeedingRoundSnapshotDataStruct fromMap(Map<String, dynamic> data) =>
      FeedingRoundSnapshotDataStruct(
        roundId: data['roundId'] as String?,
        items: getStructList(
          data['items'],
          FeedingItemDataStruct.fromMap,
        ),
      );

  static FeedingRoundSnapshotDataStruct? maybeFromMap(dynamic data) =>
      data is Map
          ? FeedingRoundSnapshotDataStruct.fromMap(data.cast<String, dynamic>())
          : null;

  Map<String, dynamic> toMap() => {
        'roundId': _roundId,
        'items': _items?.map((e) => e.toMap()).toList(),
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
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

  static FeedingRoundSnapshotDataStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      FeedingRoundSnapshotDataStruct(
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
  String toString() => 'FeedingRoundSnapshotDataStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is FeedingRoundSnapshotDataStruct &&
        roundId == other.roundId &&
        listEquality.equals(items, other.items);
  }

  @override
  int get hashCode => const ListEquality().hash([roundId, items]);
}

FeedingRoundSnapshotDataStruct createFeedingRoundSnapshotDataStruct({
  String? roundId,
}) =>
    FeedingRoundSnapshotDataStruct(
      roundId: roundId,
    );

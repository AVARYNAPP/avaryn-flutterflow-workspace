// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// Reusable, horse-scoped feeding item stored in a standard or temporary
/// schedule snapshot.
class FeedingItemDataStruct extends BaseStruct {
  FeedingItemDataStruct({
    /// Unique stable identifier for this feeding item.
    String? id,

    /// Stable feeding category identifier: feed, hay, supplements or medication.
    String? categoryId,

    /// User-entered product or feeding item name.
    String? name,

    /// Measured numeric quantity; ignored for unlimited quantity mode.
    double? quantity,

    /// Explicit quantity mode: measured or unlimited.
    String? quantityMode,

    /// Normalized feeding unit identifier.
    String? unitId,

    /// Optional user-entered label when unitId is custom.
    String? customUnitLabel,

    /// Optional preparation or administration instruction.
    String? instruction,

    /// Optional future reference to an Equinutrition or stable product.
    String? linkedProductId,

    /// Stable display order inside its round and category.
    int? sortOrder,
  })  : _id = id,
        _categoryId = categoryId,
        _name = name,
        _quantity = quantity,
        _quantityMode = quantityMode,
        _unitId = unitId,
        _customUnitLabel = customUnitLabel,
        _instruction = instruction,
        _linkedProductId = linkedProductId,
        _sortOrder = sortOrder;

  // "id" field.
  String? _id;
  String get id => _id ?? '';
  set id(String? val) => _id = val;

  bool hasId() => _id != null;

  // "categoryId" field.
  String? _categoryId;
  String get categoryId => _categoryId ?? '';
  set categoryId(String? val) => _categoryId = val;

  bool hasCategoryId() => _categoryId != null;

  // "name" field.
  String? _name;
  String get name => _name ?? '';
  set name(String? val) => _name = val;

  bool hasName() => _name != null;

  // "quantity" field.
  double? _quantity;
  double get quantity => _quantity ?? 0.0;
  set quantity(double? val) => _quantity = val;

  void incrementQuantity(double amount) => quantity = quantity + amount;

  bool hasQuantity() => _quantity != null;

  // "quantityMode" field.
  String? _quantityMode;
  String get quantityMode => _quantityMode ?? '';
  set quantityMode(String? val) => _quantityMode = val;

  bool hasQuantityMode() => _quantityMode != null;

  // "unitId" field.
  String? _unitId;
  String get unitId => _unitId ?? '';
  set unitId(String? val) => _unitId = val;

  bool hasUnitId() => _unitId != null;

  // "customUnitLabel" field.
  String? _customUnitLabel;
  String get customUnitLabel => _customUnitLabel ?? '';
  set customUnitLabel(String? val) => _customUnitLabel = val;

  bool hasCustomUnitLabel() => _customUnitLabel != null;

  // "instruction" field.
  String? _instruction;
  String get instruction => _instruction ?? '';
  set instruction(String? val) => _instruction = val;

  bool hasInstruction() => _instruction != null;

  // "linkedProductId" field.
  String? _linkedProductId;
  String get linkedProductId => _linkedProductId ?? '';
  set linkedProductId(String? val) => _linkedProductId = val;

  bool hasLinkedProductId() => _linkedProductId != null;

  // "sortOrder" field.
  int? _sortOrder;
  int get sortOrder => _sortOrder ?? 0;
  set sortOrder(int? val) => _sortOrder = val;

  void incrementSortOrder(int amount) => sortOrder = sortOrder + amount;

  bool hasSortOrder() => _sortOrder != null;

  static FeedingItemDataStruct fromMap(Map<String, dynamic> data) =>
      FeedingItemDataStruct(
        id: data['id'] as String?,
        categoryId: data['categoryId'] as String?,
        name: data['name'] as String?,
        quantity: castToType<double>(data['quantity']),
        quantityMode: data['quantityMode'] as String?,
        unitId: data['unitId'] as String?,
        customUnitLabel: data['customUnitLabel'] as String?,
        instruction: data['instruction'] as String?,
        linkedProductId: data['linkedProductId'] as String?,
        sortOrder: castToType<int>(data['sortOrder']),
      );

  static FeedingItemDataStruct? maybeFromMap(dynamic data) => data is Map
      ? FeedingItemDataStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'id': _id,
        'categoryId': _categoryId,
        'name': _name,
        'quantity': _quantity,
        'quantityMode': _quantityMode,
        'unitId': _unitId,
        'customUnitLabel': _customUnitLabel,
        'instruction': _instruction,
        'linkedProductId': _linkedProductId,
        'sortOrder': _sortOrder,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'id': serializeParam(
          _id,
          ParamType.String,
        ),
        'categoryId': serializeParam(
          _categoryId,
          ParamType.String,
        ),
        'name': serializeParam(
          _name,
          ParamType.String,
        ),
        'quantity': serializeParam(
          _quantity,
          ParamType.double,
        ),
        'quantityMode': serializeParam(
          _quantityMode,
          ParamType.String,
        ),
        'unitId': serializeParam(
          _unitId,
          ParamType.String,
        ),
        'customUnitLabel': serializeParam(
          _customUnitLabel,
          ParamType.String,
        ),
        'instruction': serializeParam(
          _instruction,
          ParamType.String,
        ),
        'linkedProductId': serializeParam(
          _linkedProductId,
          ParamType.String,
        ),
        'sortOrder': serializeParam(
          _sortOrder,
          ParamType.int,
        ),
      }.withoutNulls;

  static FeedingItemDataStruct fromSerializableMap(Map<String, dynamic> data) =>
      FeedingItemDataStruct(
        id: deserializeParam(
          data['id'],
          ParamType.String,
          false,
        ),
        categoryId: deserializeParam(
          data['categoryId'],
          ParamType.String,
          false,
        ),
        name: deserializeParam(
          data['name'],
          ParamType.String,
          false,
        ),
        quantity: deserializeParam(
          data['quantity'],
          ParamType.double,
          false,
        ),
        quantityMode: deserializeParam(
          data['quantityMode'],
          ParamType.String,
          false,
        ),
        unitId: deserializeParam(
          data['unitId'],
          ParamType.String,
          false,
        ),
        customUnitLabel: deserializeParam(
          data['customUnitLabel'],
          ParamType.String,
          false,
        ),
        instruction: deserializeParam(
          data['instruction'],
          ParamType.String,
          false,
        ),
        linkedProductId: deserializeParam(
          data['linkedProductId'],
          ParamType.String,
          false,
        ),
        sortOrder: deserializeParam(
          data['sortOrder'],
          ParamType.int,
          false,
        ),
      );

  @override
  String toString() => 'FeedingItemDataStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is FeedingItemDataStruct &&
        id == other.id &&
        categoryId == other.categoryId &&
        name == other.name &&
        quantity == other.quantity &&
        quantityMode == other.quantityMode &&
        unitId == other.unitId &&
        customUnitLabel == other.customUnitLabel &&
        instruction == other.instruction &&
        linkedProductId == other.linkedProductId &&
        sortOrder == other.sortOrder;
  }

  @override
  int get hashCode => const ListEquality().hash([
        id,
        categoryId,
        name,
        quantity,
        quantityMode,
        unitId,
        customUnitLabel,
        instruction,
        linkedProductId,
        sortOrder
      ]);
}

FeedingItemDataStruct createFeedingItemDataStruct({
  String? id,
  String? categoryId,
  String? name,
  double? quantity,
  String? quantityMode,
  String? unitId,
  String? customUnitLabel,
  String? instruction,
  String? linkedProductId,
  int? sortOrder,
}) =>
    FeedingItemDataStruct(
      id: id,
      categoryId: categoryId,
      name: name,
      quantity: quantity,
      quantityMode: quantityMode,
      unitId: unitId,
      customUnitLabel: customUnitLabel,
      instruction: instruction,
      linkedProductId: linkedProductId,
      sortOrder: sortOrder,
    );

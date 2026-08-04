// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// Explicit account-scoped mapping between one cloud stable and one unchanged
/// local stable ID.
class LocalStableCloudLinkDataStruct extends BaseStruct {
  LocalStableCloudLinkDataStruct({
    /// Auth UUID that owns this explicit local mapping.
    String? authUserId,

    /// Selected cloud stable UUID; never a local stable ID.
    String? cloudStableId,

    /// Existing local stable ID preserved byte-for-byte from Phase 1-3.
    String? localStableId,

    /// Per-cloud-stable selected existing local horse ID.
    int? selectedHorseId,

    /// True only after explicit local-to-cloud confirmation.
    bool? confirmed,

    /// Local timestamp of the explicit mapping decision.
    DateTime? linkedAt,
  })  : _authUserId = authUserId,
        _cloudStableId = cloudStableId,
        _localStableId = localStableId,
        _selectedHorseId = selectedHorseId,
        _confirmed = confirmed,
        _linkedAt = linkedAt;

  // "authUserId" field.
  String? _authUserId;
  String get authUserId => _authUserId ?? '';
  set authUserId(String? val) => _authUserId = val;

  bool hasAuthUserId() => _authUserId != null;

  // "cloudStableId" field.
  String? _cloudStableId;
  String get cloudStableId => _cloudStableId ?? '';
  set cloudStableId(String? val) => _cloudStableId = val;

  bool hasCloudStableId() => _cloudStableId != null;

  // "localStableId" field.
  String? _localStableId;
  String get localStableId => _localStableId ?? '';
  set localStableId(String? val) => _localStableId = val;

  bool hasLocalStableId() => _localStableId != null;

  // "selectedHorseId" field.
  int? _selectedHorseId;
  int get selectedHorseId => _selectedHorseId ?? 0;
  set selectedHorseId(int? val) => _selectedHorseId = val;

  void incrementSelectedHorseId(int amount) =>
      selectedHorseId = selectedHorseId + amount;

  bool hasSelectedHorseId() => _selectedHorseId != null;

  // "confirmed" field.
  bool? _confirmed;
  bool get confirmed => _confirmed ?? false;
  set confirmed(bool? val) => _confirmed = val;

  bool hasConfirmed() => _confirmed != null;

  // "linkedAt" field.
  DateTime? _linkedAt;
  DateTime? get linkedAt => _linkedAt;
  set linkedAt(DateTime? val) => _linkedAt = val;

  bool hasLinkedAt() => _linkedAt != null;

  static LocalStableCloudLinkDataStruct fromMap(Map<String, dynamic> data) =>
      LocalStableCloudLinkDataStruct(
        authUserId: data['authUserId'] as String?,
        cloudStableId: data['cloudStableId'] as String?,
        localStableId: data['localStableId'] as String?,
        selectedHorseId: castToType<int>(data['selectedHorseId']),
        confirmed: data['confirmed'] as bool?,
        linkedAt: data['linkedAt'] as DateTime?,
      );

  static LocalStableCloudLinkDataStruct? maybeFromMap(dynamic data) =>
      data is Map
          ? LocalStableCloudLinkDataStruct.fromMap(data.cast<String, dynamic>())
          : null;

  Map<String, dynamic> toMap() => {
        'authUserId': _authUserId,
        'cloudStableId': _cloudStableId,
        'localStableId': _localStableId,
        'selectedHorseId': _selectedHorseId,
        'confirmed': _confirmed,
        'linkedAt': _linkedAt,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'authUserId': serializeParam(
          _authUserId,
          ParamType.String,
        ),
        'cloudStableId': serializeParam(
          _cloudStableId,
          ParamType.String,
        ),
        'localStableId': serializeParam(
          _localStableId,
          ParamType.String,
        ),
        'selectedHorseId': serializeParam(
          _selectedHorseId,
          ParamType.int,
        ),
        'confirmed': serializeParam(
          _confirmed,
          ParamType.bool,
        ),
        'linkedAt': serializeParam(
          _linkedAt,
          ParamType.DateTime,
        ),
      }.withoutNulls;

  static LocalStableCloudLinkDataStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      LocalStableCloudLinkDataStruct(
        authUserId: deserializeParam(
          data['authUserId'],
          ParamType.String,
          false,
        ),
        cloudStableId: deserializeParam(
          data['cloudStableId'],
          ParamType.String,
          false,
        ),
        localStableId: deserializeParam(
          data['localStableId'],
          ParamType.String,
          false,
        ),
        selectedHorseId: deserializeParam(
          data['selectedHorseId'],
          ParamType.int,
          false,
        ),
        confirmed: deserializeParam(
          data['confirmed'],
          ParamType.bool,
          false,
        ),
        linkedAt: deserializeParam(
          data['linkedAt'],
          ParamType.DateTime,
          false,
        ),
      );

  @override
  String toString() => 'LocalStableCloudLinkDataStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is LocalStableCloudLinkDataStruct &&
        authUserId == other.authUserId &&
        cloudStableId == other.cloudStableId &&
        localStableId == other.localStableId &&
        selectedHorseId == other.selectedHorseId &&
        confirmed == other.confirmed &&
        linkedAt == other.linkedAt;
  }

  @override
  int get hashCode => const ListEquality().hash([
        authUserId,
        cloudStableId,
        localStableId,
        selectedHorseId,
        confirmed,
        linkedAt
      ]);
}

LocalStableCloudLinkDataStruct createLocalStableCloudLinkDataStruct({
  String? authUserId,
  String? cloudStableId,
  String? localStableId,
  int? selectedHorseId,
  bool? confirmed,
  DateTime? linkedAt,
}) =>
    LocalStableCloudLinkDataStruct(
      authUserId: authUserId,
      cloudStableId: cloudStableId,
      localStableId: localStableId,
      selectedHorseId: selectedHorseId,
      confirmed: confirmed,
      linkedAt: linkedAt,
    );

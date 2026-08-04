// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// Short-lived offline read-only cache of a validated stable membership
/// without contact data.
class StableMembershipCacheDataStruct extends BaseStruct {
  StableMembershipCacheDataStruct({
    /// Auth UUID that owns this read-only offline cache.
    String? authUserId,

    /// Cloud stable UUID.
    String? stableId,

    /// Last validated non-contact stable label.
    String? stableName,

    /// Last validated organization or personal kind.
    String? stableKind,

    /// Authoritative membership UUID.
    String? membershipId,

    /// Distinct operational stable-member UUID.
    String? stableMemberId,

    /// Last validated role; never trusted for offline writes.
    String? role,

    /// Last validated membership status.
    String? status,

    /// UTC time of the last successful server validation.
    DateTime? lastValidatedAt,
  })  : _authUserId = authUserId,
        _stableId = stableId,
        _stableName = stableName,
        _stableKind = stableKind,
        _membershipId = membershipId,
        _stableMemberId = stableMemberId,
        _role = role,
        _status = status,
        _lastValidatedAt = lastValidatedAt;

  // "authUserId" field.
  String? _authUserId;
  String get authUserId => _authUserId ?? '';
  set authUserId(String? val) => _authUserId = val;

  bool hasAuthUserId() => _authUserId != null;

  // "stableId" field.
  String? _stableId;
  String get stableId => _stableId ?? '';
  set stableId(String? val) => _stableId = val;

  bool hasStableId() => _stableId != null;

  // "stableName" field.
  String? _stableName;
  String get stableName => _stableName ?? '';
  set stableName(String? val) => _stableName = val;

  bool hasStableName() => _stableName != null;

  // "stableKind" field.
  String? _stableKind;
  String get stableKind => _stableKind ?? '';
  set stableKind(String? val) => _stableKind = val;

  bool hasStableKind() => _stableKind != null;

  // "membershipId" field.
  String? _membershipId;
  String get membershipId => _membershipId ?? '';
  set membershipId(String? val) => _membershipId = val;

  bool hasMembershipId() => _membershipId != null;

  // "stableMemberId" field.
  String? _stableMemberId;
  String get stableMemberId => _stableMemberId ?? '';
  set stableMemberId(String? val) => _stableMemberId = val;

  bool hasStableMemberId() => _stableMemberId != null;

  // "role" field.
  String? _role;
  String get role => _role ?? '';
  set role(String? val) => _role = val;

  bool hasRole() => _role != null;

  // "status" field.
  String? _status;
  String get status => _status ?? '';
  set status(String? val) => _status = val;

  bool hasStatus() => _status != null;

  // "lastValidatedAt" field.
  DateTime? _lastValidatedAt;
  DateTime? get lastValidatedAt => _lastValidatedAt;
  set lastValidatedAt(DateTime? val) => _lastValidatedAt = val;

  bool hasLastValidatedAt() => _lastValidatedAt != null;

  static StableMembershipCacheDataStruct fromMap(Map<String, dynamic> data) =>
      StableMembershipCacheDataStruct(
        authUserId: data['authUserId'] as String?,
        stableId: data['stableId'] as String?,
        stableName: data['stableName'] as String?,
        stableKind: data['stableKind'] as String?,
        membershipId: data['membershipId'] as String?,
        stableMemberId: data['stableMemberId'] as String?,
        role: data['role'] as String?,
        status: data['status'] as String?,
        lastValidatedAt: data['lastValidatedAt'] as DateTime?,
      );

  static StableMembershipCacheDataStruct? maybeFromMap(dynamic data) => data
          is Map
      ? StableMembershipCacheDataStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'authUserId': _authUserId,
        'stableId': _stableId,
        'stableName': _stableName,
        'stableKind': _stableKind,
        'membershipId': _membershipId,
        'stableMemberId': _stableMemberId,
        'role': _role,
        'status': _status,
        'lastValidatedAt': _lastValidatedAt,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'authUserId': serializeParam(
          _authUserId,
          ParamType.String,
        ),
        'stableId': serializeParam(
          _stableId,
          ParamType.String,
        ),
        'stableName': serializeParam(
          _stableName,
          ParamType.String,
        ),
        'stableKind': serializeParam(
          _stableKind,
          ParamType.String,
        ),
        'membershipId': serializeParam(
          _membershipId,
          ParamType.String,
        ),
        'stableMemberId': serializeParam(
          _stableMemberId,
          ParamType.String,
        ),
        'role': serializeParam(
          _role,
          ParamType.String,
        ),
        'status': serializeParam(
          _status,
          ParamType.String,
        ),
        'lastValidatedAt': serializeParam(
          _lastValidatedAt,
          ParamType.DateTime,
        ),
      }.withoutNulls;

  static StableMembershipCacheDataStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      StableMembershipCacheDataStruct(
        authUserId: deserializeParam(
          data['authUserId'],
          ParamType.String,
          false,
        ),
        stableId: deserializeParam(
          data['stableId'],
          ParamType.String,
          false,
        ),
        stableName: deserializeParam(
          data['stableName'],
          ParamType.String,
          false,
        ),
        stableKind: deserializeParam(
          data['stableKind'],
          ParamType.String,
          false,
        ),
        membershipId: deserializeParam(
          data['membershipId'],
          ParamType.String,
          false,
        ),
        stableMemberId: deserializeParam(
          data['stableMemberId'],
          ParamType.String,
          false,
        ),
        role: deserializeParam(
          data['role'],
          ParamType.String,
          false,
        ),
        status: deserializeParam(
          data['status'],
          ParamType.String,
          false,
        ),
        lastValidatedAt: deserializeParam(
          data['lastValidatedAt'],
          ParamType.DateTime,
          false,
        ),
      );

  @override
  String toString() => 'StableMembershipCacheDataStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is StableMembershipCacheDataStruct &&
        authUserId == other.authUserId &&
        stableId == other.stableId &&
        stableName == other.stableName &&
        stableKind == other.stableKind &&
        membershipId == other.membershipId &&
        stableMemberId == other.stableMemberId &&
        role == other.role &&
        status == other.status &&
        lastValidatedAt == other.lastValidatedAt;
  }

  @override
  int get hashCode => const ListEquality().hash([
        authUserId,
        stableId,
        stableName,
        stableKind,
        membershipId,
        stableMemberId,
        role,
        status,
        lastValidatedAt
      ]);
}

StableMembershipCacheDataStruct createStableMembershipCacheDataStruct({
  String? authUserId,
  String? stableId,
  String? stableName,
  String? stableKind,
  String? membershipId,
  String? stableMemberId,
  String? role,
  String? status,
  DateTime? lastValidatedAt,
}) =>
    StableMembershipCacheDataStruct(
      authUserId: authUserId,
      stableId: stableId,
      stableName: stableName,
      stableKind: stableKind,
      membershipId: membershipId,
      stableMemberId: stableMemberId,
      role: role,
      status: status,
      lastValidatedAt: lastValidatedAt,
    );

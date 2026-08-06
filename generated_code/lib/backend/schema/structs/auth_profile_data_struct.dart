// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// Cached personal profile owned by one immutable Supabase Auth UUID; it
/// contains no stable role or permission.
class AuthProfileDataStruct extends BaseStruct {
  AuthProfileDataStruct({
    /// Immutable Supabase Auth user UUID.
    String? id,

    /// Optional first name.
    String? firstName,

    /// Optional last name.
    String? lastName,

    /// Safely resolved personal display name.
    String? displayName,

    /// Optional auth-UUID-owned avatar object path.
    String? avatarObjectPath,

    /// Optional E.164 telephone number.
    String? phoneE164,

    /// Personal interface locale.
    String? locale,

    /// Personal system, light or dark preference.
    String? themeMode,

    /// Intent only; never a stable membership or role.
    String? onboardingIntent,

    /// Server timestamp for idempotent onboarding completion.
    DateTime? onboardingCompletedAt,

    /// Profile creation timestamp.
    DateTime? createdAt,

    /// Most recent profile update timestamp.
    DateTime? updatedAt,

    /// Durable Account Foundation v2 personal-profile UUID.
    String? profileId,

    /// Personal IANA time-zone identifier.
    String? timeZone,

    /// Server profile lifecycle status; only active profiles enter the app.
    String? profileStatus,

    /// Server-owned access-revocation version.
    int? accessVersion,

    /// Server-owned optimistic-concurrency version.
    int? rowVersion,
  })  : _id = id,
        _firstName = firstName,
        _lastName = lastName,
        _displayName = displayName,
        _avatarObjectPath = avatarObjectPath,
        _phoneE164 = phoneE164,
        _locale = locale,
        _themeMode = themeMode,
        _onboardingIntent = onboardingIntent,
        _onboardingCompletedAt = onboardingCompletedAt,
        _createdAt = createdAt,
        _updatedAt = updatedAt,
        _profileId = profileId,
        _timeZone = timeZone,
        _profileStatus = profileStatus,
        _accessVersion = accessVersion,
        _rowVersion = rowVersion;

  // "id" field.
  String? _id;
  String get id => _id ?? '';
  set id(String? val) => _id = val;

  bool hasId() => _id != null;

  // "firstName" field.
  String? _firstName;
  String get firstName => _firstName ?? '';
  set firstName(String? val) => _firstName = val;

  bool hasFirstName() => _firstName != null;

  // "lastName" field.
  String? _lastName;
  String get lastName => _lastName ?? '';
  set lastName(String? val) => _lastName = val;

  bool hasLastName() => _lastName != null;

  // "displayName" field.
  String? _displayName;
  String get displayName => _displayName ?? '';
  set displayName(String? val) => _displayName = val;

  bool hasDisplayName() => _displayName != null;

  // "avatarObjectPath" field.
  String? _avatarObjectPath;
  String get avatarObjectPath => _avatarObjectPath ?? '';
  set avatarObjectPath(String? val) => _avatarObjectPath = val;

  bool hasAvatarObjectPath() => _avatarObjectPath != null;

  // "phoneE164" field.
  String? _phoneE164;
  String get phoneE164 => _phoneE164 ?? '';
  set phoneE164(String? val) => _phoneE164 = val;

  bool hasPhoneE164() => _phoneE164 != null;

  // "locale" field.
  String? _locale;
  String get locale => _locale ?? '';
  set locale(String? val) => _locale = val;

  bool hasLocale() => _locale != null;

  // "themeMode" field.
  String? _themeMode;
  String get themeMode => _themeMode ?? '';
  set themeMode(String? val) => _themeMode = val;

  bool hasThemeMode() => _themeMode != null;

  // "onboardingIntent" field.
  String? _onboardingIntent;
  String get onboardingIntent => _onboardingIntent ?? '';
  set onboardingIntent(String? val) => _onboardingIntent = val;

  bool hasOnboardingIntent() => _onboardingIntent != null;

  // "onboardingCompletedAt" field.
  DateTime? _onboardingCompletedAt;
  DateTime? get onboardingCompletedAt => _onboardingCompletedAt;
  set onboardingCompletedAt(DateTime? val) => _onboardingCompletedAt = val;

  bool hasOnboardingCompletedAt() => _onboardingCompletedAt != null;

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

  // "profileId" field.
  String? _profileId;
  String get profileId => _profileId ?? '';
  set profileId(String? val) => _profileId = val;

  bool hasProfileId() => _profileId != null;

  // "timeZone" field.
  String? _timeZone;
  String get timeZone => _timeZone ?? '';
  set timeZone(String? val) => _timeZone = val;

  bool hasTimeZone() => _timeZone != null;

  // "profileStatus" field.
  String? _profileStatus;
  String get profileStatus => _profileStatus ?? '';
  set profileStatus(String? val) => _profileStatus = val;

  bool hasProfileStatus() => _profileStatus != null;

  // "accessVersion" field.
  int? _accessVersion;
  int get accessVersion => _accessVersion ?? 0;
  set accessVersion(int? val) => _accessVersion = val;

  void incrementAccessVersion(int amount) =>
      accessVersion = accessVersion + amount;

  bool hasAccessVersion() => _accessVersion != null;

  // "rowVersion" field.
  int? _rowVersion;
  int get rowVersion => _rowVersion ?? 0;
  set rowVersion(int? val) => _rowVersion = val;

  void incrementRowVersion(int amount) => rowVersion = rowVersion + amount;

  bool hasRowVersion() => _rowVersion != null;

  static AuthProfileDataStruct fromMap(Map<String, dynamic> data) =>
      AuthProfileDataStruct(
        id: data['id'] as String?,
        firstName: data['firstName'] as String?,
        lastName: data['lastName'] as String?,
        displayName: data['displayName'] as String?,
        avatarObjectPath: data['avatarObjectPath'] as String?,
        phoneE164: data['phoneE164'] as String?,
        locale: data['locale'] as String?,
        themeMode: data['themeMode'] as String?,
        onboardingIntent: data['onboardingIntent'] as String?,
        onboardingCompletedAt: data['onboardingCompletedAt'] as DateTime?,
        createdAt: data['createdAt'] as DateTime?,
        updatedAt: data['updatedAt'] as DateTime?,
        profileId: data['profileId'] as String?,
        timeZone: data['timeZone'] as String?,
        profileStatus: data['profileStatus'] as String?,
        accessVersion: castToType<int>(data['accessVersion']),
        rowVersion: castToType<int>(data['rowVersion']),
      );

  static AuthProfileDataStruct? maybeFromMap(dynamic data) => data is Map
      ? AuthProfileDataStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'id': _id,
        'firstName': _firstName,
        'lastName': _lastName,
        'displayName': _displayName,
        'avatarObjectPath': _avatarObjectPath,
        'phoneE164': _phoneE164,
        'locale': _locale,
        'themeMode': _themeMode,
        'onboardingIntent': _onboardingIntent,
        'onboardingCompletedAt': _onboardingCompletedAt,
        'createdAt': _createdAt,
        'updatedAt': _updatedAt,
        'profileId': _profileId,
        'timeZone': _timeZone,
        'profileStatus': _profileStatus,
        'accessVersion': _accessVersion,
        'rowVersion': _rowVersion,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'id': serializeParam(
          _id,
          ParamType.String,
        ),
        'firstName': serializeParam(
          _firstName,
          ParamType.String,
        ),
        'lastName': serializeParam(
          _lastName,
          ParamType.String,
        ),
        'displayName': serializeParam(
          _displayName,
          ParamType.String,
        ),
        'avatarObjectPath': serializeParam(
          _avatarObjectPath,
          ParamType.String,
        ),
        'phoneE164': serializeParam(
          _phoneE164,
          ParamType.String,
        ),
        'locale': serializeParam(
          _locale,
          ParamType.String,
        ),
        'themeMode': serializeParam(
          _themeMode,
          ParamType.String,
        ),
        'onboardingIntent': serializeParam(
          _onboardingIntent,
          ParamType.String,
        ),
        'onboardingCompletedAt': serializeParam(
          _onboardingCompletedAt,
          ParamType.DateTime,
        ),
        'createdAt': serializeParam(
          _createdAt,
          ParamType.DateTime,
        ),
        'updatedAt': serializeParam(
          _updatedAt,
          ParamType.DateTime,
        ),
        'profileId': serializeParam(
          _profileId,
          ParamType.String,
        ),
        'timeZone': serializeParam(
          _timeZone,
          ParamType.String,
        ),
        'profileStatus': serializeParam(
          _profileStatus,
          ParamType.String,
        ),
        'accessVersion': serializeParam(
          _accessVersion,
          ParamType.int,
        ),
        'rowVersion': serializeParam(
          _rowVersion,
          ParamType.int,
        ),
      }.withoutNulls;

  static AuthProfileDataStruct fromSerializableMap(Map<String, dynamic> data) =>
      AuthProfileDataStruct(
        id: deserializeParam(
          data['id'],
          ParamType.String,
          false,
        ),
        firstName: deserializeParam(
          data['firstName'],
          ParamType.String,
          false,
        ),
        lastName: deserializeParam(
          data['lastName'],
          ParamType.String,
          false,
        ),
        displayName: deserializeParam(
          data['displayName'],
          ParamType.String,
          false,
        ),
        avatarObjectPath: deserializeParam(
          data['avatarObjectPath'],
          ParamType.String,
          false,
        ),
        phoneE164: deserializeParam(
          data['phoneE164'],
          ParamType.String,
          false,
        ),
        locale: deserializeParam(
          data['locale'],
          ParamType.String,
          false,
        ),
        themeMode: deserializeParam(
          data['themeMode'],
          ParamType.String,
          false,
        ),
        onboardingIntent: deserializeParam(
          data['onboardingIntent'],
          ParamType.String,
          false,
        ),
        onboardingCompletedAt: deserializeParam(
          data['onboardingCompletedAt'],
          ParamType.DateTime,
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
        profileId: deserializeParam(
          data['profileId'],
          ParamType.String,
          false,
        ),
        timeZone: deserializeParam(
          data['timeZone'],
          ParamType.String,
          false,
        ),
        profileStatus: deserializeParam(
          data['profileStatus'],
          ParamType.String,
          false,
        ),
        accessVersion: deserializeParam(
          data['accessVersion'],
          ParamType.int,
          false,
        ),
        rowVersion: deserializeParam(
          data['rowVersion'],
          ParamType.int,
          false,
        ),
      );

  @override
  String toString() => 'AuthProfileDataStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is AuthProfileDataStruct &&
        id == other.id &&
        firstName == other.firstName &&
        lastName == other.lastName &&
        displayName == other.displayName &&
        avatarObjectPath == other.avatarObjectPath &&
        phoneE164 == other.phoneE164 &&
        locale == other.locale &&
        themeMode == other.themeMode &&
        onboardingIntent == other.onboardingIntent &&
        onboardingCompletedAt == other.onboardingCompletedAt &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt &&
        profileId == other.profileId &&
        timeZone == other.timeZone &&
        profileStatus == other.profileStatus &&
        accessVersion == other.accessVersion &&
        rowVersion == other.rowVersion;
  }

  @override
  int get hashCode => const ListEquality().hash([
        id,
        firstName,
        lastName,
        displayName,
        avatarObjectPath,
        phoneE164,
        locale,
        themeMode,
        onboardingIntent,
        onboardingCompletedAt,
        createdAt,
        updatedAt,
        profileId,
        timeZone,
        profileStatus,
        accessVersion,
        rowVersion
      ]);
}

AuthProfileDataStruct createAuthProfileDataStruct({
  String? id,
  String? firstName,
  String? lastName,
  String? displayName,
  String? avatarObjectPath,
  String? phoneE164,
  String? locale,
  String? themeMode,
  String? onboardingIntent,
  DateTime? onboardingCompletedAt,
  DateTime? createdAt,
  DateTime? updatedAt,
  String? profileId,
  String? timeZone,
  String? profileStatus,
  int? accessVersion,
  int? rowVersion,
}) =>
    AuthProfileDataStruct(
      id: id,
      firstName: firstName,
      lastName: lastName,
      displayName: displayName,
      avatarObjectPath: avatarObjectPath,
      phoneE164: phoneE164,
      locale: locale,
      themeMode: themeMode,
      onboardingIntent: onboardingIntent,
      onboardingCompletedAt: onboardingCompletedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      profileId: profileId,
      timeZone: timeZone,
      profileStatus: profileStatus,
      accessVersion: accessVersion,
      rowVersion: rowVersion,
    );

import 'dart:async';
import 'dart:convert';

import 'phase_4b_context_model.dart';
import 'phase_4c7_runtime_contract.dart';
import 'phase_5b1_account_navigation_model.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutterflow_generated/app_state.dart';
import 'package:flutterflow_generated/backend/schema/structs/index.dart';
import 'package:flutterflow_generated/flutter_flow/flutter_flow_theme.dart';
import 'package:flutterflow_generated/flutter_flow/flutter_flow_util.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

const String _c007AlphaPrivacyVersion = 'Alpha 2026-08-07';
const String _phase4ALegacyBackupId = 'legacy-unscoped-backup';
const String _phase4ALegacyLocalUserId = 'local-current-user';
const String _phase4ALegacyStableId = 'local-stable';
const int _phase4ALocalScopeSchemaVersion = 2;
const Duration _phase5PasswordRecoveryLifetime = Duration(minutes: 15);
const List<String> _c007TimeZones = [
  'UTC',
  'Europe/Amsterdam',
  'Europe/Brussels',
  'Europe/Berlin',
  'Europe/London',
  'Europe/Paris',
  'America/New_York',
  'America/Los_Angeles',
  'Asia/Dubai',
  'Australia/Sydney',
];

String _phase5PasswordRecoveryUserId = '';
DateTime? _phase5PasswordRecoveryAuthorizedAt;

String _c007EmailLinkTokenHash(String mode, Uri uri) {
  final expectedType = switch (mode) {
    'callback' => 'email',
    'reset' => 'recovery',
    _ => '',
  };
  if (expectedType.isEmpty || uri.queryParameters['type'] != expectedType) {
    return '';
  }
  final tokenHash = (uri.queryParameters['token_hash'] ?? '').trim();
  if (tokenHash.length < 16 || tokenHash.length > 2048) return '';
  if (tokenHash.runes.any((value) => value < 0x21 || value == 0x7f)) return '';
  return tokenHash;
}

void _phase5ClearPasswordRecoveryAuthorization() {
  _phase5PasswordRecoveryUserId = '';
  _phase5PasswordRecoveryAuthorizedAt = null;
}

bool _phase5AuthorizePasswordRecovery(Session? session) {
  if (session == null) {
    _phase5ClearPasswordRecoveryAuthorization();
    return false;
  }
  _phase5PasswordRecoveryUserId = session.user.id;
  _phase5PasswordRecoveryAuthorizedAt = DateTime.now().toUtc();
  return true;
}

bool _phase5HasPasswordRecoveryAuthorization(Session? session) {
  final authorizedAt = _phase5PasswordRecoveryAuthorizedAt;
  if (session == null ||
      authorizedAt == null ||
      session.user.id != _phase5PasswordRecoveryUserId) {
    return false;
  }
  final age = DateTime.now().toUtc().difference(authorizedAt);
  if (age.isNegative || age > _phase5PasswordRecoveryLifetime) {
    _phase5ClearPasswordRecoveryAuthorization();
    return false;
  }
  return true;
}

Future<void> _phase4APurgeOperationalSecureState(String authUserId) async {
  final normalized = authUserId.trim();
  if (normalized.isEmpty) return;
  const storage = FlutterSecureStorage();
  Object? lastError;
  for (var attempt = 0; attempt < 3; attempt += 1) {
    try {
      final values = await storage.readAll();
      final keys = phase4C7SecureKeysForAccount(values.keys, normalized);
      for (final key in keys) {
        await storage.delete(key: key);
      }
      final remaining = await storage.readAll();
      if (phase4C7SecureKeysForAccount(remaining.keys, normalized).isEmpty) {
        return;
      }
      lastError = StateError('Operational secure-state purge incomplete');
    } catch (error) {
      lastError = error;
    }
    if (attempt < 2) {
      await Future<void>.delayed(Duration(milliseconds: 200 * (attempt + 1)));
    }
  }
  throw StateError(
    'Operational secure-state purge failed after retries: '
    '${lastError.runtimeType}',
  );
}

String _phase4ARedirectUrl(String path) {
  if (kIsWeb) {
    final base = Uri.base;
    return base
        .replace(
          path: path,
          queryParameters: const <String, String>{},
          fragment: '',
        )
        .toString();
  }
  return 'avarynconsumerapp://avarynconsumerapp.com$path';
}

String _phase4ANullableString(dynamic value) =>
    value is String ? value.trim() : '';

DateTime? _phase4ADate(dynamic value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String _phase4ADisplayName(AuthProfileDataStruct profile) {
  final saved = profile.displayName.trim();
  if (saved.isNotEmpty) return saved;
  final composed = '${profile.firstName} ${profile.lastName}'.trim();
  return composed.isEmpty ? 'AVARYN-gebruiker' : composed;
}

String _phase4AFirstName(AuthProfileDataStruct profile) {
  final firstName = profile.firstName.trim();
  if (firstName.isNotEmpty) return firstName;
  final displayName = _phase4ADisplayName(profile);
  final words =
      displayName
          .split(RegExp(r'\s+'))
          .where((word) => word.trim().isNotEmpty)
          .toList();
  return words.isEmpty ? 'daar' : words.first;
}

String _phase4AInitials(AuthProfileDataStruct profile) {
  final words =
      _phase4ADisplayName(
        profile,
      ).split(RegExp(r'\s+')).where((word) => word.trim().isNotEmpty).toList();
  if (words.isEmpty) return 'AV';
  if (words.length == 1) {
    final value = words.first;
    return value.substring(0, value.length.clamp(1, 2)).toUpperCase();
  }
  return '${words.first[0]}${words.last[0]}'.toUpperCase();
}

String _phase4AProviderLabel(String provider) {
  return switch (provider.toLowerCase()) {
    'email' => 'E-mail',
    'google' => 'Google',
    'apple' => 'Apple',
    _ => 'Andere aanmeldmethode',
  };
}

String _phase4AIntentLabel(String intent) {
  return switch (intent) {
    'createStable' => 'Ik wil een nieuwe stal aanmaken',
    'joinStable' => 'Ik heb een uitnodiging ontvangen',
    'individualHorse' => 'Ik beheer voorlopig alleen mijn eigen paard',
    _ => 'Nog niet gekozen',
  };
}

String _phase4AAuthError(Object error) {
  if (error is AuthException) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'E-mailadres of wachtwoord is onjuist.';
    }
    if (message.contains('email not confirmed')) {
      return 'Bevestig eerst je e-mailadres.';
    }
    if (message.contains('password')) {
      return 'Het wachtwoord voldoet niet aan de beveiligingseisen.';
    }
    if (message.contains('rate') || message.contains('too many')) {
      return 'Te veel pogingen. Wacht even en probeer het opnieuw.';
    }
    if (message.contains('network') || message.contains('socket')) {
      return 'Geen netwerkverbinding. Controleer je verbinding en probeer opnieuw.';
    }
  }
  if (error is PostgrestException) {
    if (error.code == '42P01' || error.code == 'PGRST202') {
      return 'Het Account Foundation-profielcontract is nog niet beschikbaar.';
    }
    if (error.code == '40001' ||
        error.message.contains('PROFILE_VERSION_STALE')) {
      return 'Je profiel is intussen gewijzigd. Vernieuw de pagina en probeer opnieuw.';
    }
    if (error.message.contains('AVATAR_PATH_NOT_OWNED')) {
      return 'Het gekozen avatarpad hoort niet bij dit account.';
    }
    if (error.code == '42501' ||
        error.message.contains('ACTIVE_PROFILE_REQUIRED')) {
      return 'Dit account heeft geen actief persoonlijk profiel.';
    }
  }
  if (error.toString().contains('ACTIVE_PROFILE_REQUIRED')) {
    return 'Dit account heeft geen actief persoonlijk profiel.';
  }
  return 'Er ging iets mis. Probeer het opnieuw.';
}

String _phase5AccountDeletionCode(Object error) {
  if (error is! FunctionException) return '';
  dynamic details = error.details;
  if (details is String) {
    try {
      details = jsonDecode(details);
    } catch (_) {
      return '';
    }
  }
  return details is Map ? _phase4ANullableString(details['code']) : '';
}

String _phase5AccountDeletionMessage(String code) {
  return switch (code) {
    'ACTIVE_STABLE_OWNER_REQUIRES_TRANSFER' =>
      'Draag eerst het fictieve staleigenaarschap aantoonbaar over.',
    'ACTIVE_MEMBERSHIPS_REQUIRE_RESOLUTION' =>
      'Verlaat of laat eerst alle actieve fictieve stallen verwijderen.',
    'ACCOUNT_HISTORY_REQUIRES_ADMIN_REVIEW' =>
      'Dit account heeft bewaarde historie en vereist gecontroleerde '
          'beheerdersverwerking.',
    'APPLE_REVOCATION_NOT_CONFIGURED' =>
      'Apple-intrekking is nog niet veilig ingericht; verwijderen blijft '
          'geblokkeerd.',
    'AVATAR_CLEANUP_REQUIRES_ADMIN_REVIEW' =>
      'De profielfoto-opslag vereist gecontroleerde beheerdersverwerking.',
    _ =>
      'Veilige accountverwijdering kon niet worden bevestigd. '
          'Er is niets als verwijderd gemeld.',
  };
}

void _phase5ClearDeletedAccountState(String authUserId) {
  final state = FFAppState();
  state.update(() {
    state.authProfileCaches =
        state.authProfileCaches
            .where((profile) => profile.id != authUserId)
            .toList();
    state.localAccountScopes =
        state.localAccountScopes
            .where((scope) => scope.authUserId != authUserId)
            .toList();
    state.phase4BAccountOperationalBackups =
        state.phase4BAccountOperationalBackups
            .where((scope) => scope.authUserId != authUserId)
            .toList();
    state.stableMembershipCaches =
        state.stableMembershipCaches
            .where((cache) => cache.authUserId != authUserId)
            .toList();
    state.localStableCloudLinks =
        state.localStableCloudLinks
            .where((link) => link.authUserId != authUserId)
            .toList();
    state.activeAuthAccountId = '';
    state.currentAuthProfile = AuthProfileDataStruct();
    state.selectedCloudStableId = '';
    state.pendingStableInvitationToken = '';
    state.pendingStableInvitationId = '';
    state.pendingStableCreateRequestId = '';
    state.pendingStableCreatePayloadKey = '';
    state.stableAccessStatus = 'signed_out';
  });
  _phase4AClearWorkingSet();
}

Map<String, dynamic> _c007SingleRpcRow(dynamic response) {
  if (response is Map) return Map<String, dynamic>.from(response);
  if (response is List && response.length == 1 && response.single is Map) {
    return Map<String, dynamic>.from(response.single as Map);
  }
  throw StateError('ACCOUNT_PROFILE_PROJECTION_INVALID');
}

AuthProfileDataStruct _phase4AProfileFromMap(
  Map<String, dynamic> data, {
  required String authUserId,
}) {
  return AuthProfileDataStruct(
    id: authUserId,
    profileId: _phase4ANullableString(data['profile_id']),
    firstName: _phase4ANullableString(data['first_name']),
    lastName: _phase4ANullableString(data['last_name']),
    displayName: _phase4ANullableString(data['display_name']),
    avatarObjectPath: _phase4ANullableString(data['avatar_object_path']),
    phoneE164: _phase4ANullableString(data['phone_e164']),
    locale:
        _phase4ANullableString(data['locale']).isEmpty
            ? 'nl'
            : _phase4ANullableString(data['locale']),
    timeZone:
        _phase4ANullableString(data['time_zone']).isEmpty
            ? 'UTC'
            : _phase4ANullableString(data['time_zone']),
    themeMode:
        _phase4ANullableString(data['theme_mode']).isEmpty
            ? 'system'
            : _phase4ANullableString(data['theme_mode']),
    onboardingIntent: _phase4ANullableString(data['onboarding_intent']),
    onboardingCompletedAt: _phase4ADate(data['onboarding_completed_at']),
    profileStatus: _phase4ANullableString(data['profile_status']),
    accessVersion:
        data['access_version'] is num
            ? (data['access_version'] as num).toInt()
            : 0,
    rowVersion:
        data['row_version'] is num ? (data['row_version'] as num).toInt() : 0,
    createdAt: _phase4ADate(data['created_at']),
    updatedAt: _phase4ADate(data['updated_at']),
  );
}

List<HorseProfileDataStruct> _phase4ACopyHorses(
  Iterable<HorseProfileDataStruct> values,
) =>
    values
        .map(
          (value) => HorseProfileDataStruct.fromSerializableMap(
            jsonDecode(value.serialize()),
          ),
        )
        .toList();

List<ActivityDataStruct> _phase4ACopyActivities(
  Iterable<ActivityDataStruct> values,
) =>
    values
        .map(
          (value) => ActivityDataStruct.fromSerializableMap(
            jsonDecode(value.serialize()),
          ),
        )
        .toList();

List<HorseFeedingPlanDataStruct> _phase4ACopyFeedingPlans(
  Iterable<HorseFeedingPlanDataStruct> values,
) =>
    values
        .map(
          (value) => HorseFeedingPlanDataStruct.fromSerializableMap(
            jsonDecode(value.serialize()),
          ),
        )
        .toList();

List<TemporaryFeedingScheduleDataStruct> _phase4ACopyTemporarySchedules(
  Iterable<TemporaryFeedingScheduleDataStruct> values,
) =>
    values
        .map(
          (value) => TemporaryFeedingScheduleDataStruct.fromSerializableMap(
            jsonDecode(value.serialize()),
          ),
        )
        .toList();

List<FeedingRoundConfigDataStruct> _phase4ACopyRoundConfigs(
  Iterable<FeedingRoundConfigDataStruct> values,
) =>
    values
        .map(
          (value) => FeedingRoundConfigDataStruct.fromSerializableMap(
            jsonDecode(value.serialize()),
          ),
        )
        .toList();

List<FeedingAssignmentExceptionDataStruct> _phase4ACopyExceptions(
  Iterable<FeedingAssignmentExceptionDataStruct> values,
) =>
    values
        .map(
          (value) => FeedingAssignmentExceptionDataStruct.fromSerializableMap(
            jsonDecode(value.serialize()),
          ),
        )
        .toList();

List<FeedingExecutionRecordDataStruct> _phase4ACopyExecutions(
  Iterable<FeedingExecutionRecordDataStruct> values,
) =>
    values
        .map(
          (value) => FeedingExecutionRecordDataStruct.fromSerializableMap(
            jsonDecode(value.serialize()),
          ),
        )
        .toList();

List<LocalStableCloudLinkDataStruct> _phase4ACopyStableLinks(
  Iterable<LocalStableCloudLinkDataStruct> values,
) =>
    values
        .map(
          (value) => LocalStableCloudLinkDataStruct.fromSerializableMap(
            jsonDecode(value.serialize()),
          ),
        )
        .toList();

List<StableMembershipCacheDataStruct> _phase4ACopyMembershipCaches(
  Iterable<StableMembershipCacheDataStruct> values,
) =>
    values
        .map(
          (value) => StableMembershipCacheDataStruct.fromSerializableMap(
            jsonDecode(value.serialize()),
          ),
        )
        .toList();

HorseProfileDataStruct _phase4ACopyHorse(HorseProfileDataStruct value) =>
    HorseProfileDataStruct.fromSerializableMap(jsonDecode(value.serialize()));

LocalAccountScopeDataStruct _phase4ACaptureScope(String authUserId) {
  final state = FFAppState();
  return LocalAccountScopeDataStruct(
    authUserId: authUserId,
    horses: _phase4ACopyHorses(state.horses),
    selectedHorse: _phase4ACopyHorse(state.selectedHorse),
    selectedHorseIndex: state.selectedHorseIndex,
    nextHorseId: state.nextHorseId,
    nextHorseIndex: state.nextHorseIndex,
    horseSeedVersion: state.horseSeedVersion,
    passportPrototypeVersion: state.passportPrototypeVersion,
    activities: _phase4ACopyActivities(state.activities),
    nextActivityId: state.nextActivityId,
    currentLocalUserId: state.currentLocalUserId,
    currentLocalStableId: state.currentLocalStableId,
    horseFeedingPlans: _phase4ACopyFeedingPlans(state.horseFeedingPlans),
    temporaryFeedingSchedules: _phase4ACopyTemporarySchedules(
      state.temporaryFeedingSchedules,
    ),
    nextFeedingItemId: state.nextFeedingItemId,
    nextTemporaryFeedingScheduleId: state.nextTemporaryFeedingScheduleId,
    feedingRoundConfigs: _phase4ACopyRoundConfigs(state.feedingRoundConfigs),
    feedingAssignmentExceptions: _phase4ACopyExceptions(
      state.feedingAssignmentExceptions,
    ),
    feedingExecutionRecords: _phase4ACopyExecutions(
      state.feedingExecutionRecords,
    ),
    nextFeedingAssignmentExceptionId: state.nextFeedingAssignmentExceptionId,
    nextFeedingExecutionRecordId: state.nextFeedingExecutionRecordId,
    selectedCloudStableId: state.selectedCloudStableId,
    localStableCloudLinks: _phase4ACopyStableLinks(state.localStableCloudLinks),
    stableMembershipCaches: _phase4ACopyMembershipCaches(
      state.stableMembershipCaches,
    ),
    schemaVersion: _phase4ALocalScopeSchemaVersion,
    updatedAt: DateTime.now().toUtc(),
  );
}

bool _phase4AHasOperationalData() {
  final state = FFAppState();
  return state.horses.isNotEmpty ||
      state.activities.isNotEmpty ||
      state.horseFeedingPlans.isNotEmpty ||
      state.temporaryFeedingSchedules.isNotEmpty ||
      state.feedingRoundConfigs.isNotEmpty ||
      state.feedingAssignmentExceptions.isNotEmpty ||
      state.feedingExecutionRecords.isNotEmpty;
}

LocalAccountScopeDataStruct? _phase4AScopeFor(String authUserId) {
  for (final scope in FFAppState().localAccountScopes) {
    if (scope.authUserId == authUserId) return scope;
  }
  return null;
}

void _phase5AccountInvalidateMembershipAuthority(String authUserId) {
  final state = FFAppState();
  final localAccountScopes = List<LocalAccountScopeDataStruct>.from(
    state.localAccountScopes,
  );
  final operationalBackups = List<LocalAccountScopeDataStruct>.from(
    state.phase4BAccountOperationalBackups,
  );

  void sanitizeScopes(List<LocalAccountScopeDataStruct> scopes) {
    for (final scope in scopes) {
      if (scope.authUserId != authUserId) continue;
      scope.selectedCloudStableId = '';
      scope.stableMembershipCaches =
          scope.stableMembershipCaches
              .where((cache) => cache.authUserId != authUserId)
              .toList();
    }
  }

  sanitizeScopes(localAccountScopes);
  sanitizeScopes(operationalBackups);
  state.update(() {
    state.selectedCloudStableId = '';
    state.stableMembershipCaches =
        state.stableMembershipCaches
            .where((cache) => cache.authUserId != authUserId)
            .toList();
    state.localAccountScopes = localAccountScopes;
    state.phase4BAccountOperationalBackups = operationalBackups;
    state.stableAccessStatus = 'access_denied';
  });
}

void _phase4ASaveScope(String authUserId) {
  if (authUserId.trim().isEmpty) return;
  final state = FFAppState();
  final scopes = List<LocalAccountScopeDataStruct>.from(
    state.localAccountScopes,
  )..removeWhere((scope) => scope.authUserId == authUserId);
  scopes.add(_phase4ACaptureScope(authUserId));
  state.localAccountScopes = scopes;
}

LocalAccountScopeDataStruct? _phase4BOperationalMasterFor(String authUserId) {
  for (final scope in FFAppState().phase4BAccountOperationalBackups) {
    if (scope.authUserId == authUserId) return scope;
  }
  return null;
}

void _phase4ASavePhase4BOperationalMaster(String authUserId) {
  if (authUserId.trim().isEmpty) return;
  final selectedCloudStableId = FFAppState().selectedCloudStableId;
  if (selectedCloudStableId.isNotEmpty) {
    final links = List<LocalStableCloudLinkDataStruct>.from(
      FFAppState().localStableCloudLinks,
    );
    for (final link in links) {
      if (link.authUserId == authUserId &&
          link.cloudStableId == selectedCloudStableId &&
          link.confirmed) {
        link.selectedHorseId = FFAppState().selectedHorse.id;
      }
    }
    FFAppState().localStableCloudLinks = links;
  }
  final current = _phase4ACaptureScope(authUserId);
  final existing = _phase4BOperationalMasterFor(authUserId);
  final plan = phase4BPlanSerializedOperationalMasterSave(
    current: current,
    existing: existing,
    toSerializableMap:
        (scope) => jsonDecode(scope.serialize()) as Map<String, dynamic>,
    fromSerializableMap: LocalAccountScopeDataStruct.fromSerializableMap,
  );
  if (!plan.shouldPersist) return;
  final masters = List<LocalAccountScopeDataStruct>.from(
    FFAppState().phase4BAccountOperationalBackups,
  )..removeWhere((scope) => scope.authUserId == authUserId);
  masters.add(plan.master);
  FFAppState().phase4BAccountOperationalBackups = masters;
}

void _phase4AClearWorkingSet() {
  final state = FFAppState();
  state.update(() {
    state.horses = <HorseProfileDataStruct>[];
    state.selectedHorse = HorseProfileDataStruct();
    state.selectedHorseIndex = 0;
    state.nextHorseId = 1;
    state.nextHorseIndex = 0;
    // Prevent the legacy prototype seed from crossing into a new auth scope.
    state.horseSeedVersion = 1;
    state.passportPrototypeVersion = 1;
    state.activities = <ActivityDataStruct>[];
    state.nextActivityId = 1;
    state.selectedActivity = ActivityDataStruct();
    state.selectedActivityIndex = 0;
    state.currentLocalUserId = _phase4ALegacyLocalUserId;
    state.currentLocalStableId = '';
    state.horseFeedingPlans = <HorseFeedingPlanDataStruct>[];
    state.temporaryFeedingSchedules = <TemporaryFeedingScheduleDataStruct>[];
    state.nextFeedingItemId = 1;
    state.nextTemporaryFeedingScheduleId = 1;
    state.feedingRoundConfigs = <FeedingRoundConfigDataStruct>[];
    state.feedingAssignmentExceptions =
        <FeedingAssignmentExceptionDataStruct>[];
    state.feedingExecutionRecords = <FeedingExecutionRecordDataStruct>[];
    state.nextFeedingAssignmentExceptionId = 1;
    state.nextFeedingExecutionRecordId = 1;
    state.selectedFeedingDateKey = '';
    state.selectedFeedingRoundId = 'morning';
    state.selectedCloudStableId = '';
    state.stableAccessStatus = '';
    state.activityDraftHorseId = 0;
    state.activityDraftAssigneeUserIds = <String>[];
    state.activityDraftStartDate = null;
    state.activityDraftEndDate = null;
    state.activityDraftStartTime = null;
    state.activityDraftEndTime = null;
    state.activityDraftAllDay = false;
    state.activityDraftDurationMinutes = 0;
    state.activityDraftLocationType = '';
    state.activityDraftPendingType = '';
    state.activitySaveInProgress = false;
  });
}

void _phase4ALoadScope(LocalAccountScopeDataStruct scope) {
  final state = FFAppState();
  state.update(() {
    state.horses = _phase4ACopyHorses(scope.horses);
    state.selectedHorse = _phase4ACopyHorse(scope.selectedHorse);
    state.selectedHorseIndex = scope.selectedHorseIndex;
    state.nextHorseId = scope.nextHorseId <= 0 ? 1 : scope.nextHorseId;
    state.nextHorseIndex = scope.nextHorseIndex < 0 ? 0 : scope.nextHorseIndex;
    state.horseSeedVersion =
        scope.horseSeedVersion <= 0 ? 1 : scope.horseSeedVersion;
    state.passportPrototypeVersion =
        scope.passportPrototypeVersion <= 0
            ? 1
            : scope.passportPrototypeVersion;
    state.activities = _phase4ACopyActivities(scope.activities);
    state.nextActivityId = scope.nextActivityId <= 0 ? 1 : scope.nextActivityId;
    state.selectedActivity = ActivityDataStruct();
    state.selectedActivityIndex = 0;
    state.currentLocalUserId =
        scope.currentLocalUserId.trim().isEmpty
            ? _phase4ALegacyLocalUserId
            : scope.currentLocalUserId;
    state.currentLocalStableId =
        scope.currentLocalStableId.trim().isEmpty
            ? _phase4ALegacyStableId
            : scope.currentLocalStableId;
    state.horseFeedingPlans = _phase4ACopyFeedingPlans(scope.horseFeedingPlans);
    state.temporaryFeedingSchedules = _phase4ACopyTemporarySchedules(
      scope.temporaryFeedingSchedules,
    );
    state.nextFeedingItemId =
        scope.nextFeedingItemId <= 0 ? 1 : scope.nextFeedingItemId;
    state.nextTemporaryFeedingScheduleId =
        scope.nextTemporaryFeedingScheduleId <= 0
            ? 1
            : scope.nextTemporaryFeedingScheduleId;
    state.feedingRoundConfigs = _phase4ACopyRoundConfigs(
      scope.feedingRoundConfigs,
    );
    state.feedingAssignmentExceptions = _phase4ACopyExceptions(
      scope.feedingAssignmentExceptions,
    );
    state.feedingExecutionRecords = _phase4ACopyExecutions(
      scope.feedingExecutionRecords,
    );
    state.nextFeedingAssignmentExceptionId =
        scope.nextFeedingAssignmentExceptionId <= 0
            ? 1
            : scope.nextFeedingAssignmentExceptionId;
    state.nextFeedingExecutionRecordId =
        scope.nextFeedingExecutionRecordId <= 0
            ? 1
            : scope.nextFeedingExecutionRecordId;
    state.selectedFeedingDateKey = '';
    state.selectedFeedingRoundId = 'morning';
    state.selectedCloudStableId = scope.selectedCloudStableId;
    state.localStableCloudLinks = _phase4ACopyStableLinks(
      scope.localStableCloudLinks,
    );
    state.stableMembershipCaches = _phase4ACopyMembershipCaches(
      scope.stableMembershipCaches,
    );
    state.stableAccessStatus = '';
  });
}

bool _phase4AActivateScope(String authUserId) {
  final state = FFAppState();
  final current = state.activeAuthAccountId.trim();
  if (current == authUserId) {
    return state.hasLegacyLocalDataBackup &&
        !state.legacyDataPromptedAuthIds.contains(authUserId) &&
        _phase4AScopeFor(authUserId)?.horses.isEmpty != false;
  }

  if (current.isNotEmpty) {
    _phase4ASavePhase4BOperationalMaster(current);
    _phase4ASaveScope(current);
  } else if (!state.hasLegacyLocalDataBackup && _phase4AHasOperationalData()) {
    state.legacyLocalDataBackup = _phase4ACaptureScope(_phase4ALegacyBackupId);
    state.hasLegacyLocalDataBackup = true;
  }

  final saved =
      _phase4BOperationalMasterFor(authUserId) ?? _phase4AScopeFor(authUserId);
  if (saved == null) {
    _phase4AClearWorkingSet();
    _phase4ASaveScope(authUserId);
  } else {
    _phase4ALoadScope(saved);
  }
  state.activeAuthAccountId = authUserId;

  return state.hasLegacyLocalDataBackup &&
      !state.legacyDataPromptedAuthIds.contains(authUserId) &&
      saved == null;
}

void _phase4AMarkLegacyPrompted(String authUserId) {
  final state = FFAppState();
  final prompted = List<String>.from(state.legacyDataPromptedAuthIds);
  if (!prompted.contains(authUserId)) prompted.add(authUserId);
  state.legacyDataPromptedAuthIds = prompted;
}

void _phase4AAttachLegacyBackup(String authUserId) {
  final state = FFAppState();
  if (!state.hasLegacyLocalDataBackup) return;
  _phase4ALoadScope(state.legacyLocalDataBackup);
  state.activeAuthAccountId = authUserId;
  _phase4ASaveScope(authUserId);
  _phase4AMarkLegacyPrompted(authUserId);
}

void _phase4ACacheProfile(AuthProfileDataStruct profile) {
  final state = FFAppState();
  final profiles =
      List<AuthProfileDataStruct>.from(state.authProfileCaches)
        ..removeWhere((item) => item.id == profile.id)
        ..add(profile);
  state.authProfileCaches = profiles;
  state.currentAuthProfile = profile;
}

class AvarynAccountRuntime extends StatefulWidget {
  const AvarynAccountRuntime({
    super.key,
    this.width,
    this.height,
    this.mode = 'welcome',
  });

  final double? width;
  final double? height;
  final String mode;

  @override
  State<AvarynAccountRuntime> createState() => _AvarynAccountRuntimeState();
}

class _AvarynAccountRuntimeState extends State<AvarynAccountRuntime> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();

  StreamSubscription<AuthState>? _authSubscription;
  Timer? _cooldownTimer;
  bool _busy = false;
  bool _booting = false;
  bool _passwordHidden = true;
  bool _confirmPasswordHidden = true;
  bool _legacyPrompt = false;
  int _cooldownSeconds = 0;
  int _onboardingStep = 0;
  int _profileRowVersion = 0;
  String _locale = 'nl';
  String _timeZone = 'UTC';
  String _themeMode = 'system';
  String _intent = '';
  String _avatarUrl = '';
  String _emailLinkTokenHash = '';
  bool _recoveryLinkVerified = false;
  String? _error;
  String? _notice;
  AuthProfileDataStruct? _profile;

  SupabaseClient get _client => Supabase.instance.client;

  User? get _user => _client.auth.currentUser;

  bool _phase5IsTerminalSessionError(AuthException error) {
    final status = error.statusCode ?? '';
    if (status == '401' || status == '403' || status == '404') return true;
    final code = (error.code ?? '').toLowerCase();
    final message = error.message.toLowerCase();
    return code == 'user_not_found' ||
        code == 'bad_jwt' ||
        message.contains('user from sub claim') ||
        message.contains('user does not exist') ||
        message.contains('invalid jwt');
  }

  Future<User?> _phase5ValidatedCurrentUser() async {
    final session = _client.auth.currentSession;
    if (session == null) return null;
    try {
      final response = await _client.auth.getUser(session.accessToken);
      return response.user;
    } on AuthException catch (error) {
      if (!_phase5IsTerminalSessionError(error)) {
        // A retryable transport or server outage may use the authenticated
        // offline cache; an explicit 401/403/404 never may.
        return session.user;
      }
      await _phase4APurgeOperationalSecureState(session.user.id);
      _phase5ClearDeletedAccountState(session.user.id);
      // The server has already rejected or removed this identity. Clear the
      // persisted client session without depending on a second server call.
      await _client.auth.signOut(scope: SignOutScope.local);
      return null;
    } catch (_) {
      // Preserve the documented offline profile path only when the server
      // could not make an authoritative statement about the session.
      return session.user;
    }
  }

  @override
  void initState() {
    super.initState();
    _emailController.text = FFAppState().authPendingEmail;
    if (kIsWeb && (widget.mode == 'callback' || widget.mode == 'reset')) {
      _emailLinkTokenHash = _c007EmailLinkTokenHash(widget.mode, Uri.base);
      _recoveryLinkVerified = _phase5HasPasswordRecoveryAuthorization(
        _client.auth.currentSession,
      );
      if (_emailLinkTokenHash.isEmpty && !_recoveryLinkVerified) {
        _error = 'De beveiligde link is ongeldig of verlopen.';
      }
    }
    _authSubscription = _client.auth.onAuthStateChange.listen((state) {
      if (!mounted) return;
      if (state.event == AuthChangeEvent.passwordRecovery) {
        if (_phase5AuthorizePasswordRecovery(state.session)) {
          if (widget.mode == 'reset') {
            setState(() => _recoveryLinkVerified = true);
          } else {
            context.goNamed('AuthResetPasswordPage');
          }
        }
        return;
      }
      if (state.session == null ||
          (_phase5PasswordRecoveryUserId.isNotEmpty &&
              state.session!.user.id != _phase5PasswordRecoveryUserId)) {
        _phase5ClearPasswordRecoveryAuthorization();
      }
      if (widget.mode == 'verify' &&
          state.session != null &&
          state.session!.user.emailConfirmedAt != null) {
        context.goNamed('AuthGatePage');
      }
    });
    if ({'gate', 'verify', 'onboarding', 'profile'}.contains(widget.mode)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_bootstrap());
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _cooldownTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _setBusy(bool value) {
    if (mounted) setState(() => _busy = value);
  }

  void _setError(String? value) {
    if (mounted) {
      setState(() {
        _error = value;
        if (value != null) _notice = null;
      });
    }
  }

  void _setNotice(String? value) {
    if (mounted) {
      setState(() {
        _notice = value;
        if (value != null) _error = null;
      });
    }
  }

  Future<void> _bootstrap() async {
    if (_booting) return;
    _booting = true;
    try {
      if (widget.mode == 'callback') {
        await _bootstrapCallback();
      } else if (widget.mode == 'verify') {
        await _bootstrapVerification();
      } else if (widget.mode == 'gate') {
        await _bootstrapGate();
      } else if (widget.mode == 'onboarding' || widget.mode == 'profile') {
        await _bootstrapProfileScreen();
      }
    } finally {
      _booting = false;
    }
  }

  Future<AuthProfileDataStruct> _loadOrCreateProfile(User user) async {
    final response = await _client.rpc('get_current_account_profile');
    final row = _c007SingleRpcRow(response);
    final profile = _phase4AProfileFromMap(row, authUserId: user.id);
    if (profile.profileId.isEmpty ||
        profile.profileStatus != 'active' ||
        profile.rowVersion < 1) {
      throw StateError('ACTIVE_PROFILE_REQUIRED');
    }
    _profileRowVersion = profile.rowVersion;
    _phase4ACacheProfile(profile);
    return profile;
  }

  Future<void> _bootstrapCallback() async {
    if (_busy || _emailLinkTokenHash.isEmpty) return;
    _setBusy(true);
    _setError(null);
    try {
      final response = await _client.auth.verifyOTP(
        tokenHash: _emailLinkTokenHash,
        type: OtpType.email,
      );
      final session = response.session;
      if (session == null || session.user.emailConfirmedAt == null) {
        _setError('De aanmeldlink is ongeldig, verlopen of nog niet verwerkt.');
        return;
      }
      await _loadOrCreateProfile(session.user);
      if (!mounted) return;
      context.goNamed('AuthGatePage');
    } catch (error) {
      _setError(_phase4AAuthError(error));
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _verifyRecoveryLink() async {
    if (_busy || _emailLinkTokenHash.isEmpty) return;
    _setBusy(true);
    _setError(null);
    try {
      final response = await _client.auth.verifyOTP(
        tokenHash: _emailLinkTokenHash,
        type: OtpType.recovery,
      );
      if (!_phase5AuthorizePasswordRecovery(response.session)) {
        _setError('De herstellink is ongeldig of verlopen.');
        return;
      }
      if (mounted) setState(() => _recoveryLinkVerified = true);
    } catch (error) {
      _phase5ClearPasswordRecoveryAuthorization();
      _setError(_phase4AAuthError(error));
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _bootstrapVerification() async {
    final user = _user;
    if (user?.email != null && _emailController.text.trim().isEmpty) {
      _emailController.text = user!.email!;
    }
    if (user?.emailConfirmedAt != null && mounted) {
      context.goNamed('AuthGatePage');
    }
  }

  Future<void> _bootstrapGate() async {
    _setBusy(true);
    try {
      final session = _client.auth.currentSession;
      if (session == null) {
        final previousAuthId = FFAppState().activeAuthAccountId.trim();
        await _phase4APurgeOperationalSecureState(previousAuthId);
        FFAppState().activeAuthAccountId = '';
        FFAppState().selectedCloudStableId = '';
        FFAppState().pendingStableInvitationToken = '';
        if (!mounted) return;
        context.goNamed('AuthWelcomePage');
        return;
      }
      final user = await _phase5ValidatedCurrentUser();
      if (user == null) {
        if (!mounted) return;
        context.goNamed('AuthWelcomePage');
        return;
      }
      final emailProvider = (user.appMetadata['provider'] ?? '') == 'email';
      if (user.emailConfirmedAt == null && emailProvider) {
        FFAppState().authPendingEmail = user.email ?? '';
        if (!mounted) return;
        context.goNamed('AuthVerifyEmailPage');
        return;
      }
      final profile = await _loadOrCreateProfile(user);
      final previousAuthId = FFAppState().activeAuthAccountId.trim();
      if (previousAuthId.isNotEmpty && previousAuthId != user.id) {
        await _phase4APurgeOperationalSecureState(previousAuthId);
      }
      _phase4AActivateScope(user.id);
      await _hydrateSelectedStableFromServer(user);
      _applyTheme(profile.themeMode);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        // Phase 5 keeps legacy backups intact but never exposes them as an
        // Alpha data source or onboarding decision.
        _legacyPrompt = false;
      });
      _continueAfterProfile(profile, user);
    } catch (error) {
      _setError(_phase4AAuthError(error));
    } finally {
      _setBusy(false);
    }
  }

  bool _hasFreshCachedMembership(String authUserId, String stableId) {
    final now = DateTime.now().toUtc();
    for (final cache in FFAppState().stableMembershipCaches) {
      final age =
          cache.lastValidatedAt == null
              ? null
              : now.difference(cache.lastValidatedAt!);
      if (cache.authUserId == authUserId &&
          cache.stableId == stableId &&
          cache.status == 'active' &&
          age != null &&
          !age.isNegative &&
          age <= const Duration(hours: 24)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _hydrateSelectedStableFromServer(User user) async {
    final cachedStableId = FFAppState().selectedCloudStableId.trim();
    try {
      final preference =
          await _client
              .from('account_workspace_preferences')
              .select('last_selected_stable_id')
              .eq('user_id', user.id)
              .maybeSingle();
      final preferredStableId = _phase4ANullableString(
        preference?['last_selected_stable_id'],
      );
      if (preferredStableId.isEmpty) {
        FFAppState().selectedCloudStableId = '';
        return;
      }
      final membership =
          await _client
              .from('stable_memberships')
              .select('stable_id,status')
              .eq('stable_id', preferredStableId)
              .eq('user_id', user.id)
              .eq('status', 'active')
              .maybeSingle();
      FFAppState().selectedCloudStableId =
          membership == null ? '' : preferredStableId;
    } on PostgrestException catch (error) {
      final denied =
          error.code == '401' || error.code == '403' || error.code == '42501';
      if (denied) {
        _phase5AccountInvalidateMembershipAuthority(user.id);
        return;
      }
      FFAppState().selectedCloudStableId =
          _hasFreshCachedMembership(user.id, cachedStableId)
              ? cachedStableId
              : '';
    } catch (_) {
      FFAppState().selectedCloudStableId =
          _hasFreshCachedMembership(user.id, cachedStableId)
              ? cachedStableId
              : '';
    }
  }

  Future<void> _bootstrapProfileScreen() async {
    _setBusy(true);
    try {
      final user = await _phase5ValidatedCurrentUser();
      if (user == null) {
        if (!mounted) return;
        context.goNamed('AuthWelcomePage');
        return;
      }
      final profile = await _loadOrCreateProfile(user);
      final previousAuthId = FFAppState().activeAuthAccountId.trim();
      if (previousAuthId.isNotEmpty && previousAuthId != user.id) {
        await _phase4APurgeOperationalSecureState(previousAuthId);
      }
      _phase4AActivateScope(user.id);
      _firstNameController.text = profile.firstName;
      _lastNameController.text = profile.lastName;
      _phoneController.text = profile.phoneE164;
      _locale = profile.locale.trim().isEmpty ? 'nl' : profile.locale;
      _timeZone = profile.timeZone.trim().isEmpty ? 'UTC' : profile.timeZone;
      _themeMode =
          profile.themeMode.trim().isEmpty ? 'system' : profile.themeMode;
      _intent = profile.onboardingIntent;
      _onboardingStep =
          profile.firstName.trim().isEmpty
              ? 0
              : profile.onboardingIntent.trim().isEmpty
              ? 1
              : 2;
      _avatarUrl = await _signedAvatarUrl(profile.avatarObjectPath);
      if (!mounted) return;
      setState(() => _profile = profile);
      _applyTheme(_themeMode);
    } catch (error) {
      _setError(_phase4AAuthError(error));
    } finally {
      _setBusy(false);
    }
  }

  Future<String> _signedAvatarUrl(String path) async {
    if (path.trim().isEmpty) return '';
    try {
      return await _client.storage
          .from('avatars')
          .createSignedUrl(path, 60 * 60);
    } catch (_) {
      return '';
    }
  }

  void _applyTheme(String mode) {
    if (!mounted) return;
    final target = switch (mode) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };
    setDarkModeSetting(context, target);
  }

  List<DropdownMenuItem<String>> _c007TimeZoneItems() => {
        ..._c007TimeZones,
        if (_timeZone.trim().isNotEmpty) _timeZone,
      }
      .map((zone) => DropdownMenuItem<String>(value: zone, child: Text(zone)))
      .toList(growable: false);

  bool _validEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());

  String? _passwordValidation(String password) {
    if (password.length < 8) {
      return 'Gebruik minimaal 8 tekens.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password) ||
        !RegExp(r'[a-z]').hasMatch(password) ||
        !RegExp(r'[0-9]').hasMatch(password)) {
      return 'Gebruik een hoofdletter, kleine letter en cijfer.';
    }
    return null;
  }

  Future<void> _login() async {
    if (_busy) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (!_validEmail(email)) {
      _setError('Vul een geldig e-mailadres in.');
      return;
    }
    if (password.isEmpty) {
      _setError('Vul je wachtwoord in.');
      return;
    }
    _setBusy(true);
    _setError(null);
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.session == null) {
        _setError('Aanmelden is niet voltooid. Probeer het opnieuw.');
        return;
      }
      await _loadOrCreateProfile(response.user!);
      if (!mounted) return;
      context.goNamed('AuthGatePage');
    } on AuthException catch (error) {
      if (error.message.toLowerCase().contains('email not confirmed')) {
        FFAppState().authPendingEmail = email;
        if (mounted) context.goNamed('AuthVerifyEmailPage');
      } else {
        _setError(_phase4AAuthError(error));
      }
    } catch (error) {
      _setError(_phase4AAuthError(error));
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _signUp() async {
    if (_busy) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (!_validEmail(email)) {
      _setError('Vul een geldig e-mailadres in.');
      return;
    }
    final passwordError = _passwordValidation(password);
    if (passwordError != null) {
      _setError(passwordError);
      return;
    }
    if (password != _confirmPasswordController.text) {
      _setError('De wachtwoorden zijn niet gelijk.');
      return;
    }
    _setBusy(true);
    _setError(null);
    try {
      await _client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: _phase4ARedirectUrl('/auth/callback'),
      );
      FFAppState().authPendingEmail = email;
      if (!mounted) return;
      context.goNamed('AuthVerifyEmailPage');
    } catch (error) {
      _setError(_phase4AAuthError(error));
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _requestPasswordReset() async {
    if (_busy) return;
    final email = _emailController.text.trim();
    if (!_validEmail(email)) {
      _setError('Vul een geldig e-mailadres in.');
      return;
    }
    _setBusy(true);
    _setError(null);
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: _phase4ARedirectUrl('/auth/reset-password'),
      );
      _setNotice(
        'Als dit e-mailadres bij AVARYN bekend is, ontvang je een herstelbericht.',
      );
    } catch (_) {
      _setNotice(
        'Als dit e-mailadres bij AVARYN bekend is, ontvang je een herstelbericht.',
      );
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _resendVerification() async {
    if (_busy || _cooldownSeconds > 0) return;
    final email = _emailController.text.trim();
    if (!_validEmail(email)) {
      _setError('Het e-mailadres ontbreekt. Kies een ander account.');
      return;
    }
    _setBusy(true);
    _setError(null);
    try {
      await _client.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: _phase4ARedirectUrl('/auth/callback'),
      );
      _startCooldown();
      _setNotice('Een nieuwe bevestigingsmail is aangevraagd.');
    } catch (error) {
      _setError(_phase4AAuthError(error));
    } finally {
      _setBusy(false);
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds -= 1);
      }
    });
  }

  Future<void> _updatePassword() async {
    if (_busy) return;
    if (!_phase5HasPasswordRecoveryAuthorization(_client.auth.currentSession)) {
      _setError('De herstellink is ongeldig of verlopen.');
      return;
    }
    final password = _passwordController.text;
    final validation = _passwordValidation(password);
    if (validation != null) {
      _setError(validation);
      return;
    }
    if (password != _confirmPasswordController.text) {
      _setError('De wachtwoorden zijn niet gelijk.');
      return;
    }
    _setBusy(true);
    _setError(null);
    try {
      await _client.auth.updateUser(UserAttributes(password: password));
      _phase5ClearPasswordRecoveryAuthorization();
      _setNotice('Je wachtwoord is bijgewerkt.');
      if (!mounted) return;
      context.goNamed('AuthGatePage');
    } catch (error) {
      _setError(_phase4AAuthError(error));
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _savePersonalProfile({bool complete = false}) async {
    if (_busy) return;
    final user = _user;
    if (user == null) {
      if (mounted) context.goNamed('AuthWelcomePage');
      return;
    }
    final firstName = _firstNameController.text.trim();
    final phone = _phoneController.text.trim();
    if (firstName.isEmpty) {
      _setError('Voornaam is verplicht.');
      return;
    }
    if (phone.isNotEmpty && !RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(phone)) {
      _setError(
        'Gebruik een telefoonnummer in internationaal formaat, bijvoorbeeld +31612345678.',
      );
      return;
    }
    if ((_onboardingStep >= 1 || complete) && _intent.isEmpty) {
      _setError('Kies hoe je AVARYN wilt gebruiken.');
      return;
    }

    _setBusy(true);
    _setError(null);
    try {
      final profile = await _c007PersistProfile(
        user,
        completeOnboarding: complete,
        avatarObjectPath: _profile?.avatarObjectPath ?? '',
      );
      _applyTheme(profile.themeMode);
      if (!mounted) return;
      setState(() => _profile = profile);
      if (complete) {
        _continueAfterProfile(profile, user);
      } else {
        _setNotice('Je profiel is opgeslagen.');
      }
    } catch (error) {
      _setError(_phase4AAuthError(error));
    } finally {
      _setBusy(false);
    }
  }

  Future<AuthProfileDataStruct> _c007PersistProfile(
    User user, {
    required bool completeOnboarding,
    required String avatarObjectPath,
  }) async {
    if (_profileRowVersion < 1) {
      await _loadOrCreateProfile(user);
    }
    final response = await _client.rpc(
      'update_current_account_profile',
      params: {
        'p_expected_row_version': _profileRowVersion,
        'p_first_name': _firstNameController.text.trim(),
        'p_last_name': _lastNameController.text.trim(),
        'p_phone_e164': _phoneController.text.trim(),
        'p_locale': _locale,
        'p_time_zone': _timeZone,
        'p_theme_mode': _themeMode,
        'p_onboarding_intent': _intent.trim(),
        'p_complete_onboarding': completeOnboarding,
        'p_avatar_object_path':
            avatarObjectPath.trim().isEmpty ? null : avatarObjectPath.trim(),
        'p_correlation_id': const Uuid().v4(),
      },
    );
    final profile = _phase4AProfileFromMap(
      _c007SingleRpcRow(response),
      authUserId: user.id,
    );
    if (profile.profileId.isEmpty || profile.rowVersion < 1) {
      throw StateError('ACCOUNT_PROFILE_PROJECTION_INVALID');
    }
    _profileRowVersion = profile.rowVersion;
    _phase4ACacheProfile(profile);
    if (mounted) setState(() => _profile = profile);
    return profile;
  }

  Future<void> _uploadAvatar() async {
    if (_busy) return;
    final user = _user;
    if (user == null) return;
    _setBusy(true);
    _setError(null);
    try {
      final picked = await file_picker.FilePicker.pickFiles(
        type: file_picker.FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        _setError('De afbeelding kon niet worden gelezen.');
        return;
      }
      if (bytes.length > 5 * 1024 * 1024) {
        _setError('Kies een afbeelding kleiner dan 5 MB.');
        return;
      }
      final extension = (file.extension ?? '').toLowerCase();
      final contentType = switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'jpg' || 'jpeg' => 'image/jpeg',
        _ => '',
      };
      if (contentType.isEmpty) {
        _setError('Gebruik een JPG-, PNG- of WebP-afbeelding.');
        return;
      }
      if (!phase5ImageSignatureMatches(bytes, contentType)) {
        _setError(
          'Het bestandstype komt niet overeen met de inhoud van de afbeelding.',
        );
        return;
      }
      final oldPath = _profile?.avatarObjectPath ?? '';
      final path = '${user.id}/avatar-${const Uuid().v4()}.$extension';
      await _client.storage
          .from('avatars')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );
      try {
        await _c007PersistProfile(
          user,
          completeOnboarding: false,
          avatarObjectPath: path,
        );
      } catch (_) {
        if (oldPath != path) {
          try {
            await _client.storage.from('avatars').remove([path]);
          } catch (_) {
            // Best-effort compensating cleanup; the original error remains.
          }
        }
        rethrow;
      }
      if (oldPath.isNotEmpty && oldPath != path) {
        await _client.storage.from('avatars').remove([oldPath]);
      }
      final signed = await _signedAvatarUrl(path);
      if (!mounted) return;
      setState(() {
        _avatarUrl = signed;
      });
      _setNotice('Profielfoto bijgewerkt.');
    } catch (error) {
      _setError(_phase4AAuthError(error));
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _removeAvatar() async {
    if (_busy) return;
    final user = _user;
    final path = _profile?.avatarObjectPath ?? '';
    if (user == null || path.isEmpty) return;
    _setBusy(true);
    try {
      await _c007PersistProfile(
        user,
        completeOnboarding: false,
        avatarObjectPath: '',
      );
      try {
        await _client.storage.from('avatars').remove([path]);
      } catch (_) {
        // The database reference is already removed. A failed object cleanup
        // remains a non-authorizing orphan for controlled later cleanup.
      }
      if (mounted) {
        setState(() {
          _avatarUrl = '';
        });
      }
    } catch (error) {
      _setError(_phase4AAuthError(error));
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _logout() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Uitloggen'),
            content: const Text(
              'Ontsleutelde sessiegegevens worden gewist. Je cloudgegevens blijven behouden.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Annuleren'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Uitloggen'),
              ),
            ],
          ),
    );
    if (confirmed != true || _busy) return;
    _setBusy(true);
    try {
      final authId = FFAppState().activeAuthAccountId.trim();
      if (authId.isNotEmpty) {
        _phase4ASavePhase4BOperationalMaster(authId);
        _phase4ASaveScope(authId);
        await _phase4APurgeOperationalSecureState(authId);
      }
      FFAppState().activeAuthAccountId = '';
      FFAppState().currentAuthProfile = AuthProfileDataStruct();
      FFAppState().selectedCloudStableId = '';
      FFAppState().pendingStableInvitationToken = '';
      FFAppState().pendingStableInvitationId = '';
      FFAppState().stableAccessStatus = 'signed_out';
      _phase4AClearWorkingSet();
      await _client.auth.signOut();
      if (!mounted) return;
      context.goNamed('AuthWelcomePage');
    } catch (error) {
      _setError(_phase4AAuthError(error));
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _deleteAccount() async {
    if (_busy) return;
    final user = _user;
    if (user == null) {
      _setError('Meld je opnieuw aan voordat je het account verwijdert.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Account permanent verwijderen?'),
            content: const Text(
              'Dit verwijdert uitsluitend een account zonder stal-, team- of '
              'bewaarde historie. Actieve rollen, historie en Apple-accounts '
              'blijven fail-closed geblokkeerd. Deze actie kan niet ongedaan '
              'worden gemaakt.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Annuleren'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Permanent verwijderen'),
              ),
            ],
          ),
    );
    if (confirmed != true || _busy) return;
    _setBusy(true);
    try {
      final authUserId = user.id;
      final response = await _client.functions.invoke(
        'delete-account',
        headers: const <String, String>{'Content-Type': 'application/json'},
        // functions_client 2.4.2 encodes non-string bodies through a web
        // isolate. Sending the already-valid empty JSON object avoids that
        // transport-only failure without changing server authorization.
        body: '{}',
      );
      final data =
          response.data is Map
              ? Map<String, dynamic>.from(response.data as Map)
              : const <String, dynamic>{};
      final code = _phase4ANullableString(data['code']);
      if (response.status != 200 || code != 'ACCOUNT_DELETED') {
        throw FunctionException(status: response.status, details: data);
      }
      await _phase4APurgeOperationalSecureState(authUserId);
      _phase5ClearDeletedAccountState(authUserId);
      // Admin deletion revokes the server identity and refresh tokens. The
      // client only needs to remove its now-invalid persisted session.
      await _client.auth.signOut(scope: SignOutScope.local);
      if (!mounted) return;
      context.goNamed('AuthWelcomePage');
    } on FunctionException catch (error) {
      _setError(
        _phase5AccountDeletionMessage(_phase5AccountDeletionCode(error)),
      );
    } catch (_) {
      _setError(_phase5AccountDeletionMessage(''));
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _sendSecurityReset() async {
    final email = _user?.email ?? '';
    if (email.isEmpty || _busy) return;
    _setBusy(true);
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: _phase4ARedirectUrl('/auth/reset-password'),
      );
      _setNotice(
        'Als dit account e-mailaanmelding gebruikt, ontvang je een herstelbericht.',
      );
    } catch (_) {
      _setNotice(
        'Als dit account e-mailaanmelding gebruikt, ontvang je een herstelbericht.',
      );
    } finally {
      _setBusy(false);
    }
  }

  void _attachLegacy() {
    final user = _user;
    if (user == null || _busy) return;
    _phase4AAttachLegacyBackup(user.id);
    setState(() => _legacyPrompt = false);
    _continueAfterLegacyChoice();
  }

  void _deferLegacy() {
    final user = _user;
    if (user == null || _busy) return;
    _phase4AMarkLegacyPrompted(user.id);
    _phase4AClearWorkingSet();
    _phase4ASaveScope(user.id);
    setState(() => _legacyPrompt = false);
    _continueAfterLegacyChoice();
  }

  void _continueAfterLegacyChoice() {
    final profile = _profile ?? FFAppState().currentAuthProfile;
    final user = _user;
    if (user == null) {
      if (mounted) context.goNamed('AuthWelcomePage');
      return;
    }
    _continueAfterProfile(profile, user);
  }

  void _continueAfterProfile(AuthProfileDataStruct profile, User user) {
    if (!mounted) return;
    final route = phase5ResolveAccountRoute(
      hasSession: true,
      emailProvider: (user.appMetadata['provider'] ?? '') == 'email',
      emailConfirmed: user.emailConfirmedAt != null,
      onboardingCompleted: profile.onboardingCompletedAt != null,
      hasPendingInvitation:
          FFAppState().pendingStableInvitationToken.trim().isNotEmpty ||
          FFAppState().pendingStableInvitationId.trim().isNotEmpty,
      hasSelectedStable: FFAppState().selectedCloudStableId.trim().isNotEmpty,
    );
    context.goNamed(phase5AccountRouteName(route));
  }

  InputDecoration _fieldDecoration(
    FlutterFlowTheme theme,
    String label, {
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: theme.secondaryBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.alternate),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.alternate),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.secondary, width: 1.4),
      ),
    );
  }

  Widget _feedback(FlutterFlowTheme theme) {
    if (_error == null && _notice == null) return const SizedBox.shrink();
    final isError = _error != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color:
            isError
                ? theme.error.withValues(alpha: 0.12)
                : theme.success.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isError ? theme.error : theme.success,
          width: 0.7,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? theme.error : theme.success,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error ?? _notice ?? '',
              style: theme.bodyMedium.copyWith(color: theme.primaryText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _brand(FlutterFlowTheme theme, {String? eyebrow}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[
          Text(
            eyebrow.toUpperCase(),
            style: theme.labelSmall.copyWith(
              color: theme.secondary,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          'AVARYN',
          style: theme.headlineLarge.copyWith(
            color: theme.primaryText,
            letterSpacing: 2.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'One Team. Two Athletes.',
          style: theme.bodyMedium.copyWith(color: theme.secondaryText),
        ),
      ],
    );
  }

  Widget _primaryButton(
    FlutterFlowTheme theme,
    String label,
    VoidCallback onPressed, {
    IconData? icon,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: FilledButton.icon(
        onPressed: _busy ? null : onPressed,
        icon:
            _busy
                ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.primary,
                  ),
                )
                : Icon(icon ?? Icons.arrow_forward, size: 19),
        label: Text(label),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          backgroundColor: theme.secondary,
          foregroundColor: theme.primary,
          disabledBackgroundColor: theme.secondary.withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _secondaryButton(
    FlutterFlowTheme theme,
    String label,
    VoidCallback? onPressed, {
    IconData? icon,
  }) {
    return OutlinedButton.icon(
      onPressed: _busy ? null : onPressed,
      icon: Icon(icon ?? Icons.arrow_back, size: 19),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: theme.primaryText,
        side: BorderSide(color: theme.alternate),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _pageFrame(Widget child, {bool narrow = true, Color? background}) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? double.infinity,
      color: background ?? theme.primaryBackground,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: narrow ? 560 : 920),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                20,
                24,
                20,
                28 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _authCard(FlutterFlowTheme theme, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.alternate, width: 0.7),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _privacySection(FlutterFlowTheme theme, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.titleMedium.copyWith(color: theme.primaryText),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: theme.bodyMedium.copyWith(
              color: theme.secondaryText,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _alphaPrivacy() {
    final theme = FlutterFlowTheme.of(context);
    return _pageFrame(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _brand(theme, eyebrow: 'Privacy'),
          const SizedBox(height: 26),
          _authCard(theme, [
            Text(
              'Alpha-privacyverklaring',
              style: theme.headlineSmall.copyWith(color: theme.primaryText),
            ),
            const SizedBox(height: 6),
            Text(
              'Versie $_c007AlphaPrivacyVersion · uitsluitend voor de besloten externe testerfase',
              style: theme.bodySmall.copyWith(color: theme.secondaryText),
            ),
            const SizedBox(height: 22),
            _privacySection(
              theme,
              'Wie is verantwoordelijk?',
              'SDS Group B.V., handelend onder de handelsnaam AVARYN, is de '
                  'verwerkingsverantwoordelijke voor deze Alpha. KvK 91614112. '
                  'Postadres en contact voor privacyverzoeken: Nieuwe Rijksweg '
                  '2a, 4472 AB ’s-Heer Hendrikskinderen, Nederland.',
            ),
            _privacySection(
              theme,
              'Welke gegevens verwerken wij?',
              'We verwerken je e-mailadres, interne Auth- en account-ID’s, '
                  'accountstatus, de profielgegevens en avatar die je zelf '
                  'invult, technische login-, beveiligings-, fout- en '
                  'toegangsgegevens en vrijwillige feedback. Supabase, '
                  'FlutterFlow en hun infrastructuur kunnen daarnaast '
                  'IP-adres, browser- en beveiligingsmetadata verwerken. In '
                  'deze Alpha gebruiken we geen marketinganalytics, '
                  'advertentietracking of uitsluitend geautomatiseerde '
                  'besluitvorming over testers.',
            ),
            _privacySection(
              theme,
              'Waarom en op welke grond?',
              'We gebruiken deze gegevens om je de vrijwillige Alpha-test te '
                  'laten uitvoeren, authenticatie en gegevensscheiding te '
                  'beveiligen, fouten te onderzoeken, toegang in te trekken '
                  'en accounts gecontroleerd af te handelen. Noodzakelijke '
                  'account- en testverwerking berust op de Alpha-testafspraak; '
                  'minimale security- en auditlogging op ons gerechtvaardigde '
                  'beveiligingsbelang; vrijwillige feedback waar nodig op je '
                  'toestemming. Je kunt vrijwillige toestemming altijd '
                  'intrekken.',
            ),
            _privacySection(
              theme,
              'Met wie en waar?',
              'Alleen geautoriseerde AVARYN-beheerders en onze technische '
                  'verwerkers verwerken deze gegevens: Supabase voor Auth, '
                  'database en Storage en FlutterFlow voor de besloten webapp '
                  'en hosting. De stagingdatabase staat in Central EU '
                  '(Frankfurt). Leveranciers kunnen eigen subverwerkers '
                  'gebruiken; eventuele doorgiften buiten de EER volgen hun '
                  'geldige doorgiftemechanismen en verwerkersvoorwaarden.',
            ),
            _privacySection(
              theme,
              'Hoe lang bewaren wij gegevens?',
              'Testercontact, account en gewone testinhoud bewaren we tot het '
                  'einde van je deelname en daarna maximaal 30 dagen. '
                  'Pseudonimiseerbare feedback en security- of auditgegevens '
                  'bewaren we maximaal 90 dagen na intrekking of einde Alpha. '
                  'Noodzakelijk incidentbewijs maximaal 180 dagen na sluiting '
                  'van het incident. Langere bewaring gebeurt alleen bij een '
                  'aantoonbare wettelijke noodzaak of rechtsvordering. '
                  'Leveranciersback-ups en logs volgen hun vastgelegde '
                  'retentiecycli.',
            ),
            _privacySection(
              theme,
              'Je rechten',
              'Je kunt vragen om inzage, correctie, verwijdering, beperking of '
                  'overdracht en bezwaar maken of toestemming intrekken. Stuur '
                  'je verzoek naar het postadres hierboven. We reageren '
                  'binnen de wettelijke termijn. Je kunt ook een klacht '
                  'indienen bij de Autoriteit Persoonsgegevens via '
                  'autoriteitpersoonsgegevens.nl. Historische operationele '
                  'gegevens kunnen alleen worden verwijderd na een veilige '
                  'beheerdersreview wanneer integriteit, securityaudit of een '
                  'wettelijke bewaarplicht directe verwijdering verhindert.',
            ),
            _privacySection(
              theme,
              'Grenzen van de Alpha',
              'Gebruik uitsluitend toegestane fictieve paard-, stal-, '
                  'behandel-, voer- en zorggegevens. AVARYN is in deze fase '
                  'online-only en mag niet worden gebruikt voor echte '
                  'medische, veterinaire, voer- of veiligheidskritieke '
                  'beslissingen. Definitieve gebruiksvoorwaarden en social '
                  'login volgen pas na de eerste externe testerfase.',
            ),
            _secondaryButton(
              theme,
              'Terug',
              () => Navigator.of(context).maybePop(),
              icon: Icons.arrow_back,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _welcome() {
    final theme = FlutterFlowTheme.of(context);
    return _pageFrame(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _brand(theme),
          const SizedBox(height: 30),
          _authCard(theme, [
            Text(
              'Welkom bij AVARYN',
              style: theme.headlineSmall.copyWith(color: theme.primaryText),
            ),
            const SizedBox(height: 8),
            Text(
              'Persoonlijke toegang tot de prestaties, planning en dagelijkse zorg van jouw team.',
              style: theme.bodyMedium.copyWith(color: theme.secondaryText),
            ),
            const SizedBox(height: 22),
            _secondaryButton(
              theme,
              'Doorgaan met e-mail',
              () => context.goNamed('AuthEmailPage'),
              icon: Icons.mail_outline,
            ),
            const SizedBox(height: 18),
            _feedback(theme),
            TextButton(
              onPressed: () => context.pushNamed('AlphaPrivacyPage'),
              child: const Text('Alpha-privacyverklaring'),
            ),
            Text(
              'Google, Apple en definitieve gebruiksvoorwaarden volgen pas na de eerste externe testerfase.',
              textAlign: TextAlign.center,
              style: theme.bodySmall.copyWith(color: theme.secondaryText),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _emailChoice() {
    final theme = FlutterFlowTheme.of(context);
    return _pageFrame(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _brand(theme, eyebrow: 'Account'),
          const SizedBox(height: 26),
          _authCard(theme, [
            Text(
              'Doorgaan met e-mail',
              style: theme.headlineSmall.copyWith(color: theme.primaryText),
            ),
            const SizedBox(height: 8),
            Text(
              'Kies of je al een account hebt.',
              style: theme.bodyMedium.copyWith(color: theme.secondaryText),
            ),
            const SizedBox(height: 22),
            _primaryButton(
              theme,
              'Inloggen',
              () => context.goNamed('AuthLoginPage'),
              icon: Icons.login,
            ),
            const SizedBox(height: 10),
            _secondaryButton(
              theme,
              'Account aanmaken',
              () => context.goNamed('AuthCreateAccountPage'),
              icon: Icons.person_add_alt_1,
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => context.goNamed('AuthWelcomePage'),
              child: const Text('Terug'),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _loginForm() {
    final theme = FlutterFlowTheme.of(context);
    return _pageFrame(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _brand(theme, eyebrow: 'Inloggen'),
          const SizedBox(height: 26),
          _authCard(theme, [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: _fieldDecoration(
                theme,
                'E-mailadres',
                hint: 'naam@voorbeeld.nl',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: _passwordHidden,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _login(),
              decoration: _fieldDecoration(
                theme,
                'Wachtwoord',
                suffixIcon: IconButton(
                  tooltip:
                      _passwordHidden
                          ? 'Wachtwoord tonen'
                          : 'Wachtwoord verbergen',
                  onPressed:
                      () => setState(() => _passwordHidden = !_passwordHidden),
                  icon: Icon(
                    _passwordHidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.goNamed('AuthForgotPasswordPage'),
                child: const Text('Wachtwoord vergeten?'),
              ),
            ),
            _feedback(theme),
            _primaryButton(theme, 'Inloggen', _login, icon: Icons.login),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => context.goNamed('AuthCreateAccountPage'),
              child: const Text('Nog geen account? Account aanmaken'),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _signupForm() {
    final theme = FlutterFlowTheme.of(context);
    return _pageFrame(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _brand(theme, eyebrow: 'Nieuw account'),
          const SizedBox(height: 26),
          _authCard(theme, [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newUsername],
              decoration: _fieldDecoration(
                theme,
                'E-mailadres',
                hint: 'naam@voorbeeld.nl',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: _passwordHidden,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              decoration: _fieldDecoration(
                theme,
                'Wachtwoord',
                hint: 'Minimaal 8 tekens',
                suffixIcon: IconButton(
                  tooltip:
                      _passwordHidden
                          ? 'Wachtwoord tonen'
                          : 'Wachtwoord verbergen',
                  onPressed:
                      () => setState(() => _passwordHidden = !_passwordHidden),
                  icon: Icon(
                    _passwordHidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPasswordController,
              obscureText: _confirmPasswordHidden,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              onSubmitted: (_) => _signUp(),
              decoration: _fieldDecoration(
                theme,
                'Bevestig wachtwoord',
                suffixIcon: IconButton(
                  tooltip:
                      _confirmPasswordHidden
                          ? 'Wachtwoord tonen'
                          : 'Wachtwoord verbergen',
                  onPressed:
                      () => setState(
                        () => _confirmPasswordHidden = !_confirmPasswordHidden,
                      ),
                  icon: Icon(
                    _confirmPasswordHidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.secondaryBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.alternate),
              ),
              child: Column(
                children: [
                  Text(
                    'Lees vóór accountaanmaak hoe AVARYN je persoonsgegevens in de besloten Alpha verwerkt.',
                    textAlign: TextAlign.center,
                    style: theme.bodySmall.copyWith(color: theme.primaryText),
                  ),
                  TextButton(
                    onPressed: () => context.pushNamed('AlphaPrivacyPage'),
                    child: const Text('Alpha-privacyverklaring openen'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _feedback(theme),
            _primaryButton(
              theme,
              'Account aanmaken',
              _signUp,
              icon: Icons.person_add_alt_1,
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => context.goNamed('AuthLoginPage'),
              child: const Text('Al een account? Inloggen'),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _verification() {
    final theme = FlutterFlowTheme.of(context);
    final email = _emailController.text.trim();
    return _pageFrame(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _brand(theme, eyebrow: 'E-mail bevestigen'),
          const SizedBox(height: 26),
          _authCard(theme, [
            Icon(
              Icons.mark_email_read_outlined,
              size: 44,
              color: theme.secondary,
            ),
            const SizedBox(height: 16),
            Text(
              'Controleer je inbox',
              textAlign: TextAlign.center,
              style: theme.headlineSmall.copyWith(color: theme.primaryText),
            ),
            const SizedBox(height: 8),
            Text(
              email.isEmpty
                  ? 'Open de bevestigingslink in het bericht van AVARYN.'
                  : 'Open de bevestigingslink die naar $email is gestuurd.',
              textAlign: TextAlign.center,
              style: theme.bodyMedium.copyWith(color: theme.secondaryText),
            ),
            if (FFAppState().pendingStableInvitationToken.trim().isNotEmpty ||
                FFAppState().pendingStableInvitationId.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Na bevestiging hervat AVARYN de uitnodiging met een '
                'niet-geheime referentie. De uitnodigingscode zelf wordt '
                'bewust niet duurzaam opgeslagen.',
                textAlign: TextAlign.center,
                style: theme.bodySmall.copyWith(color: theme.secondaryText),
              ),
            ],
            const SizedBox(height: 20),
            _feedback(theme),
            _primaryButton(
              theme,
              _cooldownSeconds > 0
                  ? 'Opnieuw sturen over ${_cooldownSeconds}s'
                  : 'Bevestigingsmail opnieuw sturen',
              _resendVerification,
              icon: Icons.refresh,
            ),
            const SizedBox(height: 10),
            _secondaryButton(
              theme,
              'Ander e-mailadres gebruiken',
              () => context.goNamed('AuthCreateAccountPage'),
              icon: Icons.edit_outlined,
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed:
                  _busy
                      ? null
                      : () async {
                        await _phase4APurgeOperationalSecureState(
                          FFAppState().activeAuthAccountId,
                        );
                        await _client.auth.signOut();
                        if (mounted) context.goNamed('AuthWelcomePage');
                      },
              child: const Text('Uitloggen of ander account kiezen'),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _forgotPassword() {
    final theme = FlutterFlowTheme.of(context);
    return _pageFrame(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _brand(theme, eyebrow: 'Wachtwoord herstellen'),
          const SizedBox(height: 26),
          _authCard(theme, [
            Text(
              'Herstelbericht aanvragen',
              style: theme.headlineSmall.copyWith(color: theme.primaryText),
            ),
            const SizedBox(height: 8),
            Text(
              'We sturen instructies wanneer het adres bij een AVARYN-account hoort.',
              style: theme.bodyMedium.copyWith(color: theme.secondaryText),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _requestPasswordReset(),
              decoration: _fieldDecoration(theme, 'E-mailadres'),
            ),
            const SizedBox(height: 16),
            _feedback(theme),
            _primaryButton(
              theme,
              'Herstelbericht aanvragen',
              _requestPasswordReset,
              icon: Icons.lock_reset,
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => context.goNamed('AuthLoginPage'),
              child: const Text('Terug naar inloggen'),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _resetPassword() {
    final theme = FlutterFlowTheme.of(context);
    if (!_recoveryLinkVerified ||
        !_phase5HasPasswordRecoveryAuthorization(_client.auth.currentSession)) {
      return _pageFrame(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _brand(theme, eyebrow: 'Wachtwoord herstellen'),
            const SizedBox(height: 26),
            _authCard(theme, [
              Text(
                'Beveiligde herstellink',
                style: theme.headlineSmall.copyWith(color: theme.primaryText),
              ),
              const SizedBox(height: 8),
              Text(
                'Controleer de link pas wanneer je zelf op de knop drukt.',
                style: theme.bodyMedium.copyWith(color: theme.secondaryText),
              ),
              const SizedBox(height: 16),
              _feedback(theme),
              if (_emailLinkTokenHash.isNotEmpty)
                _primaryButton(
                  theme,
                  'Herstellink controleren',
                  _verifyRecoveryLink,
                  icon: Icons.verified_user_outlined,
                ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => context.goNamed('AuthForgotPasswordPage'),
                child: const Text('Nieuwe herstellink aanvragen'),
              ),
            ]),
          ],
        ),
      );
    }
    return _pageFrame(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _brand(theme, eyebrow: 'Nieuw wachtwoord'),
          const SizedBox(height: 26),
          _authCard(theme, [
            TextField(
              controller: _passwordController,
              obscureText: _passwordHidden,
              textInputAction: TextInputAction.next,
              decoration: _fieldDecoration(
                theme,
                'Nieuw wachtwoord',
                suffixIcon: IconButton(
                  tooltip: 'Wachtwoord tonen of verbergen',
                  onPressed:
                      () => setState(() => _passwordHidden = !_passwordHidden),
                  icon: Icon(
                    _passwordHidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPasswordController,
              obscureText: _confirmPasswordHidden,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _updatePassword(),
              decoration: _fieldDecoration(
                theme,
                'Bevestig nieuw wachtwoord',
                suffixIcon: IconButton(
                  tooltip: 'Wachtwoord tonen of verbergen',
                  onPressed:
                      () => setState(
                        () => _confirmPasswordHidden = !_confirmPasswordHidden,
                      ),
                  icon: Icon(
                    _confirmPasswordHidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _feedback(theme),
            _primaryButton(
              theme,
              'Wachtwoord opslaan',
              _updatePassword,
              icon: Icons.verified_user_outlined,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _loadingOrCallback() {
    final theme = FlutterFlowTheme.of(context);
    final isCallback = widget.mode == 'callback';
    return _pageFrame(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _brand(theme, eyebrow: 'Beveiligde toegang'),
          const SizedBox(height: 32),
          _authCard(theme, [
            if (_busy || !isCallback)
              Center(
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(color: theme.secondary),
                ),
              ),
            const SizedBox(height: 18),
            Text(
              widget.mode == 'gate'
                  ? 'Je AVARYN-account wordt veilig geladen.'
                  : 'Bevestig je e-mailadres pas wanneer je zelf op de knop drukt.',
              textAlign: TextAlign.center,
              style: theme.bodyMedium.copyWith(color: theme.secondaryText),
            ),
            const SizedBox(height: 16),
            _feedback(theme),
            if (isCallback && _emailLinkTokenHash.isNotEmpty && !_busy)
              _primaryButton(
                theme,
                'E-mailadres bevestigen',
                _bootstrapCallback,
                icon: Icons.mark_email_read_outlined,
              ),
            if (_error != null && !isCallback)
              _secondaryButton(
                theme,
                'Opnieuw proberen',
                _bootstrap,
                icon: Icons.refresh,
              ),
          ]),
        ],
      ),
    );
  }

  Widget _legacyOwnershipPrompt() {
    final theme = FlutterFlowTheme.of(context);
    return _pageFrame(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _brand(theme, eyebrow: 'Lokale testgegevens'),
          const SizedBox(height: 26),
          _authCard(theme, [
            Icon(Icons.inventory_2_outlined, size: 42, color: theme.secondary),
            const SizedBox(height: 14),
            Text(
              'Bestaande AVARYN-testgegevens gevonden',
              style: theme.headlineSmall.copyWith(color: theme.primaryText),
            ),
            const SizedBox(height: 8),
            Text(
              'Op dit apparaat staan lokale paarden-, planning- en voedingsgegevens uit het prototype. Koppel een rollbackveilige kopie uitsluitend aan dit account, of ga verder met een lege accountomgeving.',
              style: theme.bodyMedium.copyWith(color: theme.secondaryText),
            ),
            const SizedBox(height: 20),
            _primaryButton(
              theme,
              'Kopie aan dit account koppelen',
              _attachLegacy,
              icon: Icons.link,
            ),
            const SizedBox(height: 10),
            _secondaryButton(
              theme,
              'Niet nu',
              _deferLegacy,
              icon: Icons.schedule,
            ),
            const SizedBox(height: 10),
            Text(
              'De oorspronkelijke legacyback-up blijft in beide gevallen bewaard tot Phase 4C is beoordeeld.',
              style: theme.bodySmall.copyWith(color: theme.secondaryText),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _avatar(FlutterFlowTheme theme, {double size = 84}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.accent2,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: theme.alternate, width: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child:
          _avatarUrl.isNotEmpty
              ? Image.network(
                _avatarUrl,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) => Icon(
                      Icons.person_outline,
                      size: size * 0.48,
                      color: theme.primaryText,
                    ),
              )
              : Icon(
                Icons.person_outline,
                size: size * 0.48,
                color: theme.primaryText,
              ),
    );
  }

  Widget _onboarding() {
    final theme = FlutterFlowTheme.of(context);
    if (_profile == null && _error == null) return _loadingOrCallback();
    return _pageFrame(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _brand(theme, eyebrow: 'Eerste inrichting'),
          const SizedBox(height: 22),
          Row(
            children: List.generate(3, (index) {
              final active = index <= _onboardingStep;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: index == 2 ? 0 : 7),
                  decoration: BoxDecoration(
                    color: active ? theme.secondary : theme.alternate,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 18),
          _authCard(
            theme,
            _onboardingStep == 0
                ? _onboardingProfileStep(theme)
                : _onboardingStep == 1
                ? _onboardingIntentStep(theme)
                : _onboardingCompletionStep(theme),
          ),
        ],
      ),
    );
  }

  List<Widget> _onboardingProfileStep(FlutterFlowTheme theme) {
    return [
      Text(
        'Jouw persoonlijke profiel',
        style: theme.headlineSmall.copyWith(color: theme.primaryText),
      ),
      const SizedBox(height: 8),
      Text(
        'Alleen gegevens die nodig zijn om AVARYN persoonlijk te maken.',
        style: theme.bodyMedium.copyWith(color: theme.secondaryText),
      ),
      const SizedBox(height: 18),
      Row(
        children: [
          _avatar(theme),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _uploadAvatar,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Foto kiezen'),
                ),
                if ((_profile?.avatarObjectPath ?? '').isNotEmpty)
                  TextButton(
                    onPressed: _busy ? null : _removeAvatar,
                    child: const Text('Foto verwijderen'),
                  ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _firstNameController,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.givenName],
        decoration: _fieldDecoration(theme, 'Voornaam'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _lastNameController,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.familyName],
        decoration: _fieldDecoration(theme, 'Achternaam (optioneel)'),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: {'nl', 'en'}.contains(_locale) ? _locale : 'nl',
        decoration: _fieldDecoration(theme, 'Taal'),
        items: const [
          DropdownMenuItem(value: 'nl', child: Text('Nederlands')),
          DropdownMenuItem(value: 'en', child: Text('English (preference)')),
        ],
        onChanged: (value) => setState(() => _locale = value ?? 'nl'),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: _timeZone,
        decoration: _fieldDecoration(theme, 'Tijdzone'),
        items: _c007TimeZoneItems(),
        onChanged: (value) => setState(() => _timeZone = value ?? 'UTC'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.telephoneNumber],
        decoration: _fieldDecoration(
          theme,
          'Telefoonnummer (optioneel)',
          hint: '+31612345678',
        ),
      ),
      const SizedBox(height: 16),
      _feedback(theme),
      _primaryButton(theme, 'Verder', () {
        if (_firstNameController.text.trim().isEmpty) {
          _setError('Voornaam is verplicht.');
          return;
        }
        setState(() {
          _error = null;
          _onboardingStep = 1;
        });
      }),
    ];
  }

  List<Widget> _onboardingIntentStep(FlutterFlowTheme theme) {
    final options = const [
      (
        'createStable',
        'Ik wil een nieuwe stal aanmaken',
        Icons.home_work_outlined,
      ),
      ('joinStable', 'Ik heb een uitnodiging ontvangen', Icons.mail_outline),
      (
        'individualHorse',
        'Ik beheer voorlopig alleen mijn eigen paard',
        Icons.pets_outlined,
      ),
    ];
    return [
      Text(
        'Hoe wil je AVARYN gebruiken?',
        style: theme.headlineSmall.copyWith(color: theme.primaryText),
      ),
      const SizedBox(height: 8),
      Text(
        'Dit is alleen jouw voorkeur. Er wordt nog geen stal, rol of lidmaatschap aangemaakt.',
        style: theme.bodyMedium.copyWith(color: theme.secondaryText),
      ),
      const SizedBox(height: 16),
      ...options.map(
        (option) => Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: RadioListTile<String>(
            value: option.$1,
            groupValue: _intent,
            onChanged: (value) => setState(() => _intent = value ?? ''),
            title: Text(option.$2),
            secondary: Icon(option.$3, color: theme.secondary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: _intent == option.$1 ? theme.secondary : theme.alternate,
              ),
            ),
          ),
        ),
      ),
      _feedback(theme),
      Row(
        children: [
          Expanded(
            child: _secondaryButton(
              theme,
              'Terug',
              () => setState(() => _onboardingStep = 0),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _primaryButton(theme, 'Verder', () {
              if (_intent.isEmpty) {
                _setError('Kies hoe je AVARYN wilt gebruiken.');
                return;
              }
              setState(() {
                _error = null;
                _onboardingStep = 2;
              });
            }),
          ),
        ],
      ),
    ];
  }

  List<Widget> _onboardingCompletionStep(FlutterFlowTheme theme) {
    return [
      Icon(Icons.check_circle_outline, size: 52, color: theme.success),
      const SizedBox(height: 14),
      Text(
        'Je persoonlijke account is klaar',
        textAlign: TextAlign.center,
        style: theme.headlineSmall.copyWith(color: theme.primaryText),
      ),
      const SizedBox(height: 8),
      Text(
        _phase4AIntentLabel(_intent),
        textAlign: TextAlign.center,
        style: theme.bodyMedium.copyWith(color: theme.secondaryText),
      ),
      const SizedBox(height: 8),
      Text(
        'Hierna bevestig je expliciet een stal, uitnodiging of persoonlijke workspace.',
        textAlign: TextAlign.center,
        style: theme.bodySmall.copyWith(color: theme.secondaryText),
      ),
      const SizedBox(height: 18),
      _feedback(theme),
      _primaryButton(
        theme,
        'AVARYN openen',
        () => _savePersonalProfile(complete: true),
        icon: Icons.arrow_forward,
      ),
      const SizedBox(height: 10),
      TextButton(
        onPressed: _busy ? null : () => setState(() => _onboardingStep = 1),
        child: const Text('Keuze aanpassen'),
      ),
    ];
  }

  Widget _profilePage() {
    final theme = FlutterFlowTheme.of(context);
    final profile = _profile;
    final user = _user;
    if (profile == null && _error == null) return _loadingOrCallback();
    final providers =
        (user?.identities ?? const <UserIdentity>[])
            .map((identity) => identity.provider)
            .toSet()
            .toList()
          ..sort();
    return _pageFrame(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _avatar(theme, size: 86),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _phase4ADisplayName(profile ?? AuthProfileDataStruct()),
                      style: theme.headlineSmall.copyWith(
                        color: theme.primaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? 'Geen e-mailadres beschikbaar',
                      style: theme.bodyMedium.copyWith(
                        color: theme.secondaryText,
                      ),
                    ),
                    if (user?.emailConfirmedAt != null)
                      Text(
                        'Geverifieerd e-mailadres',
                        style: theme.bodySmall.copyWith(color: theme.success),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _feedback(theme),
          _authCard(theme, [
            Text(
              'Persoonlijk profiel',
              style: theme.titleLarge.copyWith(color: theme.primaryText),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _firstNameController,
              decoration: _fieldDecoration(theme, 'Voornaam'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lastNameController,
              decoration: _fieldDecoration(theme, 'Achternaam'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: _fieldDecoration(theme, 'Telefoonnummer (optioneel)'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: {'nl', 'en'}.contains(_locale) ? _locale : 'nl',
              decoration: _fieldDecoration(theme, 'Taalvoorkeur'),
              items: const [
                DropdownMenuItem(value: 'nl', child: Text('Nederlands')),
                DropdownMenuItem(
                  value: 'en',
                  child: Text('English (preference)'),
                ),
              ],
              onChanged: (value) => setState(() => _locale = value ?? 'nl'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _timeZone,
              decoration: _fieldDecoration(theme, 'Tijdzone'),
              items: _c007TimeZoneItems(),
              onChanged: (value) => setState(() => _timeZone = value ?? 'UTC'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value:
                  {'system', 'light', 'dark'}.contains(_themeMode)
                      ? _themeMode
                      : 'system',
              decoration: _fieldDecoration(theme, 'Thema'),
              items: const [
                DropdownMenuItem(value: 'system', child: Text('Systeem')),
                DropdownMenuItem(value: 'light', child: Text('Licht')),
                DropdownMenuItem(value: 'dark', child: Text('Donker')),
              ],
              onChanged: (value) {
                final mode = value ?? 'system';
                setState(() => _themeMode = mode);
                _applyTheme(mode);
              },
            ),
            const SizedBox(height: 12),
            _primaryButton(
              theme,
              'Profiel opslaan',
              () => _savePersonalProfile(),
              icon: Icons.save_outlined,
            ),
            const SizedBox(height: 10),
            _secondaryButton(
              theme,
              'Profielfoto vervangen',
              _uploadAvatar,
              icon: Icons.add_a_photo_outlined,
            ),
            if ((profile?.avatarObjectPath ?? '').isNotEmpty)
              TextButton(
                onPressed: _busy ? null : _removeAvatar,
                child: const Text('Profielfoto verwijderen'),
              ),
          ]),
          const SizedBox(height: 14),
          _authCard(theme, [
            Text(
              'Account en beveiliging',
              style: theme.titleLarge.copyWith(color: theme.primaryText),
            ),
            const SizedBox(height: 10),
            Text(
              providers.isEmpty
                  ? 'Aanmeldmethode niet beschikbaar'
                  : providers.map(_phase4AProviderLabel).join(' · '),
              style: theme.bodyMedium.copyWith(color: theme.primaryText),
            ),
            const SizedBox(height: 6),
            Text(
              'Aanmeldmethoden worden nooit stil samengevoegd of ontkoppeld. Veilig koppelen volgt pas na afzonderlijke provider-validatie.',
              style: theme.bodySmall.copyWith(color: theme.secondaryText),
            ),
            const SizedBox(height: 12),
            _secondaryButton(
              theme,
              'Wachtwoord herstellen via e-mail',
              _sendSecurityReset,
              icon: Icons.lock_reset,
            ),
          ]),
          const SizedBox(height: 14),
          _authCard(theme, [
            Text(
              'Gebruik van AVARYN',
              style: theme.titleLarge.copyWith(color: theme.primaryText),
            ),
            const SizedBox(height: 8),
            Text(
              _phase4AIntentLabel(profile?.onboardingIntent ?? _intent),
              style: theme.bodyMedium.copyWith(color: theme.primaryText),
            ),
            const SizedBox(height: 6),
            Text(
              FFAppState().selectedCloudStableId.trim().isEmpty
                  ? 'Kies een stal of persoonlijke workspace om je veilige werkcontext te activeren.'
                  : 'Je actieve stalcontext is server-side gevalideerd. Rollen komen nooit uit dit profiel.',
              style: theme.bodySmall.copyWith(color: theme.secondaryText),
            ),
            const SizedBox(height: 12),
            _secondaryButton(
              theme,
              FFAppState().selectedCloudStableId.trim().isEmpty
                  ? 'Stal of workspace kiezen'
                  : 'Stal en team beheren',
              () => context.pushNamed(
                FFAppState().selectedCloudStableId.trim().isEmpty
                    ? 'StableOnboardingHandoffPage'
                    : 'StableDetailsPage',
              ),
              icon: Icons.groups_outlined,
            ),
          ]),
          const SizedBox(height: 14),
          _authCard(theme, [
            Text(
              'Privacy en account',
              style: theme.titleLarge.copyWith(color: theme.primaryText),
            ),
            const SizedBox(height: 10),
            _secondaryButton(
              theme,
              'Alpha-privacyverklaring',
              () => context.pushNamed('AlphaPrivacyPage'),
              icon: Icons.privacy_tip_outlined,
            ),
            const SizedBox(height: 8),
            Text(
              'Definitieve gebruiksvoorwaarden en social login zijn uitgesteld tot na de eerste externe testerfase.',
              style: theme.bodySmall.copyWith(color: theme.secondaryText),
            ),
            const SizedBox(height: 12),
            _secondaryButton(theme, 'Uitloggen', _logout, icon: Icons.logout),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _deleteAccount,
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('Account permanent verwijderen'),
            ),
            const SizedBox(height: 6),
            Text(
              'Zelfbediening is uitsluitend beschikbaar voor een account '
              'zonder stal-, team- of bewaarde historie. Actieve rollen, '
              'historie en Apple-intrekking blijven veilig geblokkeerd.',
              style: theme.bodySmall.copyWith(color: theme.secondaryText),
            ),
          ]),
          const SizedBox(height: 34),
        ],
      ),
      narrow: false,
    );
  }

  Widget _accountInitials() {
    final profile = FFAppState().currentAuthProfile;
    return Center(
      child: Text(
        _phase4AInitials(profile),
        style: FlutterFlowTheme.of(
          context,
        ).labelSmall.copyWith(color: FlutterFlowTheme.of(context).accent1),
      ),
    );
  }

  Widget _accountGreeting({required bool compact}) {
    final profile = FFAppState().currentAuthProfile;
    final firstName = _phase4AFirstName(profile);
    return Text(
      compact
          ? 'Goedemorgen, $firstName. Dit vraagt vandaag je aandacht.'
          : 'Goedemorgen, $firstName. Dit vraagt vandaag je aandacht.',
      style: FlutterFlowTheme.of(
        context,
      ).bodyLarge.copyWith(color: FlutterFlowTheme.of(context).secondaryText),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == 'gate' && _legacyPrompt) {
      return _legacyOwnershipPrompt();
    }
    return switch (widget.mode) {
      'welcome' => _welcome(),
      'privacy' => _alphaPrivacy(),
      'email' => _emailChoice(),
      'login' => _loginForm(),
      'signup' => _signupForm(),
      'verify' => _verification(),
      'forgot' => _forgotPassword(),
      'reset' => _resetPassword(),
      'callback' => _loadingOrCallback(),
      'gate' => _loadingOrCallback(),
      'onboarding' => _onboarding(),
      'profile' => _profilePage(),
      'initials' => _accountInitials(),
      'greeting' => _accountGreeting(compact: false),
      'greetingCompact' => _accountGreeting(compact: true),
      _ => _welcome(),
    };
  }
}

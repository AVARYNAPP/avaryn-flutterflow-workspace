import 'dart:async';
import 'dart:convert';

import 'phase_4b_context_model.dart';
import 'phase_4c7_runtime_contract.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutterflow_generated/app_state.dart';
import 'package:flutterflow_generated/backend/schema/structs/index.dart';
import 'package:flutterflow_generated/flutter_flow/flutter_flow_theme.dart';
import 'package:flutterflow_generated/flutter_flow/flutter_flow_util.dart';
import 'package:sign_in_button/sign_in_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const String _phase4APrivacyPolicyUrl = String.fromEnvironment(
  'AVARYN_PRIVACY_POLICY_URL',
);
const String _phase4ATermsUrl = String.fromEnvironment('AVARYN_TERMS_URL');
const String _phase4ALegacyBackupId = 'legacy-unscoped-backup';
const String _phase4ALegacyLocalUserId = 'local-current-user';
const String _phase4ALegacyStableId = 'local-stable';
const int _phase4ALocalScopeSchemaVersion = 2;

bool get _phase4ALegalConfigured =>
    Uri.tryParse(_phase4APrivacyPolicyUrl)?.hasScheme == true &&
    Uri.tryParse(_phase4ATermsUrl)?.hasScheme == true;

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
  if (error is PostgrestException && error.code == '42P01') {
    return 'Het persoonlijke profiel is nog niet ingericht. Voer de Phase 4A Supabase-migratie uit.';
  }
  return 'Er ging iets mis. Probeer het opnieuw.';
}

AuthProfileDataStruct _phase4AProfileFromMap(Map<String, dynamic> data) {
  return AuthProfileDataStruct(
    id: _phase4ANullableString(data['id']),
    firstName: _phase4ANullableString(data['first_name']),
    lastName: _phase4ANullableString(data['last_name']),
    displayName: _phase4ANullableString(data['display_name']),
    avatarObjectPath: _phase4ANullableString(data['avatar_object_path']),
    phoneE164: _phase4ANullableString(data['phone_e164']),
    locale:
        _phase4ANullableString(data['locale']).isEmpty
            ? 'nl'
            : _phase4ANullableString(data['locale']),
    themeMode:
        _phase4ANullableString(data['theme_mode']).isEmpty
            ? 'system'
            : _phase4ANullableString(data['theme_mode']),
    onboardingIntent: _phase4ANullableString(data['onboarding_intent']),
    onboardingCompletedAt: _phase4ADate(data['onboarding_completed_at']),
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

AuthProfileDataStruct? _phase4ACachedProfile(String authUserId) {
  for (final profile in FFAppState().authProfileCaches) {
    if (profile.id == authUserId) return profile;
  }
  return null;
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
  bool _legalAccepted = false;
  bool _legacyPrompt = false;
  bool _offlineProfile = false;
  int _cooldownSeconds = 0;
  int _onboardingStep = 0;
  String _locale = 'nl';
  String _themeMode = 'system';
  String _intent = '';
  String _avatarUrl = '';
  String? _error;
  String? _notice;
  AuthProfileDataStruct? _profile;

  SupabaseClient get _client => Supabase.instance.client;

  User? get _user => _client.auth.currentUser;

  @override
  void initState() {
    super.initState();
    _emailController.text = FFAppState().authPendingEmail;
    _authSubscription = _client.auth.onAuthStateChange.listen((state) {
      if (!mounted) return;
      if (state.event == AuthChangeEvent.passwordRecovery) {
        context.goNamed('AuthResetPasswordPage');
        return;
      }
      if ((widget.mode == 'verify' || widget.mode == 'callback') &&
          state.session != null &&
          state.session!.user.emailConfirmedAt != null) {
        context.goNamed('AuthGatePage');
      }
    });
    if ({
      'gate',
      'callback',
      'verify',
      'onboarding',
      'profile',
    }.contains(widget.mode)) {
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
    try {
      final selected =
          await _client
              .from('profiles')
              .select()
              .eq('id', user.id)
              .maybeSingle();
      if (selected != null) {
        final profile = _phase4AProfileFromMap(selected);
        _phase4ACacheProfile(profile);
        return profile;
      }

      final metadata = user.userMetadata ?? const <String, dynamic>{};
      final firstName = _phase4ANullableString(
        metadata['given_name'] ?? metadata['first_name'],
      );
      final lastName = _phase4ANullableString(
        metadata['family_name'] ?? metadata['last_name'],
      );
      final displayName = _phase4ANullableString(
        metadata['full_name'] ?? metadata['name'],
      );
      final deviceLocale =
          WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      final payload = <String, dynamic>{
        'id': user.id,
        'display_name':
            displayName.isEmpty
                ? '${firstName} ${lastName}'.trim().isEmpty
                    ? 'AVARYN-gebruiker'
                    : '${firstName} ${lastName}'.trim()
                : displayName,
        'locale': deviceLocale.isEmpty ? 'nl' : deviceLocale,
        'theme_mode': 'system',
      };
      if (firstName.isNotEmpty) payload['first_name'] = firstName;
      if (lastName.isNotEmpty) payload['last_name'] = lastName;
      await _client.from('profiles').upsert(payload, onConflict: 'id');
      final created =
          await _client.from('profiles').select().eq('id', user.id).single();
      final profile = _phase4AProfileFromMap(created);
      _phase4ACacheProfile(profile);
      return profile;
    } catch (error) {
      final cached = _phase4ACachedProfile(user.id);
      if (cached != null) {
        _offlineProfile = true;
        FFAppState().currentAuthProfile = cached;
        return cached;
      }
      rethrow;
    }
  }

  Future<void> _bootstrapCallback() async {
    _setBusy(true);
    try {
      final session = _client.auth.currentSession;
      if (session == null) {
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
        if (!mounted) return;
        context.goNamed('AuthWelcomePage');
        return;
      }
      if (session.user.emailConfirmedAt == null &&
          (session.user.appMetadata['provider'] ?? '') == 'email') {
        FFAppState().authPendingEmail = session.user.email ?? '';
        if (!mounted) return;
        context.goNamed('AuthVerifyEmailPage');
        return;
      }
      final profile = await _loadOrCreateProfile(session.user);
      final previousAuthId = FFAppState().activeAuthAccountId.trim();
      if (previousAuthId.isNotEmpty && previousAuthId != session.user.id) {
        await _phase4APurgeOperationalSecureState(previousAuthId);
      }
      final legacyPrompt = _phase4AActivateScope(session.user.id);
      _applyTheme(profile.themeMode);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _legacyPrompt = legacyPrompt;
      });
      if (profile.onboardingCompletedAt == null) {
        context.goNamed('OnboardingPage');
      } else if (!legacyPrompt) {
        if (FFAppState().selectedCloudStableId.trim().isEmpty) {
          context.goNamed('StableOnboardingHandoffPage');
        } else {
          context.goNamed('TodayDashboardPage');
        }
      }
    } catch (error) {
      _setError(_phase4AAuthError(error));
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _bootstrapProfileScreen() async {
    _setBusy(true);
    try {
      final user = _user;
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

  Future<void> _signInWithProvider(OAuthProvider provider) async {
    if (_busy) return;
    _setBusy(true);
    _setError(null);
    try {
      final started = await _client.auth.signInWithOAuth(
        provider,
        redirectTo: _phase4ARedirectUrl('/auth/callback'),
      );
      if (!started) {
        _setNotice('Aanmelden is geannuleerd.');
      }
    } on AuthException catch (error) {
      _setError(_phase4AAuthError(error));
    } catch (_) {
      _setError(
        'De provider is niet geconfigureerd of de aanmelding is geannuleerd.',
      );
    } finally {
      _setBusy(false);
    }
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
    if (_phase4ALegalConfigured && !_legalAccepted) {
      _setError('Accepteer eerst het privacybeleid en de voorwaarden.');
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
    if (_client.auth.currentSession == null) {
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
    final lastName = _lastNameController.text.trim();
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
      final payload = <String, dynamic>{
        'id': user.id,
        'first_name': firstName,
        'last_name': lastName.isEmpty ? null : lastName,
        'display_name': '$firstName $lastName'.trim(),
        'phone_e164': phone.isEmpty ? null : phone,
        'locale': _locale,
        'theme_mode': _themeMode,
      };
      if (_intent.isNotEmpty) payload['onboarding_intent'] = _intent;
      if (complete) {
        payload['onboarding_completed_at'] =
            DateTime.now().toUtc().toIso8601String();
      }
      final updated =
          await _client
              .from('profiles')
              .upsert(payload, onConflict: 'id')
              .select()
              .single();
      final profile = _phase4AProfileFromMap(updated);
      _phase4ACacheProfile(profile);
      _applyTheme(profile.themeMode);
      if (!mounted) return;
      setState(() => _profile = profile);
      if (complete) {
        context.goNamed('StableOnboardingHandoffPage');
      } else {
        _setNotice('Je profiel is opgeslagen.');
      }
    } catch (error) {
      _setError(_phase4AAuthError(error));
    } finally {
      _setBusy(false);
    }
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
      final oldPath = _profile?.avatarObjectPath ?? '';
      final path = '${user.id}/avatar.$extension';
      await _client.storage
          .from('avatars')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );
      await _client
          .from('profiles')
          .update({'avatar_object_path': path})
          .eq('id', user.id);
      if (oldPath.isNotEmpty && oldPath != path) {
        await _client.storage.from('avatars').remove([oldPath]);
      }
      final profile = _profile ?? await _loadOrCreateProfile(user);
      profile.avatarObjectPath = path;
      profile.updatedAt = DateTime.now().toUtc();
      _phase4ACacheProfile(profile);
      final signed = await _signedAvatarUrl(path);
      if (!mounted) return;
      setState(() {
        _profile = profile;
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
      await _client.storage.from('avatars').remove([path]);
      await _client
          .from('profiles')
          .update({'avatar_object_path': null})
          .eq('id', user.id);
      final profile = _profile!;
      profile.avatarObjectPath = '';
      profile.updatedAt = DateTime.now().toUtc();
      _phase4ACacheProfile(profile);
      if (mounted) {
        setState(() {
          _profile = profile;
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
              'Je lokale gegevens blijven veilig bewaard voor dit account.',
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
    if (!mounted) return;
    if (profile.onboardingCompletedAt == null) {
      context.goNamed('OnboardingPage');
    } else {
      if (FFAppState().selectedCloudStableId.trim().isEmpty) {
        context.goNamed('StableOnboardingHandoffPage');
      } else {
        context.goNamed('TodayDashboardPage');
      }
    }
  }

  Future<void> _openLegal(String url, String label) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      _setError('$label is nog niet geconfigureerd.');
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) _setError('$label kon niet worden geopend.');
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
            IgnorePointer(
              ignoring: _busy,
              child: Semantics(
                button: true,
                label: 'Doorgaan met Apple',
                child: SizedBox(
                  width: double.infinity,
                  child: SignInButton(
                    Theme.of(context).brightness == Brightness.dark
                        ? Buttons.appleDark
                        : Buttons.apple,
                    text: 'Doorgaan met Apple',
                    onPressed: () => _signInWithProvider(OAuthProvider.apple),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            IgnorePointer(
              ignoring: _busy,
              child: Semantics(
                button: true,
                label: 'Doorgaan met Google',
                child: SizedBox(
                  width: double.infinity,
                  child: SignInButton(
                    Buttons.google,
                    text: 'Doorgaan met Google',
                    onPressed: () => _signInWithProvider(OAuthProvider.google),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _secondaryButton(
              theme,
              'Doorgaan met e-mail',
              () => context.goNamed('AuthEmailPage'),
              icon: Icons.mail_outline,
            ),
            const SizedBox(height: 18),
            _feedback(theme),
            if (_phase4ALegalConfigured)
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  TextButton(
                    onPressed:
                        () => _openLegal(
                          _phase4APrivacyPolicyUrl,
                          'Privacybeleid',
                        ),
                    child: const Text('Privacybeleid'),
                  ),
                  TextButton(
                    onPressed:
                        () => _openLegal(_phase4ATermsUrl, 'Voorwaarden'),
                    child: const Text('Voorwaarden'),
                  ),
                ],
              )
            else
              Text(
                'Privacybeleid en voorwaarden moeten vóór release met echte HTTPS-links worden geconfigureerd.',
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
            if (_phase4ALegalConfigured)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _legalAccepted,
                onChanged:
                    (value) => setState(() => _legalAccepted = value ?? false),
                title: Text(
                  'Ik accepteer het privacybeleid en de voorwaarden.',
                  style: theme.bodySmall.copyWith(color: theme.primaryText),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.warning,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Lokale ontwikkelmodus: juridische links ontbreken. Dit blokkeert een release, maar niet het testen van e-mailauthenticatie.',
                  style: theme.bodySmall.copyWith(color: theme.primaryText),
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
    return _pageFrame(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _brand(theme, eyebrow: 'Beveiligde toegang'),
          const SizedBox(height: 32),
          _authCard(theme, [
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
                  : 'De aanmeldlink wordt gecontroleerd.',
              textAlign: TextAlign.center,
              style: theme.bodyMedium.copyWith(color: theme.secondaryText),
            ),
            const SizedBox(height: 16),
            _feedback(theme),
            if (_error != null)
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
        initialValue: {'nl', 'en'}.contains(_locale) ? _locale : 'nl',
        decoration: _fieldDecoration(theme, 'Taal'),
        items: const [
          DropdownMenuItem(value: 'nl', child: Text('Nederlands')),
          DropdownMenuItem(value: 'en', child: Text('English (preference)')),
        ],
        onChanged: (value) => setState(() => _locale = value ?? 'nl'),
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
          if (_offlineProfile)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.warning,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Offline profielweergave. Wijzigingen vereisen een netwerkverbinding.',
              ),
            ),
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
              initialValue: {'nl', 'en'}.contains(_locale) ? _locale : 'nl',
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
              initialValue:
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
              'De geselecteerde stal hieronder blijft lokale prototypecontext en is nog geen cloudlidmaatschap: ${FFAppState().currentLocalStableId}.',
              style: theme.bodySmall.copyWith(color: theme.secondaryText),
            ),
            if (FFAppState().hasLegacyLocalDataBackup &&
                _phase4AScopeFor(user?.id ?? '')?.horses.isEmpty != false) ...[
              const SizedBox(height: 12),
              _secondaryButton(
                theme,
                'Bestaande lokale testdata koppelen',
                user == null ? null : _attachLegacy,
                icon: Icons.link,
              ),
            ],
          ]),
          const SizedBox(height: 14),
          _authCard(theme, [
            Text(
              'Privacy en account',
              style: theme.titleLarge.copyWith(color: theme.primaryText),
            ),
            const SizedBox(height: 10),
            if (_phase4ALegalConfigured) ...[
              _secondaryButton(
                theme,
                'Privacybeleid',
                () => _openLegal(_phase4APrivacyPolicyUrl, 'Privacybeleid'),
                icon: Icons.privacy_tip_outlined,
              ),
              const SizedBox(height: 8),
              _secondaryButton(
                theme,
                'Voorwaarden',
                () => _openLegal(_phase4ATermsUrl, 'Voorwaarden'),
                icon: Icons.description_outlined,
              ),
            ] else
              Text(
                'Juridische links ontbreken en blokkeren een release.',
                style: theme.bodySmall.copyWith(color: theme.error),
              ),
            const SizedBox(height: 12),
            _secondaryButton(theme, 'Uitloggen', _logout, icon: Icons.logout),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('Account verwijderen — nog niet beschikbaar'),
            ),
            const SizedBox(height: 6),
            Text(
              'De beveiligde serverfunctie is voorbereid maar niet uitgerold. Apple-intrekking en providerconfiguratie moeten eerst aantoonbaar werken; er wordt geen fictieve verwijdering gemeld.',
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
          ? 'Goedemorgen, $firstName. Orion vraagt je aandacht vóór de training.'
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

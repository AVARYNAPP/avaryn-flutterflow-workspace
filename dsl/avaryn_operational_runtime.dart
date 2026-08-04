import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'phase_4c7_runtime_contract.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutterflow_generated/app_state.dart';
import 'package:flutterflow_generated/flutter_flow/flutter_flow_theme.dart';
import 'package:flutterflow_generated/flutter_flow/flutter_flow_util.dart';
import 'package:image/image.dart' as image;
import 'package:openpgp/openpgp.dart';
import 'package:realtime_client/realtime_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '/custom_code/widgets/avaryn_orion_photo.dart';

bool _operationalTimezonesInitialized = false;
final Set<String> _operationalPendingPurgeAccounts = <String>{};
final Map<RealtimeChannel, SupabaseClient> _operationalPendingChannelRemovals =
    <RealtimeChannel, SupabaseClient>{};
Timer? _operationalSecurityCleanupTimer;
bool _operationalSecurityCleanupRunning = false;

Future<bool> _deleteOperationalSecureStateForAccount(String authUserId) async {
  final normalized = authUserId.trim();
  if (normalized.isEmpty) return true;
  try {
    const storage = FlutterSecureStorage();
    final values = await storage.readAll();
    final keys = phase4C7SecureKeysForAccount(values.keys, normalized);
    for (final key in keys) {
      await storage.delete(key: key);
    }
    final remaining = await storage.readAll();
    return phase4C7SecureKeysForAccount(remaining.keys, normalized).isEmpty;
  } catch (_) {
    return false;
  }
}

void _scheduleOperationalSecurityCleanup({
  String authUserId = '',
  Map<RealtimeChannel, SupabaseClient> channels =
      const <RealtimeChannel, SupabaseClient>{},
}) {
  final normalized = authUserId.trim();
  if (normalized.isNotEmpty) {
    _operationalPendingPurgeAccounts.add(normalized);
  }
  _operationalPendingChannelRemovals.addAll(channels);
  if (_operationalSecurityCleanupRunning ||
      _operationalSecurityCleanupTimer != null ||
      (_operationalPendingPurgeAccounts.isEmpty &&
          _operationalPendingChannelRemovals.isEmpty)) {
    return;
  }
  _operationalSecurityCleanupTimer = Timer(const Duration(seconds: 2), () {
    _operationalSecurityCleanupTimer = null;
    unawaited(_retryOperationalSecurityCleanup());
  });
}

Future<void> _retryOperationalSecurityCleanup() async {
  if (_operationalSecurityCleanupRunning) return;
  _operationalSecurityCleanupRunning = true;
  try {
    for (final entry
        in Map<RealtimeChannel, SupabaseClient>.from(
          _operationalPendingChannelRemovals,
        ).entries) {
      try {
        await entry.value.removeChannel(entry.key);
        _operationalPendingChannelRemovals.remove(entry.key);
      } catch (_) {
        // Retained for the next bounded retry.
      }
    }
    for (final authUserId in Set<String>.from(
      _operationalPendingPurgeAccounts,
    )) {
      if (await _deleteOperationalSecureStateForAccount(authUserId)) {
        _operationalPendingPurgeAccounts.remove(authUserId);
      }
    }
  } finally {
    _operationalSecurityCleanupRunning = false;
    _scheduleOperationalSecurityCleanup();
  }
}

String _operationalString(dynamic value) =>
    value == null ? '' : value.toString().trim();

Map<String, dynamic> _operationalMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> _operationalRows(dynamic value) =>
    value is List
        ? value
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(growable: false)
        : const <Map<String, dynamic>>[];

class _OperationalMediaException implements Exception {
  const _OperationalMediaException(this.status, this.code);

  final int status;
  final String code;

  @override
  String toString() => code;
}

DateTime? _operationalDate(dynamic value) =>
    value is DateTime
        ? value
        : value is String
        ? DateTime.tryParse(value)
        : null;

String _operationalDateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

DateTime? _operationalParseDisplayDate(dynamic value) {
  if (value is DateTime) return value;
  final text = _operationalString(value);
  final parts = text.split('-');
  if (parts.length == 3 &&
      parts[0].length == 2 &&
      parts[1].length == 2 &&
      parts[2].length == 4) {
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day != null && month != null && year != null) {
      final parsed = DateTime(year, month, day);
      if (parsed.year == year && parsed.month == month && parsed.day == day) {
        return parsed;
      }
    }
  }
  return DateTime.tryParse(text);
}

String _operationalDisplayDate(dynamic value) {
  final parsed = _operationalParseDisplayDate(value);
  if (parsed == null) return _operationalString(value);
  return '${parsed.day.toString().padLeft(2, '0')}-'
      '${parsed.month.toString().padLeft(2, '0')}-'
      '${parsed.year.toString().padLeft(4, '0')}';
}

class AvarynOperationalRuntime extends StatefulWidget {
  const AvarynOperationalRuntime({
    super.key,
    this.width,
    this.height,
    required this.mode,
  });

  final double? width;
  final double? height;
  final String mode;

  @override
  State<AvarynOperationalRuntime> createState() =>
      _AvarynOperationalRuntimeState();
}

class _AvarynOperationalRuntimeState extends State<AvarynOperationalRuntime> {
  final _client = Supabase.instance.client;
  final _secureStorage = const FlutterSecureStorage();
  final _uuid = const Uuid();
  final _channels = <RealtimeChannel>[];
  final _requestLedger = Phase4C7RequestLedger();

  List<Map<String, dynamic>> _horses = const [];
  List<Map<String, dynamic>> _schedule = const [];
  List<Map<String, dynamic>> _feedingPlans = const [];
  List<Map<String, dynamic>> _feedingPlanVersions = const [];
  List<Map<String, dynamic>> _feedingPlanItems = const [];
  List<Map<String, dynamic>> _feedingHistory = const [];
  List<Map<String, dynamic>> _conflicts = const [];
  List<Map<String, dynamic>> _offlineSchedule = const [];
  List<Map<String, dynamic>> _horseAccessGrants = const [];
  List<Map<String, dynamic>> _horseRelationships = const [];
  List<Map<String, dynamic>> _horseMedia = const [];
  Map<String, String> _horseProfilePhotoUrls = const {};
  Map<String, Map<String, Map<String, dynamic>>> _horseIdentifiers = const {};
  List<Map<String, dynamic>> _stableRoster = const [];
  List<Map<String, dynamic>> _planningRoster = const [];
  Map<String, dynamic> _actorMembership = const {};
  Map<String, dynamic> _horseCapabilities = const {};

  StreamSubscription<AuthState>? _authSubscription;
  String _boundUserId = '';
  String _stableId = '';
  String _stableName = '';
  String _stableTimezone = '';
  String _selectedHorseId = '';
  String _selectedFeedingPlanId = '';
  String _selectedFeedingVersionId = '';
  String _calendarView = 'day';
  String _calendarHorseFilter = '';
  String _calendarMemberFilter = '';
  String _calendarCategoryFilter = '';
  String _calendarTeamFilter = 'team';
  String _planningDisplayMode = 'list';
  String _horseProfileTab = 'overview';
  String _error = '';
  String _notice = '';
  DateTime? _scheduleDate;
  int _authorityVersion = 0;
  int _cursor = 0;
  bool _loading = true;
  bool _busy = false;
  bool _offline = false;
  bool _permissionDenied = false;
  bool _offlineReady = false;
  bool _dayGuidanceActive = false;
  bool _secureCleanupPending = false;
  Timer? _wakeDebounce;
  BuildContext? _sensitiveConflictDialogContext;
  Route<dynamic>? _sensitiveConflictDialogRoute;
  BuildContext? _sensitivePlanningDialogContext;
  Route<dynamic>? _sensitivePlanningDialogRoute;
  int _sensitiveStateGeneration = 0;

  String get _storagePrefix {
    final userId =
        _boundUserId.isNotEmpty
            ? _boundUserId
            : (_client.auth.currentUser?.id ?? 'signed-out');
    return 'avaryn.4c7.$userId.$_stableId';
  }

  String _storageKey(String suffix) => '$_storagePrefix.$suffix';

  @override
  void initState() {
    super.initState();
    if (!_operationalTimezonesInitialized) {
      timezone_data.initializeTimeZones();
      _operationalTimezonesInitialized = true;
    }
    _authSubscription = _client.auth.onAuthStateChange.listen((state) {
      unawaited(_handleAuthBoundary(state));
    });
    _load();
  }

  @override
  void didUpdateWidget(covariant AvarynOperationalRuntime oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) _load();
  }

  @override
  void dispose() {
    _dismissSensitiveDialogs();
    _authSubscription?.cancel();
    _wakeDebounce?.cancel();
    for (final channel in _channels) {
      unawaited(_client.removeChannel(channel));
    }
    _channels.clear();
    _clearDecryptedState();
    super.dispose();
  }

  Future<void> _handleAuthBoundary(AuthState state) async {
    final nextUserId = state.session?.user.id ?? '';
    if (_boundUserId.isEmpty) {
      _boundUserId = nextUserId;
      return;
    }
    if (nextUserId == _boundUserId) return;
    await _purgeOperationalState(clearSelectedStable: true);
    _boundUserId = nextUserId;
    if (!mounted) return;
    setState(() {
      _permissionDenied = true;
      _offline = false;
      _loading = false;
      _error =
          nextUserId.isEmpty
              ? 'Meld aan om de beveiligde stalgegevens te openen.'
              : 'Account gewijzigd. Kies opnieuw een toegankelijke stal.';
      if (_secureCleanupPending) {
        _error =
            '$_error Beveiligde opslagopruiming loopt op de achtergrond door.';
      }
    });
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet && mounted) {
      setState(() {
        _loading = true;
        _error = '';
        _notice = '';
        _permissionDenied = false;
      });
    }
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        await _purgeOperationalState(clearSelectedStable: true);
        _error = 'Meld aan om de beveiligde stalgegevens te openen.';
        return;
      }
      if (_operationalPendingPurgeAccounts.contains(user.id)) {
        final cleanupComplete = await _deleteOperationalSecureStateForAccount(
          user.id,
        );
        if (!cleanupComplete) {
          throw StateError('LOCAL_PURGE_INCOMPLETE');
        }
        _operationalPendingPurgeAccounts.remove(user.id);
      }
      _secureCleanupPending = false;
      if (_boundUserId.isNotEmpty && _boundUserId != user.id) {
        await _purgeOperationalState(clearSelectedStable: true);
      }
      _boundUserId = user.id;
      _stableId = FFAppState().selectedCloudStableId.trim();
      if (_stableId.isEmpty) {
        final preference =
            await _client
                .from('account_workspace_preferences')
                .select('last_selected_stable_id')
                .eq('user_id', user.id)
                .maybeSingle();
        _stableId = _operationalString(preference?['last_selected_stable_id']);
        if (_stableId.isNotEmpty) {
          FFAppState().selectedCloudStableId = _stableId;
        }
      }
      if (_stableId.isEmpty) {
        _clearDecryptedState();
        _requestLedger.reset();
        _error = 'Kies eerst een actieve stal.';
        return;
      }

      _requestLedger.bindScope(user.id, _stableId);
      await _restoreCachedStableTimezone();
      await _refreshStableTimezone();
      await _refreshAuthorityAndTopics();
      await _pullDurableChanges();
      await _fetchOperationalData();
      await _flushOfflineMutations();
      await _fetchOperationalData();
      await _readOfflineAvailability();
      await _restorePendingMarkers();
      _offline = false;
    } catch (error) {
      if (_requiresSecurityReset(error)) {
        await _purgeOperationalState(clearSelectedStable: true);
        _permissionDenied = true;
        _error =
            'Je toegang is gewijzigd. Lokale werkdata is direct gewist; '
            'kies opnieuw een toegankelijke stal.';
        if (_secureCleanupPending) {
          _error =
              'Je toegang is gewijzigd. De data is uit het geheugen gewist; '
              'beveiligde opslagopruiming loopt op de achtergrond door.';
        }
      } else {
        _clearDecryptedState();
        await _restoreCachedStableTimezone();
        await _restoreCachedAuthorityVersion();
        final restored = await _restoreEncryptedDayset();
        _offline = restored;
        _error =
            restored
                ? 'Geen verbinding. Alleen de versleutelde toegewezen dagset '
                    'is tijdelijk beschikbaar.'
                : _friendlyError(error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _busy = false;
        });
      }
    }
  }

  bool _requiresSecurityReset(Object error) {
    if (error is AuthException) return true;
    if (error is FunctionException && error.status == 401) return true;
    if (error is StateError && error.message == 'LOCAL_PURGE_INCOMPLETE') {
      return true;
    }
    if (error is StateError && error.message == 'STALE_PLANNING_CONFIRMATION') {
      return true;
    }
    if (error is PostgrestException) {
      final message = '${error.code} ${error.message}'.toUpperCase();
      return error.code == '42501' ||
          message.contains('SYNC_RESET_REQUIRED') ||
          message.contains('AUTHENTICATION_REQUIRED') ||
          message.contains('MEMBERSHIP_UNAVAILABLE') ||
          message.contains('STABLE_UNAVAILABLE');
    }
    return false;
  }

  String _friendlyError(Object error) {
    if (error is StateError &&
        error.message == 'DURABLE_REQUEST_STORAGE_REQUIRED') {
      return 'Deze bewerking vereist veilige lokale request-opslag. Controleer de browseropslag en probeer opnieuw.';
    }
    final mediaCode = _mediaFailureCode(error);
    if (mediaCode.isNotEmpty) {
      if (mediaCode.contains('EDIT_REQUIRED') ||
          mediaCode.contains('FORBIDDEN')) {
        return 'Je hebt voor deze private mediahandeling onvoldoende rechten.';
      }
      if (mediaCode.contains('VERSION_CONFLICT')) {
        return 'Deze media is intussen gewijzigd. Vernieuw en probeer opnieuw.';
      }
      if (mediaCode.contains('CONTENT_TYPE') ||
          mediaCode.contains('VARIANT') ||
          mediaCode.contains('THUMBNAIL') ||
          mediaCode.contains('BYTE_SIZE')) {
        return 'Het mediabestand is niet veilig te verwerken. Kies een geldige JPG, PNG of PDF.';
      }
      if (mediaCode.contains('UPLOAD_INCOMPLETE')) {
        return 'De upload is nog niet compleet. Probeer dezelfde bijlage opnieuw.';
      }
      if (mediaCode.contains('STATUS_UNCERTAIN') ||
          mediaCode.contains('SESSION_CLOSED')) {
        return 'De uploadstatus wordt veilig hersteld. Probeer exact dezelfde bijlage opnieuw.';
      }
      if (mediaCode.contains('UNAVAILABLE') ||
          mediaCode.contains('NOT_READY')) {
        return 'Deze private media is niet meer beschikbaar.';
      }
    }
    if (error is StorageException) {
      return 'De private upload kon niet worden bevestigd. Probeer dezelfde bijlage opnieuw.';
    }
    if (error is PostgrestException) {
      final message = error.message.toUpperCase();
      if (message.contains('NOT_AUTHORIZED')) {
        return 'Je hebt voor deze handeling onvoldoende rechten.';
      }
      if (message.contains('ROW_VERSION_CONFLICT')) {
        return 'Deze gegevens zijn intussen gewijzigd. Vernieuw en probeer opnieuw.';
      }
      if (message.contains('REQUEST_ID_REUSED')) {
        return 'Deze bewerking is al verwerkt. Vernieuw het overzicht.';
      }
      if (message.contains('INVALID_HORSE_PROFILE') ||
          message.contains('INVALID_BIRTH_DATE')) {
        return 'Controleer de kerngegevens en probeer opnieuw.';
      }
      if (message.contains('HORSE_ACCESS_ALREADY_ACTIVE')) {
        return 'Deze toegang bestaat al. Trek haar eerst in om de rechten te wijzigen.';
      }
      if (message.contains('RELATIONSHIP_ALREADY_ACTIVE')) {
        return 'Deze paard-teamrelatie bestaat al.';
      }
      if (message.contains('GRANT_NOT_ALLOWED')) {
        return 'Deze combinatie van stalrol en paardtoegang is niet toegestaan.';
      }
      if (message.contains('FEEDING_VERSION_IMMUTABLE') ||
          message.contains('FEEDING_VERSION_NOT_APPROVABLE')) {
        return 'Deze voerplanversie kan niet meer worden gewijzigd of mist geldige items.';
      }
      if (message.contains('FEEDING_UNIT_CONVERSION_REQUIRED')) {
        return 'Gebruik exact dezelfde eenheid als het geactiveerde voerplan.';
      }
      if (message.contains('FEEDING_ACTIVATION') ||
          message.contains('FEEDING_TEMPORARY') ||
          message.contains('FEEDING_STANDARD')) {
        return 'Dit voerplan kan niet veilig worden geactiveerd. Controleer datumvensters en voerslots.';
      }
      if (message.contains('NUTRITION_UNAVAILABLE')) {
        return 'Dit voerplan is niet beschikbaar binnen je actuele toegang.';
      }
    }
    return 'De beveiligde gegevens konden niet worden geladen. Probeer opnieuw.';
  }

  Future<void> _refreshStableTimezone() async {
    final stable =
        await _client
            .from('stables')
            .select('name,timezone')
            .eq('id', _stableId)
            .maybeSingle();
    final timezoneName = _operationalString(stable?['timezone']);
    if (timezoneName.isEmpty) {
      throw const PostgrestException(
        message: 'STABLE_UNAVAILABLE',
        code: '42501',
      );
    }
    try {
      timezone.getLocation(timezoneName);
    } catch (_) {
      throw const PostgrestException(
        message: 'STABLE_UNAVAILABLE',
        code: '42501',
      );
    }
    _stableName = _operationalString(stable?['name']);
    _stableTimezone = timezoneName;
    await _secureStorage.write(
      key: _storageKey('timezone'),
      value: _stableTimezone,
    );
  }

  Future<void> _restoreCachedStableTimezone() async {
    if (_stableId.isEmpty) return;
    final cached = _operationalString(
      await _secureStorage.read(key: _storageKey('timezone')),
    );
    if (cached.isEmpty) return;
    try {
      timezone.getLocation(cached);
      _stableTimezone = cached;
    } catch (_) {
      await _secureStorage.delete(key: _storageKey('timezone'));
      _stableTimezone = '';
    }
  }

  timezone.Location get _stableLocation =>
      timezone.getLocation(_stableTimezone);

  timezone.TZDateTime _stableNow() => timezone.TZDateTime.now(_stableLocation);

  bool get _selectedScheduleDateIsToday {
    final stableNow = _stableNow();
    final selected = _scheduleDate ?? stableNow;
    return selected.year == stableNow.year &&
        selected.month == stableNow.month &&
        selected.day == stableNow.day;
  }

  String _stableLocalTimestamp(DateTime value) {
    final local = timezone.TZDateTime.from(value, _stableLocation);
    return '${_operationalDateKey(local)}T'
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}:'
        '${local.second.toString().padLeft(2, '0')}';
  }

  String _stableClock(dynamic value) {
    final parsed = _operationalDate(value);
    if (parsed == null) return '--:--';
    final local = timezone.TZDateTime.from(parsed, _stableLocation);
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  String _stableDateTimeLabel(dynamic value) {
    final parsed = _operationalDate(value);
    if (parsed == null) return _operationalString(value);
    final local = timezone.TZDateTime.from(parsed, _stableLocation);
    return '${_operationalDisplayDate(local)} · ${_stableClock(parsed)}';
  }

  Future<void> _refreshAuthorityAndTopics() async {
    final cachedAuthority =
        int.tryParse(
          await _secureStorage.read(key: _storageKey('authority')) ?? '',
        ) ??
        0;
    final previousAuthority =
        _authorityVersion > 0 ? _authorityVersion : cachedAuthority;
    final result = _operationalMap(
      await _client.rpc(
        'get_realtime_topics',
        params: {'p_stable_id': _stableId},
      ),
    );
    final refreshedAuthority =
        int.tryParse(_operationalString(result['authority_version'])) ?? 0;
    if (refreshedAuthority < 1) {
      throw StateError('Invalid authority version.');
    }
    if (previousAuthority > 0 && previousAuthority != refreshedAuthority) {
      final cleanupComplete = await _purgeOperationalState(
        clearSelectedStable: false,
      );
      if (!cleanupComplete) {
        throw StateError('LOCAL_PURGE_INCOMPLETE');
      }
    }
    _authorityVersion = refreshedAuthority;

    for (final channel in _channels) {
      await _client.removeChannel(channel);
    }
    _channels.clear();
    final topics = _operationalRows(result['topics']);
    for (final topic in topics) {
      final token = _operationalString(topic['topic']);
      if (token.isEmpty) continue;
      final channel = _client
          .channel(token, opts: const RealtimeChannelConfig(private: true))
          .onBroadcast(
            event: 'change_available',
            callback: (_) => _scheduleWakeRefresh(),
          );
      channel.subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.channelError ||
            status == RealtimeSubscribeStatus.timedOut) {
          _scheduleWakeRefresh();
        }
      });
      _channels.add(channel);
    }
    await _secureStorage.write(
      key: _storageKey('authority'),
      value: _authorityVersion.toString(),
    );
    await _secureStorage.write(
      key: _storageKey('timezone'),
      value: _stableTimezone,
    );
  }

  Future<void> _restoreCachedAuthorityVersion() async {
    if (_authorityVersion > 0 || _stableId.isEmpty) return;
    final cached = await _secureStorage.read(key: _storageKey('authority'));
    _authorityVersion = int.tryParse(cached ?? '') ?? 0;
  }

  void _scheduleWakeRefresh() {
    _wakeDebounce?.cancel();
    _wakeDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted && !_busy) unawaited(_load(quiet: true));
    });
  }

  Future<void> _pullDurableChanges() async {
    final storedCursor = await _secureStorage.read(key: _storageKey('cursor'));
    _cursor = int.tryParse(storedCursor ?? '') ?? 0;
    final result = _operationalMap(
      await _client.rpc(
        'pull_operation_changes',
        params: {
          'p_stable_id': _stableId,
          'p_after_sequence': _cursor,
          'p_limit': 500,
          'p_expected_authority_version': _authorityVersion,
        },
      ),
    );
    _cursor =
        int.tryParse(_operationalString(result['next_cursor'])) ?? _cursor;
    await _secureStorage.write(
      key: _storageKey('cursor'),
      value: _cursor.toString(),
    );
  }

  (DateTime, DateTime) _scheduleRange() {
    final selected = _scheduleDate ?? _stableNow();
    final day = DateTime(selected.year, selected.month, selected.day);
    if (_calendarView == 'week') {
      final start = day.subtract(Duration(days: day.weekday - 1));
      return (start, start.add(const Duration(days: 6)));
    }
    if (_calendarView == 'month') {
      return (
        DateTime(day.year, day.month),
        DateTime(day.year, day.month + 1, 0),
      );
    }
    return (day, day);
  }

  Future<void> _fetchOperationalData() async {
    final stableNow = _stableNow();
    _scheduleDate ??= DateTime(stableNow.year, stableNow.month, stableNow.day);
    final range = _scheduleRange();
    final selectedDate = _operationalDateKey(_scheduleDate!);
    final userId = _client.auth.currentUser?.id ?? '';
    final results = await Future.wait<dynamic>([
      _client
          .from('horses')
          .select(
            'id,display_name,official_name,birth_date,sex,breed,discipline,'
            'level,profile_media_asset_id,row_version,status',
          )
          .eq('stable_id', _stableId)
          .eq('status', 'active')
          .order('display_name'),
      _client.rpc(
        'list_schedule_calendar',
        params: {
          'p_stable_id': _stableId,
          'p_from_local_date':
              widget.mode == 'planning'
                  ? _operationalDateKey(range.$1)
                  : selectedDate,
          'p_through_local_date':
              widget.mode == 'planning'
                  ? _operationalDateKey(range.$2)
                  : selectedDate,
        },
      ),
      widget.mode == 'feeding'
          ? _client
              .from('feeding_plans')
              .select(
                'id,horse_id,name,plan_type,status,effective_from,'
                'effective_until,row_version,active_version_id',
              )
              .eq('stable_id', _stableId)
              .neq('status', 'retired')
              .order('effective_from', ascending: false)
          : Future<dynamic>.value(const <Map<String, dynamic>>[]),
      _client.rpc('list_sync_conflicts', params: {'p_stable_id': _stableId}),
      _client
          .from('stable_memberships')
          .select('id,stable_member_id,role,status,row_version')
          .eq('stable_id', _stableId)
          .eq('user_id', userId)
          .eq('status', 'active')
          .maybeSingle(),
      widget.mode == 'planning' || widget.mode == 'feeding'
          ? _client
              .from('stable_members')
              .select('id,display_name,function_title,status')
              .eq('stable_id', _stableId)
              .eq('status', 'active')
              .order('display_name')
          : Future<dynamic>.value(const <Map<String, dynamic>>[]),
      _client
          .from('horse_identifiers')
          .select(
            'id,horse_id,identifier_type,identifier_value,valid_until,'
            'row_version,updated_at',
          )
          .eq('stable_id', _stableId)
          .order('updated_at', ascending: false),
    ]);
    _horses = _operationalRows(results[0]);
    await _refreshHorseProfilePhotos();
    _schedule = await _attachLatestScheduleExecutions(
      _operationalRows(results[1]),
    );
    _feedingPlans = _operationalRows(results[2]);
    _conflicts = _operationalRows(results[3]);
    _actorMembership = _operationalMap(results[4]);
    _planningRoster = _operationalRows(results[5]);
    final identifiers = <String, Map<String, Map<String, dynamic>>>{};
    for (final identifier in _operationalRows(results[6])) {
      final horseId = _operationalString(identifier['horse_id']);
      final type = _operationalString(identifier['identifier_type']);
      if (horseId.isEmpty || !const {'passport', 'chip'}.contains(type)) {
        continue;
      }
      identifiers
          .putIfAbsent(horseId, () => <String, Map<String, dynamic>>{})
          .putIfAbsent(type, () => identifier);
    }
    _horseIdentifiers = identifiers;
    if (_actorMembership.isEmpty) {
      throw const PostgrestException(
        message: 'MEMBERSHIP_UNAVAILABLE',
        code: '42501',
      );
    }
    if (_selectedHorseId.isNotEmpty &&
        !_horses.any(
          (horse) => _operationalString(horse['id']) == _selectedHorseId,
        )) {
      _selectedHorseId = '';
    }
    if (_selectedHorseId.isEmpty && _horses.isNotEmpty) {
      _selectedHorseId = _operationalString(_horses.first['id']);
    }
    if (widget.mode == 'horses' && _selectedHorseId.isNotEmpty) {
      await _fetchHorseManagementData();
    } else {
      _horseCapabilities = const {};
      _horseAccessGrants = const [];
      _horseRelationships = const [];
      _horseMedia = const [];
      _stableRoster = const [];
    }
    if (widget.mode == 'feeding') {
      await _fetchFeedingManagementData();
    } else {
      _feedingPlanVersions = const [];
      _feedingPlanItems = const [];
      _feedingHistory = const [];
      _selectedFeedingPlanId = '';
      _selectedFeedingVersionId = '';
    }
  }

  Future<void> _fetchFeedingManagementData() async {
    final planIds = _feedingPlans
        .map((plan) => _operationalString(plan['id']))
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (planIds.isEmpty) {
      _feedingPlanVersions = const [];
      _feedingPlanItems = const [];
      _selectedFeedingPlanId = '';
      _selectedFeedingVersionId = '';
      _feedingHistory = const [];
      return;
    }
    if (!planIds.contains(_selectedFeedingPlanId)) {
      _selectedFeedingPlanId = planIds.first;
    }
    _feedingPlanVersions = _operationalRows(
      await _client
          .from('feeding_plan_versions')
          .select(
            'id,feeding_plan_id,version_number,status,row_version,'
            'change_reason,approved_at',
          )
          .inFilter('feeding_plan_id', planIds)
          .order('version_number', ascending: false),
    );
    final versionIds = _feedingPlanVersions
        .map((version) => _operationalString(version['id']))
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    _feedingPlanItems =
        versionIds.isEmpty
            ? const []
            : _operationalRows(
              await _client
                  .from('feeding_plan_items')
                  .select(
                    'id,feeding_plan_version_id,product_brand,product_name,'
                    'product_variant,item_category,source_status,'
                    'planned_quantity,unit_code,'
                    'offering_method,round_code,local_time,weekdays,'
                    'interval_days,override_key,default_stable_member_id,'
                    'batch_lot,expires_on,instruction,row_version',
                  )
                  .inFilter('feeding_plan_version_id', versionIds)
                  .order('round_code')
                  .order('local_time'),
            );
    final selectedVersions = _feedingPlanVersions
        .where(
          (version) =>
              _operationalString(version['feeding_plan_id']) ==
              _selectedFeedingPlanId,
        )
        .toList(growable: false);
    if (!selectedVersions.any(
      (version) =>
          _operationalString(version['id']) == _selectedFeedingVersionId,
    )) {
      _selectedFeedingVersionId =
          selectedVersions.isEmpty
              ? ''
              : _operationalString(selectedVersions.first['id']);
    }
    final stableToday = _stableNow();
    final historyFrom = stableToday.subtract(const Duration(days: 365));
    _feedingHistory = _operationalRows(
      await _client.rpc(
        'list_schedule_calendar',
        params: {
          'p_stable_id': _stableId,
          'p_from_local_date': _operationalDateKey(historyFrom),
          'p_through_local_date': _operationalDateKey(stableToday),
        },
      ),
    ).where((item) => item['item_kind'] == 'feeding').toList(growable: false);
  }

  bool get _isStableManager {
    final role = _operationalString(_actorMembership['role']);
    return role == 'owner' || role == 'admin';
  }

  bool get _canEditSelectedHorse =>
      _horseCapabilities['can_edit_profile'] == true;

  bool get _canArchiveSelectedHorse =>
      _horseCapabilities['can_archive'] == true;

  bool get _canManageHorseAccess =>
      _horseCapabilities['can_manage_basic_access'] == true ||
      _horseCapabilities['can_manage_schedule_access'] == true ||
      _horseCapabilities['can_manage_media_access'] == true;

  bool get _canManageHorseRelationships =>
      _horseCapabilities['can_manage_relationships'] == true;

  bool get _canViewSelectedHorseMedia =>
      _horseCapabilities['can_view_media'] == true;

  bool get _canEditSelectedHorseMedia =>
      _horseCapabilities['can_edit_media'] == true;

  Future<void> _ensureStableRoster() async {
    if (_stableRoster.isNotEmpty) return;
    final rosterRows = _operationalRows(
      await _client
          .from('stable_members')
          .select('id,display_name,function_title,status')
          .eq('stable_id', _stableId)
          .eq('status', 'active')
          .order('display_name'),
    );
    final membershipRows = _operationalRows(
      await _client
          .from('stable_memberships')
          .select('id,user_id,stable_member_id,role,status,row_version')
          .eq('stable_id', _stableId)
          .eq('status', 'active'),
    );
    _stableRoster = rosterRows
        .map((member) {
          Map<String, dynamic>? membership;
          for (final candidate in membershipRows) {
            if (candidate['stable_member_id'] == member['id']) {
              membership = candidate;
              break;
            }
          }
          return {
            ...member,
            'membership_id': membership?['id'],
            'user_id': membership?['user_id'],
            'role': membership?['role'],
            'membership_row_version': membership?['row_version'],
          };
        })
        .toList(growable: false);
  }

  Future<void> _fetchHorseManagementData() async {
    _horseCapabilities = _operationalMap(
      await _client.rpc(
        'get_horse_capabilities',
        params: {'p_horse_id': _selectedHorseId},
      ),
    );
    _horseMedia =
        _canViewSelectedHorseMedia
            ? await _fetchLinkedMedia(horseId: _selectedHorseId)
            : const [];
    if (!_canManageHorseAccess && !_canManageHorseRelationships) {
      _horseAccessGrants = const [];
      _horseRelationships = const [];
      _stableRoster = const [];
      return;
    }

    await _ensureStableRoster();

    if (_canManageHorseAccess) {
      _horseAccessGrants = _operationalRows(
        await _client
            .from('horse_access_grants')
            .select(
              'id,membership_id,category,can_view,can_execute,can_edit,'
              'can_manage,status,valid_from,valid_until,row_version,grant_reason',
            )
            .eq('horse_id', _selectedHorseId)
            .eq('status', 'active')
            .order('category'),
      );
    } else {
      _horseAccessGrants = const [];
    }
    if (_canManageHorseRelationships) {
      _horseRelationships = _operationalRows(
        await _client
            .from('horse_relationships')
            .select(
              'id,horse_id,stable_member_id,relationship_type,label,status,'
              'valid_from,valid_until,row_version',
            )
            .eq('horse_id', _selectedHorseId)
            .eq('status', 'active')
            .order('relationship_type'),
      );
    } else {
      _horseRelationships = const [];
    }
  }

  Future<void> _refreshHorseProfilePhotos() async {
    final entries = await Future.wait(
      _horses.map((horse) async {
        final horseId = _operationalString(horse['id']);
        final assetId = _operationalString(horse['profile_media_asset_id']);
        if (horseId.isEmpty || assetId.isEmpty) return null;
        try {
          final response = await _client.functions.invoke(
            'media-assets',
            body: {
              'action': 'download',
              'media_asset_id': assetId,
              'variant': 'thumbnail',
            },
          );
          final data = _operationalMap(response.data);
          final uri = Uri.tryParse(
            _operationalString(data['signed_download_url']),
          );
          final configuredStorageUri = Uri.tryParse(_client.storage.url);
          if (response.status != 200 ||
              uri == null ||
              configuredStorageUri == null ||
              uri.scheme != 'https' ||
              uri.host.toLowerCase() !=
                  configuredStorageUri.host.toLowerCase() ||
              uri.port != configuredStorageUri.port ||
              !uri.path.startsWith('/storage/v1/object/sign/horse-media/')) {
            return null;
          }
          return MapEntry(horseId, uri.toString());
        } catch (_) {
          return null;
        }
      }),
    );
    _horseProfilePhotoUrls = Map.fromEntries(
      entries.whereType<MapEntry<String, String>>(),
    );
  }

  Widget _horsePhoto(
    Map<String, dynamic> horse, {
    required double width,
    required double height,
  }) {
    final url = _horseProfilePhotoUrls[_operationalString(horse['id'])] ?? '';
    if (url.isEmpty) {
      return AvarynOrionPhoto(width: width, height: height);
    }
    return Image.network(
      url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder:
          (context, error, stackTrace) =>
              AvarynOrionPhoto(width: width, height: height),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchLinkedMedia({
    String horseId = '',
    String scheduleExecutionId = '',
  }) async {
    if (horseId.isEmpty && scheduleExecutionId.isEmpty) return const [];
    dynamic query = _client
        .from('media_links')
        .select('media_asset_id')
        .isFilter('archived_at', null);
    query =
        scheduleExecutionId.isNotEmpty
            ? query.eq('schedule_execution_id', scheduleExecutionId)
            : query
                .eq('horse_id', horseId)
                .isFilter('schedule_execution_id', null);
    final links = _operationalRows(await query);
    final assetIds = links
        .map((link) => _operationalString(link['media_asset_id']))
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (assetIds.isEmpty) return const [];
    return _operationalRows(
      await _client
          .from('media_assets')
          .select(
            'id,horse_id,status,original_filename,mime_type,byte_size,'
            'row_version,ready_at',
          )
          .inFilter('id', assetIds)
          .eq('status', 'ready')
          .order('ready_at', ascending: false),
    );
  }

  Future<List<Map<String, dynamic>>> _attachLatestScheduleExecutions(
    List<Map<String, dynamic>> schedule,
  ) async {
    return Future.wait(
      schedule.map((item) async {
        if (!const {
          'completed',
          'skipped',
          'in_progress',
        }.contains(_operationalString(item['state']))) {
          return item;
        }
        final itemId = _operationalString(item['schedule_item_id']);
        if (itemId.isEmpty) return item;
        final executions = _operationalRows(
          await _client.rpc(
            'list_schedule_executions',
            params: {'p_schedule_item_id': itemId},
          ),
        );
        if (executions.isEmpty) return item;
        final execution = executions.last;
        return {
          ...item,
          'execution_id': execution['execution_id'],
          'execution_actor_user_id': execution['actor_user_id'],
          'execution_status': execution['execution_status'],
          'actual_started_at': execution['actual_started_at'],
          'actual_completed_at': execution['actual_completed_at'],
          'execution_note': execution['note'],
        };
      }),
    );
  }

  Future<void> _readOfflineAvailability() async {
    if (kIsWeb) {
      _offlineReady = false;
      return;
    }
    final payload = await _secureStorage.read(key: _storageKey('dayset'));
    if (payload == null || payload.isEmpty) {
      _offlineReady = false;
      return;
    }
    final envelope = _operationalMap(jsonDecode(payload));
    final expiresAt = _operationalDate(envelope['expires_at']);
    _offlineReady =
        expiresAt != null &&
        expiresAt.isAfter(DateTime.now().toUtc()) &&
        _operationalString(envelope['ciphertext']).isNotEmpty;
    if (!_offlineReady) {
      await _secureStorage.delete(key: _storageKey('dayset'));
    }
  }

  Future<void> _restorePendingMarkers() async {
    if (kIsWeb) return;
    final ciphertext = await _secureStorage.read(key: _storageKey('pending'));
    if (ciphertext == null || ciphertext.isEmpty) return;
    final keys = await _ensureDeviceKeys();
    _markPendingScheduleItems(await _readOfflineMutations(keys));
  }

  Future<Map<String, String>> _ensureDeviceKeys() async {
    if (kIsWeb) {
      throw StateError('OFFLINE_REQUIRES_OS_KEYSTORE');
    }
    var deviceId = await _secureStorage.read(key: _storageKey('device_id'));
    var privateKey = await _secureStorage.read(key: _storageKey('private_key'));
    var publicKey = await _secureStorage.read(key: _storageKey('public_key'));
    var passphrase = await _secureStorage.read(
      key: _storageKey('key_passphrase'),
    );
    if (deviceId == null ||
        privateKey == null ||
        publicKey == null ||
        passphrase == null) {
      deviceId = _uuid.v4();
      passphrase = '${_uuid.v4()}${_uuid.v4()}';
      final keyPair = await OpenPGP.generate(
        options:
            Options()
              ..name = 'AVARYN offline device'
              ..email = 'device@avaryn.invalid'
              ..passphrase = passphrase
              ..keyOptions = (KeyOptions()..rsaBits = 2048),
      );
      privateKey = keyPair.privateKey;
      publicKey = keyPair.publicKey;
      await _secureStorage.write(
        key: _storageKey('device_id'),
        value: deviceId,
      );
      await _secureStorage.write(
        key: _storageKey('private_key'),
        value: privateKey,
      );
      await _secureStorage.write(
        key: _storageKey('public_key'),
        value: publicKey,
      );
      await _secureStorage.write(
        key: _storageKey('key_passphrase'),
        value: passphrase,
      );
    }
    return {
      'device_id': deviceId,
      'private_key': privateKey,
      'public_key': publicKey,
      'passphrase': passphrase,
    };
  }

  Future<void> _prepareOfflineDayset() async {
    if (kIsWeb) {
      setState(() {
        _error =
            'Veilige offline dagsets vereisen OS-backed sleutelopslag en '
            'zijn daarom niet beschikbaar in de webapp.';
      });
      return;
    }
    if (!_selectedScheduleDateIsToday) {
      setState(() {
        _error =
            'Ga terug naar Vandaag voordat je de versleutelde offline '
            'dagset voorbereidt.';
      });
      return;
    }
    await _guarded(() async {
      final keys = await _ensureDeviceKeys();
      await _runIdempotentRpc(
        operation: 'register_sync_device',
        intentKey: keys['device_id']!,
        buildParams:
            (requestId) => {
              'p_stable_id': _stableId,
              'p_device_instance_id': keys['device_id'],
              'p_encryption_public_key': keys['public_key'],
              'p_request_id': requestId,
            },
      );
      final localDate = _operationalDateKey(_stableNow());
      final responseEnvelope = _operationalMap(
        await _client.rpc(
          'get_encrypted_offline_dayset',
          params: {
            'p_stable_id': _stableId,
            'p_device_instance_id': keys['device_id'],
            'p_local_date': localDate,
            'p_timezone': _stableTimezone,
            'p_expected_authority_version': _authorityVersion,
          },
        ),
      );
      final envelope = <String, dynamic>{
        ...responseEnvelope,
        'local_date': localDate,
      };
      if (_operationalString(envelope['format']) != 'openpgp-aes256' ||
          _operationalString(envelope['ciphertext']).isEmpty) {
        throw StateError('Invalid encrypted dayset.');
      }
      await _secureStorage.write(
        key: _storageKey('dayset'),
        value: jsonEncode(envelope),
      );
      _offlineReady = true;
      _notice =
          'De toegewezen dagset is versleuteld opgeslagen tot maximaal 36 uur.';
    });
  }

  Future<bool> _restoreEncryptedDayset() async {
    if (kIsWeb || _stableId.isEmpty) return false;
    try {
      final encoded = await _secureStorage.read(key: _storageKey('dayset'));
      if (encoded == null) return false;
      final envelope = _operationalMap(jsonDecode(encoded));
      final expiresAt = _operationalDate(envelope['expires_at']);
      if (expiresAt == null || expiresAt.isBefore(DateTime.now().toUtc())) {
        await _secureStorage.delete(key: _storageKey('dayset'));
        return false;
      }
      final keys = await _ensureDeviceKeys();
      final bytes = base64Decode(_operationalString(envelope['ciphertext']));
      final armored = await OpenPGP.armorEncode(
        'PGP MESSAGE',
        Uint8List.fromList(bytes),
      );
      final plaintext = await OpenPGP.decrypt(
        armored,
        keys['private_key']!,
        keys['passphrase']!,
      );
      final dayset = _operationalMap(jsonDecode(plaintext));
      final localDate = _operationalDateKey(_stableNow());
      if (!phase4C7DaysetMetadataMatches(
        envelope: envelope,
        plaintext: dayset,
        stableId: _stableId,
        timezone: _stableTimezone,
        localDate: localDate,
        authorityVersion: _authorityVersion,
        nowUtc: DateTime.now().toUtc(),
      )) {
        await _purgeOperationalState(clearSelectedStable: true);
        return false;
      }
      _offlineSchedule = _operationalRows(dayset['schedule_items']);
      _schedule = _offlineSchedule;
      final pending = await _readOfflineMutations(keys);
      _markPendingScheduleItems(pending);
      _offlineReady = true;
      return true;
    } catch (_) {
      _clearDecryptedState();
      return false;
    }
  }

  Future<void> _queueOfflineCompletion(
    Map<String, dynamic> item, {
    Map<String, dynamic>? feedingDetails,
  }) async {
    if (kIsWeb) {
      setState(() {
        _error =
            'Offline uitvoeringen vereisen de mobiele of desktop-app met '
            'OS-backed sleutelopslag.';
      });
      return;
    }
    await _guarded(() async {
      final keys = await _ensureDeviceKeys();
      var queued = List<Map<String, dynamic>>.from(
        await _readOfflineMutations(keys),
      );
      final itemId = _operationalString(item['schedule_item_id']);
      if (queued.any(
        (mutation) =>
            _operationalString(mutation['schedule_item_id']) == itemId,
      )) {
        _markPendingScheduleItems(queued);
        _notice = 'Deze uitvoering staat al veilig klaar voor synchronisatie.';
        return;
      }
      queued = phase4C7QueueOnce(queued, {
        'kind':
            item['item_kind'] == 'feeding'
                ? 'feeding_execution'
                : 'schedule_execution',
        'schedule_item_id': itemId,
        'request_id': _uuid.v4(),
        'completed_at': DateTime.now().toUtc().toIso8601String(),
        'recorded_local_at': _stableLocalTimestamp(DateTime.now()),
        'recorded_timezone': _stableTimezone,
        if (feedingDetails != null) ...feedingDetails,
      });
      await _writeOfflineMutations(queued, keys);
      _markPendingScheduleItems(queued);
      _notice =
          'Offline voltooiing versleuteld klaargezet voor synchronisatie.';
    });
  }

  Future<List<Map<String, dynamic>>> _readOfflineMutations(
    Map<String, String> keys,
  ) async {
    final ciphertext = await _secureStorage.read(key: _storageKey('pending'));
    if (ciphertext == null || ciphertext.isEmpty) return [];
    final plaintext = await OpenPGP.decrypt(
      ciphertext,
      keys['private_key']!,
      keys['passphrase']!,
    );
    return _operationalRows(jsonDecode(plaintext));
  }

  Future<void> _writeOfflineMutations(
    List<Map<String, dynamic>> queued,
    Map<String, String> keys,
  ) async {
    if (queued.isEmpty) {
      await _secureStorage.delete(key: _storageKey('pending'));
      return;
    }
    final ciphertext = await OpenPGP.encrypt(
      jsonEncode(queued),
      keys['public_key']!,
    );
    await _secureStorage.write(key: _storageKey('pending'), value: ciphertext);
  }

  void _markPendingScheduleItems(List<Map<String, dynamic>> queued) {
    _schedule = phase4C7MarkPendingItems(_schedule, queued);
  }

  Future<void> _flushOfflineMutations() async {
    if (kIsWeb) return;
    final ciphertext = await _secureStorage.read(key: _storageKey('pending'));
    if (ciphertext == null || ciphertext.isEmpty) return;
    final keys = await _ensureDeviceKeys();
    final queued = await _readOfflineMutations(keys);
    final remaining = List<Map<String, dynamic>>.from(queued);
    var failedCount = 0;
    for (final mutation in List<Map<String, dynamic>>.from(queued)) {
      final itemId = _operationalString(mutation['schedule_item_id']);
      final params = {
        'p_stable_id': _stableId,
        'p_device_instance_id': keys['device_id'],
        'p_expected_authority_version': _authorityVersion,
        'p_schedule_item_id': itemId,
        'p_request_id': mutation['request_id'],
        'p_execution_status': 'completed',
        'p_actual_started_at': null,
        'p_actual_completed_at': mutation['completed_at'],
        'p_recorded_local_at': mutation['recorded_local_at'],
        'p_recorded_timezone': mutation['recorded_timezone'],
        'p_note':
            _operationalString(mutation['comments']).isEmpty
                ? null
                : mutation['comments'],
      };
      try {
        if (mutation['kind'] == 'feeding_execution') {
          await _client.rpc(
            'sync_feeding_execution',
            params: {
              ...params,
              'p_actual_quantity': mutation['actual_quantity'],
              'p_unit_code': mutation['unit_code'],
              'p_remaining_quantity': mutation['remaining_quantity'],
              'p_deviation_code': mutation['deviation_code'],
              'p_observation':
                  _operationalString(mutation['observation']).isEmpty
                      ? null
                      : mutation['observation'],
              'p_batch_lot': null,
            },
          );
        } else {
          await _client.rpc('sync_schedule_execution', params: params);
        }
        final updated = phase4C7RemoveProcessedMutation(remaining, mutation);
        remaining
          ..clear()
          ..addAll(updated);
        await _writeOfflineMutations(remaining, keys);
      } catch (error) {
        if (_requiresSecurityReset(error) || error is! PostgrestException) {
          rethrow;
        }
        failedCount += 1;
      }
    }
    if (failedCount > 0) {
      _notice =
          '$failedCount offline uitvoering${failedCount == 1 ? '' : 'en'} '
          'vereist controle; overige uitvoeringen zijn verwerkt.';
    }
  }

  Future<dynamic> _runIdempotentRpc({
    required String operation,
    required String intentKey,
    required Map<String, dynamic> Function(String requestId) buildParams,
  }) async {
    final params = _requestLedger.acquire(
      operation,
      intentKey,
      () => buildParams(_uuid.v4()),
    );
    try {
      final result = await _client.rpc(operation, params: params);
      _requestLedger.complete(operation, intentKey);
      return result;
    } on PostgrestException catch (error) {
      // A five-character PostgreSQL SQLSTATE is a definitive database
      // rejection. Gateway/PGRST failures can still be ambiguous, so those
      // retain the exact request payload and ID for a safe retry.
      if (RegExp(r'^[0-9A-Z]{5}$').hasMatch(error.code ?? '')) {
        _requestLedger.complete(operation, intentKey);
      }
      rethrow;
    }
  }

  Future<dynamic> _runDurableIdempotentRpc({
    required String operation,
    required String intentKey,
    Map<String, String> initialReplayValues = const {},
    void Function()? scopePreflight,
    required Map<String, dynamic> Function(
      String requestId,
      Map<String, String> replayValues,
    )
    buildParams,
  }) async {
    scopePreflight?.call();
    final digest =
        sha256.convert(utf8.encode('$operation\n$intentKey')).toString();
    final storageKey = _storageKey('request.$digest');
    final persistedValue = await _secureStorage.read(key: storageKey);
    Map<String, dynamic>? persistedRecord;
    if (!phase5B2DurableStorageIsAbsent(persistedValue)) {
      try {
        persistedRecord = _operationalMap(jsonDecode(persistedValue!));
      } catch (_) {
        throw StateError('DURABLE_REQUEST_STORAGE_REQUIRED');
      }
    }
    late Phase5B2DurableRequestRecord record;
    try {
      record = phase5B2ResolveDurableRequestRecord(
        persistedRecord,
        _uuid.v4,
        initialReplayValues,
      );
    } catch (_) {
      throw StateError('DURABLE_REQUEST_STORAGE_REQUIRED');
    }
    final encodedRecord = jsonEncode({
      'request_id': record.requestId,
      'replay_values': record.replayValues,
    });
    if (encodedRecord != persistedValue) {
      await _secureStorage.write(key: storageKey, value: encodedRecord);
      final persisted = await _secureStorage.read(key: storageKey);
      if (persisted != encodedRecord) {
        throw StateError('DURABLE_REQUEST_STORAGE_REQUIRED');
      }
    }
    try {
      scopePreflight?.call();
    } catch (_) {
      try {
        await _secureStorage.delete(key: storageKey);
      } catch (_) {
        // The account-wide purge retry remains the fail-closed cleanup path
        // if the exact stale request record cannot be removed immediately.
      }
      rethrow;
    }
    try {
      final result = await _client.rpc(
        operation,
        params: buildParams(record.requestId, record.replayValues),
      );
      try {
        await _secureStorage.delete(key: storageKey);
      } catch (_) {
        // Retaining a completed request ID is safe: the server will return
        // the same idempotent outcome when this exact intent is retried.
      }
      return result;
    } on PostgrestException catch (error) {
      if (RegExp(r'^[0-9A-Z]{5}$').hasMatch(error.code ?? '')) {
        try {
          await _secureStorage.delete(key: storageKey);
        } catch (_) {
          // A stale definitive request ID remains harmless for the same
          // payload and is removed by the account/stable purge boundary.
        }
      }
      rethrow;
    }
  }

  String _mediaFailureCode(Object error) {
    if (error is _OperationalMediaException) return error.code;
    if (error is FunctionException) {
      final details =
          error.details is Map
              ? Map<String, dynamic>.from(error.details as Map)
              : const <String, dynamic>{};
      return _operationalString(details['code']);
    }
    return '';
  }

  int _mediaFailureStatus(Object error) {
    if (error is _OperationalMediaException) return error.status;
    if (error is FunctionException) return error.status;
    return 0;
  }

  bool _mediaFailureIsDefinitive(Object error) {
    final status = _mediaFailureStatus(error);
    final code = _mediaFailureCode(error);
    if (status < 400 || status >= 500) return false;
    return !const {
      'MEDIA_UPLOAD_INCOMPLETE',
      'MEDIA_UPLOAD_SIGNING_UNAVAILABLE',
      'MEDIA_DOWNLOAD_SIGNING_UNAVAILABLE',
      'MEDIA_UPLOAD_SESSION_CLOSED',
      'MEDIA_UPLOAD_STATUS_UNCERTAIN',
    }.contains(code);
  }

  Future<void> _deleteDurableMediaRecord(String storageKey) async {
    try {
      await _secureStorage.delete(key: storageKey);
    } catch (_) {
      // The exact request envelope remains safe and the account/stable purge
      // will remove it. A later retry is still idempotent server-side.
    }
  }

  Future<bool> _recoverCompletedMediaUpload(String createRequestId) async {
    final actorId = _client.auth.currentUser?.id ?? '';
    if (actorId.isEmpty || createRequestId.isEmpty) return false;
    final recovered = _operationalMap(
      await _client
          .from('media_assets')
          .select('id,status')
          .eq('uploaded_by_user_id', actorId)
          .eq('created_request_id', createRequestId)
          .eq('status', 'ready')
          .maybeSingle(),
    );
    return _operationalString(recovered['id']).isNotEmpty &&
        _operationalString(recovered['status']) == 'ready';
  }

  String _mediaMimeType(String extension) => switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'pdf' => 'application/pdf',
    _ => '',
  };

  Uint8List _buildMediaThumbnail(Uint8List bytes, String mimeType) {
    final image.Decoder decoder = switch (mimeType) {
      'image/jpeg' => image.JpegDecoder(),
      'image/png' => image.PngDecoder(),
      _ =>
        throw const _OperationalMediaException(
          400,
          'MEDIA_CONTENT_TYPE_INVALID',
        ),
    };
    final info = decoder.startDecode(bytes);
    if (info == null ||
        info.numFrames != 1 ||
        info.width <= 0 ||
        info.height <= 0 ||
        info.width * info.height * 4 > 32 * 1024 * 1024) {
      throw const _OperationalMediaException(400, 'MEDIA_CONTENT_TYPE_INVALID');
    }
    final decoded = decoder.decodeFrame(0);
    if (decoded == null) {
      throw const _OperationalMediaException(400, 'MEDIA_CONTENT_TYPE_INVALID');
    }
    var maxDimension = 512;
    while (maxDimension >= 192) {
      final resized =
          decoded.width >= decoded.height
              ? image.copyResize(
                decoded,
                width: maxDimension,
                interpolation: image.Interpolation.average,
              )
              : image.copyResize(
                decoded,
                height: maxDimension,
                interpolation: image.Interpolation.average,
              );
      final encoded = switch (mimeType) {
        'image/jpeg' => image.encodeJpg(resized, quality: 82),
        'image/png' => image.encodePng(resized, level: 9),
        _ => Uint8List(0),
      };
      if (encoded.isNotEmpty && encoded.length <= 1024 * 1024) {
        return encoded;
      }
      maxDimension = (maxDimension * 0.75).floor();
    }
    throw const _OperationalMediaException(400, 'MEDIA_THUMBNAIL_INVALID');
  }

  Future<Uint8List?> _readPickedMediaBytes(
    file_picker.PlatformFile file,
    int maxBytes,
  ) async {
    final inMemory = file.bytes;
    if (inMemory != null) {
      return inMemory.length <= maxBytes ? inMemory : null;
    }
    final stream = file.readStream;
    if (stream == null) return null;
    final builder = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      if (builder.length + chunk.length > maxBytes) return null;
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  Future<void> _pickAndUploadMedia({
    required String horseId,
    String scheduleExecutionId = '',
    bool imagesOnly = false,
  }) async {
    if (_offline || _busy || horseId.isEmpty) return;
    final picked =
        imagesOnly
            ? await file_picker.FilePicker.pickFiles(
              type: file_picker.FileType.custom,
              allowedExtensions: const ['jpg', 'jpeg', 'png'],
              allowMultiple: false,
              withData: false,
              withReadStream: true,
            )
            : await file_picker.FilePicker.pickFiles(
              type: file_picker.FileType.custom,
              allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
              allowMultiple: false,
              withData: false,
              withReadStream: true,
            );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;
    final filename = file.name.trim();
    final extension = (file.extension ?? '').trim().toLowerCase();
    final mimeType = _mediaMimeType(extension);
    if (filename.isEmpty || mimeType.isEmpty) {
      setState(
        () =>
            _error =
                imagesOnly
                    ? 'Kies een geldige JPG- of PNG-afbeelding.'
                    : 'Kies een geldige JPG-, PNG- of PDF-bijlage.',
      );
      return;
    }
    final maxBytes =
        mimeType == 'application/pdf' ? 20 * 1024 * 1024 : 10 * 1024 * 1024;
    if (file.size <= 0 || file.size > maxBytes) {
      setState(
        () =>
            _error =
                mimeType == 'application/pdf'
                    ? 'Kies een PDF kleiner dan 20 MB.'
                    : 'Kies een afbeelding kleiner dan 10 MB.',
      );
      return;
    }
    final bytes = await _readPickedMediaBytes(file, maxBytes);
    if (bytes == null || bytes.isEmpty || bytes.length != file.size) {
      setState(
        () => _error = 'Het gekozen bestand kon niet volledig worden gelezen.',
      );
      return;
    }
    await _guarded(() async {
      final thumbnail =
          mimeType == 'application/pdf'
              ? null
              : _buildMediaThumbnail(bytes, mimeType);
      await _uploadMediaBytes(
        horseId: horseId,
        scheduleExecutionId: scheduleExecutionId,
        filename: filename,
        mimeType: mimeType,
        original: bytes,
        thumbnail: thumbnail,
      );
      _notice =
          scheduleExecutionId.isEmpty
              ? 'Private Horse-media veilig toegevoegd.'
              : 'Privébewijs veilig aan de uitvoering gekoppeld.';
      await _load(quiet: true);
    });
  }

  Future<void> _uploadMediaBytes({
    required String horseId,
    required String scheduleExecutionId,
    required String filename,
    required String mimeType,
    required Uint8List original,
    required Uint8List? thumbnail,
  }) async {
    final contentHash = sha256.convert(original).toString();
    final intentKey = [
      horseId,
      scheduleExecutionId,
      filename,
      mimeType,
      contentHash,
    ].join('|');
    final digest =
        sha256.convert(utf8.encode('media-upload\n$intentKey')).toString();
    final storageKey = _storageKey('request.$digest');
    final persistedValue = await _secureStorage.read(key: storageKey);
    Map<String, dynamic>? persistedRecord;
    if (!phase5B2DurableStorageIsAbsent(persistedValue)) {
      try {
        persistedRecord = _operationalMap(jsonDecode(persistedValue!));
      } catch (_) {
        throw StateError('DURABLE_REQUEST_STORAGE_REQUIRED');
      }
    }
    late Phase5B2DurableRequestRecord record;
    try {
      record = phase5B2ResolveDurableRequestRecord(persistedRecord, _uuid.v4, {
        'finalize_request_id': _uuid.v4(),
      });
    } catch (_) {
      throw StateError('DURABLE_REQUEST_STORAGE_REQUIRED');
    }
    final encodedRecord = jsonEncode({
      'request_id': record.requestId,
      'replay_values': record.replayValues,
    });
    if (persistedValue != encodedRecord) {
      await _secureStorage.write(key: storageKey, value: encodedRecord);
      if (await _secureStorage.read(key: storageKey) != encodedRecord) {
        throw StateError('DURABLE_REQUEST_STORAGE_REQUIRED');
      }
    }

    String mediaAssetId = '';
    int? rowVersion;
    try {
      late FunctionResponse created;
      try {
        created = await _client.functions.invoke(
          'media-assets',
          body: {
            'action': 'create',
            'horse_id': horseId,
            'schedule_execution_id':
                scheduleExecutionId.isEmpty ? null : scheduleExecutionId,
            'original_filename': filename,
            'mime_type': mimeType,
            'request_id': record.requestId,
          },
        );
      } on FunctionException catch (error) {
        if (_mediaFailureCode(error) == 'MEDIA_UPLOAD_SESSION_CLOSED') {
          try {
            if (await _recoverCompletedMediaUpload(record.requestId)) {
              await _deleteDurableMediaRecord(storageKey);
              return;
            }
          } catch (_) {
            // The prior finalize outcome stays ambiguous. Retain the durable
            // request envelope and retry this exact attachment later.
          }
          throw const _OperationalMediaException(
            503,
            'MEDIA_UPLOAD_STATUS_UNCERTAIN',
          );
        }
        rethrow;
      }
      final createData = _operationalMap(created.data);
      if (created.status != 200) {
        final createCode = _operationalString(createData['code']);
        if (createCode == 'MEDIA_UPLOAD_SESSION_CLOSED') {
          if (await _recoverCompletedMediaUpload(record.requestId)) {
            await _deleteDurableMediaRecord(storageKey);
            return;
          }
          throw const _OperationalMediaException(
            503,
            'MEDIA_UPLOAD_STATUS_UNCERTAIN',
          );
        }
        throw _OperationalMediaException(created.status, createCode);
      }
      mediaAssetId = _operationalString(createData['media_asset_id']);
      rowVersion = int.tryParse(_operationalString(createData['row_version']));
      final uploads = _operationalRows(createData['uploads']);
      if (_operationalString(createData['status']) == 'ready' &&
          mediaAssetId.isNotEmpty &&
          rowVersion != null &&
          uploads.isEmpty) {
        await _deleteDurableMediaRecord(storageKey);
        return;
      }
      if (mediaAssetId.isEmpty || rowVersion == null || uploads.isEmpty) {
        throw const _OperationalMediaException(
          503,
          'MEDIA_UPLOAD_SIGNING_UNAVAILABLE',
        );
      }
      for (final upload in uploads) {
        final variant = _operationalString(upload['variant']);
        final objectPath = _operationalString(upload['object_path']);
        final uploadToken = _operationalString(upload['upload_token']);
        final expectedMime = _operationalString(upload['expected_mime_type']);
        final variantBytes =
            variant == 'original'
                ? original
                : variant == 'thumbnail'
                ? thumbnail
                : null;
        if (objectPath.isEmpty ||
            uploadToken.isEmpty ||
            expectedMime != mimeType ||
            variantBytes == null ||
            variantBytes.isEmpty) {
          throw const _OperationalMediaException(409, 'MEDIA_VARIANT_MISMATCH');
        }
        try {
          await _client.storage
              .from('horse-media')
              .uploadBinaryToSignedUrl(
                objectPath,
                uploadToken,
                variantBytes,
                FileOptions(contentType: mimeType, upsert: true),
              );
        } on StorageException {
          // The PUT result can be ambiguous. Finalize is the authority: it
          // downloads and validates the exact server-side bytes.
        }
      }
      final finalized = await _client.functions.invoke(
        'media-assets',
        body: {
          'action': 'finalize',
          'media_asset_id': mediaAssetId,
          'expected_row_version': rowVersion,
          'request_id': record.replayValues['finalize_request_id']!,
        },
      );
      final finalizeData = _operationalMap(finalized.data);
      if (finalized.status != 200) {
        throw _OperationalMediaException(
          finalized.status,
          _operationalString(finalizeData['code']),
        );
      }
      await _deleteDurableMediaRecord(storageKey);
    } catch (error) {
      if (_mediaFailureIsDefinitive(error)) {
        await _deleteDurableMediaRecord(storageKey);
        if (mediaAssetId.isNotEmpty && rowVersion != null) {
          try {
            await _runDurableIdempotentRpc(
              operation: 'archive_media_asset',
              intentKey: '$mediaAssetId:$rowVersion:rejected-upload',
              buildParams:
                  (requestId, _) => {
                    'p_media_asset_id': mediaAssetId,
                    'p_expected_row_version': rowVersion,
                    'p_request_id': requestId,
                  },
            );
          } catch (_) {
            // Pending/quarantined media stays unreadable and can be archived
            // on a later authorized retry.
          }
        }
      }
      rethrow;
    }
  }

  Future<void> _openMediaAsset(Map<String, dynamic> asset) async {
    if (_busy || _offline) return;
    await _guarded(() async {
      final response = await _client.functions.invoke(
        'media-assets',
        body: {
          'action': 'download',
          'media_asset_id': asset['id'],
          'variant': 'original',
        },
      );
      final data = _operationalMap(response.data);
      if (response.status != 200) {
        throw _OperationalMediaException(
          response.status,
          _operationalString(data['code']),
        );
      }
      final uri = Uri.tryParse(_operationalString(data['signed_download_url']));
      final configuredStorageUri = Uri.tryParse(_client.storage.url);
      if (uri == null ||
          configuredStorageUri == null ||
          uri.scheme != 'https' ||
          configuredStorageUri.scheme != 'https' ||
          uri.host.toLowerCase() != configuredStorageUri.host.toLowerCase() ||
          uri.port != configuredStorageUri.port ||
          !uri.path.startsWith('/storage/v1/object/sign/horse-media/')) {
        throw const _OperationalMediaException(
          503,
          'MEDIA_DOWNLOAD_SIGNING_UNAVAILABLE',
        );
      }
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        throw const _OperationalMediaException(
          503,
          'MEDIA_DOWNLOAD_SIGNING_UNAVAILABLE',
        );
      }
    });
  }

  Future<void> _archiveMediaAsset(Map<String, dynamic> asset) async {
    final assetId = _operationalString(asset['id']);
    final rowVersion = int.tryParse(_operationalString(asset['row_version']));
    if (assetId.isEmpty || rowVersion == null) return;
    final confirmed = await _confirmDialog(
      title: 'Media archiveren',
      body:
          'Archiveer ${_operationalString(asset['original_filename'])}? '
          'De historie blijft bewaard.',
      action: 'Archiveren',
    );
    if (!confirmed) return;
    await _guarded(() async {
      await _runDurableIdempotentRpc(
        operation: 'archive_media_asset',
        intentKey: '$assetId:$rowVersion',
        buildParams:
            (requestId, _) => {
              'p_media_asset_id': assetId,
              'p_expected_row_version': rowVersion,
              'p_request_id': requestId,
            },
      );
      _notice = 'Media gearchiveerd; de historie blijft bewaard.';
      await _load(quiet: true);
    });
  }

  Future<void> _setSelectedHorseProfileMedia(String mediaAssetId) async {
    final horse = _selectedHorse;
    if (horse == null || _offline) return;
    final horseId = _operationalString(horse['id']);
    final rowVersion = int.tryParse(_operationalString(horse['row_version']));
    if (horseId.isEmpty || rowVersion == null) return;
    await _guarded(() async {
      await _runDurableIdempotentRpc(
        operation: 'set_horse_profile_media',
        intentKey: '$horseId:$rowVersion:$mediaAssetId',
        buildParams:
            (requestId, _) => {
              'p_horse_id': horseId,
              'p_media_asset_id': mediaAssetId.isEmpty ? null : mediaAssetId,
              'p_expected_row_version': rowVersion,
              'p_request_id': requestId,
            },
      );
      _notice =
          mediaAssetId.isEmpty
              ? 'Profielfoto verwijderd; de standaardafbeelding is actief.'
              : 'Profielfoto veilig bijgewerkt.';
      await _load(quiet: true);
    });
  }

  Future<void> _pickAndSetSelectedHorseProfilePhoto() async {
    final horseId = _selectedHorseId;
    if (horseId.isEmpty || _offline || _busy) return;
    await _pickAndUploadMedia(horseId: horseId, imagesOnly: true);
    if (_error.isNotEmpty || !mounted) return;
    final imageAssets = _horseMedia
        .where(
          (asset) => const {
            'image/jpeg',
            'image/png',
            'image/webp',
          }.contains(_operationalString(asset['mime_type'])),
        )
        .toList(growable: false);
    if (imageAssets.isEmpty) {
      setState(() => _error = 'De nieuwe profielfoto is niet beschikbaar.');
      return;
    }
    await _setSelectedHorseProfileMedia(
      _operationalString(imageAssets.first['id']),
    );
  }

  Future<void> _removeSelectedHorseProfilePhoto() async {
    final currentId = _operationalString(
      _selectedHorse?['profile_media_asset_id'],
    );
    if (currentId.isEmpty) return;
    final confirmed = await _confirmDialog(
      title: 'Profielfoto verwijderen',
      body:
          'Verwijder de foto uit het paardprofiel? De beveiligde '
          'mediahistorie blijft afzonderlijk bewaard.',
      action: 'Verwijderen',
    );
    if (confirmed) await _setSelectedHorseProfileMedia('');
  }

  Future<void> _showExecutionMedia(Map<String, dynamic> item) async {
    final executionId = _operationalString(item['execution_id']);
    final horseId = _operationalString(item['horse_id']);
    if (_busy || _offline || executionId.isEmpty || horseId.isEmpty) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    List<Map<String, dynamic>> media = const [];
    var canEditMedia = false;
    try {
      media = await _fetchLinkedMedia(scheduleExecutionId: executionId);
      try {
        final capabilities = _operationalMap(
          await _client.rpc(
            'get_horse_capabilities',
            params: {'p_horse_id': horseId},
          ),
        );
        canEditMedia = capabilities['can_edit_media'] == true;
      } catch (_) {
        // Execution-minimal access intentionally does not open the Horse
        // dossier. The execution actor may still upload to this exact target.
      }
    } catch (error) {
      if (_requiresSecurityReset(error)) {
        await _purgeOperationalState(clearSelectedStable: true);
      }
      if (mounted) setState(() => _error = _friendlyError(error));
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    final actorId = _client.auth.currentUser?.id ?? '';
    final canUpload =
        canEditMedia ||
        (actorId.isNotEmpty &&
            actorId == _operationalString(item['execution_actor_user_id']));
    final theme = FlutterFlowTheme.of(context);
    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Privébewijs bij uitvoering'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Alleen geautoriseerde gebruikers krijgen per aanvraag '
                      'een downloadlink van 60 seconden.',
                      style: theme.bodySmall.copyWith(
                        color: theme.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (media.isEmpty)
                      const Text('Nog geen toegankelijk bewijs.')
                    else
                      ...media.map(
                        (asset) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.verified_user_outlined),
                          title: Text(
                            _operationalString(asset['original_filename']),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            _operationalString(asset['mime_type']),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Veilig openen',
                                onPressed:
                                    () => unawaited(_openMediaAsset(asset)),
                                icon: const Icon(Icons.open_in_new_outlined),
                              ),
                              if (canEditMedia)
                                IconButton(
                                  tooltip: 'Media archiveren',
                                  onPressed:
                                      () =>
                                          unawaited(_archiveMediaAsset(asset)),
                                  icon: const Icon(Icons.archive_outlined),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Sluiten'),
              ),
              if (canUpload)
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    unawaited(
                      _pickAndUploadMedia(
                        horseId: horseId,
                        scheduleExecutionId: executionId,
                      ),
                    );
                  },
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Bewijs toevoegen'),
                ),
            ],
          ),
    );
  }

  Future<Map<String, dynamic>?> _showFeedingExecutionDialog({
    String title = 'Werkelijk gevoerd',
    Map<String, dynamic>? item,
  }) async {
    final quantity = TextEditingController(
      text: _operationalString(item?['planned_quantity']),
    );
    final remaining = TextEditingController();
    final observation = TextEditingController();
    final comments = TextEditingController();
    var unitCode =
        _operationalString(item?['planned_unit_code']).isEmpty
            ? 'portion'
            : _operationalString(item?['planned_unit_code']);
    var deviationCode = 'none';
    String? validationError;
    BuildContext? openedDialogContext;
    Route<dynamic>? openedDialogRoute;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        final dialogRoute = ModalRoute.of(dialogContext);
        openedDialogContext = dialogContext;
        openedDialogRoute = dialogRoute;
        _sensitivePlanningDialogContext = dialogContext;
        _sensitivePlanningDialogRoute = dialogRoute;
        return StatefulBuilder(
          builder:
              (context, setDialogState) => AlertDialog(
                title: Text(title),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: quantity,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Werkelijke hoeveelheid',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: unitCode,
                        decoration: const InputDecoration(
                          labelText: 'Eenheid van het voerplan',
                        ),
                        items:
                            const [
                                  'g',
                                  'kg',
                                  'ml',
                                  'l',
                                  'scoop',
                                  'portion',
                                  'piece',
                                ]
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(value),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            (value) => setDialogState(
                              () => unitCode = value ?? unitCode,
                            ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: remaining,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Resterend (optioneel)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: deviationCode,
                        decoration: const InputDecoration(
                          labelText: 'Afwijking',
                        ),
                        items:
                            const [
                                  'none',
                                  'less',
                                  'more',
                                  'refused',
                                  'spilled',
                                  'substituted',
                                  'other',
                                ]
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(value),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            (value) => setDialogState(
                              () => deviationCode = value ?? deviationCode,
                            ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: observation,
                        maxLength: 1000,
                        decoration: const InputDecoration(
                          labelText: 'Observatie',
                          hintText: 'Bijvoorbeeld eetlust, gedrag of weigering',
                        ),
                      ),
                      TextField(
                        controller: comments,
                        maxLength: 1000,
                        decoration: const InputDecoration(
                          labelText: 'Opmerking',
                        ),
                      ),
                      if (validationError != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          validationError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Annuleren'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final actual = double.tryParse(
                        quantity.text.trim().replaceAll(',', '.'),
                      );
                      final remainingValue =
                          remaining.text.trim().isEmpty
                              ? null
                              : double.tryParse(
                                remaining.text.trim().replaceAll(',', '.'),
                              );
                      if (actual == null ||
                          actual < 0 ||
                          (remaining.text.trim().isNotEmpty &&
                              (remainingValue == null || remainingValue < 0))) {
                        setDialogState(
                          () =>
                              validationError =
                                  'Vul geldige niet-negatieve hoeveelheden in.',
                        );
                        return;
                      }
                      Navigator.pop(dialogContext, {
                        'actual_quantity': actual,
                        'unit_code': unitCode,
                        'remaining_quantity': remainingValue,
                        'deviation_code': deviationCode,
                        'observation': observation.text.trim(),
                        'comments': comments.text.trim(),
                      });
                    },
                    child: const Text('Registreren'),
                  ),
                ],
              ),
        );
      },
    );
    if (identical(_sensitivePlanningDialogContext, openedDialogContext) &&
        identical(_sensitivePlanningDialogRoute, openedDialogRoute)) {
      _sensitivePlanningDialogContext = null;
      _sensitivePlanningDialogRoute = null;
    }
    quantity.dispose();
    remaining.dispose();
    observation.dispose();
    comments.dispose();
    return result;
  }

  Future<void> _completeSchedule(Map<String, dynamic> item) async {
    final isFeeding = item['item_kind'] == 'feeding';
    final actorUserId = _client.auth.currentUser?.id ?? '';
    final stableId = _stableId;
    final generation = _sensitiveStateGeneration;
    final feedingDetails =
        isFeeding ? await _showFeedingExecutionDialog(item: item) : null;
    if (isFeeding &&
        (feedingDetails == null ||
            !_planningScopeMatches(
              generation: generation,
              actorUserId: actorUserId,
              stableId: stableId,
            ))) {
      return;
    }
    void scopePreflight() => _assertPlanningScopeCurrent(
      generation: generation,
      actorUserId: actorUserId,
      stableId: stableId,
    );
    if (_offline) {
      scopePreflight();
      await _queueOfflineCompletion(item, feedingDetails: feedingDetails);
      return;
    }
    await _guarded(() async {
      scopePreflight();
      final now = DateTime.now();
      if (isFeeding) {
        final scheduleItemId = _operationalString(item['schedule_item_id']);
        final completedAt = now.toUtc().toIso8601String();
        final recordedLocalAt = _stableLocalTimestamp(now);
        await _runDurableIdempotentRpc(
          operation: 'record_feeding_execution',
          intentKey:
              '$scheduleItemId:${feedingDetails!['actual_quantity']}:'
              '${feedingDetails['unit_code']}:'
              '${feedingDetails['remaining_quantity']}:'
              '${feedingDetails['deviation_code']}:'
              '${feedingDetails['observation']}:'
              '${feedingDetails['comments']}',
          initialReplayValues: {
            'schedule_item_id': scheduleItemId,
            'completed_at': completedAt,
            'recorded_local_at': recordedLocalAt,
            'recorded_timezone': _stableTimezone,
            'actual_quantity': feedingDetails['actual_quantity'].toString(),
            'unit_code': feedingDetails['unit_code'].toString(),
            'remaining_quantity':
                feedingDetails['remaining_quantity']?.toString() ?? '',
            'deviation_code': feedingDetails['deviation_code'].toString(),
            'observation': feedingDetails['observation'].toString(),
            'comments': feedingDetails['comments'].toString(),
          },
          scopePreflight: scopePreflight,
          buildParams:
              (requestId, replayValues) => {
                'p_schedule_item_id': replayValues['schedule_item_id'],
                'p_corrects_execution_id': null,
                'p_request_id': requestId,
                'p_execution_status': 'completed',
                'p_actual_started_at': null,
                'p_actual_completed_at': replayValues['completed_at'],
                'p_recorded_local_at': replayValues['recorded_local_at'],
                'p_recorded_timezone': replayValues['recorded_timezone'],
                'p_source': 'online',
                'p_device_instance_id': null,
                'p_note':
                    replayValues['comments']!.isEmpty
                        ? null
                        : replayValues['comments'],
                'p_actual_quantity': double.parse(
                  replayValues['actual_quantity']!,
                ),
                'p_unit_code': replayValues['unit_code'],
                'p_remaining_quantity':
                    replayValues['remaining_quantity']!.isEmpty
                        ? null
                        : double.parse(replayValues['remaining_quantity']!),
                'p_deviation_code': replayValues['deviation_code'],
                'p_observation':
                    replayValues['observation']!.isEmpty
                        ? null
                        : replayValues['observation'],
                'p_batch_lot': null,
              },
        );
        scopePreflight();
      } else {
        await _runIdempotentRpc(
          operation: 'record_schedule_execution',
          intentKey: _operationalString(item['schedule_item_id']),
          buildParams:
              (requestId) => {
                'p_schedule_item_id': item['schedule_item_id'],
                'p_request_id': requestId,
                'p_execution_status': 'completed',
                'p_actual_started_at': null,
                'p_actual_completed_at': now.toUtc().toIso8601String(),
                'p_recorded_local_at': _stableLocalTimestamp(now),
                'p_recorded_timezone': _stableTimezone,
                'p_source': 'online',
                'p_device_instance_id': null,
                'p_note': null,
              },
        );
        scopePreflight();
      }
      _notice = 'Uitvoering veilig geregistreerd.';
      await _load(quiet: true);
    });
    if (_dayGuidanceActive && mounted && _error.isEmpty) {
      await _offerNextGuidedTask();
    }
  }

  Future<void> _showCompletedExecutionActions(Map<String, dynamic> item) async {
    final isFeeding = _operationalString(item['item_kind']) == 'feeding';
    final canCorrect =
        isFeeding && _operationalString(item['execution_id']).isNotEmpty;
    BuildContext? openedDialogContext;
    Route<dynamic>? openedDialogRoute;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final dialogRoute = ModalRoute.of(dialogContext);
        openedDialogContext = dialogContext;
        openedDialogRoute = dialogRoute;
        _sensitivePlanningDialogContext = dialogContext;
        _sensitivePlanningDialogRoute = dialogRoute;
        return AlertDialog(
          title: const Text('Geregistreerde uitvoering'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_operationalString(item['title'])),
                Text(
                  '${_scheduleActivityType(item)} · '
                  '${_operationalString(item['horse_name'])}',
                ),
                Text(
                  '${_operationalDisplayDate(item['source_local_date'])} · '
                  '${_stableClock(item['scheduled_start_at'])}',
                ),
                Text('Status: ${_scheduleStateLabel(item)}'),
                Text(
                  'Verantwoordelijke: '
                  '${_operationalString(item['responsible_name']).isEmpty ? 'Niet toegewezen' : _operationalString(item['responsible_name'])}',
                ),
                Text(
                  'Locatie: '
                  '${_scheduleLocation(item).isEmpty ? 'Niet opgegeven' : _scheduleLocation(item)}',
                ),
                if (_scheduleInstruction(item).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(_scheduleInstruction(item)),
                ],
                const SizedBox(height: 12),
                Text('Afgetekend door: ${_executionActorLabel(item)}'),
                if (_operationalString(item['actual_started_at']).isNotEmpty)
                  Text(
                    'Gestart: '
                    '${_stableDateTimeLabel(item['actual_started_at'])}',
                  ),
                if (_operationalString(item['actual_completed_at']).isNotEmpty)
                  Text(
                    'Afgetekend: '
                    '${_stableDateTimeLabel(item['actual_completed_at'])}',
                  ),
                if (!isFeeding &&
                    _operationalString(item['execution_note']).isNotEmpty)
                  Text(
                    'Opmerking: '
                    '${_operationalString(item['execution_note'])}',
                  ),
                if (isFeeding) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Gepland: ${item['planned_quantity'] ?? '—'} '
                    '${_operationalString(item['planned_unit_code'])}',
                  ),
                  Text(
                    'Werkelijk: ${item['actual_quantity'] ?? '—'} '
                    '${_operationalString(item['actual_unit_code'])}',
                  ),
                  if (item['remaining_quantity'] != null)
                    Text('Resterend: ${item['remaining_quantity']}'),
                  if (_operationalString(item['deviation_code']).isNotEmpty)
                    Text(
                      'Afwijking: ${_operationalString(item['deviation_code'])}',
                    ),
                  if (_operationalString(item['observation']).isNotEmpty)
                    Text(
                      'Observatie: ${_operationalString(item['observation'])}',
                    ),
                  if (_operationalString(item['execution_note']).isNotEmpty)
                    Text(
                      'Opmerking: ${_operationalString(item['execution_note'])}',
                    ),
                  if (_operationalString(
                    item['actual_completed_at'],
                  ).isNotEmpty)
                    Text(
                      'Afgetekend: '
                      '${_stableDateTimeLabel(item['actual_completed_at'])}',
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Sluiten'),
            ),
            if (_operationalString(item['execution_id']).isNotEmpty)
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  unawaited(_showExecutionMedia(item));
                },
                icon: const Icon(Icons.lock_outline),
                label: const Text('Private media'),
              ),
            if (canCorrect)
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  unawaited(_correctFeedingExecution(item));
                },
                icon: const Icon(Icons.history_outlined),
                label: const Text('Correctie'),
              ),
          ],
        );
      },
    );
    if (identical(_sensitivePlanningDialogContext, openedDialogContext) &&
        identical(_sensitivePlanningDialogRoute, openedDialogRoute)) {
      _sensitivePlanningDialogContext = null;
      _sensitivePlanningDialogRoute = null;
    }
  }

  Future<void> _correctFeedingExecution(Map<String, dynamic> item) async {
    final originalExecutionId = _operationalString(item['execution_id']);
    final scheduleItemId = _operationalString(item['schedule_item_id']);
    if (originalExecutionId.isEmpty || scheduleItemId.isEmpty) {
      setState(() {
        _error =
            'De oorspronkelijke uitvoering is niet beschikbaar. Vernieuw '
            'voordat je corrigeert.';
      });
      return;
    }
    final actorUserId = _client.auth.currentUser?.id ?? '';
    final stableId = _stableId;
    final generation = _sensitiveStateGeneration;
    final details = await _showFeedingExecutionDialog(
      title: 'Correctie registreren',
    );
    if (details == null ||
        !_planningScopeMatches(
          generation: generation,
          actorUserId: actorUserId,
          stableId: stableId,
        )) {
      return;
    }
    void scopePreflight() => _assertPlanningScopeCurrent(
      generation: generation,
      actorUserId: actorUserId,
      stableId: stableId,
    );
    await _guarded(() async {
      final now = DateTime.now();
      await _runDurableIdempotentRpc(
        operation: 'record_feeding_execution',
        intentKey:
            'correction:$originalExecutionId:'
            '${details['actual_quantity']}:${details['unit_code']}:'
            '${details['remaining_quantity']}:${details['deviation_code']}',
        initialReplayValues: {
          'schedule_item_id': scheduleItemId,
          'corrects_execution_id': originalExecutionId,
          'completed_at': now.toUtc().toIso8601String(),
          'recorded_local_at': _stableLocalTimestamp(now),
          'recorded_timezone': _stableTimezone,
          'actual_quantity': details['actual_quantity'].toString(),
          'unit_code': details['unit_code'].toString(),
          'remaining_quantity': details['remaining_quantity']?.toString() ?? '',
          'deviation_code': details['deviation_code'].toString(),
        },
        scopePreflight: scopePreflight,
        buildParams:
            (requestId, replayValues) => {
              'p_schedule_item_id': replayValues['schedule_item_id'],
              'p_corrects_execution_id': replayValues['corrects_execution_id'],
              'p_request_id': requestId,
              'p_execution_status': 'completed',
              'p_actual_started_at': null,
              'p_actual_completed_at': replayValues['completed_at'],
              'p_recorded_local_at': replayValues['recorded_local_at'],
              'p_recorded_timezone': replayValues['recorded_timezone'],
              'p_source': 'online',
              'p_device_instance_id': null,
              'p_note': 'Append-only correctie',
              'p_actual_quantity': double.parse(
                replayValues['actual_quantity']!,
              ),
              'p_unit_code': replayValues['unit_code'],
              'p_remaining_quantity':
                  replayValues['remaining_quantity']!.isEmpty
                      ? null
                      : double.parse(replayValues['remaining_quantity']!),
              'p_deviation_code': replayValues['deviation_code'],
              'p_observation': null,
              'p_batch_lot': null,
            },
      );
      scopePreflight();
      _notice =
          'Correctie toegevoegd; de oorspronkelijke uitvoering is bewaard.';
      await _load(quiet: true);
    });
  }

  String _conflictFieldLabel(String field) => switch (field) {
    'display_name' => 'Roepnaam',
    'official_name' => 'Officiële naam',
    'birth_date' => 'Geboortedatum',
    'sex' => 'Geslacht',
    'breed' => 'Ras',
    'discipline' => 'Discipline',
    'level' => 'Niveau',
    _ => 'Onbekend veld',
  };

  String _conflictValue(dynamic value) {
    if (value == null) return 'leegmaken';
    if (value is! String && value is! num && value is! bool) {
      return 'ongeldige waarde';
    }
    final normalized = value.toString().trim();
    if (normalized.isEmpty) return 'leegmaken';
    return normalized.length <= 96
        ? normalized
        : '${normalized.substring(0, 93)}…';
  }

  Future<void> _resolveSyncConflict(Map<String, dynamic> conflict) async {
    if (_offline || _busy) return;
    final actorUserId = _client.auth.currentUser?.id ?? '';
    final stableId = _stableId;
    final sensitiveStateGeneration = _sensitiveStateGeneration;
    if (actorUserId.isEmpty || stableId.isEmpty) return;
    final conflictId = _operationalString(conflict['conflict_id']);
    final entityType = _operationalString(conflict['entity_type']);
    final patch = _operationalMap(conflict['client_patch']);
    const allowedFields = {
      'display_name',
      'official_name',
      'birth_date',
      'sex',
      'breed',
      'discipline',
      'level',
    };
    if (conflictId.isEmpty ||
        entityType != 'horse_basic_noncritical' ||
        patch.keys.any((field) => !allowedFields.contains(field))) {
      setState(
        () =>
            _error =
                'Dit conflict heeft een onverwachte vorm en is niet aangepast.',
      );
      return;
    }

    final reason = TextEditingController();
    String? validationError;
    BuildContext? openedDialogContext;
    Route<dynamic>? openedDialogRoute;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dialogRoute = ModalRoute.of(dialogContext);
        openedDialogContext = dialogContext;
        openedDialogRoute = dialogRoute;
        _sensitiveConflictDialogContext = dialogContext;
        _sensitiveConflictDialogRoute = dialogRoute;
        return StatefulBuilder(
          builder:
              (context, setDialogState) => AlertDialog(
                title: const Text('Synchronisatieconflict beoordelen'),
                content: SizedBox(
                  width: 520,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'De serverversie blijft actief. Je kunt dit '
                          'conflict sluiten en de lokale wijziging later '
                          'bewust opnieuw invoeren.',
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Paardprofiel · lokaal v'
                          '${_operationalString(conflict['base_row_version'])}'
                          ' · server v'
                          '${_operationalString(conflict['server_row_version'])}',
                        ),
                        const SizedBox(height: 10),
                        if (patch.isEmpty)
                          const Text('Geen leesbare lokale wijziging.')
                        else
                          ...patch.entries.map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: Text(
                                '${_conflictFieldLabel(entry.key)}: '
                                '${_conflictValue(entry.value)}',
                              ),
                            ),
                          ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: reason,
                          autofocus: true,
                          minLines: 2,
                          maxLines: 4,
                          maxLength: 500,
                          decoration: const InputDecoration(
                            labelText: 'Reden (verplicht)',
                            hintText:
                                'Waarom blijft de actuele serverversie behouden?',
                          ),
                        ),
                        if (validationError != null)
                          Text(
                            validationError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Annuleren'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final normalized = reason.text.trim();
                      if (normalized.isEmpty || normalized.length > 500) {
                        setDialogState(
                          () =>
                              validationError =
                                  'Vul een reden van maximaal 500 tekens in.',
                        );
                        return;
                      }
                      Navigator.pop(dialogContext, true);
                    },
                    child: const Text('Serverversie behouden'),
                  ),
                ],
              ),
        );
      },
    );
    if (identical(_sensitiveConflictDialogContext, openedDialogContext) &&
        identical(_sensitiveConflictDialogRoute, openedDialogRoute)) {
      _sensitiveConflictDialogContext = null;
      _sensitiveConflictDialogRoute = null;
    }
    final normalizedReason = reason.text.trim();
    reason.dispose();
    if (confirmed != true ||
        normalizedReason.isEmpty ||
        sensitiveStateGeneration != _sensitiveStateGeneration ||
        _client.auth.currentUser?.id != actorUserId ||
        _stableId != stableId) {
      return;
    }

    await _guarded(() async {
      final reasonHash =
          sha256.convert(utf8.encode(normalizedReason)).toString();
      await _runDurableIdempotentRpc(
        operation: 'resolve_sync_conflict',
        intentKey: '$conflictId:resolved_server:$reasonHash',
        initialReplayValues: {
          'resolution': 'resolved_server',
          'reason': normalizedReason,
        },
        scopePreflight: () {
          if (sensitiveStateGeneration != _sensitiveStateGeneration ||
              _client.auth.currentUser?.id != actorUserId ||
              _stableId != stableId) {
            throw StateError('STALE_CONFLICT_CONFIRMATION');
          }
        },
        buildParams:
            (requestId, replayValues) => {
              'p_conflict_id': conflictId,
              'p_resolution': replayValues['resolution'],
              'p_reason': replayValues['reason'],
              'p_request_id': requestId,
            },
      );
      _notice =
          'Conflict gesloten; de actuele serverversie is bewust behouden.';
      await _load(quiet: true);
    });
  }

  Future<void> _createHorse() async {
    await _ensureStableRoster();
    final profile = await _showHorseProfilePage();
    if (profile == null) return;
    await _guarded(() async {
      final result = _operationalMap(
        await _runDurableIdempotentRpc(
          operation: 'create_horse',
          intentKey: _horseProfileIntentKey('create', profile),
          buildParams:
              (requestId, _) => {
                'p_stable_id': _stableId,
                'p_display_name': profile['display_name'],
                'p_request_id': requestId,
                'p_official_name': profile['official_name'],
                'p_birth_date': profile['birth_date'],
                'p_sex': profile['sex'],
                'p_breed': profile['breed'],
                'p_discipline': profile['discipline'],
                'p_level': profile['level'],
              },
        ),
      );
      final horseId = _operationalString(result['horse_id']);
      _selectedHorseId = horseId;
      await _saveHorseIdentifiers(horseId: horseId, profile: profile);
      await _addHorseRelationshipsFromProfile(
        horseId: horseId,
        profile: profile,
      );
      _notice = 'Paard veilig toegevoegd.';
      await _load(quiet: true);
    });
  }

  Future<void> _editSelectedHorse() async {
    final horse = _selectedHorse;
    if (horse == null) return;
    await _ensureStableRoster();
    final profile = await _showHorseProfilePage(horse: horse);
    if (profile == null) return;
    final horseId = _operationalString(horse['id']);
    final rowVersion = int.tryParse(_operationalString(horse['row_version']));
    if (horseId.isEmpty || rowVersion == null || rowVersion < 1) {
      setState(() => _error = 'Vernieuw het paard voordat je het bewerkt.');
      return;
    }
    await _guarded(() async {
      await _runDurableIdempotentRpc(
        operation: 'update_horse_profile',
        intentKey:
            '$horseId:$rowVersion:${_horseProfileIntentKey('update', profile)}',
        buildParams:
            (requestId, _) => {
              'p_horse_id': horseId,
              'p_expected_row_version': rowVersion,
              'p_request_id': requestId,
              'p_display_name': profile['display_name'],
              'p_official_name': profile['official_name'],
              'p_birth_date': profile['birth_date'],
              'p_sex': profile['sex'],
              'p_breed': profile['breed'],
              'p_discipline': profile['discipline'],
              'p_level': profile['level'],
            },
      );
      await _saveHorseIdentifiers(horseId: horseId, profile: profile);
      await _addHorseRelationshipsFromProfile(
        horseId: horseId,
        profile: profile,
      );
      _notice = 'Paardgegevens veilig bijgewerkt.';
      await _load(quiet: true);
    });
  }

  Future<void> _saveHorseIdentifiers({
    required String horseId,
    required Map<String, dynamic> profile,
  }) async {
    final passportNumber = _operationalString(profile['passport_number']);
    final chipNumber = _operationalString(profile['chip_number']);
    final passportExpiresOn = _operationalString(
      profile['passport_expires_on'],
    );
    await _saveHorseIdentifier(
      horseId: horseId,
      type: 'passport',
      value: passportNumber,
      validUntil: passportExpiresOn,
    );
    await _saveHorseIdentifier(
      horseId: horseId,
      type: 'chip',
      value: chipNumber,
    );
  }

  Future<void> _saveHorseIdentifier({
    required String horseId,
    required String type,
    required String value,
    String validUntil = '',
  }) async {
    final current = _horseIdentifiers[horseId]?[type] ?? const {};
    if (value.isEmpty) {
      return;
    }
    final unchanged =
        _operationalString(current['identifier_value']) == value &&
        _operationalString(current['valid_until']) == validUntil;
    if (unchanged) return;
    final identifierId = _operationalString(current['id']);
    final expectedRowVersion = int.tryParse(
      _operationalString(current['row_version']),
    );
    await _runDurableIdempotentRpc(
      operation: 'upsert_horse_identifier',
      intentKey: jsonEncode([
        horseId,
        type,
        identifierId,
        expectedRowVersion,
        value,
        validUntil,
      ]),
      buildParams:
          (requestId, _) => {
            'p_horse_id': horseId,
            'p_identifier_id': identifierId.isEmpty ? null : identifierId,
            'p_expected_row_version':
                identifierId.isEmpty ? null : expectedRowVersion,
            'p_request_id': requestId,
            'p_identifier_type': type,
            'p_identifier_value': value,
            'p_issuer': null,
            'p_country_code': null,
            'p_valid_from': null,
            'p_valid_until': validUntil.isEmpty ? null : validUntil,
          },
    );
  }

  Future<void> _addHorseRelationshipsFromProfile({
    required String horseId,
    required Map<String, dynamic> profile,
  }) async {
    final validFrom = _operationalDateKey(_stableNow());
    for (final entry
        in const {
          'owner': 'owner_member_id',
          'trainer': 'trainer_member_id',
          'rider': 'rider_member_id',
        }.entries) {
      final stableMemberId = _operationalString(profile[entry.value]);
      if (stableMemberId.isEmpty ||
          _horseRelationships.any(
            (relationship) =>
                _operationalString(relationship['horse_id']) == horseId &&
                _operationalString(relationship['stable_member_id']) ==
                    stableMemberId &&
                _operationalString(relationship['relationship_type']) ==
                    entry.key,
          )) {
        continue;
      }
      await _runDurableIdempotentRpc(
        operation: 'add_horse_relationship',
        intentKey: '$horseId:$stableMemberId:${entry.key}',
        initialReplayValues: {'valid_from': validFrom},
        buildParams:
            (requestId, replayValues) => {
              'p_horse_id': horseId,
              'p_stable_member_id': stableMemberId,
              'p_relationship_type': entry.key,
              'p_request_id': requestId,
              'p_valid_from': replayValues['valid_from']!,
              'p_label': null,
            },
      );
    }
  }

  Future<void> _archiveSelectedHorse() async {
    final horse = _selectedHorse;
    if (horse == null) return;
    final reason = TextEditingController();
    final confirmed = await _showFormDialog(
      title: 'Paard archiveren',
      controller: reason,
      label: 'Reden',
      action: 'Archiveren',
    );
    final normalizedReason = reason.text.trim();
    reason.dispose();
    if (!confirmed || normalizedReason.isEmpty) return;
    final horseId = _operationalString(horse['id']);
    await _guarded(() async {
      await _runDurableIdempotentRpc(
        operation: 'archive_horse',
        intentKey: '$horseId:$normalizedReason',
        buildParams:
            (requestId, _) => {
              'p_horse_id': horseId,
              'p_request_id': requestId,
              'p_reason': normalizedReason,
            },
      );
      _selectedHorseId = '';
      _notice = 'Paard gearchiveerd; historische gegevens blijven bewaard.';
      await _load(quiet: true);
    });
  }

  Map<String, dynamic>? get _selectedHorse {
    for (final horse in _horses) {
      if (_operationalString(horse['id']) == _selectedHorseId) return horse;
    }
    return null;
  }

  String _horseProfileIntentKey(
    String operation,
    Map<String, dynamic> profile,
  ) => jsonEncode([
    operation,
    profile['display_name'],
    profile['official_name'],
    profile['birth_date'],
    profile['sex'],
    profile['breed'],
    profile['discipline'],
    profile['level'],
    profile['passport_number'],
    profile['chip_number'],
    profile['passport_expires_on'],
    profile['owner_member_id'],
    profile['trainer_member_id'],
    profile['rider_member_id'],
  ]);

  Future<Map<String, dynamic>?> _showHorseProfilePage({
    Map<String, dynamic>? horse,
  }) async {
    final horseId = _operationalString(horse?['id']);
    final passport = _horseIdentifiers[horseId]?['passport'] ?? const {};
    final chip = _horseIdentifiers[horseId]?['chip'] ?? const {};
    final displayName = TextEditingController(
      text: _operationalString(horse?['display_name']),
    );
    final officialName = TextEditingController(
      text: _operationalString(horse?['official_name']),
    );
    final birthDate = TextEditingController(
      text: _operationalDisplayDate(horse?['birth_date']),
    );
    final breed = TextEditingController(
      text: _operationalString(horse?['breed']),
    );
    final discipline = TextEditingController(
      text: _operationalString(horse?['discipline']),
    );
    final passportNumber = TextEditingController(
      text: _operationalString(passport['identifier_value']),
    );
    final chipNumber = TextEditingController(
      text: _operationalString(chip['identifier_value']),
    );
    final passportExpiresOn = TextEditingController(
      text: _operationalDisplayDate(passport['valid_until']),
    );
    var sex =
        const {'mare', 'gelding', 'stallion'}.contains(horse?['sex'])
            ? _operationalString(horse?['sex'])
            : '';
    var selectedDiscipline = discipline.text.trim();
    var ownerMemberId = '';
    var trainerMemberId = '';
    var riderMemberId = '';
    final actorRole = _operationalString(_actorMembership['role']);
    final canChooseRelationships =
        horse == null
            ? const {'owner', 'admin'}.contains(actorRole)
            : _canManageHorseRelationships;
    var step = 0;
    String? validationError;
    const roseGold = Color(0xFFC98980);
    const canvas = Color(0xFF141215);
    const panel = Color(0xFF211E22);
    const border = Color(0xFF494047);
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder:
            (routeContext) => StatefulBuilder(
              builder: (context, setPageState) {
                final liveHorse =
                    horse == null ? null : (_selectedHorse ?? horse);
                Map<String, dynamic>? normalizedProfile() {
                  final normalizedName = displayName.text.trim();
                  final normalizedBirth = birthDate.text.trim();
                  final normalizedExpiry = passportExpiresOn.text.trim();
                  final parsedBirth =
                      normalizedBirth.isEmpty
                          ? null
                          : _operationalParseDisplayDate(normalizedBirth);
                  final parsedExpiry =
                      normalizedExpiry.isEmpty
                          ? null
                          : _operationalParseDisplayDate(normalizedExpiry);
                  final today = DateTime.now();
                  final currentDay = DateTime(
                    today.year,
                    today.month,
                    today.day,
                  );
                  if (normalizedName.isEmpty) {
                    validationError = 'Vul een roepnaam in.';
                    return null;
                  }
                  if (sex.isEmpty || sex == 'unknown') {
                    validationError = 'Kies het geslacht.';
                    return null;
                  }
                  if (selectedDiscipline.isEmpty) {
                    validationError = 'Kies een discipline.';
                    return null;
                  }
                  if (normalizedBirth.isNotEmpty &&
                      (parsedBirth == null ||
                          parsedBirth.isAfter(currentDay))) {
                    validationError =
                        'Gebruik voor de geboortedatum DD-MM-JJJJ.';
                    return null;
                  }
                  if (normalizedExpiry.isNotEmpty && parsedExpiry == null) {
                    validationError =
                        'Gebruik voor de paspoortdatum DD-MM-JJJJ.';
                    return null;
                  }
                  validationError = null;
                  return {
                    'display_name': normalizedName,
                    'official_name':
                        officialName.text.trim().isEmpty
                            ? null
                            : officialName.text.trim(),
                    'birth_date':
                        parsedBirth == null
                            ? null
                            : _operationalDateKey(parsedBirth),
                    'sex': sex,
                    'breed':
                        breed.text.trim().isEmpty ? null : breed.text.trim(),
                    'discipline': selectedDiscipline,
                    'level':
                        _operationalString(horse?['level']).isEmpty
                            ? null
                            : _operationalString(horse?['level']),
                    'passport_number':
                        passportNumber.text.trim().isEmpty
                            ? null
                            : passportNumber.text.trim(),
                    'chip_number':
                        chipNumber.text.trim().isEmpty
                            ? null
                            : chipNumber.text.trim(),
                    'passport_expires_on':
                        parsedExpiry == null
                            ? null
                            : _operationalDateKey(parsedExpiry),
                    'owner_member_id':
                        ownerMemberId.isEmpty ? null : ownerMemberId,
                    'trainer_member_id':
                        trainerMemberId.isEmpty ? null : trainerMemberId,
                    'rider_member_id':
                        riderMemberId.isEmpty ? null : riderMemberId,
                  };
                }

                Widget fieldLabel(String label, {bool required = false}) =>
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            required ? 'Verplicht' : 'Optioneel',
                            style: TextStyle(
                              color:
                                  required
                                      ? roseGold
                                      : Colors.white.withValues(alpha: 0.66),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );

                Widget input(
                  String label,
                  TextEditingController controller, {
                  bool required = false,
                  String hint = '',
                  TextInputType? keyboardType,
                  VoidCallback? onTap,
                }) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    fieldLabel(label, required: required),
                    TextField(
                      controller: controller,
                      keyboardType: keyboardType,
                      readOnly: onTap != null,
                      onTap: onTap,
                      maxLength: 200,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: hint,
                        counterText: '',
                        suffixIcon:
                            onTap == null
                                ? null
                                : const Icon(Icons.calendar_today_outlined),
                        filled: true,
                        fillColor: panel,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: roseGold,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                );

                Future<void> pickDate(
                  TextEditingController controller, {
                  required DateTime firstDate,
                  required DateTime lastDate,
                }) async {
                  final parsed = _operationalParseDisplayDate(
                    controller.text.trim(),
                  );
                  final now = DateTime.now();
                  final fallback = DateTime(now.year, now.month, now.day);
                  final initial =
                      parsed != null &&
                              !parsed.isBefore(firstDate) &&
                              !parsed.isAfter(lastDate)
                          ? parsed
                          : fallback.isBefore(firstDate)
                          ? firstDate
                          : fallback.isAfter(lastDate)
                          ? lastDate
                          : fallback;
                  final selected = await showDatePicker(
                    context: context,
                    initialDate: initial,
                    firstDate: firstDate,
                    lastDate: lastDate,
                    builder:
                        (context, child) => Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: roseGold,
                              secondary: roseGold,
                              surface: panel,
                            ),
                          ),
                          child: child!,
                        ),
                  );
                  if (selected == null) return;
                  setPageState(
                    () => controller.text = _operationalDisplayDate(selected),
                  );
                }

                Widget relationshipPicker({
                  required String label,
                  required String value,
                  required ValueChanged<String?> onChanged,
                }) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    fieldLabel(label),
                    DropdownButtonFormField<String>(
                      value: value.isEmpty ? null : value,
                      isExpanded: true,
                      dropdownColor: panel,
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: panel,
                        border: OutlineInputBorder(),
                      ),
                      hint: const Text('Kies een teamlid'),
                      items: _stableRoster
                          .map(
                            (member) => DropdownMenuItem(
                              value: _operationalString(member['id']),
                              child: Text(
                                [
                                  _operationalString(member['display_name']),
                                  _operationalString(member['function_title']),
                                ].where((part) => part.isNotEmpty).join(' · '),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: onChanged,
                    ),
                    const SizedBox(height: 18),
                  ],
                );

                final disciplineOptions = <String>[
                  'Dressuur',
                  'Springen',
                  'Eventing',
                  'Hobby',
                ];
                if (selectedDiscipline.isNotEmpty &&
                    !disciplineOptions.contains(selectedDiscipline)) {
                  disciplineOptions.add(selectedDiscipline);
                }
                final routeTheme = ThemeData.dark().copyWith(
                  scaffoldBackgroundColor: canvas,
                  colorScheme: const ColorScheme.dark(
                    primary: roseGold,
                    secondary: roseGold,
                    surface: panel,
                  ),
                  filledButtonTheme: FilledButtonThemeData(
                    style: FilledButton.styleFrom(
                      backgroundColor: roseGold,
                      foregroundColor: canvas,
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  segmentedButtonTheme: SegmentedButtonThemeData(
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (states) =>
                            states.contains(WidgetState.selected)
                                ? roseGold.withValues(alpha: 0.18)
                                : Colors.transparent,
                      ),
                      foregroundColor: WidgetStateProperty.resolveWith(
                        (states) =>
                            states.contains(WidgetState.selected)
                                ? roseGold
                                : Colors.white.withValues(alpha: 0.72),
                      ),
                      side: const WidgetStatePropertyAll(
                        BorderSide(color: border),
                      ),
                    ),
                  ),
                );
                return Theme(
                  data: routeTheme,
                  child: Scaffold(
                    body: SafeArea(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 20, 8),
                            child: Row(
                              children: [
                                IconButton(
                                  tooltip: 'Sluiten',
                                  onPressed: () => Navigator.pop(routeContext),
                                  icon: const Icon(Icons.close, size: 30),
                                ),
                                const Spacer(),
                                const Text(
                                  'A V A R Y N',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  horse == null
                                      ? 'Paard toevoegen'
                                      : 'Paard bewerken',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (horse != null)
                                  Text(
                                    _operationalString(horse['display_name']),
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.58,
                                      ),
                                      fontSize: 18,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: SegmentedButton<int>(
                              showSelectedIcon: false,
                              segments: const [
                                ButtonSegment(
                                  value: 0,
                                  label: Text('Gegevens'),
                                ),
                                ButtonSegment(
                                  value: 1,
                                  label: Text('Identificatie'),
                                ),
                                ButtonSegment(value: 2, label: Text('Team')),
                              ],
                              selected: {step},
                              onSelectionChanged:
                                  (values) =>
                                      setPageState(() => step = values.single),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                22,
                                24,
                                22,
                                30,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    switch (step) {
                                      0 => 'Gegevens paard',
                                      1 => 'Identificatie',
                                      _ => 'Team en profielfoto',
                                    },
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    switch (step) {
                                      0 =>
                                        'Alleen de gegevens die je dagelijks nodig hebt.',
                                      1 =>
                                        'Bewaar de officiële identificatie overzichtelijk.',
                                      _ =>
                                        'Koppel de vaste betrokkenen en kies een herkenbare foto.',
                                    },
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.68,
                                      ),
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  if (step == 0) ...[
                                    input(
                                      'Roepnaam',
                                      displayName,
                                      required: true,
                                    ),
                                    input('Officiële naam', officialName),
                                    input(
                                      'Geboortedatum',
                                      birthDate,
                                      hint: 'Kies datum',
                                      onTap:
                                          () => pickDate(
                                            birthDate,
                                            firstDate: DateTime(1980),
                                            lastDate: DateTime.now(),
                                          ),
                                    ),
                                    fieldLabel('Geslacht', required: true),
                                    DropdownButtonFormField<String>(
                                      value: sex.isEmpty ? null : sex,
                                      dropdownColor: panel,
                                      decoration: const InputDecoration(
                                        filled: true,
                                        fillColor: panel,
                                        border: OutlineInputBorder(),
                                      ),
                                      hint: const Text('Kies geslacht'),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'mare',
                                          child: Text('Merrie'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'gelding',
                                          child: Text('Ruin'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'stallion',
                                          child: Text('Hengst'),
                                        ),
                                      ],
                                      onChanged:
                                          (value) => setPageState(
                                            () => sex = value ?? '',
                                          ),
                                    ),
                                    const SizedBox(height: 18),
                                    input('Ras', breed),
                                    fieldLabel('Discipline', required: true),
                                    DropdownButtonFormField<String>(
                                      value:
                                          selectedDiscipline.isEmpty
                                              ? null
                                              : selectedDiscipline,
                                      dropdownColor: panel,
                                      decoration: const InputDecoration(
                                        filled: true,
                                        fillColor: panel,
                                        border: OutlineInputBorder(),
                                      ),
                                      hint: const Text('Kies discipline'),
                                      items: disciplineOptions
                                          .map(
                                            (value) => DropdownMenuItem(
                                              value: value,
                                              child: Text(value),
                                            ),
                                          )
                                          .toList(growable: false),
                                      onChanged:
                                          (value) => setPageState(
                                            () =>
                                                selectedDiscipline =
                                                    value ?? '',
                                          ),
                                    ),
                                  ],
                                  if (step == 1) ...[
                                    input('Paspoortnummer', passportNumber),
                                    input('Chipnummer', chipNumber),
                                    input(
                                      'Paspoort geldig tot en met',
                                      passportExpiresOn,
                                      hint: 'Kies vervaldatum',
                                      onTap:
                                          () => pickDate(
                                            passportExpiresOn,
                                            firstDate: DateTime(2000),
                                            lastDate: DateTime(
                                              DateTime.now().year + 30,
                                              12,
                                              31,
                                            ),
                                          ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: roseGold.withValues(alpha: 0.10),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: roseGold.withValues(
                                            alpha: 0.35,
                                          ),
                                        ),
                                      ),
                                      child: const Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.notifications_none,
                                            color: roseGold,
                                          ),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'Vanaf drie maanden voor de vervaldatum verschijnt een melding op Vandaag.',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (step == 2) ...[
                                    if (canChooseRelationships) ...[
                                      relationshipPicker(
                                        label: 'Eigenaar toevoegen',
                                        value: ownerMemberId,
                                        onChanged:
                                            (value) => setPageState(
                                              () => ownerMemberId = value ?? '',
                                            ),
                                      ),
                                      relationshipPicker(
                                        label: 'Trainer toevoegen',
                                        value: trainerMemberId,
                                        onChanged:
                                            (value) => setPageState(
                                              () =>
                                                  trainerMemberId = value ?? '',
                                            ),
                                      ),
                                      relationshipPicker(
                                        label: 'Ruiter toevoegen',
                                        value: riderMemberId,
                                        onChanged:
                                            (value) => setPageState(
                                              () => riderMemberId = value ?? '',
                                            ),
                                      ),
                                    ],
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: panel,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(color: border),
                                      ),
                                      child: Row(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            child:
                                                liveHorse == null
                                                    ? const AvarynOrionPhoto(
                                                      width: 92,
                                                      height: 92,
                                                    )
                                                    : _horsePhoto(
                                                      liveHorse,
                                                      width: 92,
                                                      height: 92,
                                                    ),
                                          ),
                                          const SizedBox(width: 15),
                                          Expanded(
                                            child: Text(
                                              horse == null
                                                  ? 'Na het aanmaken kun je direct via Bewerken een profielfoto kiezen.'
                                                  : 'Deze foto staat alleen als profielfoto ingesteld; gewone private media blijven apart.',
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.76,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (liveHorse != null &&
                                        _canEditSelectedHorseMedia) ...[
                                      const SizedBox(height: 16),
                                      OutlinedButton.icon(
                                        onPressed: () async {
                                          await _pickAndSetSelectedHorseProfilePhoto();
                                          if (context.mounted) {
                                            setPageState(() {});
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.add_a_photo_outlined,
                                        ),
                                        label: Text(
                                          _operationalString(
                                                liveHorse['profile_media_asset_id'],
                                              ).isEmpty
                                              ? 'Foto kiezen'
                                              : 'Foto vervangen',
                                        ),
                                      ),
                                      if (_operationalString(
                                        liveHorse['profile_media_asset_id'],
                                      ).isNotEmpty)
                                        TextButton.icon(
                                          onPressed: () async {
                                            await _removeSelectedHorseProfilePhoto();
                                            if (context.mounted) {
                                              setPageState(() {});
                                            }
                                          },
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                          label: const Text(
                                            'Profielfoto verwijderen',
                                          ),
                                        ),
                                    ],
                                  ],
                                  if (validationError != null) ...[
                                    const SizedBox(height: 18),
                                    Text(
                                      validationError!,
                                      style: const TextStyle(
                                        color: Color(0xFFD87870),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
                            decoration: const BoxDecoration(
                              color: panel,
                              border: Border(top: BorderSide(color: border)),
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () {
                                  if (step < 2) {
                                    if (step == 0 &&
                                        normalizedProfile() == null) {
                                      setPageState(() {});
                                      return;
                                    }
                                    setPageState(() {
                                      validationError = null;
                                      step++;
                                    });
                                    return;
                                  }
                                  final profile = normalizedProfile();
                                  if (profile == null) {
                                    setPageState(() {});
                                    return;
                                  }
                                  Navigator.pop(routeContext, profile);
                                },
                                icon: Icon(
                                  step < 2 ? Icons.arrow_forward : Icons.check,
                                ),
                                label: Text(
                                  step < 2
                                      ? 'Volgende'
                                      : horse == null
                                      ? 'Paard toevoegen'
                                      : 'Wijzigingen opslaan',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      ),
    );
    displayName.dispose();
    officialName.dispose();
    birthDate.dispose();
    breed.dispose();
    discipline.dispose();
    passportNumber.dispose();
    chipNumber.dispose();
    passportExpiresOn.dispose();
    return result;
  }

  String _rosterNameFor({
    String membershipId = '',
    String stableMemberId = '',
  }) {
    for (final member in _stableRoster) {
      if ((membershipId.isNotEmpty &&
              _operationalString(member['membership_id']) == membershipId) ||
          (stableMemberId.isNotEmpty &&
              _operationalString(member['id']) == stableMemberId)) {
        return _operationalString(member['display_name']);
      }
    }
    return 'Teamlid';
  }

  Future<void> _grantSelectedHorseAccess() async {
    final grant = await _showHorseAccessDialog();
    if (grant == null) return;
    final horseId = _selectedHorseId;
    await _guarded(() async {
      await _runDurableIdempotentRpc(
        operation: 'grant_horse_access',
        intentKey: [
          horseId,
          grant['membership_id'],
          grant['category'],
          grant['access_level'],
          grant['reason'],
        ].map(_operationalString).join('|'),
        buildParams:
            (requestId, _) => {
              'p_horse_id': horseId,
              'p_membership_id': grant['membership_id'],
              'p_category': grant['category'],
              'p_can_view': true,
              'p_can_execute':
                  grant['access_level'] == 'work' &&
                  grant['category'] == 'horse.schedule',
              'p_can_edit':
                  grant['access_level'] == 'work' &&
                  const {
                    'horse.basic',
                    'horse.media',
                  }.contains(grant['category']),
              'p_can_manage': false,
              'p_valid_from': null,
              'p_valid_until': null,
              'p_grant_reason': grant['reason'],
              'p_request_id': requestId,
            },
      );
      _notice = 'Beperkte paardtoegang veilig toegekend.';
      await _load(quiet: true);
    });
  }

  Future<Map<String, dynamic>?> _showHorseAccessDialog() async {
    final actorRole = _operationalString(_actorMembership['role']);
    final candidates = _stableRoster
        .where(
          (member) =>
              _operationalString(member['membership_id']).isNotEmpty &&
              _operationalString(member['membership_id']) !=
                  _operationalString(_actorMembership['id']) &&
              const {
                'admin',
                'member',
                'viewer',
              }.contains(_operationalString(member['role'])) &&
              (actorRole == 'owner' ||
                  _operationalString(member['role']) != 'admin'),
        )
        .toList(growable: false);
    if (candidates.isEmpty) {
      setState(
        () =>
            _error =
                'Er is geen actief member- of viewer-lid waaraan beperkte toegang kan worden gegeven.',
      );
      return null;
    }
    var membershipId = _operationalString(candidates.first['membership_id']);
    var category = 'horse.basic';
    var accessLevel = 'view';
    final reason = TextEditingController();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) {
              final selected = candidates.firstWhere(
                (member) =>
                    _operationalString(member['membership_id']) == membershipId,
              );
              final targetRole = _operationalString(selected['role']);
              if (targetRole == 'viewer' && accessLevel == 'work') {
                accessLevel = 'view';
              }
              return AlertDialog(
                title: const Text('Beperkte paardtoegang'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: membershipId,
                        decoration: const InputDecoration(labelText: 'Teamlid'),
                        items:
                            candidates
                                .map(
                                  (member) => DropdownMenuItem(
                                    value: _operationalString(
                                      member['membership_id'],
                                    ),
                                    child: Text(
                                      '${member['display_name']} · ${member['role']}',
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            (value) => setDialogState(
                              () => membershipId = value ?? membershipId,
                            ),
                      ),
                      DropdownButtonFormField<String>(
                        value: category,
                        decoration: const InputDecoration(labelText: 'Context'),
                        items: const [
                          DropdownMenuItem(
                            value: 'horse.basic',
                            child: Text('Kerngegevens'),
                          ),
                          DropdownMenuItem(
                            value: 'horse.schedule',
                            child: Text('Planning en uitvoering'),
                          ),
                          DropdownMenuItem(
                            value: 'horse.media',
                            child: Text('Private operationele media'),
                          ),
                        ],
                        onChanged:
                            (value) => setDialogState(
                              () => category = value ?? category,
                            ),
                      ),
                      DropdownButtonFormField<String>(
                        value: accessLevel,
                        decoration: const InputDecoration(labelText: 'Toegang'),
                        items: [
                          const DropdownMenuItem(
                            value: 'view',
                            child: Text('Alleen bekijken'),
                          ),
                          if (targetRole != 'viewer')
                            DropdownMenuItem(
                              value: 'work',
                              child: Text(switch (category) {
                                'horse.basic' => 'Bekijken en bewerken',
                                'horse.media' => 'Bekijken en uploaden',
                                _ => 'Bekijken en uitvoeren',
                              }),
                            ),
                        ],
                        onChanged:
                            (value) => setDialogState(
                              () => accessLevel = value ?? accessLevel,
                            ),
                      ),
                      TextField(
                        controller: reason,
                        maxLength: 500,
                        onChanged: (_) => setDialogState(() {}),
                        decoration: InputDecoration(
                          labelText:
                              category == 'horse.media'
                                  ? 'Reden (verplicht voor media)'
                                  : 'Reden (optioneel)',
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Annuleren'),
                  ),
                  FilledButton(
                    onPressed:
                        category == 'horse.media' && reason.text.trim().isEmpty
                            ? null
                            : () => Navigator.pop(dialogContext, {
                              'membership_id': membershipId,
                              'category': category,
                              'access_level': accessLevel,
                              'reason':
                                  reason.text.trim().isEmpty
                                      ? null
                                      : reason.text.trim(),
                            }),
                    child: const Text('Toekennen'),
                  ),
                ],
              );
            },
          ),
    );
    reason.dispose();
    return result;
  }

  Future<void> _revokeHorseAccess(Map<String, dynamic> grant) async {
    final membershipId = _operationalString(grant['membership_id']);
    final category = _operationalString(grant['category']);
    final confirmed = await _confirmDialog(
      title: 'Toegang intrekken',
      body:
          'Trek $category voor ${_rosterNameFor(membershipId: membershipId)} direct in?',
      action: 'Intrekken',
    );
    if (!confirmed) return;
    await _guarded(() async {
      await _runDurableIdempotentRpc(
        operation: 'revoke_horse_access',
        intentKey: '$_selectedHorseId:$membershipId:$category',
        buildParams:
            (requestId, _) => {
              'p_horse_id': _selectedHorseId,
              'p_membership_id': membershipId,
              'p_category': category,
              'p_request_id': requestId,
            },
      );
      _notice = 'Paardtoegang direct ingetrokken.';
      await _load(quiet: true);
    });
  }

  Future<void> _addHorseRelationship() async {
    final relationship = await _showHorseRelationshipDialog();
    if (relationship == null) return;
    final initialValidFrom = _operationalDateKey(_stableNow());
    await _guarded(() async {
      await _runDurableIdempotentRpc(
        operation: 'add_horse_relationship',
        intentKey: [
          _selectedHorseId,
          relationship['stable_member_id'],
          relationship['relationship_type'],
          relationship['label'],
        ].map(_operationalString).join('|'),
        initialReplayValues: {'valid_from': initialValidFrom},
        buildParams:
            (requestId, replayValues) => {
              'p_horse_id': _selectedHorseId,
              'p_stable_member_id': relationship['stable_member_id'],
              'p_relationship_type': relationship['relationship_type'],
              'p_request_id': requestId,
              'p_valid_from': replayValues['valid_from']!,
              'p_label': relationship['label'],
            },
      );
      _notice = 'Paard-teamrelatie toegevoegd; autorisatie blijft apart.';
      await _load(quiet: true);
    });
  }

  String _horseRelationshipLabel(dynamic value) => switch (_operationalString(
    value,
  )) {
    'owner' => 'Eigenaar',
    'trainer' => 'Trainer',
    'rider' => 'Ruiter',
    'groom' => 'Groom',
    'veterinarian' => 'Dierenarts',
    'professional' => 'Professional',
    _ => 'Anders',
  };

  Future<Map<String, dynamic>?> _showHorseRelationshipDialog() async {
    if (_stableRoster.isEmpty) {
      setState(() => _error = 'Er zijn geen actieve stalteamleden.');
      return null;
    }
    var stableMemberId = _operationalString(_stableRoster.first['id']);
    var relationshipType = 'rider';
    final label = TextEditingController();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Relatie met paard'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          value: stableMemberId,
                          decoration: const InputDecoration(
                            labelText: 'Teamlid',
                          ),
                          items:
                              _stableRoster
                                  .map(
                                    (member) => DropdownMenuItem(
                                      value: _operationalString(member['id']),
                                      child: Text(
                                        _operationalString(
                                          member['display_name'],
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              (value) => setDialogState(
                                () => stableMemberId = value ?? stableMemberId,
                              ),
                        ),
                        DropdownButtonFormField<String>(
                          value: relationshipType,
                          decoration: const InputDecoration(
                            labelText: 'Relatie',
                          ),
                          items:
                              const {
                                    'owner': 'Eigenaar',
                                    'rider': 'Ruiter',
                                    'groom': 'Groom',
                                    'trainer': 'Trainer',
                                    'veterinarian': 'Dierenarts',
                                    'professional': 'Professional',
                                    'other': 'Anders',
                                  }.entries
                                  .map(
                                    (entry) => DropdownMenuItem(
                                      value: entry.key,
                                      child: Text(entry.value),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              (value) => setDialogState(
                                () =>
                                    relationshipType =
                                        value ?? relationshipType,
                              ),
                        ),
                        TextField(
                          controller: label,
                          maxLength: 160,
                          decoration: const InputDecoration(
                            labelText: 'Toelichting (optioneel)',
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Annuleren'),
                    ),
                    FilledButton(
                      onPressed:
                          () => Navigator.pop(dialogContext, {
                            'stable_member_id': stableMemberId,
                            'relationship_type': relationshipType,
                            'label':
                                label.text.trim().isEmpty
                                    ? null
                                    : label.text.trim(),
                          }),
                      child: const Text('Toevoegen'),
                    ),
                  ],
                ),
          ),
    );
    label.dispose();
    return result;
  }

  Future<void> _endHorseRelationship(Map<String, dynamic> relationship) async {
    final relationshipId = _operationalString(relationship['id']);
    final rowVersion = int.tryParse(
      _operationalString(relationship['row_version']),
    );
    if (relationshipId.isEmpty || rowVersion == null || rowVersion < 1) {
      setState(() => _error = 'Vernieuw de relatie voordat je haar beëindigt.');
      return;
    }
    final confirmed = await _confirmDialog(
      title: 'Relatie beëindigen',
      body:
          'Beëindig de relatie ${_horseRelationshipLabel(relationship['relationship_type'])} met '
          '${_rosterNameFor(stableMemberId: _operationalString(relationship['stable_member_id']))}?',
      action: 'Beëindigen',
    );
    if (!confirmed) return;
    final initialValidUntil = _operationalDateKey(_stableNow());
    await _guarded(() async {
      await _runDurableIdempotentRpc(
        operation: 'end_horse_relationship',
        intentKey: '$relationshipId:$rowVersion',
        initialReplayValues: {'valid_until': initialValidUntil},
        buildParams:
            (requestId, replayValues) => {
              'p_relationship_id': relationshipId,
              'p_expected_row_version': rowVersion,
              'p_request_id': requestId,
              'p_valid_until': replayValues['valid_until']!,
            },
      );
      _notice = 'Paard-teamrelatie beëindigd; historie blijft bewaard.';
      await _load(quiet: true);
    });
  }

  Future<bool> _confirmDialog({
    required String title,
    required String body,
    required String action,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: Text(title),
              content: Text(body),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Annuleren'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(action),
                ),
              ],
            ),
      ) ??
      false;

  Future<void> _createScheduleItem() async {
    if (_horses.isEmpty) {
      setState(() => _error = 'Voeg eerst een paard toe.');
      return;
    }
    final actorUserId = _client.auth.currentUser?.id ?? '';
    final stableId = _stableId;
    final stableTimezone = _stableTimezone;
    final sensitiveStateGeneration = _sensitiveStateGeneration;
    final selectedDay = _scheduleDate ?? _stableNow();
    if (actorUserId.isEmpty || stableId.isEmpty || stableTimezone.isEmpty) {
      return;
    }
    final input = await _showScheduleTaskDialog();
    if (input == null ||
        !_planningScopeMatches(
          generation: sensitiveStateGeneration,
          actorUserId: actorUserId,
          stableId: stableId,
        )) {
      return;
    }
    final taskTitle = input['title']!;
    final horseId = input['horse_id']!;
    final memberId = input['stable_member_id'] ?? '';
    final itemKind = input['item_kind']!;
    final activityType = input['activity_type']!;
    final priority = input['priority']!;
    final instruction = 'Categorie: $activityType\n${input['instruction']!}';
    final location = input['location']!;
    final allDay = input['all_day'] == 'true';
    final plannedHour = allDay ? 0 : int.parse(input['hour']!);
    final plannedMinute = allDay ? 0 : int.parse(input['minute']!);
    final plannedEndHour = allDay ? 23 : int.parse(input['end_hour']!);
    final plannedEndMinute = allDay ? 59 : int.parse(input['end_minute']!);
    final start = timezone.TZDateTime(
      timezone.getLocation(stableTimezone),
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
      plannedHour,
      plannedMinute,
    );
    final localDate = _operationalDateKey(start);
    final localTime =
        '${start.hour.toString().padLeft(2, '0')}:'
        '${start.minute.toString().padLeft(2, '0')}:00';
    final startUtc = start.toUtc().toIso8601String();
    final end = timezone.TZDateTime(
      timezone.getLocation(stableTimezone),
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
      plannedEndHour,
      plannedEndMinute,
    );
    if (!end.isAfter(start)) {
      setState(() => _error = 'De eindtijd moet na de starttijd liggen.');
      return;
    }
    final endUtc = end.toUtc().toIso8601String();
    void scopePreflight() => _assertPlanningScopeCurrent(
      generation: sensitiveStateGeneration,
      actorUserId: actorUserId,
      stableId: stableId,
    );
    await _guarded(() async {
      final created = _operationalMap(
        await _runDurableIdempotentRpc(
          operation: 'create_schedule_task_with_assignment_v2',
          intentKey:
              '$horseId:$localDate:$localTime:$taskTitle:$memberId:'
              '$itemKind:$priority:$location:$instruction',
          initialReplayValues: {
            'stable_id': stableId,
            'horse_id': horseId,
            'title': taskTitle,
            'item_kind': itemKind,
            'priority': priority,
            'instruction': instruction,
            'location': location,
            'scheduled_start_at': startUtc,
            'scheduled_end_at': endUtc,
            'source_timezone': stableTimezone,
            'source_local_date': localDate,
            'source_local_time': localTime,
            if (memberId.isNotEmpty) ...{
              'stable_member_id': memberId,
              'assignment_request_id': _uuid.v4(),
            },
          },
          scopePreflight: scopePreflight,
          buildParams:
              (requestId, replayValues) => {
                'p_stable_id': replayValues['stable_id'],
                'p_horse_id': replayValues['horse_id'],
                'p_item_kind': replayValues['item_kind'],
                'p_title': replayValues['title'],
                'p_instruction': replayValues['instruction'],
                'p_location': replayValues['location'],
                'p_priority': replayValues['priority'],
                'p_scheduled_start_at': replayValues['scheduled_start_at'],
                'p_scheduled_end_at': replayValues['scheduled_end_at'],
                'p_source_timezone': replayValues['source_timezone'],
                'p_source_local_date': replayValues['source_local_date'],
                'p_source_local_time': replayValues['source_local_time'],
                'p_create_request_id': requestId,
                'p_stable_member_id': replayValues['stable_member_id'],
                'p_assignment_request_id':
                    replayValues['assignment_request_id'],
              },
        ),
      );
      if (_operationalString(created['schedule_item_id']).isEmpty) {
        throw StateError('SCHEDULE_RESULT_INVALID');
      }
      scopePreflight();
      _notice =
          memberId.isNotEmpty
              ? 'Taak veilig gepland en toegewezen.'
              : 'Taak veilig gepland.';
      await _load(quiet: true);
    });
  }

  Future<Map<String, String>?> _showScheduleTaskDialog() async {
    final title = TextEditingController();
    final instruction = TextEditingController();
    final location = TextEditingController();
    var horseId =
        _selectedHorseId.isNotEmpty
            ? _selectedHorseId
            : _operationalString(_horses.first['id']);
    var stableMemberId = '';
    var activityType = 'Verzorging';
    var priority = 'normal';
    final stableNow = _stableNow();
    var selectedHour = stableNow.hour;
    var selectedMinute = ((stableNow.minute ~/ 15) + 1) * 15;
    if (selectedMinute >= 60) {
      if (selectedHour == 23) {
        selectedMinute = 45;
      } else {
        selectedHour += 1;
        selectedMinute = 0;
      }
    }
    var endHour = selectedHour;
    var endMinute = selectedMinute + 30;
    if (endMinute >= 60) {
      endHour = endHour >= 23 ? 23 : endHour + 1;
      endMinute -= 60;
    }
    var allDay = false;
    var showTitleError = false;
    BuildContext? openedDialogContext;
    Route<dynamic>? openedDialogRoute;
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        final dialogRoute = ModalRoute.of(dialogContext);
        openedDialogContext = dialogContext;
        openedDialogRoute = dialogRoute;
        _sensitivePlanningDialogContext = dialogContext;
        _sensitivePlanningDialogRoute = dialogRoute;
        return StatefulBuilder(
          builder:
              (context, setDialogState) => AlertDialog(
                title: const Text('Taak plannen'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: horseId,
                        decoration: const InputDecoration(labelText: 'Paard'),
                        items: _horses
                            .map(
                              (horse) => DropdownMenuItem(
                                value: _operationalString(horse['id']),
                                child: Text(
                                  _operationalString(horse['display_name']),
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged:
                            (value) => setDialogState(
                              () => horseId = value ?? horseId,
                            ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: title,
                        autofocus: true,
                        maxLength: 160,
                        decoration: InputDecoration(
                          labelText: 'Titel',
                          errorText:
                              showTitleError
                                  ? 'Vul een duidelijke titel in.'
                                  : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        value: activityType,
                        decoration: const InputDecoration(
                          labelText: 'Type activiteit',
                        ),
                        items: const [
                              'Training',
                              'Verzorging',
                              'Hoefsmid',
                              'Dierenarts',
                              'Wedstrijd',
                            ]
                            .map(
                              (option) => DropdownMenuItem(
                                value: option,
                                child: Text(option),
                              ),
                            )
                            .toList(growable: false),
                        onChanged:
                            (value) => setDialogState(
                              () => activityType = value ?? activityType,
                            ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: location,
                        maxLength: 200,
                        decoration: const InputDecoration(
                          labelText: 'Locatie (optioneel)',
                        ),
                      ),
                      TextField(
                        controller: instruction,
                        maxLength: 1600,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Instructie',
                        ),
                      ),
                      DropdownButtonFormField<String>(
                        value: priority,
                        decoration: const InputDecoration(
                          labelText: 'Prioriteit',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'normal',
                            child: Text('Normaal'),
                          ),
                          DropdownMenuItem(value: 'high', child: Text('Hoog')),
                        ],
                        onChanged:
                            (value) => setDialogState(
                              () => priority = value ?? priority,
                            ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: stableMemberId,
                        decoration: const InputDecoration(
                          labelText: 'Verantwoordelijke',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('Niet toegewezen'),
                          ),
                          ..._planningRoster.map(
                            (member) => DropdownMenuItem(
                              value: _operationalString(member['id']),
                              child: Text(
                                _operationalString(member['display_name']),
                              ),
                            ),
                          ),
                        ],
                        onChanged:
                            (value) => setDialogState(
                              () => stableMemberId = value ?? '',
                            ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: allDay,
                        title: const Text('Hele dag'),
                        onChanged:
                            (value) => setDialogState(() => allDay = value),
                      ),
                      if (!allDay)
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: selectedHour,
                                decoration: const InputDecoration(
                                  labelText: 'Uur',
                                ),
                                items: List.generate(
                                  24,
                                  (hour) => DropdownMenuItem(
                                    value: hour,
                                    child: Text(
                                      hour.toString().padLeft(2, '0'),
                                    ),
                                  ),
                                ),
                                onChanged:
                                    (value) => setDialogState(
                                      () =>
                                          selectedHour = value ?? selectedHour,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: selectedMinute,
                                decoration: const InputDecoration(
                                  labelText: 'Minuut',
                                ),
                                items: const [0, 15, 30, 45]
                                    .map(
                                      (minute) => DropdownMenuItem(
                                        value: minute,
                                        child: Text(
                                          minute.toString().padLeft(2, '0'),
                                        ),
                                      ),
                                    )
                                    .toList(growable: false),
                                onChanged:
                                    (value) => setDialogState(
                                      () =>
                                          selectedMinute =
                                              value ?? selectedMinute,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      if (!allDay) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: endHour,
                                decoration: const InputDecoration(
                                  labelText: 'Einduur',
                                ),
                                items: List.generate(
                                  24,
                                  (hour) => DropdownMenuItem(
                                    value: hour,
                                    child: Text(
                                      hour.toString().padLeft(2, '0'),
                                    ),
                                  ),
                                ),
                                onChanged:
                                    (value) => setDialogState(
                                      () => endHour = value ?? endHour,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: endMinute,
                                decoration: const InputDecoration(
                                  labelText: 'Eindminuut',
                                ),
                                items: const [0, 15, 30, 45]
                                    .map(
                                      (minute) => DropdownMenuItem(
                                        value: minute,
                                        child: Text(
                                          minute.toString().padLeft(2, '0'),
                                        ),
                                      ),
                                    )
                                    .toList(growable: false),
                                onChanged:
                                    (value) => setDialogState(
                                      () => endMinute = value ?? endMinute,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Annuleren'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final normalizedTitle = title.text.trim();
                      if (normalizedTitle.isEmpty) {
                        setDialogState(() => showTitleError = true);
                        return;
                      }
                      Navigator.pop(dialogContext, {
                        'title': normalizedTitle,
                        'horse_id': horseId,
                        'activity_type': activityType,
                        'item_kind':
                            activityType == 'Training'
                                ? 'training'
                                : activityType == 'Verzorging'
                                ? 'care'
                                : 'other',
                        'priority': priority,
                        'location': location.text.trim(),
                        'instruction':
                            instruction.text.trim().isEmpty
                                ? 'Uitvoeren volgens de stalplanning.'
                                : instruction.text.trim(),
                        'stable_member_id': stableMemberId,
                        'hour': selectedHour.toString(),
                        'minute': selectedMinute.toString(),
                        'end_hour': endHour.toString(),
                        'end_minute': endMinute.toString(),
                        'all_day': allDay.toString(),
                      });
                    },
                    child: const Text('Plannen'),
                  ),
                ],
              ),
        );
      },
    );
    if (identical(_sensitivePlanningDialogContext, openedDialogContext) &&
        identical(_sensitivePlanningDialogRoute, openedDialogRoute)) {
      _sensitivePlanningDialogContext = null;
      _sensitivePlanningDialogRoute = null;
    }
    title.dispose();
    instruction.dispose();
    location.dispose();
    return result;
  }

  Future<void> _createScheduleSeries() async {
    if (_horses.isEmpty) {
      setState(() => _error = 'Voeg eerst een paard toe.');
      return;
    }
    final actorUserId = _client.auth.currentUser?.id ?? '';
    final stableId = _stableId;
    final stableTimezone = _stableTimezone;
    final sensitiveStateGeneration = _sensitiveStateGeneration;
    final selectedDay = _scheduleDate ?? _stableNow();
    if (actorUserId.isEmpty || stableId.isEmpty || stableTimezone.isEmpty) {
      return;
    }
    final input = await _showScheduleSeriesDialog();
    if (input == null ||
        !_planningScopeMatches(
          generation: sensitiveStateGeneration,
          actorUserId: actorUserId,
          stableId: stableId,
        )) {
      return;
    }
    final frequency = input['frequency']!;
    final hour = int.parse(input['hour']!);
    final minute = int.parse(input['minute']!);
    final localTime =
        '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}:00';
    final throughDate = selectedDay.add(const Duration(days: 12));
    final startsOn = _operationalDateKey(selectedDay);
    final throughLocalDate = _operationalDateKey(throughDate);
    final horseId = input['horse_id']!;
    final title = input['title']!;
    final seriesKind = input['item_kind']!;
    final instruction = input['instruction']!;
    final location = input['location']!;
    final memberId = input['stable_member_id']!;
    void scopePreflight() => _assertPlanningScopeCurrent(
      generation: sensitiveStateGeneration,
      actorUserId: actorUserId,
      stableId: stableId,
    );
    await _guarded(() async {
      final created = _operationalMap(
        await _runDurableIdempotentRpc(
          operation: 'create_schedule_series_with_occurrences_v2',
          intentKey:
              '$horseId:$startsOn:$frequency:$localTime:$title:'
              '$seriesKind:$location:$memberId:$instruction',
          initialReplayValues: {
            'stable_id': stableId,
            'horse_id': horseId,
            'title': title,
            'series_kind': seriesKind,
            'instruction': instruction,
            'location': location,
            'stable_member_id': memberId,
            'timezone': stableTimezone,
            'frequency': frequency,
            'weekdays': selectedDay.weekday.toString(),
            'local_start_time': localTime,
            'starts_on': startsOn,
            'through_local_date': throughLocalDate,
            'materialize_request_id': _uuid.v4(),
          },
          scopePreflight: scopePreflight,
          buildParams:
              (requestId, replayValues) => {
                'p_stable_id': replayValues['stable_id'],
                'p_horse_id': replayValues['horse_id'],
                'p_series_kind': replayValues['series_kind'],
                'p_title': replayValues['title'],
                'p_instruction': replayValues['instruction'],
                'p_location': replayValues['location'],
                'p_timezone': replayValues['timezone'],
                'p_frequency': replayValues['frequency'],
                'p_interval_value': 1,
                'p_weekdays':
                    replayValues['frequency'] == 'weekly'
                        ? [int.parse(replayValues['weekdays']!)]
                        : null,
                'p_local_start_time': replayValues['local_start_time'],
                'p_duration_minutes': 30,
                'p_starts_on': replayValues['starts_on'],
                'p_ends_on': null,
                'p_generation_horizon_days': 30,
                'p_status': 'active',
                'p_through_local_date': replayValues['through_local_date'],
                'p_stable_member_id':
                    replayValues['stable_member_id']!.isEmpty
                        ? null
                        : replayValues['stable_member_id'],
                'p_create_request_id': requestId,
                'p_materialize_request_id':
                    replayValues['materialize_request_id'],
              },
        ),
      );
      final seriesId = _operationalString(created['series_id']);
      if (seriesId.isEmpty) {
        throw StateError('SCHEDULE_RESULT_INVALID');
      }
      scopePreflight();
      _notice =
          frequency == 'daily'
              ? 'Dagelijkse routine veilig aangemaakt.'
              : 'Wekelijkse routine veilig aangemaakt.';
      await _load(quiet: true);
    });
  }

  Future<Map<String, String>?> _showScheduleSeriesDialog() async {
    final title = TextEditingController();
    final instruction = TextEditingController();
    final location = TextEditingController();
    var horseId =
        _selectedHorseId.isNotEmpty
            ? _selectedHorseId
            : _operationalString(_horses.first['id']);
    var frequency = 'daily';
    var itemKind = 'task';
    var stableMemberId = '';
    var selectedHour = 9;
    var selectedMinute = 0;
    var showTitleError = false;
    BuildContext? openedDialogContext;
    Route<dynamic>? openedDialogRoute;
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        final dialogRoute = ModalRoute.of(dialogContext);
        openedDialogContext = dialogContext;
        openedDialogRoute = dialogRoute;
        _sensitivePlanningDialogContext = dialogContext;
        _sensitivePlanningDialogRoute = dialogRoute;
        return StatefulBuilder(
          builder:
              (context, setDialogState) => AlertDialog(
                title: const Text('Terugkerende routine'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: horseId,
                        decoration: const InputDecoration(labelText: 'Paard'),
                        items: _horses
                            .map(
                              (horse) => DropdownMenuItem(
                                value: _operationalString(horse['id']),
                                child: Text(
                                  _operationalString(horse['display_name']),
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged:
                            (value) => setDialogState(
                              () => horseId = value ?? horseId,
                            ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: title,
                        autofocus: true,
                        maxLength: 160,
                        decoration: InputDecoration(
                          labelText: 'Titel',
                          errorText:
                              showTitleError
                                  ? 'Vul een duidelijke titel in.'
                                  : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        value: itemKind,
                        decoration: const InputDecoration(
                          labelText: 'Categorie',
                        ),
                        items: const [
                              ('task', 'Taak'),
                              ('care', 'Verzorging'),
                              ('training', 'Training'),
                              ('other', 'Afspraak'),
                            ]
                            .map(
                              (option) => DropdownMenuItem(
                                value: option.$1,
                                child: Text(option.$2),
                              ),
                            )
                            .toList(growable: false),
                        onChanged:
                            (value) => setDialogState(
                              () => itemKind = value ?? itemKind,
                            ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: location,
                        maxLength: 200,
                        decoration: const InputDecoration(
                          labelText: 'Locatie (optioneel)',
                        ),
                      ),
                      TextField(
                        controller: instruction,
                        maxLength: 1600,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Instructie',
                        ),
                      ),
                      DropdownButtonFormField<String>(
                        value: stableMemberId,
                        decoration: const InputDecoration(
                          labelText: 'Verantwoordelijke',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('Niet toegewezen'),
                          ),
                          ..._planningRoster.map(
                            (member) => DropdownMenuItem(
                              value: _operationalString(member['id']),
                              child: Text(
                                _operationalString(member['display_name']),
                              ),
                            ),
                          ),
                        ],
                        onChanged:
                            (value) => setDialogState(
                              () => stableMemberId = value ?? '',
                            ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: frequency,
                        decoration: const InputDecoration(
                          labelText: 'Herhaling',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'daily',
                            child: Text('Dagelijks'),
                          ),
                          DropdownMenuItem(
                            value: 'weekly',
                            child: Text('Wekelijks op deze weekdag'),
                          ),
                        ],
                        onChanged:
                            (value) => setDialogState(
                              () => frequency = value ?? frequency,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: selectedHour,
                              decoration: const InputDecoration(
                                labelText: 'Uur',
                              ),
                              items: List.generate(
                                24,
                                (hour) => DropdownMenuItem(
                                  value: hour,
                                  child: Text(hour.toString().padLeft(2, '0')),
                                ),
                              ),
                              onChanged:
                                  (value) => setDialogState(
                                    () => selectedHour = value ?? selectedHour,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: selectedMinute,
                              decoration: const InputDecoration(
                                labelText: 'Minuut',
                              ),
                              items: const [0, 15, 30, 45]
                                  .map(
                                    (minute) => DropdownMenuItem(
                                      value: minute,
                                      child: Text(
                                        minute.toString().padLeft(2, '0'),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged:
                                  (value) => setDialogState(
                                    () =>
                                        selectedMinute =
                                            value ?? selectedMinute,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Annuleren'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final normalizedTitle = title.text.trim();
                      if (normalizedTitle.isEmpty) {
                        setDialogState(() => showTitleError = true);
                        return;
                      }
                      Navigator.pop(dialogContext, {
                        'title': normalizedTitle,
                        'horse_id': horseId,
                        'item_kind': itemKind,
                        'location': location.text.trim(),
                        'instruction':
                            instruction.text.trim().isEmpty
                                ? 'Uitvoeren volgens de stalplanning.'
                                : instruction.text.trim(),
                        'stable_member_id': stableMemberId,
                        'frequency': frequency,
                        'hour': selectedHour.toString(),
                        'minute': selectedMinute.toString(),
                      });
                    },
                    child: const Text('Routine aanmaken'),
                  ),
                ],
              ),
        );
      },
    );
    if (identical(_sensitivePlanningDialogContext, openedDialogContext) &&
        identical(_sensitivePlanningDialogRoute, openedDialogRoute)) {
      _sensitivePlanningDialogContext = null;
      _sensitivePlanningDialogRoute = null;
    }
    title.dispose();
    instruction.dispose();
    location.dispose();
    return result;
  }

  bool _planningScopeMatches({
    required int generation,
    required String actorUserId,
    required String stableId,
  }) =>
      generation == _sensitiveStateGeneration &&
      _client.auth.currentUser?.id == actorUserId &&
      _stableId == stableId;

  void _assertPlanningScopeCurrent({
    required int generation,
    required String actorUserId,
    required String stableId,
  }) {
    if (!_planningScopeMatches(
      generation: generation,
      actorUserId: actorUserId,
      stableId: stableId,
    )) {
      throw StateError('STALE_PLANNING_CONFIRMATION');
    }
  }

  Future<void> _setScheduleDate(DateTime date) async {
    if (_busy) return;
    _scheduleDate = DateTime(date.year, date.month, date.day);
    await _load();
  }

  Future<void> _setCalendarView(String value) async {
    if (_busy || value == _calendarView) return;
    setState(() => _calendarView = value);
    await _load();
  }

  Widget _scheduleDateControls(FlutterFlowTheme theme) {
    final stableNow = _stableNow();
    final selected = _scheduleDate ?? stableNow;
    final today = DateTime(stableNow.year, stableNow.month, stableNow.day);
    final selectedDay = DateTime(selected.year, selected.month, selected.day);
    final isToday = selectedDay == today;
    final step =
        _calendarView == 'month'
            ? DateTime(selectedDay.year, selectedDay.month - 1)
            : _calendarView == 'week'
            ? selectedDay.subtract(const Duration(days: 7))
            : selectedDay.subtract(const Duration(days: 1));
    final next =
        _calendarView == 'month'
            ? DateTime(selectedDay.year, selectedDay.month + 1)
            : _calendarView == 'week'
            ? selectedDay.add(const Duration(days: 7))
            : selectedDay.add(const Duration(days: 1));
    final label =
        _calendarView == 'month'
            ? '${selectedDay.month.toString().padLeft(2, '0')}-${selectedDay.year}'
            : _calendarView == 'week'
            ? 'Week ${_weekNumber(selectedDay)} · ${selectedDay.year}'
            : isToday
            ? 'Vandaag'
            : _operationalDisplayDate(selectedDay);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.titleMedium.copyWith(
            color: theme.primaryText,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Tooltip(
                message: 'Vorige periode',
                child: TextButton.icon(
                  onPressed:
                      _offline || _busy
                          ? null
                          : () => unawaited(_setScheduleDate(step)),
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Vorige'),
                ),
              ),
            ),
            Expanded(
              child: TextButton(
                onPressed:
                    _offline || _busy || isToday
                        ? null
                        : () => unawaited(_setScheduleDate(today)),
                child: const Text('Vandaag'),
              ),
            ),
            Expanded(
              child: Tooltip(
                message: 'Volgende periode',
                child: TextButton.icon(
                  onPressed:
                      _offline || _busy
                          ? null
                          : () => unawaited(_setScheduleDate(next)),
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('Volgende'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  int _weekNumber(DateTime date) {
    final thursday = date.add(Duration(days: 4 - date.weekday));
    final firstThursday = DateTime(thursday.year, 1, 4);
    return 1 +
        thursday
                .difference(
                  firstThursday.subtract(
                    Duration(days: firstThursday.weekday - 4),
                  ),
                )
                .inDays ~/
            7;
  }

  Widget _calendarControls(FlutterFlowTheme theme) => SegmentedButton<String>(
    segments: const [
      ButtonSegment(
        value: 'day',
        label: Text('Dag'),
        icon: Icon(Icons.view_day_outlined),
      ),
      ButtonSegment(
        value: 'week',
        label: Text('Week'),
        icon: Icon(Icons.view_week_outlined),
      ),
      ButtonSegment(
        value: 'month',
        label: Text('Maand'),
        icon: Icon(Icons.calendar_month_outlined),
      ),
    ],
    selected: {_calendarView},
    onSelectionChanged:
        _offline || _busy
            ? null
            : (values) => unawaited(_setCalendarView(values.single)),
  );

  Future<void> _createFeedingPlan() async {
    if (_horses.isEmpty) {
      setState(() => _error = 'Voeg eerst een paard toe.');
      return;
    }
    final actorUserId = _client.auth.currentUser?.id ?? '';
    final stableId = _stableId;
    final generation = _sensitiveStateGeneration;
    final input = await _showFeedingPlanDialog();
    if (input == null ||
        !_planningScopeMatches(
          generation: generation,
          actorUserId: actorUserId,
          stableId: stableId,
        )) {
      return;
    }
    void scopePreflight() => _assertPlanningScopeCurrent(
      generation: generation,
      actorUserId: actorUserId,
      stableId: stableId,
    );
    await _guarded(() async {
      final created = _operationalMap(
        await _runDurableIdempotentRpc(
          operation: 'create_feeding_plan_with_version',
          intentKey:
              '${input['horse_id']}:${input['plan_type']}:'
              '${input['effective_from']}:${input['effective_until']}:'
              '${input['name']}',
          initialReplayValues: {...input, 'version_request_id': _uuid.v4()},
          scopePreflight: scopePreflight,
          buildParams:
              (requestId, replayValues) => {
                'p_horse_id': replayValues['horse_id'],
                'p_plan_type': replayValues['plan_type'],
                'p_name': replayValues['name'],
                'p_effective_from': replayValues['effective_from'],
                'p_effective_until':
                    replayValues['effective_until']!.isEmpty
                        ? null
                        : replayValues['effective_until'],
                'p_change_reason': replayValues['change_reason'],
                'p_create_request_id': requestId,
                'p_version_request_id': replayValues['version_request_id'],
              },
        ),
      );
      scopePreflight();
      final planId = _operationalString(created['feeding_plan_id']);
      final versionId = _operationalString(created['feeding_plan_version_id']);
      if (planId.isEmpty || versionId.isEmpty) {
        throw StateError('FEEDING_RESULT_INVALID');
      }
      _selectedFeedingPlanId = planId;
      _selectedFeedingVersionId = versionId;
      _notice = 'Conceptvoerplan met eerste versie veilig aangemaakt.';
      await _load(quiet: true);
    });
  }

  Future<Map<String, String>?> _showFeedingPlanDialog() async {
    final name = TextEditingController();
    var horseId =
        _selectedHorseId.isNotEmpty
            ? _selectedHorseId
            : _operationalString(_horses.first['id']);
    var planType = 'standard';
    var temporaryDays = 7;
    var showNameError = false;
    BuildContext? openedDialogContext;
    Route<dynamic>? openedDialogRoute;
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        final dialogRoute = ModalRoute.of(dialogContext);
        openedDialogContext = dialogContext;
        openedDialogRoute = dialogRoute;
        _sensitivePlanningDialogContext = dialogContext;
        _sensitivePlanningDialogRoute = dialogRoute;
        return StatefulBuilder(
          builder:
              (context, setDialogState) => AlertDialog(
                title: const Text('Voerplan starten'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: horseId,
                        decoration: const InputDecoration(labelText: 'Paard'),
                        items: _horses
                            .map(
                              (horse) => DropdownMenuItem(
                                value: _operationalString(horse['id']),
                                child: Text(
                                  _operationalString(horse['display_name']),
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged:
                            (value) => setDialogState(
                              () => horseId = value ?? horseId,
                            ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: planType,
                        decoration: const InputDecoration(labelText: 'Type'),
                        items: const [
                          DropdownMenuItem(
                            value: 'standard',
                            child: Text('Standaardplan'),
                          ),
                          DropdownMenuItem(
                            value: 'temporary',
                            child: Text('Tijdelijke override'),
                          ),
                        ],
                        onChanged:
                            (value) => setDialogState(
                              () => planType = value ?? planType,
                            ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: name,
                        autofocus: true,
                        maxLength: 160,
                        decoration: InputDecoration(
                          labelText: 'Naam van het plan',
                          errorText:
                              showNameError
                                  ? 'Vul een duidelijke naam in.'
                                  : null,
                        ),
                      ),
                      if (planType == 'temporary') ...[
                        const SizedBox(height: 4),
                        DropdownButtonFormField<int>(
                          value: temporaryDays,
                          decoration: const InputDecoration(
                            labelText: 'Geldigheid vanaf vandaag',
                          ),
                          items: const [1, 3, 7, 14, 30]
                              .map(
                                (days) => DropdownMenuItem(
                                  value: days,
                                  child: Text(
                                    '$days dag${days == 1 ? '' : 'en'}',
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          onChanged:
                              (value) => setDialogState(
                                () => temporaryDays = value ?? temporaryDays,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Annuleren'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final normalizedName = name.text.trim();
                      if (normalizedName.isEmpty) {
                        setDialogState(() => showNameError = true);
                        return;
                      }
                      final start = _stableNow();
                      final end = start.add(Duration(days: temporaryDays - 1));
                      Navigator.pop(dialogContext, {
                        'horse_id': horseId,
                        'plan_type': planType,
                        'name': normalizedName,
                        'effective_from': _operationalDateKey(start),
                        'effective_until':
                            planType == 'temporary'
                                ? _operationalDateKey(end)
                                : '',
                        'change_reason':
                            planType == 'temporary'
                                ? 'Tijdelijke Alpha-override'
                                : 'Eerste Alpha-versie',
                      });
                    },
                    child: const Text('Aanmaken'),
                  ),
                ],
              ),
        );
      },
    );
    if (identical(_sensitivePlanningDialogContext, openedDialogContext) &&
        identical(_sensitivePlanningDialogRoute, openedDialogRoute)) {
      _sensitivePlanningDialogContext = null;
      _sensitivePlanningDialogRoute = null;
    }
    name.dispose();
    return result;
  }

  Map<String, dynamic>? get _selectedFeedingPlan {
    for (final plan in _feedingPlans) {
      if (_operationalString(plan['id']) == _selectedFeedingPlanId) {
        return plan;
      }
    }
    return null;
  }

  Map<String, dynamic>? get _selectedFeedingVersion {
    for (final version in _feedingPlanVersions) {
      if (_operationalString(version['id']) == _selectedFeedingVersionId) {
        return version;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> get _selectedFeedingItems => _feedingPlanItems
      .where(
        (item) =>
            _operationalString(item['feeding_plan_version_id']) ==
            _selectedFeedingVersionId,
      )
      .toList(growable: false);

  List<Map<String, dynamic>> get _selectedFeedingVersions =>
      _feedingPlanVersions
          .where(
            (version) =>
                _operationalString(version['feeding_plan_id']) ==
                _selectedFeedingPlanId,
          )
          .toList(growable: false);

  List<String> get _activeStandardOverrideKeys {
    final activeVersionIds =
        _feedingPlans
            .where(
              (plan) =>
                  _operationalString(plan['plan_type']) == 'standard' &&
                  _operationalString(plan['status']) == 'active' &&
                  _operationalString(plan['horse_id']) ==
                      _operationalString(_selectedFeedingPlan?['horse_id']),
            )
            .map((plan) => _operationalString(plan['active_version_id']))
            .where((id) => id.isNotEmpty)
            .toSet();
    final keys = _feedingPlanItems
        .where(
          (item) => activeVersionIds.contains(
            _operationalString(item['feeding_plan_version_id']),
          ),
        )
        .map((item) => _operationalString(item['override_key']))
        .where((key) => key.isNotEmpty)
        .toSet()
        .toList(growable: false);
    keys.sort();
    return keys;
  }

  Future<String?> _showSensitiveTextDialog({
    required String title,
    required String label,
    required String action,
    int maxLength = 500,
  }) async {
    final controller = TextEditingController();
    var showError = false;
    BuildContext? openedDialogContext;
    Route<dynamic>? openedDialogRoute;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final dialogRoute = ModalRoute.of(dialogContext);
        openedDialogContext = dialogContext;
        openedDialogRoute = dialogRoute;
        _sensitivePlanningDialogContext = dialogContext;
        _sensitivePlanningDialogRoute = dialogRoute;
        return StatefulBuilder(
          builder:
              (context, setDialogState) => AlertDialog(
                title: Text(title),
                content: TextField(
                  controller: controller,
                  autofocus: true,
                  maxLength: maxLength,
                  decoration: InputDecoration(
                    labelText: label,
                    errorText: showError ? 'Dit veld is verplicht.' : null,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Annuleren'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final value = controller.text.trim();
                      if (value.isEmpty) {
                        setDialogState(() => showError = true);
                        return;
                      }
                      Navigator.pop(dialogContext, value);
                    },
                    child: Text(action),
                  ),
                ],
              ),
        );
      },
    );
    if (identical(_sensitivePlanningDialogContext, openedDialogContext) &&
        identical(_sensitivePlanningDialogRoute, openedDialogRoute)) {
      _sensitivePlanningDialogContext = null;
      _sensitivePlanningDialogRoute = null;
    }
    controller.dispose();
    return result;
  }

  Future<void> _createFeedingVersion() async {
    final plan = _selectedFeedingPlan;
    if (plan == null) return;
    final actorUserId = _client.auth.currentUser?.id ?? '';
    final stableId = _stableId;
    final generation = _sensitiveStateGeneration;
    final reason = await _showSensitiveTextDialog(
      title: 'Nieuwe planversie',
      label: 'Reden voor de wijziging',
      action: 'Versie starten',
    );
    if (reason == null ||
        !_planningScopeMatches(
          generation: generation,
          actorUserId: actorUserId,
          stableId: stableId,
        )) {
      return;
    }
    void scopePreflight() => _assertPlanningScopeCurrent(
      generation: generation,
      actorUserId: actorUserId,
      stableId: stableId,
    );
    final planId = _operationalString(plan['id']);
    await _guarded(() async {
      final created = _operationalMap(
        await _runDurableIdempotentRpc(
          operation: 'create_feeding_plan_version',
          intentKey: '$planId:$reason',
          initialReplayValues: {'plan_id': planId, 'reason': reason},
          scopePreflight: scopePreflight,
          buildParams:
              (requestId, replayValues) => {
                'p_feeding_plan_id': replayValues['plan_id'],
                'p_source_kind': 'user',
                'p_source_reference': null,
                'p_change_reason': replayValues['reason'],
                'p_request_id': requestId,
              },
        ),
      );
      scopePreflight();
      _selectedFeedingVersionId = _operationalString(
        created['feeding_plan_version_id'],
      );
      _notice = 'Nieuwe conceptversie veilig gestart.';
      await _load(quiet: true);
    });
  }

  Future<void> _upsertFeedingItem([Map<String, dynamic>? existing]) async {
    final plan = _selectedFeedingPlan;
    final version = _selectedFeedingVersion;
    if (plan == null || version == null) return;
    final temporary = _operationalString(plan['plan_type']) == 'temporary';
    final overrideKeys = _activeStandardOverrideKeys;
    if (temporary && overrideKeys.isEmpty) {
      setState(() {
        _error =
            'Activeer eerst een standaardplan met een voerslot voordat je '
            'een tijdelijke override toevoegt.';
      });
      return;
    }
    final actorUserId = _client.auth.currentUser?.id ?? '';
    final stableId = _stableId;
    final generation = _sensitiveStateGeneration;
    final input = await _showFeedingItemDialog(
      existing: existing,
      temporary: temporary,
      overrideKeys: overrideKeys,
    );
    if (input == null ||
        !_planningScopeMatches(
          generation: generation,
          actorUserId: actorUserId,
          stableId: stableId,
        )) {
      return;
    }
    void scopePreflight() => _assertPlanningScopeCurrent(
      generation: generation,
      actorUserId: actorUserId,
      stableId: stableId,
    );
    final versionId = _operationalString(version['id']);
    final itemId = _operationalString(existing?['id']);
    final rowVersion = _operationalString(existing?['row_version']);
    await _guarded(() async {
      await _runDurableIdempotentRpc(
        operation: 'upsert_feeding_plan_item_v2',
        intentKey:
            '$versionId:${itemId.isEmpty ? 'new' : itemId}:'
            '${input['override_key']}:${input['product_name']}:'
            '${input['planned_quantity']}:${input['local_time']}',
        initialReplayValues: {
          ...input,
          'version_id': versionId,
          'item_id': itemId,
          'row_version': rowVersion,
        },
        scopePreflight: scopePreflight,
        buildParams:
            (requestId, replayValues) => {
              'p_feeding_plan_version_id': replayValues['version_id'],
              'p_feeding_plan_item_id':
                  replayValues['item_id']!.isEmpty
                      ? null
                      : replayValues['item_id'],
              'p_expected_row_version':
                  replayValues['row_version']!.isEmpty
                      ? null
                      : int.parse(replayValues['row_version']!),
              'p_item_category': replayValues['item_category'],
              'p_product_brand':
                  replayValues['product_brand']!.isEmpty
                      ? null
                      : replayValues['product_brand'],
              'p_product_name': replayValues['product_name'],
              'p_product_variant': null,
              'p_source_status': 'user_entered',
              'p_planned_quantity': double.parse(
                replayValues['planned_quantity']!,
              ),
              'p_unit_code': replayValues['unit_code'],
              'p_offering_method': replayValues['offering_method'],
              'p_round_code': replayValues['round_code'],
              'p_local_time': replayValues['local_time'],
              'p_weekdays': null,
              'p_interval_days': null,
              'p_override_key': replayValues['override_key'],
              'p_default_stable_member_id':
                  replayValues['stable_member_id']!.isEmpty
                      ? null
                      : replayValues['stable_member_id'],
              'p_batch_lot': null,
              'p_expires_on': null,
              'p_instruction':
                  replayValues['instruction']!.isEmpty
                      ? null
                      : replayValues['instruction'],
              'p_request_id': requestId,
            },
      );
      scopePreflight();
      _notice =
          existing == null
              ? 'Voeritem veilig toegevoegd.'
              : 'Voeritem conflictveilig bijgewerkt.';
      await _load(quiet: true);
    });
  }

  Future<Map<String, String>?> _showFeedingItemDialog({
    required Map<String, dynamic>? existing,
    required bool temporary,
    required List<String> overrideKeys,
  }) async {
    final productName = TextEditingController(
      text: _operationalString(existing?['product_name']),
    );
    final productBrand = TextEditingController(
      text: _operationalString(existing?['product_brand']),
    );
    final quantity = TextEditingController(
      text: _operationalString(existing?['planned_quantity']),
    );
    final instruction = TextEditingController(
      text: _operationalString(existing?['instruction']),
    );
    var unitCode =
        _operationalString(existing?['unit_code']).isEmpty
            ? 'kg'
            : _operationalString(existing?['unit_code']);
    var itemCategory =
        _operationalString(existing?['item_category']).isEmpty
            ? 'feed'
            : _operationalString(existing?['item_category']);
    var offeringMethod =
        _operationalString(existing?['offering_method']).isEmpty
            ? 'bucket'
            : _operationalString(existing?['offering_method']);
    var roundCode =
        _operationalString(existing?['round_code']).isEmpty
            ? 'ochtend'
            : _operationalString(existing?['round_code']);
    final roundController = TextEditingController(text: roundCode);
    final parsedTime = _operationalString(existing?['local_time']).split(':');
    var selectedHour =
        parsedTime.isNotEmpty ? int.tryParse(parsedTime[0]) ?? 7 : 7;
    var selectedMinute =
        parsedTime.length > 1 ? int.tryParse(parsedTime[1]) ?? 0 : 0;
    var overrideKey = _operationalString(existing?['override_key']);
    if (temporary && !overrideKeys.contains(overrideKey)) {
      overrideKey = overrideKeys.first;
    }
    final overrideController = TextEditingController(
      text: temporary ? '' : overrideKey,
    );
    var stableMemberId = _operationalString(
      existing?['default_stable_member_id'],
    );
    var validationError = '';
    BuildContext? openedDialogContext;
    Route<dynamic>? openedDialogRoute;
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        final dialogRoute = ModalRoute.of(dialogContext);
        openedDialogContext = dialogContext;
        openedDialogRoute = dialogRoute;
        _sensitivePlanningDialogContext = dialogContext;
        _sensitivePlanningDialogRoute = dialogRoute;
        return StatefulBuilder(
          builder:
              (context, setDialogState) => AlertDialog(
                title: Text(
                  existing == null ? 'Voeritem toevoegen' : 'Voeritem wijzigen',
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: itemCategory,
                        decoration: const InputDecoration(labelText: 'Soort'),
                        items: const [
                              ('feed', 'Voer'),
                              ('supplement', 'Supplement'),
                              ('hay', 'Hooi'),
                              ('water', 'Water'),
                              ('medication', 'Medicatie'),
                            ]
                            .map(
                              (option) => DropdownMenuItem(
                                value: option.$1,
                                child: Text(option.$2),
                              ),
                            )
                            .toList(growable: false),
                        onChanged:
                            (value) => setDialogState(
                              () => itemCategory = value ?? itemCategory,
                            ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: productName,
                        autofocus: true,
                        maxLength: 200,
                        decoration: const InputDecoration(
                          labelText: 'Productnaam',
                        ),
                      ),
                      TextField(
                        controller: productBrand,
                        maxLength: 160,
                        decoration: const InputDecoration(
                          labelText: 'Merk (optioneel)',
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: quantity,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Hoeveelheid',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: unitCode,
                              decoration: const InputDecoration(
                                labelText: 'Eenheid',
                              ),
                              items: const [
                                    'g',
                                    'kg',
                                    'ml',
                                    'l',
                                    'scoop',
                                    'portion',
                                    'piece',
                                  ]
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(value),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged:
                                  (value) => setDialogState(
                                    () => unitCode = value ?? unitCode,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: const InputDecoration(labelText: 'Ronde'),
                        controller: roundController,
                        onChanged: (value) => roundCode = value.trim(),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: selectedHour,
                              decoration: const InputDecoration(
                                labelText: 'Uur',
                              ),
                              items: List.generate(
                                24,
                                (hour) => DropdownMenuItem(
                                  value: hour,
                                  child: Text(hour.toString().padLeft(2, '0')),
                                ),
                              ),
                              onChanged:
                                  (value) => setDialogState(
                                    () => selectedHour = value ?? selectedHour,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: selectedMinute,
                              decoration: const InputDecoration(
                                labelText: 'Minuut',
                              ),
                              items: const [0, 15, 30, 45]
                                  .map(
                                    (minute) => DropdownMenuItem(
                                      value: minute,
                                      child: Text(
                                        minute.toString().padLeft(2, '0'),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged:
                                  (value) => setDialogState(
                                    () =>
                                        selectedMinute =
                                            value ?? selectedMinute,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (temporary)
                        DropdownButtonFormField<String>(
                          value: overrideKey,
                          decoration: const InputDecoration(
                            labelText: 'Te vervangen standaardvoerslot',
                          ),
                          items: overrideKeys
                              .map(
                                (key) => DropdownMenuItem(
                                  value: key,
                                  child: Text(key),
                                ),
                              )
                              .toList(growable: false),
                          onChanged:
                              (value) => setDialogState(
                                () => overrideKey = value ?? overrideKey,
                              ),
                        )
                      else
                        TextField(
                          controller: overrideController,
                          maxLength: 160,
                          decoration: const InputDecoration(
                            labelText: 'Unieke voerslotsleutel',
                            helperText:
                                'Blijft gelijk over versies, bijvoorbeeld ochtend-brok.',
                          ),
                        ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: stableMemberId,
                        decoration: const InputDecoration(
                          labelText: 'Standaard verantwoordelijke',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('Niet toegewezen'),
                          ),
                          ..._planningRoster.map(
                            (member) => DropdownMenuItem(
                              value: _operationalString(member['id']),
                              child: Text(
                                _operationalString(member['display_name']),
                              ),
                            ),
                          ),
                        ],
                        onChanged:
                            (value) => setDialogState(
                              () => stableMemberId = value ?? '',
                            ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: offeringMethod,
                        decoration: const InputDecoration(
                          labelText: 'Aanbiedingswijze',
                        ),
                        items: const [
                              'bucket',
                              'manger',
                              'hay_net',
                              'pasture',
                              'hand',
                              'other',
                            ]
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(growable: false),
                        onChanged:
                            (value) => setDialogState(
                              () => offeringMethod = value ?? offeringMethod,
                            ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: instruction,
                        maxLength: 1000,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Instructie (optioneel)',
                        ),
                      ),
                      if (validationError.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          validationError,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Annuleren'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final normalizedName = productName.text.trim();
                      final parsedQuantity = double.tryParse(
                        quantity.text.trim().replaceAll(',', '.'),
                      );
                      final normalizedRound = roundCode.trim();
                      final normalizedOverride =
                          temporary
                              ? overrideKey
                              : overrideController.text.trim();
                      if (normalizedName.isEmpty ||
                          parsedQuantity == null ||
                          parsedQuantity <= 0 ||
                          normalizedRound.isEmpty ||
                          normalizedOverride.isEmpty) {
                        setDialogState(() {
                          validationError =
                              'Vul product, positieve hoeveelheid, ronde en voerslotsleutel in.';
                        });
                        return;
                      }
                      Navigator.pop(dialogContext, {
                        'item_category': itemCategory,
                        'product_name': normalizedName,
                        'product_brand': productBrand.text.trim(),
                        'planned_quantity': parsedQuantity.toString(),
                        'unit_code': unitCode,
                        'offering_method': offeringMethod,
                        'round_code': normalizedRound,
                        'local_time':
                            '${selectedHour.toString().padLeft(2, '0')}:'
                            '${selectedMinute.toString().padLeft(2, '0')}:00',
                        'override_key': normalizedOverride,
                        'stable_member_id': stableMemberId,
                        'instruction': instruction.text.trim(),
                      });
                    },
                    child: Text(existing == null ? 'Toevoegen' : 'Opslaan'),
                  ),
                ],
              ),
        );
      },
    );
    if (identical(_sensitivePlanningDialogContext, openedDialogContext) &&
        identical(_sensitivePlanningDialogRoute, openedDialogRoute)) {
      _sensitivePlanningDialogContext = null;
      _sensitivePlanningDialogRoute = null;
    }
    productName.dispose();
    productBrand.dispose();
    quantity.dispose();
    instruction.dispose();
    roundController.dispose();
    overrideController.dispose();
    return result;
  }

  Future<bool> _confirmSensitiveFeedingAction({
    required String title,
    required String body,
    required String action,
  }) async {
    BuildContext? openedDialogContext;
    Route<dynamic>? openedDialogRoute;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dialogRoute = ModalRoute.of(dialogContext);
        openedDialogContext = dialogContext;
        openedDialogRoute = dialogRoute;
        _sensitivePlanningDialogContext = dialogContext;
        _sensitivePlanningDialogRoute = dialogRoute;
        return AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuleren'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(action),
            ),
          ],
        );
      },
    );
    if (identical(_sensitivePlanningDialogContext, openedDialogContext) &&
        identical(_sensitivePlanningDialogRoute, openedDialogRoute)) {
      _sensitivePlanningDialogContext = null;
      _sensitivePlanningDialogRoute = null;
    }
    return result ?? false;
  }

  Future<void> _approveSelectedFeedingVersion() async {
    final version = _selectedFeedingVersion;
    if (version == null || _selectedFeedingItems.isEmpty) return;
    final actorUserId = _client.auth.currentUser?.id ?? '';
    final stableId = _stableId;
    final generation = _sensitiveStateGeneration;
    final confirmed = await _confirmSensitiveFeedingAction(
      title: 'Versie goedkeuren',
      body:
          'Na goedkeuring zijn de voeritems immutable. Maak voor latere '
          'wijzigingen een nieuwe versie.',
      action: 'Goedkeuren',
    );
    if (!confirmed ||
        !_planningScopeMatches(
          generation: generation,
          actorUserId: actorUserId,
          stableId: stableId,
        )) {
      return;
    }
    void scopePreflight() => _assertPlanningScopeCurrent(
      generation: generation,
      actorUserId: actorUserId,
      stableId: stableId,
    );
    final versionId = _operationalString(version['id']);
    final rowVersion = _operationalString(version['row_version']);
    await _guarded(() async {
      await _runDurableIdempotentRpc(
        operation: 'approve_feeding_plan_version',
        intentKey: '$versionId:$rowVersion',
        initialReplayValues: {
          'version_id': versionId,
          'row_version': rowVersion,
        },
        scopePreflight: scopePreflight,
        buildParams:
            (requestId, replayValues) => {
              'p_feeding_plan_version_id': replayValues['version_id'],
              'p_expected_row_version': int.parse(replayValues['row_version']!),
              'p_request_id': requestId,
            },
      );
      scopePreflight();
      _notice = 'Voerplanversie goedgekeurd en immutable gemaakt.';
      await _load(quiet: true);
    });
  }

  Future<void> _activateSelectedFeedingVersion() async {
    final plan = _selectedFeedingPlan;
    final version = _selectedFeedingVersion;
    if (plan == null || version == null) return;
    final actorUserId = _client.auth.currentUser?.id ?? '';
    final stableId = _stableId;
    final generation = _sensitiveStateGeneration;
    final confirmed = await _confirmSensitiveFeedingAction(
      title: 'Versie activeren',
      body:
          'Dit materialiseert de komende 30 lokale dagen en vervangt alleen '
          'de contractueel overeenkomende voerslots.',
      action: 'Activeren',
    );
    if (!confirmed ||
        !_planningScopeMatches(
          generation: generation,
          actorUserId: actorUserId,
          stableId: stableId,
        )) {
      return;
    }
    void scopePreflight() => _assertPlanningScopeCurrent(
      generation: generation,
      actorUserId: actorUserId,
      stableId: stableId,
    );
    final stableToday = _stableNow();
    DateTime through = stableToday.add(const Duration(days: 29));
    final planEnd = _operationalDate(plan['effective_until']);
    if (planEnd != null && planEnd.isBefore(through)) through = planEnd;
    final versionId = _operationalString(version['id']);
    final rowVersion = _operationalString(version['row_version']);
    final throughLocalDate = _operationalDateKey(through);
    await _guarded(() async {
      await _runDurableIdempotentRpc(
        operation: 'activate_feeding_plan_version',
        intentKey: '$versionId:$rowVersion:$throughLocalDate',
        initialReplayValues: {
          'version_id': versionId,
          'row_version': rowVersion,
          'through_local_date': throughLocalDate,
        },
        scopePreflight: scopePreflight,
        buildParams:
            (requestId, replayValues) => {
              'p_feeding_plan_version_id': replayValues['version_id'],
              'p_expected_row_version': int.parse(replayValues['row_version']!),
              'p_through_local_date': replayValues['through_local_date'],
              'p_request_id': requestId,
            },
      );
      scopePreflight();
      _notice = 'Voerplan veilig geactiveerd en in Planning gezet.';
      await _load(quiet: true);
    });
  }

  Future<void> _retireSelectedFeedingPlan() async {
    final plan = _selectedFeedingPlan;
    if (plan == null) return;
    final actorUserId = _client.auth.currentUser?.id ?? '';
    final stableId = _stableId;
    final generation = _sensitiveStateGeneration;
    final reason = await _showSensitiveTextDialog(
      title: 'Voerplan stoppen',
      label: 'Reden',
      action: 'Plan stoppen',
    );
    if (reason == null ||
        !_planningScopeMatches(
          generation: generation,
          actorUserId: actorUserId,
          stableId: stableId,
        )) {
      return;
    }
    void scopePreflight() => _assertPlanningScopeCurrent(
      generation: generation,
      actorUserId: actorUserId,
      stableId: stableId,
    );
    final planId = _operationalString(plan['id']);
    final rowVersion = _operationalString(plan['row_version']);
    await _guarded(() async {
      await _runDurableIdempotentRpc(
        operation: 'retire_feeding_plan',
        intentKey: '$planId:$rowVersion:$reason',
        initialReplayValues: {
          'plan_id': planId,
          'row_version': rowVersion,
          'reason': reason,
        },
        scopePreflight: scopePreflight,
        buildParams:
            (requestId, replayValues) => {
              'p_feeding_plan_id': replayValues['plan_id'],
              'p_expected_row_version': int.parse(replayValues['row_version']!),
              'p_reason': replayValues['reason'],
              'p_request_id': requestId,
            },
      );
      scopePreflight();
      _selectedFeedingPlanId = '';
      _selectedFeedingVersionId = '';
      _notice = 'Voerplan gestopt; uitvoeringshistorie blijft bewaard.';
      await _load(quiet: true);
    });
  }

  Future<bool> _showFormDialog({
    required String title,
    required TextEditingController controller,
    required String label,
    required String action,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 160,
              decoration: InputDecoration(labelText: label),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Annuleren'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(action),
              ),
            ],
          ),
    );
    return result ?? false;
  }

  Future<void> _guarded(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = '';
      _notice = '';
    });
    try {
      await action();
    } catch (error) {
      if (_requiresSecurityReset(error)) {
        await _purgeOperationalState(clearSelectedStable: true);
        _permissionDenied = true;
        _error =
            _secureCleanupPending
                ? 'Je toegang is gewijzigd. De data is uit het geheugen '
                    'gewist; beveiligde opslagopruiming loopt door.'
                : 'Je toegang is gewijzigd. Lokale werkdata is direct gewist.';
      } else {
        _error = _friendlyError(error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _purgeOperationalState({
    required bool clearSelectedStable,
  }) async {
    final purgeAccountId =
        _boundUserId.isNotEmpty
            ? _boundUserId
            : (_client.auth.currentUser?.id ?? '');
    _dismissSensitiveDialogs();
    final channels = List<RealtimeChannel>.from(_channels);
    _channels.clear();
    _wakeDebounce?.cancel();
    _clearDecryptedState();
    if (clearSelectedStable) {
      _requestLedger.reset();
    } else {
      _requestLedger.clear();
    }
    _authorityVersion = 0;
    _cursor = 0;
    _offlineReady = false;
    _offline = false;
    if (clearSelectedStable) {
      FFAppState().selectedCloudStableId = '';
      _stableId = '';
      _stableName = '';
      _stableTimezone = '';
    }

    final failedChannels = <RealtimeChannel, SupabaseClient>{};
    for (final channel in channels) {
      try {
        await _client.removeChannel(channel);
      } catch (_) {
        failedChannels[channel] = _client;
      }
    }
    final storageCleanupComplete =
        await _deleteOperationalSecureStateForAccount(purgeAccountId);
    if (storageCleanupComplete && purgeAccountId.isNotEmpty) {
      _operationalPendingPurgeAccounts.remove(purgeAccountId);
    }
    _secureCleanupPending =
        failedChannels.isNotEmpty || !storageCleanupComplete;
    if (_secureCleanupPending) {
      _scheduleOperationalSecurityCleanup(
        authUserId: storageCleanupComplete ? '' : purgeAccountId,
        channels: failedChannels,
      );
    }
    return !_secureCleanupPending;
  }

  void _dismissSensitiveDialogs() {
    _sensitiveStateGeneration += 1;
    final conflictContext = _sensitiveConflictDialogContext;
    final conflictRoute = _sensitiveConflictDialogRoute;
    final planningContext = _sensitivePlanningDialogContext;
    final planningRoute = _sensitivePlanningDialogRoute;
    _sensitiveConflictDialogContext = null;
    _sensitiveConflictDialogRoute = null;
    _sensitivePlanningDialogContext = null;
    _sensitivePlanningDialogRoute = null;
    if (conflictContext != null &&
        conflictContext.mounted &&
        conflictRoute != null &&
        conflictRoute.isActive) {
      Navigator.of(conflictContext).removeRoute(conflictRoute);
    }
    if (planningContext != null &&
        planningContext.mounted &&
        planningRoute != null &&
        planningRoute.isActive) {
      Navigator.of(planningContext).removeRoute(planningRoute);
    }
  }

  void _clearDecryptedState() {
    _horses = const [];
    _schedule = const [];
    _feedingPlans = const [];
    _feedingPlanVersions = const [];
    _feedingPlanItems = const [];
    _feedingHistory = const [];
    _conflicts = const [];
    _offlineSchedule = const [];
    _horseAccessGrants = const [];
    _horseRelationships = const [];
    _horseMedia = const [];
    _horseProfilePhotoUrls = const {};
    _horseIdentifiers = const {};
    _stableRoster = const [];
    _planningRoster = const [];
    _actorMembership = const {};
    _horseCapabilities = const {};
    _stableName = '';
    _selectedHorseId = '';
    _selectedFeedingPlanId = '';
    _selectedFeedingVersionId = '';
    _scheduleDate = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final materialTheme = Theme.of(context);
    final avarynMaterialTheme = materialTheme.copyWith(
      colorScheme: materialTheme.colorScheme.copyWith(
        primary: theme.secondary,
        secondary: theme.secondary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: theme.secondary,
          foregroundColor: theme.primaryText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected)
                    ? theme.secondary
                    : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected)
                    ? theme.primaryText
                    : theme.secondaryText,
          ),
          iconColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected)
                    ? theme.primaryText
                    : theme.secondaryText,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: theme.alternate)),
        ),
      ),
    );
    return Theme(
      data: avarynMaterialTheme,
      child: ColoredBox(
        color: theme.primaryBackground,
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 36),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _header(theme),
                        const SizedBox(height: 18),
                        if (_loading) _loadingCard(theme),
                        if (!_loading && _error.isNotEmpty)
                          _messageCard(
                            theme,
                            _error,
                            error: !_offline,
                            icon:
                                _permissionDenied
                                    ? Icons.lock_outline
                                    : _offline
                                    ? Icons.cloud_off_outlined
                                    : Icons.error_outline,
                          ),
                        if (!_loading && _notice.isNotEmpty)
                          _messageCard(
                            theme,
                            _notice,
                            icon: Icons.verified_outlined,
                          ),
                        if (!_loading && _stableId.isEmpty)
                          _emptyCard(
                            theme,
                            icon: Icons.home_work_outlined,
                            title: 'Geen actieve stal',
                            body:
                                'Open Stallen om een beveiligde werkcontext te kiezen.',
                            actionLabel: 'Stallen openen',
                            onPressed:
                                () => context.pushNamed('StablePickerPage'),
                          ),
                        if (!_loading && _stableId.isNotEmpty) ...[
                          if (_offline || _conflicts.isNotEmpty) ...[
                            _statusStrip(theme),
                            const SizedBox(height: 18),
                          ],
                          _modeContent(theme),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(FlutterFlowTheme theme) {
    final eyebrow = switch (widget.mode) {
      'horses' => 'PAARDEN',
      'planning' => 'AGENDA & PLANNING',
      'feeding' => 'VOEDING',
      'feedingExecution' => 'VOERRONDE',
      _ => 'CENTRAAL VANDAAG',
    };
    final title = switch (widget.mode) {
      'horses' => 'De paarden in je stal',
      'planning' => 'Alles op het juiste moment',
      'feeding' => 'Voeding per paard',
      'feedingExecution' => 'Voerronde uitvoeren',
      _ => 'Vandaag geregeld',
    };
    final subtitle = switch (widget.mode) {
      'horses' => 'Dagvorm, aandacht en het volgende moment bij elkaar.',
      'planning' => 'Plan, wijs toe en volg de voortgang van het hele team.',
      'feeding' => 'Vaste rondes, tijdelijke afwijkingen en aftekenhistorie.',
      'feedingExecution' =>
        'Leg vast wat werkelijk is gegeven en wat je hebt waargenomen.',
      _ => 'Goedemorgen. Dit staat er vandaag voor jou en de paarden klaar.',
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: theme.labelMedium.copyWith(
                  color: theme.secondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                title,
                style: theme.headlineMedium.copyWith(
                  color: theme.primaryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: theme.bodyMedium.copyWith(color: theme.secondaryText),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Vernieuwen',
          onPressed: _busy ? null : _load,
          icon:
              _busy
                  ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.refresh),
        ),
      ],
    );
  }

  Widget _statusStrip(FlutterFlowTheme theme) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      color:
          _offline
              ? theme.warning.withValues(alpha: 0.12)
              : theme.success.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color:
            _offline
                ? theme.warning.withValues(alpha: 0.45)
                : theme.success.withValues(alpha: 0.35),
      ),
    ),
    child: Row(
      children: [
        Icon(
          _offline ? Icons.cloud_off_outlined : Icons.shield_outlined,
          color: _offline ? theme.warning : theme.success,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _offline
                ? 'Je werkt offline. Wijzigingen worden veilig bewaard tot de verbinding terug is.'
                : 'Er ${_conflicts.length == 1 ? 'staat een wijziging' : 'staan wijzigingen'} klaar om te beoordelen.',
            style: theme.bodySmall.copyWith(color: theme.primaryText),
          ),
        ),
        if (_conflicts.isNotEmpty)
          TextButton.icon(
            onPressed:
                _offline || _busy
                    ? null
                    : () => _resolveSyncConflict(_conflicts.first),
            icon: Icon(Icons.sync_problem_outlined, color: theme.error),
            label: Text(
              '${_conflicts.length} '
              'conflict${_conflicts.length == 1 ? '' : 'en'}',
              style: theme.labelMedium.copyWith(color: theme.error),
            ),
          ),
      ],
    ),
  );

  Widget _modeContent(FlutterFlowTheme theme) {
    return switch (widget.mode) {
      'horses' => _horsesContent(theme),
      'planning' => _scheduleContent(theme, planning: true),
      'feeding' => _feedingContent(theme),
      'feedingExecution' => _scheduleContent(theme, feedingOnly: true),
      _ => _todayContent(theme),
    };
  }

  Widget _todayContent(FlutterFlowTheme theme) {
    final rows = _filteredScheduleRows();
    final completed =
        rows
            .where(
              (item) => const {
                'completed',
                'skipped',
              }.contains(_operationalString(item['state'])),
            )
            .length;
    final feedingRows = rows
        .where((item) => _operationalString(item['item_kind']) == 'feeding')
        .toList(growable: false);
    final nextRows = rows
        .where(
          (item) =>
              !const {
                'completed',
                'skipped',
                'cancelled',
              }.contains(_operationalString(item['state'])),
        )
        .toList(growable: false);
    final progress = rows.isEmpty ? 0.0 : completed / rows.length;
    final heroHorse = _horses.isEmpty ? null : _horses.first;
    final passportWarnings = <Map<String, dynamic>>[];
    final today = DateTime(
      _stableNow().year,
      _stableNow().month,
      _stableNow().day,
    );
    final warningThrough = DateTime(today.year, today.month + 3, today.day);
    for (final horse in _horses) {
      final horseId = _operationalString(horse['id']);
      final passport = _horseIdentifiers[horseId]?['passport'];
      final expiresOn = DateTime.tryParse(
        _operationalString(passport?['valid_until']),
      );
      if (expiresOn == null || expiresOn.isAfter(warningThrough)) continue;
      passportWarnings.add({'horse': horse, 'expires_on': expiresOn});
    }
    passportWarnings.sort(
      (left, right) => (left['expires_on'] as DateTime).compareTo(
        right['expires_on'] as DateTime,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (passportWarnings.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.secondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.secondary.withValues(alpha: 0.40),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.badge_outlined, color: theme.secondary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Paspoort vernieuwen',
                        style: theme.titleMedium.copyWith(
                          color: theme.primaryText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        passportWarnings.length == 1
                            ? '${_operationalString((passportWarnings.first['horse'] as Map)['display_name'])}: geldig tot ${_operationalDisplayDate(passportWarnings.first['expires_on'])}.'
                            : '${passportWarnings.length} paarden hebben binnen drie maanden een nieuw paspoort nodig.',
                        style: theme.bodyMedium.copyWith(
                          color: theme.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.pushNamed('HorsesOverviewPage'),
                  child: const Text('Bekijken'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final photo = ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: const AvarynOrionPhoto(width: 420, height: 250),
            );
            final summary = Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: theme.secondaryBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.alternate),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _operationalString(heroHorse?['display_name']).isEmpty
                        ? 'De stal staat klaar'
                        : _operationalString(heroHorse?['display_name']),
                    style: theme.headlineSmall.copyWith(
                      color: theme.primaryText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    nextRows.isEmpty
                        ? 'Alle geplande momenten zijn afgerond.'
                        : '${nextRows.length} moment${nextRows.length == 1 ? '' : 'en'} vragen nog aandacht.',
                    style: theme.bodyMedium.copyWith(
                      color: theme.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: theme.alternate,
                            color: theme.secondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$completed/${rows.length}',
                        style: theme.labelLarge.copyWith(
                          color: theme.primaryText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _busy || nextRows.isEmpty ? null : _startMyDay,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start mijn dag'),
                  ),
                ],
              ),
            );
            if (constraints.maxWidth < 720) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [photo, const SizedBox(height: 12), summary],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: photo),
                const SizedBox(width: 16),
                Expanded(flex: 4, child: summary),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        Text(
          'Snel vastleggen',
          style: theme.titleLarge.copyWith(
            color: theme.primaryText,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _quickAction(
              theme,
              icon: Icons.calendar_month_outlined,
              label: 'Planning',
              onTap: () => context.pushNamed('PlanningPage'),
            ),
            _quickAction(
              theme,
              icon: Icons.restaurant_menu_outlined,
              label: 'Voeding',
              onTap: () => context.pushNamed('FeedingOverviewPage'),
            ),
            _quickAction(
              theme,
              icon: Icons.pets_outlined,
              label: 'Paarden',
              onTap: () => context.pushNamed('HorsesOverviewPage'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Voeding vandaag',
          style: theme.titleLarge.copyWith(
            color: theme.primaryText,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        if (feedingRows.isEmpty)
          _emptyCard(
            theme,
            icon: Icons.restaurant_outlined,
            title: 'Geen voerrondes vandaag',
            body: 'Geactiveerde voermomenten verschijnen hier automatisch.',
          )
        else
          ...feedingRows
              .take(4)
              .map((item) => _scheduleVisualCard(theme, item, compact: true)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'Vandaag gepland',
                style: theme.titleLarge.copyWith(
                  color: theme.primaryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.pushNamed('PlanningPage'),
              child: const Text('Volledige agenda'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          _emptyCard(
            theme,
            icon: Icons.event_available_outlined,
            title: 'Een rustige dag',
            body: 'Nieuwe afspraken en taken verschijnen hier op tijd.',
          )
        else
          ...rows
              .take(8)
              .map((item) => _scheduleVisualCard(theme, item, compact: true)),
      ],
    );
  }

  Widget _quickAction(
    FlutterFlowTheme theme, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );

  void _openScheduleItem(Map<String, dynamic> item) {
    final terminal = const {
      'completed',
      'skipped',
      'cancelled',
      'pending_sync',
    }.contains(_operationalString(item['state']));
    if (_operationalString(item['item_kind']) == 'feeding' && !terminal) {
      _showFeedingOccurrenceDetails(item);
    } else if (_operationalString(item['execution_id']).isNotEmpty) {
      _showCompletedExecutionActions(item);
    } else {
      _showScheduleItemActions(item);
    }
  }

  String _horseAgeLabel(dynamic value) {
    final birthDate = DateTime.tryParse(_operationalString(value));
    if (birthDate == null) return '';
    final now = _stableNow();
    var years = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      years--;
    }
    return years < 0 ? '' : '$years jaar';
  }

  String _horseSexLabel(dynamic value) => switch (_operationalString(value)) {
    'mare' => 'Merrie',
    'gelding' => 'Ruin',
    'stallion' => 'Hengst',
    _ => '',
  };

  Future<void> _showHorseSelector() async {
    final search = TextEditingController();
    var query = '';
    final horseId = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) {
              final normalizedQuery = query.trim().toLowerCase();
              final matches = _horses
                  .where((horse) {
                    if (normalizedQuery.isEmpty) return true;
                    final displayName =
                        _operationalString(horse['display_name']).toLowerCase();
                    final officialName =
                        _operationalString(
                          horse['official_name'],
                        ).toLowerCase();
                    return displayName.contains(normalizedQuery) ||
                        officialName.contains(normalizedQuery);
                  })
                  .toList(growable: false);
              return AlertDialog(
                title: const Text('Paard kiezen'),
                content: SizedBox(
                  width: 520,
                  height: 430,
                  child: Column(
                    children: [
                      TextField(
                        controller: search,
                        autofocus: true,
                        onChanged:
                            (value) => setDialogState(() => query = value),
                        decoration: const InputDecoration(
                          labelText: 'Zoek op roepnaam of officiële naam',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child:
                            matches.isEmpty
                                ? const Center(
                                  child: Text('Geen paarden gevonden.'),
                                )
                                : ListView.separated(
                                  itemCount: matches.length,
                                  separatorBuilder:
                                      (context, index) =>
                                          const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final horse = matches[index];
                                    final officialName = _operationalString(
                                      horse['official_name'],
                                    );
                                    return ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 4,
                                          ),
                                      leading: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: _horsePhoto(
                                          horse,
                                          width: 48,
                                          height: 48,
                                        ),
                                      ),
                                      title: Text(
                                        _operationalString(
                                          horse['display_name'],
                                        ),
                                      ),
                                      subtitle:
                                          officialName.isEmpty
                                              ? null
                                              : Text(officialName),
                                      trailing:
                                          _selectedHorseId ==
                                                  _operationalString(
                                                    horse['id'],
                                                  )
                                              ? const Icon(Icons.check)
                                              : null,
                                      onTap:
                                          () => Navigator.pop(
                                            dialogContext,
                                            _operationalString(horse['id']),
                                          ),
                                    );
                                  },
                                ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Sluiten'),
                  ),
                ],
              );
            },
          ),
    );
    search.dispose();
    if (!mounted || horseId == null || horseId == _selectedHorseId) return;
    setState(() {
      _selectedHorseId = horseId;
      _horseProfileTab = 'overview';
    });
    await _load(quiet: true);
  }

  Widget _horsesContent(FlutterFlowTheme theme) {
    if (_horses.isEmpty) {
      return _emptyCard(
        theme,
        icon: Icons.pets_outlined,
        title: 'Nog geen toegankelijke paarden',
        body:
            'Een beheerder kan een paard toevoegen of je expliciete toegang geven.',
        actionLabel: _offline || !_isStableManager ? null : 'Paard toevoegen',
        onPressed: _offline || !_isStableManager ? null : _createHorse,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Jouw paarden',
                style: theme.titleLarge.copyWith(
                  color: theme.primaryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_isStableManager)
              FilledButton.icon(
                onPressed: _offline || _busy ? null : _createHorse,
                icon: const Icon(Icons.add),
                label: const Text('Paard toevoegen'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Material(
          color: theme.secondaryBackground,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _busy ? null : _showHorseSelector,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.alternate),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _horsePhoto(_selectedHorse!, width: 58, height: 58),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _operationalString(_selectedHorse!['display_name']),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.titleMedium.copyWith(
                            color: theme.primaryText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (_operationalString(
                          _selectedHorse!['official_name'],
                        ).isNotEmpty)
                          Text(
                            _operationalString(
                              _selectedHorse!['official_name'],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.bodySmall.copyWith(
                              color: theme.secondaryText,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down),
                ],
              ),
            ),
          ),
        ),
        if (_selectedHorse != null) ...[
          const SizedBox(height: 18),
          _selectedHorseManagement(theme),
        ],
      ],
    );
  }

  Widget _selectedHorseManagement(FlutterFlowTheme theme) {
    final horse = _selectedHorse!;
    final horseRows = _schedule
        .where(
          (item) => _operationalString(item['horse_id']) == _selectedHorseId,
        )
        .toList(growable: false);
    final attention = horseRows
        .where(
          (item) =>
              !const {
                'completed',
                'skipped',
                'cancelled',
              }.contains(_operationalString(item['state'])),
        )
        .toList(growable: false);
    final officialName = _operationalString(horse['official_name']);
    final profileChips = [
      _operationalString(horse['discipline']),
      _operationalString(horse['level']),
      _horseAgeLabel(horse['birth_date']),
      _horseSexLabel(horse['sex']),
      _operationalString(horse['best_performance']),
    ].where((value) => value.isNotEmpty).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final heroHeight = constraints.maxWidth < 720 ? 470.0 : 410.0;
            return ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: SizedBox(
                height: heroHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _horsePhoto(
                      horse,
                      width: constraints.maxWidth,
                      height: heroHeight,
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x1A000000),
                            Color(0x59000000),
                            Color(0xE6000000),
                          ],
                          stops: [0.0, 0.50, 1.0],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'PAARDPROFIEL',
                            style: theme.labelMedium.copyWith(
                              color: const Color(0xFFF0B9AF),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _operationalString(horse['display_name']),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.headlineMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (officialName.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              officialName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.bodyLarge.copyWith(
                                color: Colors.white.withValues(alpha: 0.86),
                              ),
                            ),
                          ],
                          if (profileChips.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children: profileChips
                                  .map(
                                    (value) => Chip(
                                      label: Text(value),
                                      visualDensity: VisualDensity.compact,
                                      side: BorderSide(
                                        color: Colors.white.withValues(
                                          alpha: 0.34,
                                        ),
                                      ),
                                      backgroundColor: Colors.black.withValues(
                                        alpha: 0.28,
                                      ),
                                      labelStyle: theme.labelMedium.copyWith(
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Text(
                            attention.isEmpty
                                ? 'Vandaag vraagt niets extra aandacht.'
                                : '${attention.length} gepland moment${attention.length == 1 ? '' : 'en'} vragen vandaag aandacht.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.bodyMedium.copyWith(
                              color: Colors.white.withValues(alpha: 0.86),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              FilledButton.icon(
                                onPressed:
                                    _offline || _busy
                                        ? null
                                        : _createScheduleItem,
                                icon: const Icon(Icons.add),
                                label: const Text('Activiteit toevoegen'),
                              ),
                              OutlinedButton.icon(
                                onPressed:
                                    _offline || _busy || !_canEditSelectedHorse
                                        ? null
                                        : _editSelectedHorse,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Bewerken'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'overview',
              label: Text('Overzicht'),
              icon: Icon(Icons.dashboard_outlined),
            ),
            ButtonSegment(
              value: 'planning',
              label: Text('Planning'),
              icon: Icon(Icons.calendar_month_outlined),
            ),
            ButtonSegment(
              value: 'feeding',
              label: Text('Voeding'),
              icon: Icon(Icons.restaurant_menu_outlined),
            ),
          ],
          selected: {_horseProfileTab},
          onSelectionChanged:
              (values) => setState(() => _horseProfileTab = values.single),
        ),
        const SizedBox(height: 16),
        if (_horseProfileTab == 'overview')
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.secondaryBackground,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: theme.alternate),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dagvorm & aandacht',
                  style: theme.titleMedium.copyWith(
                    color: theme.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  attention.isEmpty
                      ? 'Geen open aandachtspunten voor vandaag.'
                      : _scheduleInstruction(attention.first).isEmpty
                      ? _operationalString(attention.first['title'])
                      : _scheduleInstruction(attention.first),
                  style: theme.bodyMedium.copyWith(color: theme.secondaryText),
                ),
                if (horseRows.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _scheduleVisualCard(theme, horseRows.first, compact: true),
                ],
              ],
            ),
          ),
        if (_horseProfileTab == 'planning')
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Planning van ${_operationalString(horse['display_name'])}',
                      style: theme.titleLarge.copyWith(
                        color: theme.primaryText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.pushNamed('PlanningPage'),
                    child: const Text('Volledige planning'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (horseRows.isEmpty)
                _emptyCard(
                  theme,
                  icon: Icons.event_available_outlined,
                  title: 'Geen activiteiten vandaag',
                  body: 'Plan een activiteit via de volledige planning.',
                )
              else
                ...horseRows.map(
                  (item) => _scheduleVisualCard(theme, item, compact: true),
                ),
            ],
          ),
        if (_horseProfileTab == 'feeding')
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Voeding van ${_operationalString(horse['display_name'])}',
                      style: theme.titleLarge.copyWith(
                        color: theme.primaryText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.pushNamed('FeedingOverviewPage'),
                    child: const Text('Volledig voerschema'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (horseRows
                  .where((item) => item['item_kind'] == 'feeding')
                  .isEmpty)
                _emptyCard(
                  theme,
                  icon: Icons.restaurant_outlined,
                  title: 'Geen voermoment vandaag',
                  body: 'Actieve voerrondes verschijnen hier automatisch.',
                )
              else
                ...horseRows
                    .where((item) => item['item_kind'] == 'feeding')
                    .map(
                      (item) => _scheduleVisualCard(theme, item, compact: true),
                    ),
            ],
          ),
        const SizedBox(height: 16),
        _selectedHorseManagementTools(theme),
      ],
    );
  }

  Widget _selectedHorseManagementTools(FlutterFlowTheme theme) {
    final horse = _selectedHorse!;
    final metadata = [
      _operationalString(horse['official_name']),
      _operationalDisplayDate(horse['birth_date']),
      _operationalString(horse['sex']),
      _operationalString(horse['breed']),
      _operationalString(horse['discipline']),
      _operationalString(horse['level']),
    ].where((value) => value.isNotEmpty).join(' · ');
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _operationalString(horse['display_name']),
            style: theme.titleLarge.copyWith(
              color: theme.primaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            metadata.isEmpty ? 'Geen aanvullende kerngegevens.' : metadata,
            style: theme.bodyMedium.copyWith(color: theme.secondaryText),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (_canEditSelectedHorse)
                OutlinedButton.icon(
                  onPressed: _offline || _busy ? null : _editSelectedHorse,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Kerngegevens'),
                ),
              if (_canArchiveSelectedHorse)
                OutlinedButton.icon(
                  onPressed: _offline || _busy ? null : _archiveSelectedHorse,
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('Archiveren'),
                ),
              if (_canManageHorseAccess)
                FilledButton.tonalIcon(
                  onPressed:
                      _offline || _busy ? null : _grantSelectedHorseAccess,
                  icon: const Icon(Icons.key_outlined),
                  label: const Text('Toegang geven'),
                ),
              if (_canManageHorseRelationships)
                FilledButton.tonalIcon(
                  onPressed: _offline || _busy ? null : _addHorseRelationship,
                  icon: const Icon(Icons.people_outline),
                  label: const Text('Relatie toevoegen'),
                ),
            ],
          ),
          if (_canManageHorseAccess) ...[
            const SizedBox(height: 20),
            Text(
              'Expliciete toegang',
              style: theme.titleMedium.copyWith(
                color: theme.primaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (_horseAccessGrants.isEmpty)
              Text(
                'Geen actieve expliciete grants. Stalrollen blijven afzonderlijk van paardtoegang.',
                style: theme.bodySmall.copyWith(color: theme.secondaryText),
              )
            else
              ..._horseAccessGrants.map(
                (grant) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.shield_outlined),
                  title: Text(
                    _rosterNameFor(
                      membershipId: _operationalString(grant['membership_id']),
                    ),
                  ),
                  subtitle: Text(
                    [
                      _operationalString(grant['category']),
                      if (grant['can_execute'] == true) 'uitvoeren',
                      if (grant['can_edit'] == true) 'bewerken',
                    ].join(' · '),
                  ),
                  trailing: IconButton(
                    tooltip: 'Toegang intrekken',
                    onPressed:
                        _offline || _busy
                            ? null
                            : () => _revokeHorseAccess(grant),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                ),
              ),
          ],
          if (_canManageHorseRelationships) ...[
            const SizedBox(height: 20),
            Text(
              'Ruiter, eigenaar en team',
              style: theme.titleMedium.copyWith(
                color: theme.primaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Deze relaties beschrijven samenwerking en geven op zichzelf geen toegang.',
              style: theme.bodySmall.copyWith(color: theme.secondaryText),
            ),
            if (_horseRelationships.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Nog geen actieve relaties.',
                  style: theme.bodySmall.copyWith(color: theme.secondaryText),
                ),
              )
            else
              ..._horseRelationships.map(
                (relationship) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.badge_outlined),
                  title: Text(
                    _rosterNameFor(
                      stableMemberId: _operationalString(
                        relationship['stable_member_id'],
                      ),
                    ),
                  ),
                  subtitle: Text(
                    [
                      _horseRelationshipLabel(
                        relationship['relationship_type'],
                      ),
                      _operationalString(relationship['label']),
                    ].where((value) => value.isNotEmpty).join(' · '),
                  ),
                  trailing: IconButton(
                    tooltip: 'Relatie beëindigen',
                    onPressed:
                        _offline || _busy
                            ? null
                            : () => _endHorseRelationship(relationship),
                    icon: const Icon(Icons.link_off_outlined),
                  ),
                ),
              ),
          ],
          if (_canViewSelectedHorseMedia) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Private operationele media',
                    style: theme.titleMedium.copyWith(
                      color: theme.primaryText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_canEditSelectedHorseMedia)
                  FilledButton.tonalIcon(
                    onPressed:
                        _offline || _busy
                            ? null
                            : () =>
                                _pickAndUploadMedia(horseId: _selectedHorseId),
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Uploaden'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Bestanden blijven privé. Downloadlinks zijn kort geldig en '
              'toegang wordt bij iedere aanvraag opnieuw gecontroleerd.',
              style: theme.bodySmall.copyWith(color: theme.secondaryText),
            ),
            if (_horseMedia.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Nog geen toegankelijke media.',
                  style: theme.bodySmall.copyWith(color: theme.secondaryText),
                ),
              )
            else
              ..._horseMedia.map(
                (asset) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _operationalString(asset['mime_type']) == 'application/pdf'
                        ? Icons.picture_as_pdf_outlined
                        : Icons.image_outlined,
                  ),
                  title: Text(
                    _operationalString(asset['original_filename']),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${_operationalString(asset['mime_type'])} · '
                    '${((int.tryParse(_operationalString(asset['byte_size'])) ?? 0) / 1024).ceil()} KB',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Veilig openen',
                        onPressed:
                            _offline || _busy
                                ? null
                                : () => _openMediaAsset(asset),
                        icon: const Icon(Icons.open_in_new_outlined),
                      ),
                      if (_canEditSelectedHorseMedia)
                        IconButton(
                          tooltip: 'Media archiveren',
                          onPressed:
                              _offline || _busy
                                  ? null
                                  : () => _archiveMediaAsset(asset),
                          icon: const Icon(Icons.archive_outlined),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<Map<String, String>?> _showScheduleEditDialog(
    Map<String, dynamic> item,
  ) async {
    final title = TextEditingController(
      text: _operationalString(item['title']),
    );
    final instruction = TextEditingController(text: _scheduleInstruction(item));
    final location = TextEditingController(text: _scheduleLocation(item));
    final parsed = _operationalString(item['source_local_time']).split(':');
    var hour = parsed.isEmpty ? 9 : int.tryParse(parsed.first) ?? 9;
    var minute = parsed.length < 2 ? 0 : int.tryParse(parsed[1]) ?? 0;
    var priority =
        _operationalString(item['priority']).isEmpty
            ? 'normal'
            : _operationalString(item['priority']);
    BuildContext? openedDialogContext;
    Route<dynamic>? openedDialogRoute;
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        final dialogRoute = ModalRoute.of(dialogContext);
        openedDialogContext = dialogContext;
        openedDialogRoute = dialogRoute;
        _sensitivePlanningDialogContext = dialogContext;
        _sensitivePlanningDialogRoute = dialogRoute;
        return StatefulBuilder(
          builder:
              (context, setDialogState) => AlertDialog(
                title: const Text('Planning wijzigen'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: title,
                        maxLength: 160,
                        decoration: const InputDecoration(labelText: 'Titel'),
                      ),
                      TextField(
                        controller: location,
                        maxLength: 200,
                        decoration: const InputDecoration(
                          labelText: 'Locatie (optioneel)',
                        ),
                      ),
                      TextField(
                        controller: instruction,
                        maxLength: 1600,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Instructie',
                        ),
                      ),
                      DropdownButtonFormField<String>(
                        value: priority,
                        decoration: const InputDecoration(
                          labelText: 'Prioriteit',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'normal',
                            child: Text('Normaal'),
                          ),
                          DropdownMenuItem(value: 'high', child: Text('Hoog')),
                        ],
                        onChanged:
                            (value) => setDialogState(
                              () => priority = value ?? priority,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: hour,
                              decoration: const InputDecoration(
                                labelText: 'Uur',
                              ),
                              items: List.generate(
                                24,
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value.toString().padLeft(2, '0')),
                                ),
                              ),
                              onChanged:
                                  (value) => setDialogState(
                                    () => hour = value ?? hour,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: minute,
                              decoration: const InputDecoration(
                                labelText: 'Minuut',
                              ),
                              items: const [0, 15, 30, 45]
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(
                                        value.toString().padLeft(2, '0'),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged:
                                  (value) => setDialogState(
                                    () => minute = value ?? minute,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Annuleren'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final normalizedTitle = title.text.trim();
                      if (normalizedTitle.isEmpty) return;
                      Navigator.pop(dialogContext, {
                        'title': normalizedTitle,
                        'instruction':
                            instruction.text.trim().isEmpty
                                ? 'Uitvoeren volgens de stalplanning.'
                                : instruction.text.trim(),
                        'location': location.text.trim(),
                        'priority': priority,
                        'hour': hour.toString(),
                        'minute': minute.toString(),
                      });
                    },
                    child: const Text('Opslaan'),
                  ),
                ],
              ),
        );
      },
    );
    if (identical(_sensitivePlanningDialogContext, openedDialogContext) &&
        identical(_sensitivePlanningDialogRoute, openedDialogRoute)) {
      _sensitivePlanningDialogContext = null;
      _sensitivePlanningDialogRoute = null;
    }
    title.dispose();
    instruction.dispose();
    location.dispose();
    return result;
  }

  String _storedScheduleInstruction(Map<String, String> input) => [
    if (input['location']!.isNotEmpty) 'Locatie: ${input['location']}',
    input['instruction']!,
  ].join('\n');

  Future<void> _editScheduleItem(
    Map<String, dynamic> item, {
    required String scope,
  }) async {
    final actorUserId = _client.auth.currentUser?.id ?? '';
    final stableId = _stableId;
    final generation = _sensitiveStateGeneration;
    final input = await _showScheduleEditDialog(item);
    if (input == null ||
        !_planningScopeMatches(
          generation: generation,
          actorUserId: actorUserId,
          stableId: stableId,
        )) {
      return;
    }
    void scopePreflight() => _assertPlanningScopeCurrent(
      generation: generation,
      actorUserId: actorUserId,
      stableId: stableId,
    );
    final sourceDate =
        DateTime.tryParse(_operationalString(item['source_local_date'])) ??
        (_scheduleDate ?? _stableNow());
    final hour = int.parse(input['hour']!);
    final minute = int.parse(input['minute']!);
    final localStart = timezone.TZDateTime(
      timezone.getLocation(_stableTimezone),
      sourceDate.year,
      sourceDate.month,
      sourceDate.day,
      hour,
      minute,
    );
    final instruction = _storedScheduleInstruction(input);
    final seriesId = _operationalString(item['series_id']);
    await _guarded(() async {
      if (seriesId.isEmpty) {
        await _runDurableIdempotentRpc(
          operation: 'update_schedule_item',
          intentKey:
              '${item['schedule_item_id']}:${item['row_version']}:'
              '${input['title']}:$instruction:${input['priority']}:'
              '${localStart.toUtc().toIso8601String()}',
          initialReplayValues: {
            'schedule_item_id': _operationalString(item['schedule_item_id']),
            'row_version': _operationalString(item['row_version']),
            'title': input['title']!,
            'instruction': instruction,
            'priority': input['priority']!,
            'scheduled_start_at': localStart.toUtc().toIso8601String(),
            'scheduled_end_at':
                localStart
                    .add(const Duration(minutes: 30))
                    .toUtc()
                    .toIso8601String(),
            'source_local_date': _operationalDateKey(localStart),
            'source_local_time':
                '${hour.toString().padLeft(2, '0')}:'
                '${minute.toString().padLeft(2, '0')}:00',
          },
          scopePreflight: scopePreflight,
          buildParams:
              (requestId, replayValues) => {
                'p_schedule_item_id': replayValues['schedule_item_id'],
                'p_expected_row_version': int.parse(
                  replayValues['row_version']!,
                ),
                'p_request_id': requestId,
                'p_title': replayValues['title'],
                'p_instruction': replayValues['instruction'],
                'p_priority': replayValues['priority'],
                'p_scheduled_start_at': replayValues['scheduled_start_at'],
                'p_scheduled_end_at': replayValues['scheduled_end_at'],
                'p_source_timezone': _stableTimezone,
                'p_source_local_date': replayValues['source_local_date'],
                'p_source_local_time': replayValues['source_local_time'],
              },
        );
      } else {
        final occurrenceScope = scope == 'occurrence';
        final through = sourceDate.add(const Duration(days: 45));
        await _runDurableIdempotentRpc(
          operation: 'update_schedule_series_scope_materialized',
          intentKey:
              '$seriesId:$scope:${item['row_version']}:'
              '${item['series_row_version']}:${input['title']}:$instruction:'
              '${input['hour']}:${input['minute']}',
          initialReplayValues: {
            'series_id': seriesId,
            'expected_row_version':
                occurrenceScope
                    ? _operationalString(item['row_version'])
                    : _operationalString(item['series_row_version']),
            'scope': scope,
            'schedule_item_id':
                occurrenceScope
                    ? _operationalString(item['schedule_item_id'])
                    : '',
            'effective_date': _operationalString(
              item['occurrence_local_date'] ?? item['source_local_date'],
            ),
            'title': input['title']!,
            'instruction': instruction,
            'local_start_time':
                '${hour.toString().padLeft(2, '0')}:'
                '${minute.toString().padLeft(2, '0')}:00',
            'materialize_request_id': _uuid.v4(),
            'through_date': _operationalDateKey(through),
          },
          scopePreflight: scopePreflight,
          buildParams:
              (requestId, replayValues) => {
                'p_series_id': replayValues['series_id'],
                'p_expected_row_version': int.parse(
                  replayValues['expected_row_version']!,
                ),
                'p_scope': replayValues['scope'],
                'p_occurrence_item_id':
                    replayValues['schedule_item_id']!.isEmpty
                        ? null
                        : replayValues['schedule_item_id'],
                'p_effective_local_date': replayValues['effective_date'],
                'p_request_id': requestId,
                'p_title': replayValues['title'],
                'p_instruction': replayValues['instruction'],
                'p_timezone': _stableTimezone,
                'p_frequency':
                    _operationalString(item['series_frequency']).isEmpty
                        ? 'daily'
                        : item['series_frequency'],
                'p_interval_value':
                    int.tryParse(
                      _operationalString(item['series_interval_value']),
                    ) ??
                    1,
                'p_weekdays': item['series_weekdays'],
                'p_local_start_time': replayValues['local_start_time'],
                'p_duration_minutes':
                    int.tryParse(
                      _operationalString(item['series_duration_minutes']),
                    ) ??
                    30,
                'p_ends_on':
                    _operationalString(item['series_ends_on']).isEmpty
                        ? null
                        : item['series_ends_on'],
                'p_generation_horizon_days': 45,
                'p_status':
                    _operationalString(item['series_status']).isEmpty
                        ? 'active'
                        : item['series_status'],
                'p_through_local_date': replayValues['through_date'],
                'p_materialize_request_id':
                    replayValues['materialize_request_id'],
              },
        );
      }
      _notice =
          scope == 'future'
              ? 'Deze en toekomstige afspraken zijn veilig bijgewerkt.'
              : 'De afspraak is conflictveilig bijgewerkt.';
      await _load(quiet: true);
    });
  }

  Future<void> _skipSchedule(Map<String, dynamic> item) async {
    final actorUserId = _client.auth.currentUser?.id ?? '';
    final stableId = _stableId;
    final generation = _sensitiveStateGeneration;
    final now = DateTime.now();
    await _guarded(() async {
      _assertPlanningScopeCurrent(
        generation: generation,
        actorUserId: actorUserId,
        stableId: stableId,
      );
      await _runIdempotentRpc(
        operation: 'record_schedule_execution',
        intentKey: '${item['schedule_item_id']}:skipped',
        buildParams:
            (requestId) => {
              'p_schedule_item_id': item['schedule_item_id'],
              'p_request_id': requestId,
              'p_execution_status': 'skipped',
              'p_actual_started_at': null,
              'p_actual_completed_at': now.toUtc().toIso8601String(),
              'p_recorded_local_at': _stableLocalTimestamp(now),
              'p_recorded_timezone': _stableTimezone,
              'p_source': 'online',
              'p_device_instance_id': null,
              'p_note': 'Gemist gemarkeerd via agenda.',
            },
      );
      _notice = 'Item als gemist geregistreerd; historie blijft bewaard.';
      await _load(quiet: true);
    });
  }

  List<Map<String, dynamic>> get _guidedOpenSchedule {
    final rows = _filteredScheduleRows()
        .where(
          (item) =>
              !const {
                'completed',
                'skipped',
                'cancelled',
                'pending_sync',
              }.contains(_operationalString(item['state'])),
        )
        .toList(growable: false);
    rows.sort(
      (left, right) => _operationalString(
        left['scheduled_start_at'],
      ).compareTo(_operationalString(right['scheduled_start_at'])),
    );
    return rows;
  }

  void _startMyDay() {
    final next = _guidedOpenSchedule;
    if (next.isEmpty) return;
    setState(() => _dayGuidanceActive = true);
    _openScheduleItem(next.first);
  }

  Future<void> _offerNextGuidedTask() async {
    if (!mounted || !_dayGuidanceActive) return;
    final next = _guidedOpenSchedule;
    if (next.isEmpty) {
      _dayGuidanceActive = false;
      await showDialog<void>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('Alles afgerond'),
              content: const Text(
                'Er zijn geen toegankelijke open taken meer voor deze dag.',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Klaar'),
                ),
              ],
            ),
      );
      return;
    }
    final openNext = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Volgende taak'),
            content: Text(
              '${_stableClock(next.first['scheduled_start_at'])} · '
              '${_operationalString(next.first['title'])}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Stoppen'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Volgende taak openen'),
              ),
            ],
          ),
    );
    if (openNext == true && mounted) {
      _openScheduleItem(next.first);
    } else {
      _dayGuidanceActive = false;
    }
  }

  Future<void> _recordScheduleProgress(
    Map<String, dynamic> item, {
    required String status,
    required String note,
  }) async {
    final actorUserId = _client.auth.currentUser?.id ?? '';
    final stableId = _stableId;
    final generation = _sensitiveStateGeneration;
    final now = DateTime.now();
    await _guarded(() async {
      _assertPlanningScopeCurrent(
        generation: generation,
        actorUserId: actorUserId,
        stableId: stableId,
      );
      await _runIdempotentRpc(
        operation: 'record_schedule_execution',
        intentKey:
            '${item['schedule_item_id']}:$status:'
            '${now.toUtc().toIso8601String()}',
        buildParams:
            (requestId) => {
              'p_schedule_item_id': item['schedule_item_id'],
              'p_request_id': requestId,
              'p_execution_status': status,
              'p_actual_started_at': now.toUtc().toIso8601String(),
              'p_actual_completed_at': now.toUtc().toIso8601String(),
              'p_recorded_local_at': _stableLocalTimestamp(now),
              'p_recorded_timezone': _stableTimezone,
              'p_source': 'online',
              'p_device_instance_id': null,
              'p_note': note,
            },
      );
      _notice =
          status == 'partial'
              ? 'Taak gestart; de eindstatus blijft open.'
              : 'Afwijking veilig geregistreerd; de taak blijft zichtbaar.';
      await _load(quiet: true);
    });
  }

  Future<void> _reportScheduleDeviation(Map<String, dynamic> item) async {
    final note = TextEditingController();
    var status = 'problem';
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Afwijking registreren'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: status,
                        decoration: const InputDecoration(
                          labelText: 'Soort afwijking',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'problem',
                            child: Text('Probleem'),
                          ),
                          DropdownMenuItem(
                            value: 'refused',
                            child: Text('Geweigerd'),
                          ),
                          DropdownMenuItem(
                            value: 'skipped',
                            child: Text('Niet uitgevoerd'),
                          ),
                        ],
                        onChanged:
                            (value) =>
                                setDialogState(() => status = value ?? status),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: note,
                        autofocus: true,
                        maxLength: 1000,
                        minLines: 2,
                        maxLines: 5,
                        onChanged: (_) => setDialogState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Toelichting',
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Annuleren'),
                    ),
                    FilledButton(
                      onPressed:
                          note.text.trim().isEmpty
                              ? null
                              : () => Navigator.pop(dialogContext, {
                                'status': status,
                                'note': note.text.trim(),
                              }),
                      child: const Text('Registreren'),
                    ),
                  ],
                ),
          ),
    );
    note.dispose();
    if (result == null) return;
    await _recordScheduleProgress(
      item,
      status: result['status']!,
      note: result['note']!,
    );
  }

  Future<void> _showScheduleItemActions(Map<String, dynamic> item) async {
    final terminal = const {
      'completed',
      'skipped',
      'cancelled',
      'pending_sync',
    }.contains(_operationalString(item['state']));
    final seriesId = _operationalString(item['series_id']);
    BuildContext? openedDialogContext;
    Route<dynamic>? openedDialogRoute;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final dialogRoute = ModalRoute.of(dialogContext);
        openedDialogContext = dialogContext;
        openedDialogRoute = dialogRoute;
        _sensitivePlanningDialogContext = dialogContext;
        _sensitivePlanningDialogRoute = dialogRoute;
        return AlertDialog(
          title: Text(_operationalString(item['title'])),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Categorie: '
                  '${_scheduleActivityType(item)}',
                ),
                Text('Status: ${_scheduleStateLabel(item)}'),
                const SizedBox(height: 8),
                Text('Paard: ${_operationalString(item['horse_name'])}'),
                Text(
                  'Datum en tijd: '
                  '${_operationalDisplayDate(item['source_local_date'])} · '
                  '${_stableClock(item['scheduled_start_at'])}',
                ),
                if (_operationalString(item['responsible_name']).isNotEmpty)
                  Text(
                    'Verantwoordelijke: '
                    '${_operationalString(item['responsible_name'])}',
                  ),
                if (_scheduleLocation(item).isNotEmpty)
                  Text('Locatie: ${_scheduleLocation(item)}'),
                const SizedBox(height: 12),
                Text(
                  _scheduleInstruction(item).isEmpty
                      ? 'Geen aanvullende instructie.'
                      : _scheduleInstruction(item),
                ),
                if (_operationalString(
                  item['actual_completed_at'],
                ).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Uitgevoerd op: '
                    '${_stableDateTimeLabel(item['actual_completed_at'])}',
                  ),
                ],
                if (_operationalString(
                  item['execution_actor_user_id'],
                ).isNotEmpty)
                  Text(
                    'Afgetekend door: '
                    '${_executionActorLabel(item)}',
                  ),
                if (_operationalString(item['execution_note']).isNotEmpty)
                  Text(
                    'Registratie: '
                    '${_operationalString(item['execution_note'])}',
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Sluiten'),
            ),
            if (!terminal)
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  unawaited(_reportScheduleDeviation(item));
                },
                child: const Text('Afwijking'),
              ),
            if (!terminal && _operationalString(item['state']) != 'in_progress')
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  unawaited(
                    _recordScheduleProgress(
                      item,
                      status: 'partial',
                      note: 'Taak gestart via taakdetail.',
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start'),
              ),
            if (!terminal)
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  unawaited(
                    _editScheduleItem(
                      item,
                      scope: seriesId.isEmpty ? 'item' : 'occurrence',
                    ),
                  );
                },
                child: Text(
                  seriesId.isEmpty ? 'Wijzigen' : 'Alleen deze wijzigen',
                ),
              ),
            if (!terminal && seriesId.isNotEmpty)
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  unawaited(_editScheduleItem(item, scope: 'future'));
                },
                child: const Text('Deze en volgende'),
              ),
            if (!terminal)
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  unawaited(_completeSchedule(item));
                },
                icon: const Icon(Icons.check),
                label: const Text('Voltooien'),
              ),
          ],
        );
      },
    );
    if (identical(_sensitivePlanningDialogContext, openedDialogContext) &&
        identical(_sensitivePlanningDialogRoute, openedDialogRoute)) {
      _sensitivePlanningDialogContext = null;
      _sensitivePlanningDialogRoute = null;
    }
  }

  Future<void> _showFeedingOccurrenceDetails(Map<String, dynamic> item) async {
    BuildContext? openedDialogContext;
    Route<dynamic>? openedDialogRoute;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final dialogRoute = ModalRoute.of(dialogContext);
        openedDialogContext = dialogContext;
        openedDialogRoute = dialogRoute;
        _sensitivePlanningDialogContext = dialogContext;
        _sensitivePlanningDialogRoute = dialogRoute;
        return AlertDialog(
          title: Text(
            _operationalString(item['product_name']).isEmpty
                ? _operationalString(item['title'])
                : _operationalString(item['product_name']),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_feedingCategoryLabel(item['feeding_item_category'])} · '
                  '${item['planned_quantity']} '
                  '${_operationalString(item['planned_unit_code'])}',
                ),
                if (_operationalString(item['responsible_name']).isNotEmpty)
                  Text(
                    'Verantwoordelijke: '
                    '${_operationalString(item['responsible_name'])}',
                  ),
                const SizedBox(height: 12),
                Text(_scheduleInstruction(item)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Sluiten'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                unawaited(_completeSchedule(item));
              },
              child: const Text('Uitvoeren'),
            ),
          ],
        );
      },
    );
    if (identical(_sensitivePlanningDialogContext, openedDialogContext) &&
        identical(_sensitivePlanningDialogRoute, openedDialogRoute)) {
      _sensitivePlanningDialogContext = null;
      _sensitivePlanningDialogRoute = null;
    }
  }

  String _scheduleLocation(Map<String, dynamic> item) {
    final instruction = _operationalString(item['instruction']);
    if (!instruction.startsWith('Locatie: ')) return '';
    return instruction.split('\n').first.substring('Locatie: '.length).trim();
  }

  String _scheduleInstruction(Map<String, dynamic> item) {
    final instruction = _operationalString(item['instruction']);
    final parts = instruction.split('\n').toList(growable: false);
    return parts
        .where(
          (part) =>
              !part.startsWith('Locatie: ') && !part.startsWith('Categorie: '),
        )
        .join('\n')
        .trim();
  }

  String _scheduleActivityType(Map<String, dynamic> item) {
    for (final part in _operationalString(item['instruction']).split('\n')) {
      if (part.startsWith('Categorie: ')) {
        return part.substring('Categorie: '.length).trim();
      }
    }
    return _scheduleCategoryLabel(item['item_kind']);
  }

  Color _scheduleCategoryColor(String kind, FlutterFlowTheme theme) =>
      switch (kind) {
        'feeding' => theme.warning,
        'care' => theme.success,
        'training' => theme.secondary,
        'other' => theme.info,
        _ => theme.primary,
      };

  String _scheduleCategoryLabel(dynamic value) => switch (_operationalString(
    value,
  )) {
    'feeding' => 'Voeding',
    'care' => 'Verzorging',
    'training' => 'Training',
    'farrier' => 'Hoefsmid',
    'veterinary' => 'Dierenarts',
    'competition' => 'Wedstrijd',
    'other' => 'Afspraak',
    _ => 'Taak',
  };

  String _executionActorLabel(Map<String, dynamic> item) {
    final actorUserId = _operationalString(item['execution_actor_user_id']);
    final ownUserId = _client.auth.currentUser?.id ?? '';
    if (actorUserId.isNotEmpty && actorUserId == ownUserId) {
      return 'Jij';
    }
    for (final member in _stableRoster) {
      if (_operationalString(member['user_id']) == actorUserId) {
        final name = _operationalString(member['display_name']);
        if (name.isNotEmpty) return name;
      }
    }
    return 'Bevoegde teamgebruiker';
  }

  List<Map<String, dynamic>> _filteredScheduleRows({bool feedingOnly = false}) {
    final ownMemberId = _operationalString(
      _actorMembership['stable_member_id'],
    );
    final rows =
        _schedule.where((item) {
          if (feedingOnly && item['item_kind'] != 'feeding') return false;
          if (_calendarHorseFilter.isNotEmpty &&
              _operationalString(item['horse_id']) != _calendarHorseFilter) {
            return false;
          }
          if (_calendarMemberFilter.isNotEmpty &&
              _operationalString(item['responsible_stable_member_id']) !=
                  _calendarMemberFilter) {
            return false;
          }
          if (_calendarCategoryFilter.isNotEmpty &&
              _operationalString(item['item_kind']) !=
                  _calendarCategoryFilter) {
            return false;
          }
          if (_calendarTeamFilter == 'mine' &&
              _operationalString(item['responsible_stable_member_id']) !=
                  ownMemberId &&
              _operationalString(item['assignment_status']).isEmpty) {
            return false;
          }
          return true;
        }).toList();
    rows.sort((left, right) {
      final leftTime =
          _operationalDate(left['scheduled_start_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final rightTime =
          _operationalDate(right['scheduled_start_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final timeOrder = leftTime.compareTo(rightTime);
      if (timeOrder != 0) return timeOrder;
      return _operationalString(
        left['id'],
      ).compareTo(_operationalString(right['id']));
    });
    return rows;
  }

  String _scheduleStateLabel(Map<String, dynamic> item) {
    if (item['is_overdue'] == true) return 'Te laat';
    return switch (_operationalString(item['state'])) {
      'completed' => 'Afgerond',
      'skipped' => 'Gemist',
      'cancelled' => 'Geannuleerd',
      'pending_sync' => 'Wordt gesynchroniseerd',
      'in_progress' => 'Bezig',
      _ => 'Gepland',
    };
  }

  Widget _scheduleVisualCard(
    FlutterFlowTheme theme,
    Map<String, dynamic> item, {
    bool planning = false,
    bool compact = false,
  }) {
    final kind = _operationalString(item['item_kind']);
    final accent = _scheduleCategoryColor(kind, theme);
    final responsible =
        _operationalString(item['responsible_name']).isEmpty
            ? 'Niet toegewezen'
            : _operationalString(item['responsible_name']);
    final horse = _operationalString(item['horse_name']);
    final horseRecord = _horses.firstWhere(
      (candidate) =>
          _operationalString(candidate['id']) ==
          _operationalString(item['horse_id']),
      orElse: () => const <String, dynamic>{},
    );
    final location = _scheduleLocation(item);
    final state = _operationalString(item['state']);
    final terminal = const {
      'completed',
      'skipped',
      'cancelled',
      'pending_sync',
    }.contains(state);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: theme.secondaryBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.alternate),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap:
            _busy
                ? null
                : planning
                ? () => _showScheduleItemActions(item)
                : () => _openScheduleItem(item),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(compact ? 13 : 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: compact ? 48 : 58,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _stableClock(item['scheduled_start_at']),
                              style: theme.labelLarge.copyWith(
                                color: theme.primaryText,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Icon(
                              kind == 'feeding'
                                  ? Icons.restaurant_outlined
                                  : kind == 'training'
                                  ? Icons.fitness_center_outlined
                                  : Icons.event_available_outlined,
                              color: accent,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 13),
                      if (horseRecord.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _horsePhoto(
                            horseRecord,
                            width: 38,
                            height: 38,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _operationalString(item['title']),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.titleSmall.copyWith(
                                color: theme.primaryText,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              [
                                horse,
                                responsible,
                                location,
                              ].where((value) => value.isNotEmpty).join(' · '),
                              maxLines: compact ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.bodySmall.copyWith(
                                color: theme.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(_scheduleStateLabel(item)),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide(
                          color:
                              terminal
                                  ? theme.success.withValues(alpha: 0.35)
                                  : accent.withValues(alpha: 0.35),
                        ),
                        backgroundColor:
                            terminal
                                ? theme.success.withValues(alpha: 0.10)
                                : accent.withValues(alpha: 0.08),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dayCalendar(
    FlutterFlowTheme theme,
    List<Map<String, dynamic>> rows, {
    bool planning = false,
  }) {
    if (rows.isEmpty) return const SizedBox.shrink();
    int localHour(Map<String, dynamic> item) {
      final parsed = _operationalDate(item['scheduled_start_at']);
      return parsed == null
          ? 0
          : timezone.TZDateTime.from(parsed, _stableLocation).hour;
    }

    final scheduledHours = rows.map(localHour).toList(growable: false);
    final firstHour = scheduledHours.reduce((a, b) => a < b ? a : b);
    final lastHour = scheduledHours.reduce((a, b) => a > b ? a : b);
    final startHour = firstHour < 6 ? firstHour : 6;
    final endHour = lastHour > 20 ? lastHour : 20;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var hour = startHour; hour <= endHour; hour++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 52,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${hour.toString().padLeft(2, '0')}:00',
                      style: theme.labelSmall.copyWith(
                        color: theme.secondaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 20,
                  child: Column(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: theme.secondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Container(width: 1, color: theme.alternate),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final hourRows = rows
                          .where((item) => localHour(item) == hour)
                          .toList(growable: false);
                      if (hourRows.isEmpty) {
                        return Container(
                          height: 58,
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: theme.alternate),
                            ),
                          ),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: hourRows
                            .map(
                              (item) => _scheduleVisualCard(
                                theme,
                                item,
                                planning: planning,
                                compact: true,
                              ),
                            )
                            .toList(growable: false),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _weekCalendar(
    FlutterFlowTheme theme,
    List<Map<String, dynamic>> rows,
  ) {
    final selected = _scheduleDate ?? _stableNow();
    final monday = DateTime(
      selected.year,
      selected.month,
      selected.day,
    ).subtract(Duration(days: selected.weekday - 1));
    const labels = ['MA', 'DI', 'WO', 'DO', 'VR', 'ZA', 'ZO'];
    return LayoutBuilder(
      builder: (context, constraints) {
        final days = List.generate(7, (index) {
          final day = monday.add(Duration(days: index));
          final key = _operationalDateKey(day);
          final dayRows = rows
              .where(
                (item) => _operationalString(item['source_local_date']) == key,
              )
              .toList(growable: false);
          return Container(
            width: constraints.maxWidth < 860 ? null : 132,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.secondaryBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.alternate),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${labels[index]} ${day.day}',
                  style: theme.labelLarge.copyWith(
                    color: theme.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (dayRows.isEmpty)
                  Text(
                    'Vrij',
                    style: theme.bodySmall.copyWith(color: theme.secondaryText),
                  )
                else
                  ...dayRows.map(
                    (item) => InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap:
                          _busy ? null : () => _showScheduleItemActions(item),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _scheduleCategoryColor(
                            _operationalString(item['item_kind']),
                            theme,
                          ).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _stableClock(item['scheduled_start_at']),
                              style: theme.labelSmall.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              _operationalString(item['title']),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.bodySmall.copyWith(
                                color: theme.primaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        });
        if (constraints.maxWidth < 860) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: days,
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < days.length; index++) ...[
              Expanded(child: days[index]),
              if (index < days.length - 1) const SizedBox(width: 7),
            ],
          ],
        );
      },
    );
  }

  Widget _monthCalendar(
    FlutterFlowTheme theme,
    List<Map<String, dynamic>> rows,
  ) {
    final selected = _scheduleDate ?? _stableNow();
    final first = DateTime(selected.year, selected.month);
    final days = DateTime(selected.year, selected.month + 1, 0).day;
    final leading = first.weekday - 1;
    final selectedKey = _operationalDateKey(selected);
    final selectedRows = rows
        .where(
          (item) =>
              _operationalString(item['source_local_date']) == selectedKey,
        )
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 600;
            final cells = <Widget>[
              for (final label in const [
                'MA',
                'DI',
                'WO',
                'DO',
                'VR',
                'ZA',
                'ZO',
              ])
                Center(
                  child: Text(
                    label,
                    style: theme.labelSmall.copyWith(
                      color: theme.secondaryText,
                      fontWeight: FontWeight.w700,
                      fontSize: compact ? 10 : null,
                    ),
                  ),
                ),
              for (var index = 0; index < leading; index++)
                const SizedBox.shrink(),
              for (var day = 1; day <= days; day++)
                Builder(
                  builder: (context) {
                    final date = DateTime(selected.year, selected.month, day);
                    final key = _operationalDateKey(date);
                    final dayRows = rows
                        .where(
                          (item) =>
                              _operationalString(item['source_local_date']) ==
                              key,
                        )
                        .toList(growable: false);
                    final isSelected =
                        date.year == selected.year &&
                        date.month == selected.month &&
                        date.day == selected.day;
                    return InkWell(
                      borderRadius: BorderRadius.circular(compact ? 9 : 12),
                      onTap:
                          _busy
                              ? null
                              : () => setState(() => _scheduleDate = date),
                      child: Container(
                        padding: EdgeInsets.all(compact ? 4 : 8),
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? theme.secondary.withValues(alpha: 0.12)
                                  : theme.secondaryBackground,
                          borderRadius: BorderRadius.circular(compact ? 9 : 12),
                          border: Border.all(
                            color:
                                isSelected ? theme.secondary : theme.alternate,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$day',
                              style: theme.labelLarge.copyWith(
                                color:
                                    isSelected
                                        ? theme.secondary
                                        : theme.primaryText,
                                fontWeight: FontWeight.w700,
                                fontSize: compact ? 11 : null,
                              ),
                            ),
                            SizedBox(height: compact ? 4 : 6),
                            if (compact && dayRows.isNotEmpty)
                              Wrap(
                                spacing: 3,
                                runSpacing: 3,
                                children: [
                                  ...dayRows
                                      .take(3)
                                      .map(
                                        (item) => Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: _scheduleCategoryColor(
                                              _operationalString(
                                                item['item_kind'],
                                              ),
                                              theme,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                  if (dayRows.length > 3)
                                    Text(
                                      '+${dayRows.length - 3}',
                                      style: theme.labelSmall.copyWith(
                                        color: theme.secondary,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                ],
                              )
                            else if (!compact)
                              ...dayRows
                                  .take(2)
                                  .map(
                                    (item) => Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 4),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _scheduleCategoryColor(
                                          _operationalString(item['item_kind']),
                                          theme,
                                        ).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${_stableClock(item['scheduled_start_at'])} '
                                        '${_operationalString(item['title'])}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.labelSmall.copyWith(
                                          color: theme.primaryText,
                                          fontSize: 9,
                                        ),
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ];
            return GridView.count(
              crossAxisCount: 7,
              crossAxisSpacing: compact ? 3 : 6,
              mainAxisSpacing: compact ? 4 : 6,
              childAspectRatio: compact ? 0.72 : 0.88,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: cells,
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          'Activiteiten op ${_operationalDisplayDate(selected)}',
          style: theme.titleMedium.copyWith(
            color: theme.primaryText,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (selectedRows.isEmpty)
          Text(
            'Geen activiteiten op deze dag.',
            style: theme.bodyMedium.copyWith(color: theme.secondaryText),
          )
        else
          ...selectedRows.map(
            (item) =>
                _scheduleVisualCard(theme, item, planning: true, compact: true),
          ),
      ],
    );
  }

  Widget _planningModeControls(FlutterFlowTheme theme) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(
            value: 'list',
            label: Text('Lijst'),
            icon: Icon(Icons.view_agenda_outlined),
          ),
          ButtonSegment(
            value: 'calendar',
            label: Text('Agenda'),
            icon: Icon(Icons.calendar_month_outlined),
          ),
        ],
        selected: {_planningDisplayMode},
        onSelectionChanged:
            _busy
                ? null
                : (values) =>
                    setState(() => _planningDisplayMode = values.single),
      ),
      const SizedBox(height: 10),
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'mine', label: Text('Mijn taken')),
          ButtonSegment(value: 'team', label: Text('Alle stal')),
        ],
        selected: {_calendarTeamFilter},
        onSelectionChanged:
            _busy
                ? null
                : (values) =>
                    setState(() => _calendarTeamFilter = values.single),
      ),
    ],
  );

  Widget _planningGroupedList(
    FlutterFlowTheme theme,
    List<Map<String, dynamic>> rows,
  ) {
    if (rows.isEmpty) {
      return _emptyCard(
        theme,
        icon: Icons.event_available_outlined,
        title: 'Geen planning in deze periode',
        body: 'Plan een activiteit voor een paard of teamlid.',
      );
    }
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in rows) {
      final key = _operationalString(item['source_local_date']);
      grouped.putIfAbsent(key, () => []).add(item);
    }
    final dates = grouped.keys.toList(growable: false)..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final date in dates) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(
              _operationalDisplayDate(date),
              style: theme.titleMedium.copyWith(
                color: theme.primaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ...grouped[date]!.map(
            (item) => _scheduleVisualCard(theme, item, planning: true),
          ),
        ],
      ],
    );
  }

  Widget _scheduleContent(
    FlutterFlowTheme theme, {
    bool planning = false,
    bool feedingOnly = false,
  }) {
    final rows = _filteredScheduleRows(feedingOnly: feedingOnly);
    if (rows.isEmpty && !planning) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _scheduleDateControls(theme),
          if (planning) ...[
            const SizedBox(height: 10),
            _calendarControls(theme),
          ],
          if (planning && !_offline) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _busy ? null : _createScheduleItem,
                icon: const Icon(Icons.add_task),
                label: const Text('Taak plannen'),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _emptyCard(
            theme,
            icon:
                feedingOnly
                    ? Icons.restaurant_outlined
                    : Icons.event_available_outlined,
            title:
                feedingOnly
                    ? 'Geen toegewezen voerronde'
                    : 'Geen toegankelijke taken op deze dag',
            body:
                _offline
                    ? 'De versleutelde offline dagset bevat geen taken.'
                    : 'Nieuwe of toegewezen taken verschijnen hier automatisch.',
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (planning) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Activiteiten',
                      style: theme.headlineSmall.copyWith(
                        color: theme.primaryText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Alles voor paard en team, chronologisch op één plek.',
                      style: theme.bodyMedium.copyWith(
                        color: theme.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _offline || _busy ? null : _createScheduleItem,
                icon: const Icon(Icons.add),
                label: const Text('Activiteit toevoegen'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _planningModeControls(theme),
          const SizedBox(height: 12),
          _calendarControls(theme),
          const SizedBox(height: 10),
        ],
        _scheduleDateControls(theme),
        const SizedBox(height: 10),
        if (planning && _planningDisplayMode == 'list')
          _planningGroupedList(theme, rows)
        else if (planning && _calendarView == 'month')
          _monthCalendar(theme, rows)
        else if (planning && _calendarView == 'week')
          _weekCalendar(theme, rows)
        else if (planning && rows.isEmpty)
          _emptyCard(
            theme,
            icon: Icons.event_available_outlined,
            title: 'Geen planning op deze dag',
            body: 'Plan een taak of routine voor dit paard of team.',
          )
        else if (planning)
          _dayCalendar(theme, rows, planning: true)
        else
          _dayCalendar(theme, rows),
        const SizedBox(height: 14),
        if (!kIsWeb)
          OutlinedButton.icon(
            onPressed:
                _offline || _busy || !_selectedScheduleDateIsToday
                    ? null
                    : _prepareOfflineDayset,
            icon: Icon(
              _offlineReady
                  ? Icons.offline_pin_outlined
                  : Icons.download_outlined,
            ),
            label: Text(
              !_selectedScheduleDateIsToday
                  ? 'Offline dagset alleen voor vandaag'
                  : _offlineReady
                  ? 'Versleutelde dagset vernieuwen'
                  : 'Veilige offline dagset voorbereiden',
            ),
          ),
      ],
    );
  }

  Widget _feedingContent(FlutterFlowTheme theme) {
    if (_feedingPlans.isEmpty) {
      return _emptyCard(
        theme,
        icon: Icons.restaurant_menu_outlined,
        title: 'Nog geen toegankelijk voerplan',
        body:
            'Maak een conceptplan aan. Goedkeuring en activatie blijven '
            'afzonderlijke, traceerbare stappen.',
        actionLabel: _offline ? null : 'Conceptplan aanmaken',
        onPressed: _offline ? null : _createFeedingPlan,
      );
    }
    final selectedPlan = _selectedFeedingPlan;
    final selectedVersion = _selectedFeedingVersion;
    final selectedItems = _selectedFeedingItems;
    final versionStatus = _operationalString(selectedVersion?['status']);
    final activeVersionId = _operationalString(
      selectedPlan?['active_version_id'],
    );
    final selectedVersionId = _operationalString(selectedVersion?['id']);
    final selectedPlanHorseId = _operationalString(selectedPlan?['horse_id']);
    final historyRows = _feedingHistory
      .where(
        (item) =>
            _operationalString(item['horse_id']) == selectedPlanHorseId &&
            const {
              'completed',
              'skipped',
            }.contains(_operationalString(item['state'])),
      )
      .toList(growable: false)..sort(
      (a, b) => _operationalString(
        b['scheduled_start_at'],
      ).compareTo(_operationalString(a['scheduled_start_at'])),
    );
    final versionIsActive =
        selectedVersionId.isNotEmpty && selectedVersionId == activeVersionId;
    final selectedPlanHorse = _horses.firstWhere(
      (horse) => _operationalString(horse['id']) == selectedPlanHorseId,
      orElse: () => const <String, dynamic>{},
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: const AvarynOrionPhoto(width: 96, height: 96),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _operationalString(
                            selectedPlanHorse['display_name'],
                          ).isEmpty
                          ? 'Voerschema'
                          : _operationalString(
                            selectedPlanHorse['display_name'],
                          ),
                      style: theme.headlineSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Vaste rondes, tijdelijke afwijkingen en historie',
                      style: theme.bodyMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.76),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _offline || _busy ? null : _createFeedingPlan,
            icon: const Icon(Icons.add),
            label: const Text('Nieuw conceptplan'),
          ),
        ),
        const SizedBox(height: 12),
        ..._feedingPlans.map(
          (plan) => _dataCard(
            theme,
            leading: Icons.restaurant_menu_outlined,
            title: _operationalString(plan['name']),
            subtitle:
                '${_operationalString(plan['plan_type']) == 'temporary' ? 'Tijdelijk afwijkend schema' : 'Vast dagschema'} · '
                '${_operationalDisplayDate(plan['effective_from'])}'
                '${_operationalString(plan['effective_until']).isEmpty ? '' : ' t/m ${_operationalDisplayDate(plan['effective_until'])}'}',
            trailing:
                plan['active_version_id'] == null ? 'In opbouw' : 'Actief',
            selected: _operationalString(plan['id']) == _selectedFeedingPlanId,
            onTap:
                _busy
                    ? null
                    : () {
                      final planId = _operationalString(plan['id']);
                      final versions = _feedingPlanVersions
                          .where(
                            (version) =>
                                _operationalString(
                                  version['feeding_plan_id'],
                                ) ==
                                planId,
                          )
                          .toList(growable: false);
                      setState(() {
                        _selectedFeedingPlanId = planId;
                        _selectedFeedingVersionId =
                            versions.isEmpty
                                ? ''
                                : _operationalString(versions.first['id']);
                      });
                    },
          ),
        ),
        if (selectedPlan != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.secondaryBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.alternate),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Dagschema',
                  style: theme.titleMedium.copyWith(
                    color: theme.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_operationalString(selectedPlan['plan_type'])} · '
                  '${_operationalDisplayDate(selectedPlan['effective_from'])}'
                  '${_operationalString(selectedPlan['effective_until']).isEmpty ? '' : ' t/m ${_operationalDisplayDate(selectedPlan['effective_until'])}'}',
                  style: theme.bodySmall.copyWith(color: theme.secondaryText),
                ),
                const SizedBox(height: 12),
                if (_selectedFeedingVersions.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: _selectedFeedingVersionId,
                    decoration: const InputDecoration(labelText: 'Versie'),
                    items: _selectedFeedingVersions
                        .map(
                          (version) => DropdownMenuItem(
                            value: _operationalString(version['id']),
                            child: Text(
                              'Versie ${version['version_number']} · '
                              '${_operationalString(version['status'])}',
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged:
                        _busy
                            ? null
                            : (value) {
                              if (value == null) return;
                              setState(() => _selectedFeedingVersionId = value);
                            },
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (versionStatus != 'draft')
                      OutlinedButton.icon(
                        onPressed:
                            _offline || _busy ? null : _createFeedingVersion,
                        icon: const Icon(Icons.copy_all_outlined),
                        label: const Text('Nieuwe versie'),
                      ),
                    if (versionStatus == 'draft')
                      FilledButton.icon(
                        onPressed:
                            _offline || _busy
                                ? null
                                : () => _upsertFeedingItem(),
                        icon: const Icon(Icons.add),
                        label: const Text('Voermoment'),
                      ),
                    if (versionStatus == 'draft' && selectedItems.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed:
                            _offline || _busy
                                ? null
                                : _approveSelectedFeedingVersion,
                        icon: const Icon(Icons.verified_outlined),
                        label: const Text('Goedkeuren'),
                      ),
                    if (versionStatus == 'approved' && !versionIsActive)
                      FilledButton.icon(
                        onPressed:
                            _offline || _busy
                                ? null
                                : _activateSelectedFeedingVersion,
                        icon: const Icon(Icons.play_arrow_outlined),
                        label: const Text('Activeren'),
                      ),
                    OutlinedButton.icon(
                      onPressed:
                          _offline || _busy ? null : _retireSelectedFeedingPlan,
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('Plan stoppen'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (selectedVersion == null)
                  Text(
                    'Dit plan heeft nog geen toegankelijke versie.',
                    style: theme.bodyMedium.copyWith(
                      color: theme.secondaryText,
                    ),
                  )
                else if (selectedItems.isEmpty)
                  Text(
                    'Nog geen voeritems in deze versie.',
                    style: theme.bodyMedium.copyWith(
                      color: theme.secondaryText,
                    ),
                  )
                else
                  for (final roundCode
                      in selectedItems
                          .map((item) => _operationalString(item['round_code']))
                          .toSet()) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            _feedingRoundIcon(roundCode),
                            color: theme.secondary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _feedingRoundLabel(roundCode),
                            style: theme.titleSmall.copyWith(
                              color: theme.primaryText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...selectedItems
                        .where(
                          (item) =>
                              _operationalString(item['round_code']) ==
                              roundCode,
                        )
                        .map(
                          (item) => _dataCard(
                            theme,
                            leading:
                                _operationalString(item['item_category']) ==
                                        'medication'
                                    ? Icons.medication_outlined
                                    : _operationalString(
                                          item['item_category'],
                                        ) ==
                                        'water'
                                    ? Icons.water_drop_outlined
                                    : Icons.restaurant_outlined,
                            title: _operationalString(item['product_name']),
                            subtitle:
                                '${_feedingCategoryLabel(item['item_category'])} · '
                                '${item['planned_quantity']} '
                                '${_operationalString(item['unit_code'])} · '
                                '${_operationalString(item['local_time'])}'
                                '${_operationalString(item['instruction']).isEmpty ? '' : '\n${_operationalString(item['instruction'])}'}',
                            trailing:
                                versionStatus == 'draft'
                                    ? 'Wijzigen'
                                    : 'In schema',
                            onTap:
                                _offline || _busy || versionStatus != 'draft'
                                    ? null
                                    : () => _upsertFeedingItem(item),
                          ),
                        ),
                  ],
              ],
            ),
          ),
        ],
        if (selectedPlan != null) ...[
          const SizedBox(height: 14),
          Text(
            'Historie per paard',
            style: theme.titleMedium.copyWith(
              color: theme.primaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (historyRows.isEmpty)
            Text(
              'Nog geen afgetekende of gemiste voermomenten voor dit paard.',
              style: theme.bodyMedium.copyWith(color: theme.secondaryText),
            )
          else
            ...historyRows
                .take(20)
                .map(
                  (item) => _dataCard(
                    theme,
                    leading:
                        _operationalString(item['state']) == 'skipped'
                            ? Icons.block_outlined
                            : Icons.history_outlined,
                    title:
                        _operationalString(item['product_name']).isEmpty
                            ? _operationalString(item['title'])
                            : _operationalString(item['product_name']),
                    subtitle:
                        '${_operationalDisplayDate(item['source_local_date'])} · '
                        'gepland ${item['planned_quantity']} '
                        '${_operationalString(item['planned_unit_code'])} · '
                        'gegeven ${item['actual_quantity'] ?? '—'} '
                        '${_operationalString(item['actual_unit_code'])}'
                        '${_operationalString(item['deviation_code']).isEmpty ? '' : ' · ${_operationalString(item['deviation_code'])}'}'
                        '${_operationalString(item['observation']).isEmpty ? '' : ' · ${_operationalString(item['observation'])}'}',
                    trailing:
                        _operationalString(item['state']) == 'skipped'
                            ? 'Gemist'
                            : 'Afgetekend',
                    accentColor: _scheduleCategoryColor('feeding', theme),
                    onTap: () => _showCompletedExecutionActions(item),
                  ),
                ),
        ],
      ],
    );
  }

  String _feedingCategoryLabel(dynamic value) => switch (_operationalString(
    value,
  )) {
    'supplement' => 'Supplement',
    'hay' => 'Hooi',
    'water' => 'Water',
    'medication' => 'Medicatie',
    _ => 'Voer',
  };

  String _feedingRoundLabel(String value) => switch (value.toLowerCase()) {
    'morning' || 'ochtend' => 'Ochtend',
    'afternoon' || 'middag' => 'Middag',
    'evening' || 'avond' => 'Avond',
    _ => value.isEmpty ? 'Vrij voermoment' : value,
  };

  IconData _feedingRoundIcon(String value) => switch (value.toLowerCase()) {
    'morning' || 'ochtend' => Icons.wb_sunny_outlined,
    'afternoon' || 'middag' => Icons.light_mode_outlined,
    'evening' || 'avond' => Icons.nights_stay_outlined,
    _ => Icons.schedule_outlined,
  };

  Widget _dataCard(
    FlutterFlowTheme theme, {
    required IconData leading,
    required String title,
    required String subtitle,
    String trailing = '',
    bool selected = false,
    Color? accentColor,
    VoidCallback? onTap,
  }) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    elevation: 0,
    color:
        selected
            ? theme.secondary.withValues(alpha: 0.10)
            : theme.secondaryBackground,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color:
            selected ? theme.secondary : theme.alternate.withValues(alpha: 0.8),
      ),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: (accentColor ?? theme.primary).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                leading,
                color: accentColor ?? theme.primary,
                size: 21,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty ? 'Zonder titel' : title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.titleMedium.copyWith(
                      color: theme.primaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.bodySmall.copyWith(
                        color: theme.secondaryText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing.isNotEmpty) ...[
              const SizedBox(width: 10),
              Text(
                trailing,
                style: theme.labelMedium.copyWith(color: theme.secondary),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _loadingCard(FlutterFlowTheme theme) => Container(
    padding: const EdgeInsets.all(26),
    decoration: BoxDecoration(
      color: theme.secondaryBackground,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: theme.alternate),
    ),
    child: const Column(
      children: [
        SizedBox.square(
          dimension: 30,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        SizedBox(height: 14),
        Text('Beveiligde stalgegevens laden…'),
      ],
    ),
  );

  Widget _messageCard(
    FlutterFlowTheme theme,
    String message, {
    bool error = false,
    IconData icon = Icons.info_outline,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color:
          error
              ? theme.error.withValues(alpha: 0.08)
              : theme.info.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color:
            error
                ? theme.error.withValues(alpha: 0.35)
                : theme.info.withValues(alpha: 0.30),
      ),
    ),
    child: Row(
      children: [
        Icon(icon, color: error ? theme.error : theme.info),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: theme.bodyMedium)),
        if (error) TextButton(onPressed: _load, child: const Text('Opnieuw')),
      ],
    ),
  );

  Widget _emptyCard(
    FlutterFlowTheme theme, {
    required IconData icon,
    required String title,
    required String body,
    String? actionLabel,
    VoidCallback? onPressed,
  }) => Container(
    padding: const EdgeInsets.all(26),
    decoration: BoxDecoration(
      color: theme.secondaryBackground,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: theme.alternate),
    ),
    child: Column(
      children: [
        Icon(icon, size: 38, color: theme.secondary),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.titleLarge.copyWith(
            color: theme.primaryText,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          body,
          textAlign: TextAlign.center,
          style: theme.bodyMedium.copyWith(color: theme.secondaryText),
        ),
        if (actionLabel != null && onPressed != null) ...[
          const SizedBox(height: 16),
          FilledButton(onPressed: onPressed, child: Text(actionLabel)),
        ],
      ],
    ),
  );
}

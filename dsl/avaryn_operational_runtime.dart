import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'phase_4c7_runtime_contract.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutterflow_generated/app_state.dart';
import 'package:flutterflow_generated/flutter_flow/flutter_flow_theme.dart';
import 'package:flutterflow_generated/flutter_flow/flutter_flow_util.dart';
import 'package:openpgp/openpgp.dart';
import 'package:realtime_client/realtime_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;
import 'package:uuid/uuid.dart';

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
  List<Map<String, dynamic>> _conflicts = const [];
  List<Map<String, dynamic>> _offlineSchedule = const [];

  StreamSubscription<AuthState>? _authSubscription;
  String _boundUserId = '';
  String _stableId = '';
  String _stableTimezone = '';
  String _selectedHorseId = '';
  String _error = '';
  String _notice = '';
  int _authorityVersion = 0;
  int _cursor = 0;
  bool _loading = true;
  bool _busy = false;
  bool _offline = false;
  bool _permissionDenied = false;
  bool _offlineReady = false;
  bool _secureCleanupPending = false;
  Timer? _wakeDebounce;

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
    if (error is StateError && error.message == 'LOCAL_PURGE_INCOMPLETE') {
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
    }
    return 'De beveiligde gegevens konden niet worden geladen. Probeer opnieuw.';
  }

  Future<void> _refreshStableTimezone() async {
    final stable =
        await _client
            .from('stables')
            .select('timezone')
            .eq('id', _stableId)
            .maybeSingle();
    final name = _operationalString(stable?['timezone']);
    if (name.isEmpty) {
      throw const PostgrestException(
        message: 'STABLE_UNAVAILABLE',
        code: '42501',
      );
    }
    try {
      timezone.getLocation(name);
    } catch (_) {
      throw const PostgrestException(
        message: 'STABLE_UNAVAILABLE',
        code: '42501',
      );
    }
    _stableTimezone = name;
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
      final channel =
          _client
              .channel(token, opts: const RealtimeChannelConfig(private: true))
              .onBroadcast(
                event: 'change_available',
                callback: (_) => _scheduleWakeRefresh(),
              )
              .subscribe();
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

  Future<void> _fetchOperationalData() async {
    final today = _operationalDateKey(_stableNow());
    final results = await Future.wait<dynamic>([
      _client
          .from('horses')
          .select(
            'id,display_name,official_name,birth_date,sex,breed,discipline,'
            'level,row_version,status',
          )
          .eq('stable_id', _stableId)
          .eq('status', 'active')
          .order('display_name'),
      _client.rpc(
        'list_today_schedule',
        params: {'p_stable_id': _stableId, 'p_local_date': today},
      ),
      _client
          .from('feeding_plans')
          .select(
            'id,horse_id,name,plan_type,status,effective_from,'
            'effective_until,row_version,active_version_id',
          )
          .eq('stable_id', _stableId)
          .neq('status', 'retired')
          .order('effective_from', ascending: false),
      _client.rpc('list_sync_conflicts', params: {'p_stable_id': _stableId}),
    ]);
    _horses = _operationalRows(results[0]);
    _schedule = _operationalRows(results[1]);
    _feedingPlans = _operationalRows(results[2]);
    _conflicts = _operationalRows(results[3]);
    if (_selectedHorseId.isEmpty && _horses.isNotEmpty) {
      _selectedHorseId = _operationalString(_horses.first['id']);
    }
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
      final envelope = _operationalMap(
        await _client.rpc(
          'get_encrypted_offline_dayset',
          params: {
            'p_stable_id': _stableId,
            'p_device_instance_id': keys['device_id'],
            'p_local_date': _operationalDateKey(_stableNow()),
            'p_timezone': _stableTimezone,
            'p_expected_authority_version': _authorityVersion,
          },
        ),
      );
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
      if (!phase4C7DaysetMetadataMatches(
        envelope: envelope,
        plaintext: dayset,
        stableId: _stableId,
        timezone: _stableTimezone,
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
        'p_note': null,
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
              'p_observation': null,
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

  Future<Map<String, dynamic>?> _showFeedingExecutionDialog() async {
    final quantity = TextEditingController();
    final remaining = TextEditingController();
    var unitCode = 'portion';
    var deviationCode = 'none';
    String? validationError;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Werkelijk gevoerd'),
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
                                (remainingValue == null ||
                                    remainingValue < 0))) {
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
                        });
                      },
                      child: const Text('Registreren'),
                    ),
                  ],
                ),
          ),
    );
    quantity.dispose();
    remaining.dispose();
    return result;
  }

  Future<void> _completeSchedule(Map<String, dynamic> item) async {
    final feedingDetails =
        item['item_kind'] == 'feeding'
            ? await _showFeedingExecutionDialog()
            : null;
    if (item['item_kind'] == 'feeding' && feedingDetails == null) return;
    if (_offline) {
      await _queueOfflineCompletion(item, feedingDetails: feedingDetails);
      return;
    }
    await _guarded(() async {
      final now = DateTime.now();
      if (item['item_kind'] == 'feeding') {
        await _runIdempotentRpc(
          operation: 'record_feeding_execution',
          intentKey: _operationalString(item['schedule_item_id']),
          buildParams:
              (requestId) => {
                'p_schedule_item_id': item['schedule_item_id'],
                'p_corrects_execution_id': null,
                'p_request_id': requestId,
                'p_execution_status': 'completed',
                'p_actual_started_at': null,
                'p_actual_completed_at': now.toUtc().toIso8601String(),
                'p_recorded_local_at': _stableLocalTimestamp(now),
                'p_recorded_timezone': _stableTimezone,
                'p_source': 'online',
                'p_device_instance_id': null,
                'p_note': null,
                'p_actual_quantity': feedingDetails!['actual_quantity'],
                'p_unit_code': feedingDetails['unit_code'],
                'p_remaining_quantity': feedingDetails['remaining_quantity'],
                'p_deviation_code': feedingDetails['deviation_code'],
                'p_observation': null,
                'p_batch_lot': null,
              },
        );
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
      }
      _notice = 'Uitvoering veilig geregistreerd.';
      await _load(quiet: true);
    });
  }

  Future<void> _createHorse() async {
    final name = TextEditingController();
    final confirmed = await _showFormDialog(
      title: 'Paard toevoegen',
      controller: name,
      label: 'Roepnaam',
      action: 'Toevoegen',
    );
    final displayName = name.text.trim();
    name.dispose();
    if (!confirmed || displayName.isEmpty) return;
    await _guarded(() async {
      await _runIdempotentRpc(
        operation: 'create_horse',
        intentKey: displayName,
        buildParams:
            (requestId) => {
              'p_stable_id': _stableId,
              'p_display_name': displayName,
              'p_request_id': requestId,
              'p_official_name': null,
              'p_birth_date': null,
              'p_sex': 'unknown',
              'p_breed': null,
              'p_discipline': null,
              'p_level': null,
            },
      );
      _notice = 'Paard veilig toegevoegd.';
      await _load(quiet: true);
    });
  }

  Future<void> _createScheduleItem() async {
    if (_horses.isEmpty) {
      setState(() => _error = 'Voeg eerst een paard toe.');
      return;
    }
    final title = TextEditingController();
    final confirmed = await _showFormDialog(
      title: 'Taak voor vandaag',
      controller: title,
      label: 'Titel',
      action: 'Plannen',
    );
    final taskTitle = title.text.trim();
    title.dispose();
    if (!confirmed || taskTitle.isEmpty) return;
    await _guarded(() async {
      final start = _stableNow().add(const Duration(minutes: 15));
      await _runIdempotentRpc(
        operation: 'create_schedule_item',
        intentKey: '$_selectedHorseId:$taskTitle',
        buildParams:
            (requestId) => {
              'p_stable_id': _stableId,
              'p_horse_id': _selectedHorseId,
              'p_item_kind': 'task',
              'p_data_category': 'horse.schedule',
              'p_title': taskTitle,
              'p_instruction': 'Uitvoeren volgens de stalplanning.',
              'p_priority': 'normal',
              'p_scheduled_start_at': start.toUtc().toIso8601String(),
              'p_scheduled_end_at':
                  start
                      .add(const Duration(minutes: 30))
                      .toUtc()
                      .toIso8601String(),
              'p_source_timezone': _stableTimezone,
              'p_source_local_date': _operationalDateKey(start),
              'p_source_local_time':
                  '${start.hour.toString().padLeft(2, '0')}:'
                  '${start.minute.toString().padLeft(2, '0')}:00',
              'p_request_id': requestId,
            },
      );
      _notice = 'Taak veilig gepland.';
      await _load(quiet: true);
    });
  }

  Future<void> _createFeedingPlan() async {
    if (_horses.isEmpty) {
      setState(() => _error = 'Voeg eerst een paard toe.');
      return;
    }
    final name = TextEditingController();
    final confirmed = await _showFormDialog(
      title: 'Voerplan starten',
      controller: name,
      label: 'Naam van het plan',
      action: 'Aanmaken',
    );
    final planName = name.text.trim();
    name.dispose();
    if (!confirmed || planName.isEmpty) return;
    await _guarded(() async {
      await _runIdempotentRpc(
        operation: 'create_feeding_plan',
        intentKey: '$_selectedHorseId:$planName',
        buildParams:
            (requestId) => {
              'p_horse_id': _selectedHorseId,
              'p_plan_type': 'standard',
              'p_name': planName,
              'p_effective_from': _operationalDateKey(_stableNow()),
              'p_effective_until': null,
              'p_request_id': requestId,
            },
      );
      _notice = 'Conceptvoerplan veilig aangemaakt.';
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

  void _clearDecryptedState() {
    _horses = const [];
    _schedule = const [];
    _feedingPlans = const [];
    _conflicts = const [];
    _offlineSchedule = const [];
    _selectedHorseId = '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return ColoredBox(
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
                        _securityStrip(theme),
                        const SizedBox(height: 18),
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
    );
  }

  Widget _header(FlutterFlowTheme theme) {
    final title = switch (widget.mode) {
      'horses' => 'Paarden',
      'planning' => 'Planning',
      'feeding' => 'Voeding',
      'feedingExecution' => 'Voerronde',
      _ => 'Vandaag',
    };
    final subtitle = switch (widget.mode) {
      'horses' => 'Alleen paarden waarvoor je actuele toegang hebt.',
      'planning' => 'De duurzame stalplanning, met conflictcontrole.',
      'feeding' => 'Goedgekeurde plannen en traceerbare uitvoeringen.',
      'feedingExecution' =>
        'Registreer per toegewezen voertaak wat werkelijk is gegeven.',
      _ => 'Jouw toegankelijke werkzaamheden voor deze lokale dag.',
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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

  Widget _securityStrip(FlutterFlowTheme theme) => Container(
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
                ? 'Offline · alleen tijdelijk ontsleuteld in geheugen'
                : 'Autoriteit $_authorityVersion · serverbeleid is leidend',
            style: theme.bodySmall.copyWith(color: theme.primaryText),
          ),
        ),
        if (_conflicts.isNotEmpty)
          Text(
            '${_conflicts.length} conflict${_conflicts.length == 1 ? '' : 'en'}',
            style: theme.labelMedium.copyWith(color: theme.error),
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
      _ => _scheduleContent(theme),
    };
  }

  Widget _horsesContent(FlutterFlowTheme theme) {
    if (_horses.isEmpty) {
      return _emptyCard(
        theme,
        icon: Icons.pets_outlined,
        title: 'Nog geen toegankelijke paarden',
        body:
            'Een beheerder kan een paard toevoegen of je expliciete toegang geven.',
        actionLabel: _offline ? null : 'Paard toevoegen',
        onPressed: _offline ? null : _createHorse,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _offline || _busy ? null : _createHorse,
            icon: const Icon(Icons.add),
            label: const Text('Paard toevoegen'),
          ),
        ),
        const SizedBox(height: 12),
        ..._horses.map(
          (horse) => _dataCard(
            theme,
            leading: Icons.pets_outlined,
            title: _operationalString(horse['display_name']),
            subtitle: [
              _operationalString(horse['official_name']),
              _operationalString(horse['breed']),
              _operationalString(horse['discipline']),
            ].where((value) => value.isNotEmpty).join(' · '),
            trailing: 'v${horse['row_version']}',
            selected: _selectedHorseId == _operationalString(horse['id']),
            onTap: () {
              setState(
                () => _selectedHorseId = _operationalString(horse['id']),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _scheduleContent(
    FlutterFlowTheme theme, {
    bool planning = false,
    bool feedingOnly = false,
  }) {
    final rows = _schedule
        .where((item) => !feedingOnly || item['item_kind'] == 'feeding')
        .toList(growable: false);
    if (rows.isEmpty) {
      return _emptyCard(
        theme,
        icon:
            feedingOnly
                ? Icons.restaurant_outlined
                : Icons.event_available_outlined,
        title:
            feedingOnly
                ? 'Geen toegewezen voerronde'
                : 'Geen toegankelijke taken vandaag',
        body:
            _offline
                ? 'De versleutelde offline dagset bevat geen taken.'
                : 'Nieuwe of toegewezen taken verschijnen hier automatisch.',
        actionLabel: planning && !_offline ? 'Taak plannen' : null,
        onPressed: planning && !_offline ? _createScheduleItem : null,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (planning)
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _offline || _busy ? null : _createScheduleItem,
              icon: const Icon(Icons.add_task),
              label: const Text('Taak plannen'),
            ),
          ),
        if (planning) const SizedBox(height: 12),
        ...rows.map((item) {
          final state = _operationalString(item['state']);
          final terminal = const {
            'completed',
            'skipped',
            'cancelled',
            'pending_sync',
          }.contains(state);
          return _dataCard(
            theme,
            leading:
                item['item_kind'] == 'feeding'
                    ? Icons.restaurant_outlined
                    : Icons.task_alt_outlined,
            title: _operationalString(item['title']),
            subtitle:
                '${_stableClock(item['scheduled_start_at'])} · '
                '${_operationalString(item['priority'])} · $state',
            trailing: terminal ? 'Klaar' : 'Afronden',
            onTap: terminal || _busy ? null : () => _completeSchedule(item),
          );
        }),
        const SizedBox(height: 14),
        if (kIsWeb)
          _messageCard(
            theme,
            'Offline dagsets zijn bewust uitgeschakeld in de webapp: '
            'OS-backed sleutelopslag is verplicht.',
            icon: Icons.phonelink_lock_outlined,
          )
        else
          OutlinedButton.icon(
            onPressed: _offline || _busy ? null : _prepareOfflineDayset,
            icon: Icon(
              _offlineReady
                  ? Icons.offline_pin_outlined
                  : Icons.download_outlined,
            ),
            label: Text(
              _offlineReady
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                '${_operationalString(plan['plan_type'])} · '
                '${_operationalString(plan['status'])} · '
                'v${plan['row_version']}',
            trailing: plan['active_version_id'] == null ? 'Concept' : 'Actief',
          ),
        ),
      ],
    );
  }

  Widget _dataCard(
    FlutterFlowTheme theme, {
    required IconData leading,
    required String title,
    required String subtitle,
    String trailing = '',
    bool selected = false,
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
                color: theme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(leading, color: theme.primary, size: 21),
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

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image/image.dart' as image;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class _FeedingProductDraft {
  _FeedingProductDraft({
    this.itemId,
    this.expectedRowVersion,
    this.productType = 'pellet',
    String description = '',
    String quantity = '',
    this.unitCode = 'kg',
    String note = '',
  }) : descriptionController = TextEditingController(text: description),
       quantityController = TextEditingController(text: quantity),
       noteController = TextEditingController(text: note);

  final String? itemId;
  final int? expectedRowVersion;
  String productType;
  String unitCode;
  final TextEditingController descriptionController;
  final TextEditingController quantityController;
  final TextEditingController noteController;

  void dispose() {
    descriptionController.dispose();
    quantityController.dispose();
    noteController.dispose();
  }
}

class _ScheduleRangeSelection {
  const _ScheduleRangeSelection({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

class AvarynHorseAccountRuntime extends StatefulWidget {
  const AvarynHorseAccountRuntime({super.key, this.width, this.height});

  final double? width;
  final double? height;

  @override
  State<AvarynHorseAccountRuntime> createState() =>
      _AvarynHorseAccountRuntimeState();
}

class _AvarynHorseAccountRuntimeState extends State<AvarynHorseAccountRuntime> {
  static const _darkCanvas = Color(0xFF141215);
  static const _darkPanel = Color(0xFF211E22);
  static const _darkPanelSoft = Color(0xFF2B262B);
  static const _darkRoseBronze = Color(0xFFC98980);
  static const _darkRoseSoft = Color(0xFFF0B9AF);
  static const _darkInk = Color(0xFFF8F2EE);
  static const _darkMuted = Color(0xFFB9ADB2);
  static const _darkWarmBorder = Color(0xFF494047);
  static const _lightCanvas = Color(0xFFF7F3F1);
  static const _lightPanel = Color(0xFFFFFBF9);
  static const _lightPanelSoft = Color(0xFFF1E8E5);
  static const _lightRoseBronze = Color(0xFF9B5F58);
  static const _lightRoseSoft = Color(0xFF7D4944);
  static const _lightInk = Color(0xFF251F21);
  static const _lightMuted = Color(0xFF74686C);
  static const _lightWarmBorder = Color(0xFFD8C9C5);

  final _uuid = const Uuid();
  final _secureStorage = const FlutterSecureStorage();
  StreamSubscription<AuthState>? _authSubscription;
  Timer? _noticeTimer;
  List<Map<String, dynamic>> _horses = const [];
  Map<String, String> _photoUrls = const {};
  List<Map<String, dynamic>> _overviewSchedule = const [];
  String? _heroPhotoUrl;
  Map<String, dynamic>? _workspace;
  List<Map<String, dynamic>> _horseSchedule = const [];
  Map<String, dynamic> _horseFeeding = const {};
  String? _selectedHorseId;
  bool _loading = true;
  bool _busy = false;
  bool _profileOpen = false;
  int _profileTabIndex = 0;
  bool _scheduleAgenda = false;
  int _schedulePeriodMode = 1;
  DateTime _scheduleFocus = DateTime.now();
  double? _uploadProgress;
  String? _error;
  String? _notice;

  SupabaseClient get _client => Supabase.instance.client;
  Map<String, dynamic>? get _selected =>
      _horses.cast<Map<String, dynamic>?>().firstWhere(
        (horse) => horse?['horse_id'] == _selectedHorseId,
        orElse: () => null,
      );

  @override
  void initState() {
    super.initState();
    _authSubscription = _client.auth.onAuthStateChange.listen((_) {
      if (mounted) unawaited(_load());
    });
    unawaited(_load());
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _noticeTimer?.cancel();
    super.dispose();
  }

  void _showNotice(String message) {
    _noticeTimer?.cancel();
    if (!mounted) return;
    setState(() => _notice = message);
    _noticeTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _notice == message) setState(() => _notice = null);
    });
  }

  List<Map<String, dynamic>> _rows(dynamic value) =>
      value is List
          ? value
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList(growable: false)
          : const [];

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  Future<void> _load({String? selectHorseId}) async {
    if (_client.auth.currentSession == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _horses = const [];
          _photoUrls = const {};
          _overviewSchedule = const [];
          _workspace = null;
          _horseSchedule = const [];
          _horseFeeding = const {};
          _selectedHorseId = null;
          _error = 'Meld je opnieuw aan om je paarden te bekijken.';
        });
      }
      return;
    }
    if (mounted) setState(() => _loading = true);
    try {
      final horses = _rows(await _client.rpc('list_canonical_horses'));
      final photoUrls = await _loadPhotoUrls(horses);
      final overviewNow = DateTime.now().toUtc();
      final overviewSchedule = _rows(
        await _client.rpc(
          'list_my_canonical_horse_schedule',
          params: {
            'p_from':
                overviewNow
                    .subtract(const Duration(days: 365))
                    .toIso8601String(),
            'p_through':
                overviewNow.add(const Duration(days: 365)).toIso8601String(),
          },
        ),
      );
      final wanted = selectHorseId ?? _selectedHorseId;
      final selected =
          horses.any((horse) => horse['horse_id'] == wanted)
              ? wanted
              : horses.isEmpty
              ? null
              : horses.first['horse_id']?.toString();
      final selectedHorse = horses.cast<Map<String, dynamic>?>().firstWhere(
        (horse) => horse?['horse_id']?.toString() == selected,
        orElse: () => null,
      );
      final heroPhotoUrl =
          selectedHorse == null
              ? null
              : await _loadPhotoUrl(
                selectedHorse['profile_media_asset_id']?.toString() ?? '',
                variant: 'original',
              );
      Map<String, dynamic>? workspace;
      var schedule = const <Map<String, dynamic>>[];
      var feeding = const <String, dynamic>{};
      if (selected != null) {
        workspace = _map(
          await _client.rpc(
            'get_canonical_horse_workspace',
            params: {'p_horse_id': selected},
          ),
        );
        workspace['organization_links'] = _rows(
          await _client.rpc(
            'get_horse_organization_links',
            params: {'p_horse_id': selected},
          ),
        );
        final now = DateTime.now().toUtc();
        final periodStart = now.subtract(const Duration(days: 365));
        final periodEnd = periodStart.add(const Duration(days: 730));
        schedule = _rows(
          await _client.rpc(
            'list_canonical_horse_schedule',
            params: {
              'p_horse_id': selected,
              'p_from': periodStart.toIso8601String(),
              'p_through': periodEnd.toIso8601String(),
            },
          ),
        );
        feeding = _map(
          await _client.rpc(
            'get_canonical_horse_feeding',
            params: {'p_horse_id': selected},
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _horses = horses;
        _photoUrls = photoUrls;
        _overviewSchedule = overviewSchedule;
        _heroPhotoUrl =
            heroPhotoUrl ?? (selected == null ? null : photoUrls[selected]);
        _selectedHorseId = selected;
        _workspace = workspace;
        _horseSchedule = schedule;
        _horseFeeding = feeding;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyError(error);
      });
    }
  }

  Future<Map<String, String>> _loadPhotoUrls(
    List<Map<String, dynamic>> horses,
  ) async {
    final entries = await Future.wait(
      horses.map((horse) async {
        final horseId = horse['horse_id']?.toString() ?? '';
        final assetId = horse['profile_media_asset_id']?.toString() ?? '';
        if (horseId.isEmpty || assetId.isEmpty) return null;
        final url = await _loadPhotoUrl(assetId, variant: 'thumbnail');
        return url == null ? null : MapEntry(horseId, url);
      }),
    );
    return Map.fromEntries(entries.whereType<MapEntry<String, String>>());
  }

  Future<String?> _loadPhotoUrl(
    String assetId, {
    required String variant,
  }) async {
    if (assetId.isEmpty) return null;
    final storageUri = Uri.tryParse(_client.storage.url);
    if (storageUri == null || storageUri.scheme != 'https') return null;
    try {
      final variantBody =
          variant == 'thumbnail'
              ? const <String, dynamic>{'variant': 'thumbnail'}
              : const <String, dynamic>{'variant': 'original'};
      final response = await _client.functions.invoke(
        'media-assets',
        body: {
          'action': 'canonical_download',
          'media_asset_id': assetId,
          ...variantBody,
        },
      );
      final data = _map(response.data);
      final uri = Uri.tryParse(data['signed_download_url']?.toString() ?? '');
      if (response.status != 200 ||
          uri == null ||
          uri.scheme != 'https' ||
          uri.host.toLowerCase() != storageUri.host.toLowerCase() ||
          uri.port != storageUri.port ||
          !uri.path.startsWith('/storage/v1/object/sign/horse-media/')) {
        return null;
      }
      return uri.toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _selectHorse(String id) async {
    setState(() {
      _selectedHorseId = id;
      _workspace = null;
      _loading = true;
      _profileOpen = true;
      _profileTabIndex = 0;
    });
    await _load(selectHorseId: id);
  }

  String _friendlyError(Object error) {
    final raw = error.toString();
    if (raw.contains('STALE_')) {
      return 'Deze gegevens zijn intussen gewijzigd. Ververs en probeer opnieuw.';
    }
    if (raw.contains('PRIMARY_HORSE_AUTHORITY_REQUIRED')) {
      return 'Alleen de hoofdbeheerder van dit paard kan dit uitvoeren.';
    }
    if (raw.contains('TRANSFER_NOT_AVAILABLE')) {
      return 'Deze overdracht is niet beschikbaar, verlopen of al afgehandeld.';
    }
    if (raw.contains('ACTIVE_VERIFIED_TARGET_REQUIRED')) {
      return 'Gebruik het bevestigde e-mailadres van een actief AVARYN-profiel.';
    }
    if (raw.contains('HORSE_PERMISSION_DENIED') ||
        raw.contains('HORSE_PERMISSION_REQUIRED') ||
        raw.contains('MEDIA_PERMISSION_REQUIRED') ||
        raw.contains('insufficient_privilege')) {
      return 'Je hebt geen toegang om dit onderdeel te bekijken of te wijzigen.';
    }
    if (raw.contains('PROFILE_MEDIA_UNAVAILABLE') ||
        raw.contains('MEDIA_UNAVAILABLE')) {
      return 'Deze foto is niet beschikbaar voor dit paard.';
    }
    if (raw.contains('MEDIA_VERSION_CONFLICT')) {
      return 'De foto is intussen gewijzigd. Ververs en probeer opnieuw.';
    }
    if (raw.contains('save_canonical_horse_feeding_round') ||
        raw.contains('PGRST202') ||
        raw.contains('schema cache')) {
      return 'Deze Alpha-omgeving mist nog de beveiligde voedingsupdate. Opslaan is beschikbaar nadat de goedgekeurde migration gecontroleerd is toegepast.';
    }
    return 'De beveiligde verbinding is niet beschikbaar. Controleer je internetverbinding en ververs.';
  }

  Future<void> _mutate(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await operation();
      await _load(selectHorseId: _selectedHorseId);
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  TextEditingController _controller([dynamic value]) =>
      TextEditingController(text: value?.toString() ?? '');

  DateTime? _dateValue(dynamic value) {
    final parts = value?.toString().split('-') ?? const <String>[];
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime.utc(year, month, day);
  }

  String? _dateIso(DateTime? value) =>
      value == null
          ? null
          : '${value.year.toString().padLeft(4, '0')}-'
              '${value.month.toString().padLeft(2, '0')}-'
              '${value.day.toString().padLeft(2, '0')}';

  String _displayDate(dynamic value) {
    final date = _dateValue(value);
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  String? _optional(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<String> _persistHorseProfile({
    required Map<String, dynamic>? horse,
    required TextEditingController displayName,
    required TextEditingController officialName,
    required TextEditingController breed,
    required TextEditingController discipline,
    required TextEditingController level,
    required TextEditingController color,
    required TextEditingController notes,
    required TextEditingController chip,
    required TextEditingController passport,
    required DateTime? birthDate,
    required DateTime? passportUntil,
    required String sex,
    required String status,
  }) async {
    if (horse == null) {
      final rows = _rows(
        await _client.rpc(
          'create_canonical_horse_profile',
          params: {
            'p_display_name': displayName.text.trim(),
            'p_official_name': _optional(officialName),
            'p_birth_date': _dateIso(birthDate),
            'p_sex': sex,
            'p_breed': _optional(breed),
            'p_discipline': _optional(discipline),
            'p_level': _optional(level),
            'p_color': _optional(color),
            'p_notes': _optional(notes),
            'p_chip_number': _optional(chip),
            'p_passport_number': _optional(passport),
            'p_passport_valid_until': _dateIso(passportUntil),
            'p_correlation_id': _uuid.v4(),
          },
        ),
      );
      if (rows.isEmpty || rows.first['horse_id'] == null) {
        throw StateError('HORSE_CREATE_UNAVAILABLE');
      }
      return rows.first['horse_id'].toString();
    }
    await _client.rpc(
      'update_canonical_horse_profile',
      params: {
        'p_horse_id': horse['horse_id'],
        'p_expected_row_version': horse['row_version'],
        'p_display_name': displayName.text.trim(),
        'p_official_name': _optional(officialName),
        'p_birth_date': _dateIso(birthDate),
        'p_sex': sex,
        'p_breed': _optional(breed),
        'p_discipline': _optional(discipline),
        'p_level': _optional(level),
        'p_color': _optional(color),
        'p_notes': _optional(notes),
        'p_chip_number': _optional(chip),
        'p_passport_number': _optional(passport),
        'p_passport_valid_until': _dateIso(passportUntil),
        'p_status': status,
        'p_correlation_id': _uuid.v4(),
      },
    );
    return horse['horse_id'].toString();
  }

  Future<bool> _confirmDiscard() async =>
      await showDialog<bool>(
        context: context,
        builder:
            (context) => _horseModalTheme(
              context,
              AlertDialog(
                title: Text('Wijzigingen niet opslaan?'),
                content: Text(
                  'Je ingevulde wijzigingen gaan verloren als je nu sluit.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('Doorgaan met bewerken'),
                  ),
                  FilledButton.tonal(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text('Niet opslaan'),
                  ),
                ],
              ),
            ),
      ) ??
      false;

  Future<void> _showHorseEditor({
    Map<String, dynamic>? horse,
    int initialSection = 0,
  }) async {
    final displayName = _controller(horse?['display_name']);
    final officialName = _controller(horse?['official_name']);
    final breed = _controller(horse?['breed']);
    final discipline = _controller(horse?['discipline']);
    final level = _controller(horse?['level']);
    final color = _controller(horse?['color']);
    final notes = _controller(horse?['notes']);
    final chip = _controller(horse?['chip_number']);
    final passport = _controller(horse?['passport_number']);
    var birthDate = _dateValue(horse?['birth_date']);
    var passportUntil = _dateValue(horse?['passport_valid_until']);
    var sex = horse?['sex']?.toString() ?? 'unknown';
    var status = horse?['lifecycle_status']?.toString() ?? 'active';
    var section =
        initialSection < 0 ? 0 : (initialSection > 3 ? 3 : initialSection);
    var saving = false;
    var dirty = false;
    String? inlineError;
    final controllers = [
      displayName,
      officialName,
      breed,
      discipline,
      level,
      color,
      notes,
      chip,
      passport,
    ];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => Theme(
                  data: _horseTheme(context),
                  child: PopScope(
                    canPop: false,
                    onPopInvokedWithResult: (didPop, _) {
                      if (!didPop && !saving) {
                        if (!dirty) {
                          Navigator.pop(context);
                        } else {
                          unawaited(
                            _confirmDiscard().then((discard) {
                              if (discard && context.mounted) {
                                Navigator.pop(context);
                              }
                            }),
                          );
                        }
                      }
                    },
                    child: AlertDialog(
                      backgroundColor: _panelTone,
                      surfaceTintColor: Colors.transparent,
                      insetPadding: EdgeInsets.fromLTRB(12, 12, 12, 12),
                      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                      contentPadding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                      actionsPadding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(color: _warmBorderTone),
                      ),
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AVARYN HORSE',
                            style: TextStyle(
                              color: _roseSoftTone,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.6,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            horse == null
                                ? 'Paard toevoegen'
                                : 'Profiel bewerken',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            horse == null
                                ? 'Begin met de roepnaam. De rest kan later.'
                                : 'Werk één logisch onderdeel tegelijk bij.',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(color: _mutedTone),
                          ),
                        ],
                      ),
                      content: SizedBox(
                        width: 680,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight:
                                ((MediaQuery.sizeOf(context).height -
                                            MediaQuery.viewInsetsOf(
                                              context,
                                            ).bottom) *
                                        .90)
                                    .clamp(220.0, 720.0)
                                    .toDouble(),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (horse == null) ...[
                                Text(
                                  'Alleen de roepnaam is nodig. De rest kun je later rustig aanvullen.',
                                ),
                                const SizedBox(height: 18),
                              ] else ...[
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final item in const [
                                      (0, 'Basis'),
                                      (1, 'Identificatie'),
                                      (2, 'Gezondheid'),
                                      (3, 'Betrokkenen'),
                                    ])
                                      ChoiceChip(
                                        label: Text(item.$2),
                                        selected: section == item.$1,
                                        onSelected:
                                            (_) => setDialogState(
                                              () => section = item.$1,
                                            ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                              ],
                              Flexible(
                                child: SingleChildScrollView(
                                  keyboardDismissBehavior:
                                      ScrollViewKeyboardDismissBehavior.onDrag,
                                  padding: const EdgeInsets.only(bottom: 24),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (horse == null || section == 0) ...[
                                        _field(
                                          displayName,
                                          'Roepnaam',
                                          required: true,
                                          errorText:
                                              inlineError == 'name'
                                                  ? 'Vul de roepnaam in.'
                                                  : null,
                                          onChanged:
                                              (_) => setDialogState(() {
                                                dirty = true;
                                                inlineError = null;
                                              }),
                                        ),
                                        _field(
                                          officialName,
                                          'Officiële naam (optioneel)',
                                          onChanged:
                                              (_) => setDialogState(
                                                () => dirty = true,
                                              ),
                                        ),
                                        if (horse != null) ...[
                                          _dateField(
                                            label: 'Geboortedatum (optioneel)',
                                            value: birthDate,
                                            firstDate: DateTime(1900),
                                            lastDate: DateTime.now(),
                                            onChanged:
                                                (value) => setDialogState(() {
                                                  birthDate = value;
                                                  dirty = true;
                                                }),
                                          ),
                                          DropdownButtonFormField<String>(
                                            initialValue: sex,
                                            decoration: const InputDecoration(
                                              labelText: 'Geslacht',
                                              border: OutlineInputBorder(),
                                            ),
                                            items: const [
                                              DropdownMenuItem(
                                                value: 'unknown',
                                                child: Text('Niet ingevuld'),
                                              ),
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
                                                (value) => setDialogState(() {
                                                  sex = value ?? 'unknown';
                                                  dirty = true;
                                                }),
                                          ),
                                          const SizedBox(height: 12),
                                          _field(
                                            breed,
                                            'Ras (optioneel)',
                                            onChanged:
                                                (_) => setDialogState(
                                                  () => dirty = true,
                                                ),
                                          ),
                                          _field(
                                            color,
                                            'Kleur (optioneel)',
                                            onChanged:
                                                (_) => setDialogState(
                                                  () => dirty = true,
                                                ),
                                          ),
                                          _field(
                                            discipline,
                                            'Discipline (optioneel)',
                                            onChanged:
                                                (_) => setDialogState(
                                                  () => dirty = true,
                                                ),
                                          ),
                                          _field(
                                            level,
                                            'Niveau (optioneel)',
                                            onChanged:
                                                (_) => setDialogState(
                                                  () => dirty = true,
                                                ),
                                          ),
                                        ],
                                      ],
                                      if (horse != null && section == 1) ...[
                                        const _SectionIntro(
                                          title: 'Identificatie',
                                          body:
                                              'Vul alleen gegevens in die je zeker weet.',
                                        ),
                                        _field(
                                          chip,
                                          'Chipnummer (optioneel)',
                                          onChanged:
                                              (_) => setDialogState(
                                                () => dirty = true,
                                              ),
                                        ),
                                      ],
                                      if (horse != null && section == 2) ...[
                                        const _SectionIntro(
                                          title: 'Gezondheid & documenten',
                                          body:
                                              'Paspoortgegevens en eigen notities blijven overzichtelijk bij elkaar.',
                                        ),
                                        _field(
                                          passport,
                                          'Paspoortnummer (optioneel)',
                                          onChanged:
                                              (_) => setDialogState(
                                                () => dirty = true,
                                              ),
                                        ),
                                        _dateField(
                                          label: 'Paspoort geldig tot en met',
                                          value: passportUntil,
                                          firstDate: DateTime(2000),
                                          lastDate: DateTime(2100),
                                          onChanged:
                                              (value) => setDialogState(() {
                                                passportUntil = value;
                                                dirty = true;
                                              }),
                                        ),
                                        _field(
                                          notes,
                                          'Notities (optioneel)',
                                          lines: 4,
                                          onChanged:
                                              (_) => setDialogState(
                                                () => dirty = true,
                                              ),
                                        ),
                                      ],
                                      if (horse != null && section == 3)
                                        const _SectionIntro(
                                          title: 'Betrokkenen & locatie',
                                          body:
                                              'Relaties, eigenaren, verblijf en stalkoppelingen beheer je rechtstreeks onder dit onderdeel op het paardprofiel. Zo blijven bevoegdheden en profielgegevens duidelijk gescheiden.',
                                        ),
                                      if (horse != null && section == 0) ...[
                                        const Divider(height: 28),
                                        DropdownButtonFormField<String>(
                                          initialValue: status,
                                          decoration: const InputDecoration(
                                            labelText: 'Profielstatus',
                                            border: OutlineInputBorder(),
                                            helperText:
                                                'Archiveren is een gevoelige actie; historie blijft bewaard.',
                                          ),
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'active',
                                              child: Text('Actief'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'archived',
                                              child: Text('Gearchiveerd'),
                                            ),
                                          ],
                                          onChanged:
                                              (value) => setDialogState(() {
                                                status = value ?? 'active';
                                                dirty = true;
                                              }),
                                        ),
                                      ],
                                      if (inlineError != null &&
                                          inlineError != 'name') ...[
                                        const SizedBox(height: 12),
                                        Text(
                                          inlineError!,
                                          style: TextStyle(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.error,
                                          ),
                                        ),
                                      ],
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
                          onPressed:
                              saving
                                  ? null
                                  : () async {
                                    if (!dirty || await _confirmDiscard()) {
                                      if (context.mounted)
                                        Navigator.pop(context);
                                    }
                                  },
                          child: Text('Annuleren'),
                        ),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(168, 50),
                          ),
                          onPressed:
                              saving
                                  ? null
                                  : () async {
                                    if (displayName.text.trim().isEmpty) {
                                      setDialogState(
                                        () => inlineError = 'name',
                                      );
                                      return;
                                    }
                                    setDialogState(() {
                                      saving = true;
                                      inlineError = null;
                                    });
                                    if (mounted) {
                                      setState(() {
                                        _busy = true;
                                        _error = null;
                                        _notice = null;
                                      });
                                    }
                                    try {
                                      final horseId =
                                          await _persistHorseProfile(
                                            horse: horse,
                                            displayName: displayName,
                                            officialName: officialName,
                                            breed: breed,
                                            discipline: discipline,
                                            level: level,
                                            color: color,
                                            notes: notes,
                                            chip: chip,
                                            passport: passport,
                                            birthDate: birthDate,
                                            passportUntil: passportUntil,
                                            sex: sex,
                                            status: status,
                                          );
                                      await _load(selectHorseId: horseId);
                                      if (!mounted || !context.mounted) return;
                                      setState(() => _profileOpen = true);
                                      _showNotice(
                                        horse == null
                                            ? 'Paard toegevoegd. Je kunt het profiel nu verder aanvullen.'
                                            : 'Wijzigingen opgeslagen.',
                                      );
                                      Navigator.pop(context);
                                    } catch (error) {
                                      if (!context.mounted) return;
                                      setDialogState(() {
                                        saving = false;
                                        inlineError = _friendlyError(error);
                                      });
                                    } finally {
                                      if (mounted)
                                        setState(() => _busy = false);
                                    }
                                  },
                          icon:
                              saving
                                  ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : Icon(Icons.check),
                          label: Text(
                            horse == null ? 'Paard toevoegen' : 'Opslaan',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
    for (final controller in controllers) {
      controller.dispose();
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int lines = 1,
    bool required = false,
    String? errorText,
    ValueChanged<String>? onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: TextField(
      controller: controller,
      maxLines: lines,
      minLines: lines,
      textInputAction:
          lines > 1 ? TextInputAction.newline : TextInputAction.next,
      scrollPadding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom + 140,
      ),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        suffixText: required ? 'Verplicht' : null,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  Widget _dateField({
    required String label,
    required DateTime? value,
    required DateTime firstDate,
    required DateTime lastDate,
    required ValueChanged<DateTime?> onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final today = DateTime.now();
        final initialDate =
            value ??
            (today.isBefore(firstDate)
                ? firstDate
                : today.isAfter(lastDate)
                ? lastDate
                : today);
        final picked = await showDatePicker(
          context: context,
          builder:
              (pickerContext, child) => _horseModalTheme(
                pickerContext,
                child ?? const SizedBox.shrink(),
              ),
          locale: const Locale('nl'),
          initialDate: initialDate,
          firstDate: firstDate,
          lastDate: lastDate,
          initialDatePickerMode: DatePickerMode.year,
          helpText: label,
          cancelText: 'Annuleren',
          confirmText: 'Kiezen',
        );
        if (picked != null) {
          onChanged(DateTime.utc(picked.year, picked.month, picked.day));
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon:
              value == null
                  ? Icon(Icons.calendar_today_outlined)
                  : IconButton(
                    tooltip: 'Datum wissen',
                    onPressed: () => onChanged(null),
                    icon: Icon(Icons.close),
                  ),
        ),
        child: Text(
          value == null ? 'Niet ingevuld' : _displayDate(_dateIso(value)),
        ),
      ),
    ),
  );

  Future<Uint8List?> _readPickedPhoto(
    file_picker.PlatformFile file,
    int maxBytes,
  ) async {
    if (file.bytes != null) {
      return file.bytes!.length <= maxBytes ? file.bytes : null;
    }
    final stream = file.readStream;
    if (stream == null) return null;
    final builder = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      if (builder.length + chunk.length > maxBytes) return null;
      builder.add(chunk);
      if (mounted) {
        setState(() => _uploadProgress = .1 + .2 * builder.length / file.size);
      }
    }
    return builder.takeBytes();
  }

  Uint8List _buildPhotoThumbnail(Uint8List bytes, String mimeType) {
    final image.Decoder decoder = switch (mimeType) {
      'image/jpeg' => image.JpegDecoder(),
      'image/png' => image.PngDecoder(),
      _ => throw StateError('MEDIA_CONTENT_TYPE_INVALID'),
    };
    final info = decoder.startDecode(bytes);
    if (info == null ||
        info.numFrames != 1 ||
        info.width <= 0 ||
        info.height <= 0 ||
        info.width * info.height * 4 > 32 * 1024 * 1024) {
      throw StateError('MEDIA_CONTENT_TYPE_INVALID');
    }
    final decoded = decoder.decodeFrame(0);
    if (decoded == null) throw StateError('MEDIA_CONTENT_TYPE_INVALID');
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
      final encoded =
          mimeType == 'image/jpeg'
              ? image.encodeJpg(resized, quality: 82)
              : image.encodePng(resized, level: 9);
      if (encoded.isNotEmpty && encoded.length <= 1024 * 1024) return encoded;
      maxDimension = (maxDimension * .75).floor();
    }
    throw StateError('MEDIA_THUMBNAIL_INVALID');
  }

  Future<Map<String, String>> _durablePhotoRequest({
    required String horseId,
    required String filename,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    final actorId = _client.auth.currentUser?.id ?? '';
    if (actorId.isEmpty) throw StateError('AUTHENTICATION_REQUIRED');
    final intent =
        '$actorId|$horseId|$filename|$mimeType|${sha256.convert(bytes)}';
    final digest = sha256.convert(utf8.encode(intent)).toString();
    final key = 'avaryn.c0091.photo.$digest';
    final stored = await _secureStorage.read(key: key);
    Map<String, dynamic> values = const {};
    if (stored != null && stored.isNotEmpty) {
      final decoded = jsonDecode(stored);
      if (decoded is! Map) throw StateError('DURABLE_REQUEST_STORAGE_REQUIRED');
      values = Map<String, dynamic>.from(decoded);
    }
    final request = <String, String>{
      'storage_key': key,
      'create_request_id':
          values['create_request_id']?.toString() ?? _uuid.v4(),
      'finalize_request_id':
          values['finalize_request_id']?.toString() ?? _uuid.v4(),
      'select_request_id':
          values['select_request_id']?.toString() ?? _uuid.v4(),
    };
    final encoded = jsonEncode({
      'create_request_id': request['create_request_id'],
      'finalize_request_id': request['finalize_request_id'],
      'select_request_id': request['select_request_id'],
    });
    if (stored != encoded) {
      await _secureStorage.write(key: key, value: encoded);
      if (await _secureStorage.read(key: key) != encoded) {
        throw StateError('DURABLE_REQUEST_STORAGE_REQUIRED');
      }
    }
    return request;
  }

  Future<void> _setCanonicalProfilePhoto({
    required Map<String, dynamic> horse,
    required String? mediaAssetId,
    required String requestId,
  }) async {
    await _client.rpc(
      'set_canonical_horse_profile_media',
      params: {
        'p_horse_id': horse['horse_id'],
        'p_media_asset_id': mediaAssetId,
        'p_expected_row_version': horse['row_version'],
        'p_request_id': requestId,
      },
    );
  }

  Future<void> _pickProfilePhoto() async {
    final horse = _selected;
    if (_busy || horse == null || horse['can_edit'] != true) return;
    final picked = await file_picker.FilePicker.pickFiles(
      type: file_picker.FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png'],
      allowMultiple: false,
      withData: false,
      withReadStream: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;
    final extension = (file.extension ?? '').toLowerCase();
    final mimeType =
        extension == 'jpg' || extension == 'jpeg'
            ? 'image/jpeg'
            : extension == 'png'
            ? 'image/png'
            : '';
    if (mimeType.isEmpty) {
      setState(() => _error = 'Kies een geldige JPG- of PNG-afbeelding.');
      return;
    }
    const maxBytes = 10 * 1024 * 1024;
    if (file.size <= 0 || file.size > maxBytes) {
      setState(() => _error = 'Kies een afbeelding kleiner dan 10 MB.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
      _uploadProgress = .05;
    });
    try {
      final bytes = await _readPickedPhoto(file, maxBytes);
      if (bytes == null || bytes.isEmpty || bytes.length != file.size) {
        throw StateError('MEDIA_FILE_INCOMPLETE');
      }
      final thumbnail = _buildPhotoThumbnail(bytes, mimeType);
      final request = await _durablePhotoRequest(
        horseId: horse['horse_id'].toString(),
        filename: file.name,
        mimeType: mimeType,
        bytes: bytes,
      );
      final created = await _client.functions.invoke(
        'media-assets',
        body: {
          'action': 'canonical_create',
          'horse_id': horse['horse_id'],
          'original_filename': file.name,
          'mime_type': mimeType,
          'request_id': request['create_request_id'],
        },
      );
      final createData = _map(created.data);
      if (created.status != 200) {
        throw StateError(createData['code']?.toString() ?? 'MEDIA_UNAVAILABLE');
      }
      final mediaAssetId = createData['media_asset_id']?.toString() ?? '';
      final rowVersion = int.tryParse(createData['row_version'].toString());
      final uploads = _rows(createData['uploads']);
      if (mediaAssetId.isEmpty || rowVersion == null) {
        throw StateError('MEDIA_UPLOAD_SIGNING_UNAVAILABLE');
      }
      if (createData['status'] != 'ready') {
        if (uploads.isEmpty)
          throw StateError('MEDIA_UPLOAD_SIGNING_UNAVAILABLE');
        var completed = 0;
        for (final upload in uploads) {
          final variant = upload['variant']?.toString() ?? '';
          final objectPath = upload['object_path']?.toString() ?? '';
          final uploadToken = upload['upload_token']?.toString() ?? '';
          final expectedMime = upload['expected_mime_type']?.toString() ?? '';
          final variantBytes =
              variant == 'original'
                  ? bytes
                  : variant == 'thumbnail'
                  ? thumbnail
                  : null;
          if (objectPath.isEmpty ||
              uploadToken.isEmpty ||
              expectedMime != mimeType ||
              variantBytes == null ||
              variantBytes.isEmpty) {
            throw StateError('MEDIA_VARIANT_MISMATCH');
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
            // Finalize verifies the server-side bytes and is authoritative when
            // a signed PUT response is ambiguous.
          }
          completed += 1;
          if (mounted) {
            setState(
              () => _uploadProgress = .35 + .4 * completed / uploads.length,
            );
          }
        }
        final finalized = await _client.functions.invoke(
          'media-assets',
          body: {
            'action': 'canonical_finalize',
            'media_asset_id': mediaAssetId,
            'expected_row_version': rowVersion,
            'request_id': request['finalize_request_id'],
          },
        );
        if (finalized.status != 200) {
          final data = _map(finalized.data);
          throw StateError(data['code']?.toString() ?? 'MEDIA_UNAVAILABLE');
        }
      }
      if (mounted) setState(() => _uploadProgress = .9);
      await _setCanonicalProfilePhoto(
        horse: horse,
        mediaAssetId: mediaAssetId,
        requestId: request['select_request_id']!,
      );
      try {
        await _secureStorage.delete(key: request['storage_key']!);
      } catch (_) {
        // A retained completed request remains safe and idempotent.
      }
      await _load(selectHorseId: horse['horse_id'].toString());
      _showNotice('Profielfoto veilig bijgewerkt.');
    } catch (error) {
      if (!mounted) return;
      final raw = error.toString();
      setState(
        () =>
            _error =
                raw.contains('MEDIA_CONTENT_TYPE_INVALID') ||
                        raw.contains('MEDIA_THUMBNAIL_INVALID')
                    ? 'Deze afbeelding kan niet veilig worden verwerkt. Kies een andere JPG of PNG.'
                    : raw.contains('MEDIA_FILE_INCOMPLETE')
                    ? 'Het gekozen bestand kon niet volledig worden gelezen.'
                    : _friendlyError(error),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _uploadProgress = null;
        });
      }
    }
  }

  Future<void> _removeProfilePhoto() async {
    final horse = _selected;
    if (_busy ||
        horse == null ||
        horse['can_edit'] != true ||
        horse['profile_media_asset_id'] == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => _horseModalTheme(
            context,
            AlertDialog(
              title: Text('Profielfoto verwijderen?'),
              content: Text(
                'De foto verdwijnt uit het profiel. De beveiligde mediahistorie blijft bewaard.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Annuleren'),
                ),
                FilledButton.tonal(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('Verwijderen'),
                ),
              ],
            ),
          ),
    );
    if (confirmed != true) return;
    await _mutate(() async {
      await _setCanonicalProfilePhoto(
        horse: horse,
        mediaAssetId: null,
        requestId: _uuid.v4(),
      );
    });
    _showNotice('Profielfoto verwijderd.');
  }

  Future<String?> _askText(
    String title,
    String label, {
    String initial = '',
    String confirm = 'Doorgaan',
  }) async {
    final controller = _controller(initial);
    return showDialog<String>(
      context: context,
      builder:
          (context) => _horseModalTheme(
            context,
            AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 460,
                child: _field(
                  controller,
                  label,
                  lines: label.contains('token') ? 3 : 1,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Annuleren'),
                ),
                FilledButton(
                  onPressed:
                      () => Navigator.pop(context, controller.text.trim()),
                  child: Text(confirm),
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _addRelationship() async {
    final email = await _askText('Relatie toevoegen', 'Bevestigd e-mailadres');
    if (email == null || email.isEmpty) return;
    final type = await _askText(
      'Type relatie',
      'Type: rider, trainer, groom, veterinarian of farrier',
      initial: 'rider',
    );
    if (type == null || type.isEmpty) return;
    await _mutate(() async {
      await _client.rpc(
        'start_horse_person_relationship_by_email',
        params: {
          'p_horse_id': _selectedHorseId,
          'p_profile_email': email,
          'p_relationship_type_code': type,
          'p_valid_from': DateTime.now().toUtc().toIso8601String(),
          'p_correlation_id': _uuid.v4(),
        },
      );
    });
  }

  Future<void> _addOwner() async {
    final email = await _askText(
      'Eigenaar vastleggen',
      'Bevestigd e-mailadres',
    );
    if (email == null || email.isEmpty) return;
    final percentage = await _askText(
      'Eigendomspercentage',
      'Percentage (0–100)',
      initial: '100',
    );
    final parsed = double.tryParse(percentage ?? '');
    if (parsed == null) return;
    await _mutate(() async {
      await _client.rpc(
        'start_horse_person_ownership_by_email',
        params: {
          'p_horse_id': _selectedHorseId,
          'p_owner_email': email,
          'p_percentage': parsed,
          'p_valid_from': DateTime.now().toUtc().toIso8601String(),
          'p_correlation_id': _uuid.v4(),
        },
      );
    });
  }

  Future<void> _addDelegation() async {
    final email = _controller();
    final days = _controller('30');
    final permissions = <String>{'horse.view', 'horse.edit'};
    final accepted = await showDialog<bool>(
      context: context,
      builder:
          (context) => _horseModalTheme(
            context,
            StatefulBuilder(
              builder:
                  (context, setDialogState) => AlertDialog(
                    title: Text('Beheerder machtigen'),
                    content: SizedBox(
                      width: 520,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _field(email, 'Bevestigd e-mailadres'),
                            _field(days, 'Geldig aantal dagen (maximaal 365)'),
                            for (final permission in const [
                              'horse.view',
                              'horse.edit',
                              'horse.manage',
                              'horse.assign',
                              'horse.share',
                            ])
                              CheckboxListTile(
                                value: permissions.contains(permission),
                                title: Text(permission),
                                dense: true,
                                onChanged:
                                    (checked) => setDialogState(() {
                                      checked == true
                                          ? permissions.add(permission)
                                          : permissions.remove(permission);
                                    }),
                              ),
                            Text(
                              'Het hoofdbeheer overdragen kan nooit worden gedelegeerd.',
                            ),
                          ],
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('Annuleren'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text('Machtigen'),
                      ),
                    ],
                  ),
            ),
          ),
    );
    final validDays = int.tryParse(days.text) ?? 0;
    if (accepted != true ||
        email.text.trim().isEmpty ||
        permissions.isEmpty ||
        validDays < 1 ||
        validDays > 365) {
      return;
    }
    final now = DateTime.now().toUtc();
    await _mutate(() async {
      await _client.rpc(
        'grant_horse_delegated_administrator_by_email',
        params: {
          'p_horse_id': _selectedHorseId,
          'p_target_email': email.text.trim(),
          'p_permission_codes': permissions.toList()..sort(),
          'p_valid_from': now.toIso8601String(),
          'p_valid_until': now.add(Duration(days: validDays)).toIso8601String(),
          'p_correlation_id': _uuid.v4(),
        },
      );
    });
  }

  Future<void> _proposeOrganizationLink() async {
    final organizationId = await _askText(
      'Paard-stalkoppeling aanvragen',
      'Canonical organization UUID',
    );
    if (organizationId == null || organizationId.isEmpty) return;
    final linkType = await _askText(
      'Type samenwerking',
      'Linktype',
      initial: 'training_provider',
      confirm: 'Aanvragen',
    );
    if (linkType == null || linkType.isEmpty) return;
    await _mutate(() async {
      await _client.rpc(
        'propose_organization_horse_link',
        params: {
          'p_horse_id': _selectedHorseId,
          'p_organization_id': organizationId,
          'p_link_type_code': linkType,
          'p_initiating_context': 'horse',
          'p_correlation_id': _uuid.v4(),
        },
      );
    });
  }

  Future<void> _respondOrganizationLink(
    Map<String, dynamic> link,
    String action,
  ) async {
    await _mutate(() async {
      await _client.rpc(
        'respond_organization_horse_link',
        params: {
          'p_link_id': link['id'],
          'p_expected_row_version': link['row_version'],
          'p_action': action,
          'p_correlation_id': _uuid.v4(),
        },
      );
    });
  }

  Future<void> _grantOrganizationRoleHorseAccess(
    Map<String, dynamic> link,
  ) async {
    final roles = _rows(link['roles']);
    if (roles.isEmpty) return;
    var roleId = roles.first['id']?.toString() ?? '';
    var permission = 'horse.view';
    final accepted = await showDialog<bool>(
      context: context,
      builder:
          (context) => _horseModalTheme(
            context,
            StatefulBuilder(
              builder:
                  (context, setDialogState) => AlertDialog(
                    title: Text('Expliciete paardtoegang verlenen'),
                    content: SizedBox(
                      width: 520,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: roleId,
                            decoration: const InputDecoration(
                              labelText: 'Stalrol',
                            ),
                            items: roles
                                .map(
                                  (role) => DropdownMenuItem(
                                    value: role['id']?.toString(),
                                    child: Text(role['name']?.toString() ?? ''),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged:
                                (value) => setDialogState(
                                  () => roleId = value ?? roleId,
                                ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: permission,
                            decoration: const InputDecoration(
                              labelText: 'Horse capability',
                            ),
                            items: const [
                                  'horse.view',
                                  'horse.edit',
                                  'horse.manage',
                                  'horse.assign',
                                  'horse.share',
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
                                  () => permission = value ?? permission,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Deze grant geldt alleen voor dit paard, deze stalrol en deze capability. De koppeling zelf geeft nul toegang.',
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('Annuleren'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text('Verlenen'),
                      ),
                    ],
                  ),
            ),
          ),
    );
    if (accepted != true || roleId.isEmpty) return;
    final now = DateTime.now().toUtc();
    await _mutate(() async {
      await _client.rpc(
        'grant_horse_organization_role_permission',
        params: {
          'p_horse_id': _selectedHorseId,
          'p_role_id': roleId,
          'p_permission_code': permission,
          'p_link_id': link['id'],
          'p_valid_from': now.toIso8601String(),
          'p_valid_until': now.add(const Duration(days: 90)).toIso8601String(),
          'p_reason_code': 'LINK_BOUND',
          'p_correlation_id': _uuid.v4(),
        },
      );
    });
  }

  Future<void> _startTransfer() async {
    final email = await _askText(
      'Hoofdbeheer overdragen',
      'Bevestigd e-mailadres van de ontvanger',
      confirm: 'Overdracht starten',
    );
    if (email == null || email.isEmpty) return;
    String? token;
    String? expiresAt;
    await _mutate(() async {
      final rows = _rows(
        await _client.rpc(
          'initiate_horse_authority_transfer_by_email',
          params: {
            'p_horse_id': _selectedHorseId,
            'p_recipient_email': email,
            'p_correlation_id': _uuid.v4(),
          },
        ),
      );
      if (rows.isNotEmpty) {
        token = rows.first['transfer_token']?.toString();
        expiresAt = rows.first['expires_at']?.toString();
      }
    });
    if (!mounted || token == null || token!.isEmpty) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => _horseModalTheme(
            context,
            AlertDialog(
              title: Text('Eenmalige overdrachtcode'),
              content: SizedBox(
                width: 560,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Deel deze code uitsluitend via een veilig kanaal met de bedoelde ontvanger. AVARYN toont hem niet opnieuw.',
                    ),
                    const SizedBox(height: 16),
                    SelectableText(
                      token!,
                      style: TextStyle(fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 12),
                    Text('Geldig tot: ${_displayDateTime(expiresAt)}'),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      () async =>
                          Clipboard.setData(ClipboardData(text: token!)),
                  child: Text('Code kopiëren'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Ik heb de code veilig gedeeld'),
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _receiveTransfer() async {
    final token = await _askText(
      'Overdracht ontvangen',
      'Plak de eenmalige overdrachtcode',
      confirm: 'Controleren',
    );
    if (token == null || token.isEmpty) return;
    try {
      final preview = _rows(
        await _client.rpc(
          'preview_horse_authority_transfer',
          params: {'p_transfer_token': token},
        ),
      );
      if (!mounted || preview.isEmpty) {
        throw StateError('TRANSFER_NOT_AVAILABLE');
      }
      final item = preview.first;
      final action = await showDialog<String>(
        context: context,
        builder:
            (context) => _horseModalTheme(
              context,
              AlertDialog(
                title: Text('Overdracht van hoofdbeheer'),
                content: Text(
                  'Paard: ${item['horse_name']}\nGeldig tot: ${_displayDateTime(item['expires_at'])}\n\nNa acceptatie ben jij de enige hoofdbeheerder van dit paard.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Later'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'decline'),
                    child: Text('Weigeren'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, 'accept'),
                    child: Text('Accepteren'),
                  ),
                ],
              ),
            ),
      );
      if (action == null) return;
      await _mutate(() async {
        await _client.rpc(
          'respond_horse_authority_transfer',
          params: {
            'p_transfer_token': token,
            'p_action': action,
            'p_correlation_id': _uuid.v4(),
          },
        );
      });
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    }
  }

  Future<void> _endRecord(String rpc, Map<String, dynamic> params) async {
    await _mutate(
      () async =>
          _client.rpc(rpc, params: {...params, 'p_correlation_id': _uuid.v4()}),
    );
  }

  String _displayDateTime(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (parsed == null) return 'onbekend';
    return '${parsed.day.toString().padLeft(2, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.year} ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  }

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Color get _canvasTone => _isDarkMode ? _darkCanvas : _lightCanvas;
  Color get _panelTone => _isDarkMode ? _darkPanel : _lightPanel;
  Color get _panelSoftTone => _isDarkMode ? _darkPanelSoft : _lightPanelSoft;
  Color get _roseBronzeTone => _isDarkMode ? _darkRoseBronze : _lightRoseBronze;
  Color get _roseSoftTone => _isDarkMode ? _darkRoseSoft : _lightRoseSoft;
  Color get _inkTone => _isDarkMode ? _darkInk : _lightInk;
  Color get _mutedTone => _isDarkMode ? _darkMuted : _lightMuted;
  Color get _warmBorderTone => _isDarkMode ? _darkWarmBorder : _lightWarmBorder;

  ThemeData _horseTheme(BuildContext context) {
    final base = Theme.of(context);
    final textTheme = base.textTheme.apply(
      bodyColor: _inkTone,
      displayColor: _inkTone,
    );
    return base.copyWith(
      brightness: base.brightness,
      scaffoldBackgroundColor: _canvasTone,
      canvasColor: _canvasTone,
      cardColor: _panelTone,
      colorScheme: ColorScheme.fromSeed(
        brightness: base.brightness,
        seedColor: _roseBronzeTone,
        primary: _roseBronzeTone,
        onPrimary: _canvasTone,
        secondary: _roseBronzeTone,
        onSecondary: _canvasTone,
        surface: _panelTone,
        onSurface: _inkTone,
        outline: _warmBorderTone,
        error: Color(0xFFE38B85),
      ),
      textTheme: textTheme,
      dividerTheme: DividerThemeData(color: _warmBorderTone),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _panelSoftTone,
        labelStyle: TextStyle(color: _mutedTone),
        hintStyle: TextStyle(color: _mutedTone),
        helperStyle: TextStyle(color: _mutedTone),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _warmBorderTone),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _warmBorderTone),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _roseBronzeTone, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _roseBronzeTone,
          foregroundColor: _canvasTone,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _roseSoftTone,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: _warmBorderTone),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _roseSoftTone,
          minimumSize: const Size(44, 44),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: _panelSoftTone,
        selectedColor: _roseBronzeTone.withValues(alpha: .18),
        side: BorderSide(color: _warmBorderTone),
        labelStyle: TextStyle(color: _inkTone),
        secondaryLabelStyle: TextStyle(color: _roseSoftTone),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }

  Widget _horseModalTheme(BuildContext modalContext, Widget child) =>
      Theme(data: _horseTheme(modalContext), child: child);

  @override
  Widget build(BuildContext context) {
    final horseTheme = _horseTheme(context);
    final colors = horseTheme.colorScheme;
    return Theme(
      data: horseTheme,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: ColoredBox(
          color: _canvasTone,
          child: Column(
            children: [
              if (_uploadProgress != null)
                LinearProgressIndicator(
                  value: _uploadProgress,
                  minHeight: 3,
                  backgroundColor: _panelSoftTone,
                  color: _roseBronzeTone,
                ),
              if (_error != null)
                _messageBar(
                  icon: Icons.error_outline,
                  message: _error!,
                  color: colors.error,
                  actions: [
                    TextButton(
                      onPressed: () => setState(() => _error = null),
                      child: Text('Sluiten'),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _load,
                      child: Text('Opnieuw proberen'),
                    ),
                  ],
                ),
              if (_notice != null)
                _messageBar(
                  icon: Icons.check_circle_outline,
                  message: _notice!,
                  color: _roseBronzeTone,
                  actions: [
                    IconButton(
                      tooltip: 'Melding sluiten',
                      onPressed: () => setState(() => _notice = null),
                      icon: Icon(Icons.close),
                    ),
                  ],
                ),
              Expanded(
                child:
                    _loading
                        ? _loadingSkeleton(colors)
                        : _horses.isEmpty
                        ? _emptyState(colors)
                        : _profileOpen && _selected != null
                        ? _horseDetail(colors)
                        : _horseOverview(colors),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _messageBar({
    required IconData icon,
    required String message,
    required Color color,
    required List<Widget> actions,
  }) => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
    padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
    decoration: BoxDecoration(
      color: _panelTone,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: .55)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(message, maxLines: 3)),
          ],
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              runSpacing: 4,
              children: actions,
            ),
          ),
        ],
      ],
    ),
  );

  Widget _loadingSkeleton(ColorScheme colors) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 28, 20, 96),
    children: [
      Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 112,
                height: 14,
                decoration: BoxDecoration(
                  color: _panelSoftTone,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: 260,
                height: 42,
                decoration: BoxDecoration(
                  color: _panelSoftTone,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: List.generate(
                  3,
                  (_) => Container(
                    width: 520,
                    height: 230,
                    decoration: BoxDecoration(
                      color: _panelTone,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _warmBorderTone),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _emptyState(ColorScheme colors) => CustomScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    slivers: [
      SliverToBoxAdapter(child: _overviewIntro()),
      SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 8, 20, 96),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 38),
              decoration: BoxDecoration(
                color: _panelTone,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: _warmBorderTone),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: 92,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: CustomPaint(
                        painter: _AvarynHorseHeadPainter(
                          backgroundColor: _panelSoftTone,
                          silhouetteColor: _roseSoftTone,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Jouw eerste atleet',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    'Begin met een roepnaam. Foto, profiel en betrokkenen kun je daarna in alle rust aanvullen.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _mutedTone, height: 1.45),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : () => _showHorseEditor(),
                      icon: Icon(Icons.add),
                      label: Text('Paard toevoegen'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: _busy ? null : _receiveTransfer,
                    icon: Icon(Icons.input),
                    label: Text('Overdracht ontvangen'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );

  String _athleteSubtitle() {
    final count = _horses.length;
    if (count == 1) return 'Eén atleet, met een eigen ritme.';
    const words = <int, String>{
      2: 'Twee',
      3: 'Drie',
      4: 'Vier',
      5: 'Vijf',
      6: 'Zes',
      7: 'Zeven',
      8: 'Acht',
      9: 'Negen',
      10: 'Tien',
    };
    return '${words[count] ?? count} atleten, elk met hun eigen ritme.';
  }

  Widget _overviewIntro() => Align(
    alignment: Alignment.center,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1080),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(alignment: Alignment.centerLeft, child: _AvarynWordmark()),
            const SizedBox(height: 34),
            Text(
              'PAARDEN',
              style: TextStyle(
                color: _roseSoftTone,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.7,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Paarden',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: _inkTone,
                fontWeight: FontWeight.w700,
                letterSpacing: -.8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _horses.isEmpty
                  ? 'Een eigen plek voor iedere atleet.'
                  : _athleteSubtitle(),
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: _mutedTone),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : () => _showHorseEditor(),
                icon: Icon(Icons.add),
                label: Text('Paard toevoegen'),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _busy ? null : _receiveTransfer,
                icon: Icon(Icons.input),
                label: Text('Overdracht ontvangen'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _horseOverview(ColorScheme colors) => RefreshIndicator(
    onRefresh: _load,
    child: CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _overviewIntro()),
        SliverList.builder(
          itemCount: _horses.length,
          itemBuilder:
              (context, index) => Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      index == 0 ? 4 : 8,
                      20,
                      index == _horses.length - 1 ? 96 : 8,
                    ),
                    child: _horseCard(_horses[index]),
                  ),
                ),
              ),
        ),
      ],
    ),
  );

  Widget _horseCard(Map<String, dynamic> horse) {
    final id = horse['horse_id']?.toString() ?? '';
    final official = horse['official_name']?.toString().trim() ?? '';
    final display = horse['display_name']?.toString().trim() ?? 'Paard';
    final details = <String>[
      if ((horse['discipline']?.toString().trim() ?? '').isNotEmpty)
        horse['discipline'].toString(),
      if ((horse['level']?.toString().trim() ?? '').isNotEmpty)
        horse['level'].toString(),
    ];
    final next = _nextScheduleForHorse(id);
    return Semantics(
      button: true,
      label: 'Open het profiel van $display',
      child: Material(
        color: _panelTone,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: _warmBorderTone),
          borderRadius: BorderRadius.circular(24),
        ),
        child: InkWell(
          onTap: id.isEmpty ? null : () => _selectHorse(id),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final image = SizedBox(
                width: compact ? 116 : 250,
                height: compact ? 156 : 246,
                child: _horseImage(id),
              );
              final content = Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 15 : 22,
                  compact ? 16 : 22,
                  compact ? 14 : 20,
                  compact ? 15 : 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ATLEET',
                      style: TextStyle(
                        color: _roseSoftTone,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      display,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (official.isNotEmpty &&
                        official.toLowerCase() != display.toLowerCase()) ...[
                      const SizedBox(height: 2),
                      Text(
                        official,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: _mutedTone),
                      ),
                    ],
                    const SizedBox(height: 14),
                    if (details.isNotEmpty)
                      Text(
                        details.join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: _roseSoftTone),
                      )
                    else
                      Text(
                        'Profiel kan nog worden aangevuld',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: _mutedTone),
                      ),
                    const SizedBox(height: 16),
                    Divider(color: _warmBorderTone),
                    const SizedBox(height: 10),
                    _overviewSignal(
                      Icons.priority_high,
                      'ACTUEEL AANDACHTSPUNT',
                      'Geen aandachtspunt',
                    ),
                    const SizedBox(height: 11),
                    _overviewSignal(
                      Icons.schedule,
                      'EERSTVOLGENDE ACTIVITEIT',
                      next == null
                          ? 'Nog geen activiteit gepland'
                          : '${_displayScheduleMoment(_scheduleDate(next))} · ${_scheduleKindLabel(next['item_kind'])}',
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (horse['lifecycle_status'] == 'archived')
                          Text(
                            'Gearchiveerd',
                            style: TextStyle(color: _mutedTone, fontSize: 12),
                          ),
                        const Spacer(),
                        Icon(
                          Icons.arrow_forward,
                          color: _roseBronzeTone,
                          size: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              );
              return compact
                  ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [image, Expanded(child: content)],
                  )
                  : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [image, Expanded(child: content)],
                  );
            },
          ),
        ),
      ),
    );
  }

  Map<String, dynamic>? _nextScheduleForHorse(String horseId) {
    final now = DateTime.now();
    final rows = _overviewSchedule
      .where(
        (row) =>
            row['horse_id']?.toString() == horseId &&
            row['state']?.toString() != 'cancelled' &&
            !_scheduleDate(row).isBefore(now),
      )
      .toList(growable: false)..sort(
      (left, right) => _scheduleDate(left).compareTo(_scheduleDate(right)),
    );
    return rows.isEmpty ? null : rows.first;
  }

  String _displayScheduleMoment(DateTime value) =>
      '${value.day} ${_monthLabel(value.month)} · '
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';

  Widget _overviewSignal(IconData icon, String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _panelSoftTone,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: _roseBronzeTone),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _mutedTone,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: .7,
              ),
            ),
            const SizedBox(height: 2),
            Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    ],
  );

  Widget _horseImage(String horseId) {
    final url = _photoUrls[horseId];
    return url == null
        ? _horseFallbackImage()
        : Image.network(
          url,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (_, __, ___) => _horseFallbackImage(),
        );
  }

  Widget _horseFallbackImage() =>
      const AvarynOrionPhoto(width: double.infinity, height: double.infinity);

  Widget _horseDetail(ColorScheme colors) {
    final horse = _selected;
    if (horse == null) return const Center(child: Text('Selecteer een paard.'));
    final workspace = _workspace ?? const <String, dynamic>{};
    return RefreshIndicator(
      onRefresh: () => _load(selectHorseId: _selectedHorseId),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 96),
        children: [
          Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _profileHeader(horse, compactIdentity: _profileTabIndex != 2),
                  const SizedBox(height: 16),
                  _profileNavigation(),
                  const SizedBox(height: 28),
                  if (_profileTabIndex == 2) ...[
                    _sectionHeading(
                      'In één oogopslag',
                      'Het profiel van je paard, rustig en overzichtelijk bij elkaar.',
                    ),
                    const SizedBox(height: 14),
                    _informationCard(
                      title: 'Basisinformatie',
                      icon: Icons.info_outline,
                      facts: [
                        ('Geboortedatum', _displayDate(horse['birth_date'])),
                        ('Geslacht', _sexLabel(horse['sex'])),
                        ('Ras', _textValue(horse['breed'])),
                        ('Kleur', _textValue(horse['color'])),
                        ('Discipline', _textValue(horse['discipline'])),
                        ('Niveau', _textValue(horse['level'])),
                      ],
                      emptyMessage:
                          'Basisgegevens kunnen nog worden aangevuld.',
                      onEdit:
                          horse['can_edit'] == true
                              ? () => _showHorseEditor(
                                horse: horse,
                                initialSection: 0,
                              )
                              : null,
                    ),
                    const SizedBox(height: 14),
                    _informationCard(
                      title: 'Identificatie',
                      icon: Icons.badge_outlined,
                      facts: [('Chipnummer', _textValue(horse['chip_number']))],
                      emptyMessage:
                          'Er zijn nog geen identificatiegegevens ingevuld.',
                      onEdit:
                          horse['can_edit'] == true
                              ? () => _showHorseEditor(
                                horse: horse,
                                initialSection: 1,
                              )
                              : null,
                    ),
                    const SizedBox(height: 14),
                    _informationCard(
                      title: 'Gezondheid & documenten',
                      icon: Icons.health_and_safety_outlined,
                      facts: [
                        (
                          'Paspoortnummer',
                          _textValue(horse['passport_number']),
                        ),
                        (
                          'Paspoort geldig tot en met',
                          _displayDate(horse['passport_valid_until']),
                        ),
                        ('Notities', _textValue(horse['notes'])),
                      ],
                      emptyMessage:
                          'Documentgegevens en notities kunnen later worden toegevoegd.',
                      onEdit:
                          horse['can_edit'] == true
                              ? () => _showHorseEditor(
                                horse: horse,
                                initialSection: 2,
                              )
                              : null,
                    ),
                    const SizedBox(height: 14),
                    _dailyConnectionsCard(),
                    const SizedBox(height: 30),
                    _sectionHeading(
                      'Betrokkenen & locatie',
                      'Personen, verblijf en stalkoppelingen blijven afzonderlijk en geven nooit vanzelf toegang.',
                    ),
                    const SizedBox(height: 14),
                    _organizationLinksCard(
                      horse,
                      _rows(workspace['organization_links']),
                    ),
                    const SizedBox(height: 14),
                    _recordsCard(
                      'Eigenaren',
                      'Juridisch eigendom staat los van het beheer van het profiel.',
                      _rows(workspace['person_ownerships']),
                      horse['can_manage'] == true ? _addOwner : null,
                      (row) => '${row['profile_name']} · ${row['percentage']}%',
                      endRpc: 'end_horse_person_ownership',
                      idParam: 'p_ownership_id',
                    ),
                    const SizedBox(height: 14),
                    _recordsCard(
                      'Betrokken personen',
                      'Ruiters, trainers en verzorgers krijgen door registratie geen impliciete bevoegdheid of toegang.',
                      _rows(workspace['relationships']),
                      horse['can_manage'] == true ? _addRelationship : null,
                      (row) =>
                          '${row['profile_name']} · ${_relationshipLabel(row['relationship_type'])}',
                      endRpc: 'end_horse_person_relationship',
                      idParam: 'p_relationship_id',
                    ),
                    const SizedBox(height: 14),
                    _recordsCard(
                      'Verblijf',
                      'De verblijfslocatie is informatief en verleent geen toegang.',
                      [
                        ..._rows(workspace['organization_ownerships']),
                        ..._rows(workspace['residencies']),
                      ],
                      null,
                      (row) =>
                          '${row['organization_name']} · ${row.containsKey('percentage') ? '${row['percentage']}% eigendom' : 'verblijf'}',
                    ),
                    const SizedBox(height: 30),
                    _sectionHeading(
                      'Beheer & toegang',
                      'Authority, overdracht en historie blijven volledig beschikbaar in deze secundaire beheersectie.',
                    ),
                    const SizedBox(height: 14),
                    _authorityCard(horse, workspace),
                    const SizedBox(height: 14),
                    _auditCard(_rows(workspace['audit'])),
                  ] else if (_profileTabIndex == 0)
                    _planningTab(horse)
                  else
                    _feedingTab(horse),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileHeader(
    Map<String, dynamic> horse, {
    bool compactIdentity = false,
  }) {
    final id = horse['horse_id']?.toString() ?? '';
    final display = horse['display_name']?.toString().trim() ?? 'Paard';
    final official = horse['official_name']?.toString().trim() ?? '';
    final chips = <String>[
      _textValue(horse['discipline']),
      _textValue(horse['level']),
      _ageLabel(horse['birth_date']),
      _sexLabel(horse['sex']),
      if (horse['lifecycle_status'] == 'archived') 'Gearchiveerd',
    ].where((value) => value.isNotEmpty).toList(growable: false);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final heroHeight =
            compactIdentity
                ? (compact ? 300.0 : 280.0)
                : (compact ? 520.0 : 460.0);
        return ClipRRect(
          borderRadius: BorderRadius.circular(compact ? 22 : 28),
          child: SizedBox(
            height: heroHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _heroImage(id),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x26000000),
                        Color(0x33000000),
                        Color(0xE6141215),
                      ],
                      stops: [0, .42, 1],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(compact ? 18 : 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          _heroAction(
                            icon: Icons.arrow_back,
                            label: 'Paarden',
                            onPressed:
                                () => setState(() {
                                  _profileOpen = false;
                                  _notice = null;
                                }),
                          ),
                          const Spacer(),
                          const _AvarynWordmark(compact: true, onHero: true),
                          if (horse['can_edit'] == true &&
                              horse['profile_media_asset_id'] != null) ...[
                            const SizedBox(width: 8),
                            PopupMenuButton<String>(
                              tooltip: 'Meer fotoacties',
                              color: _panelTone,
                              iconColor: _inkTone,
                              onSelected: (value) {
                                if (value == 'remove') {
                                  unawaited(_removeProfilePhoto());
                                }
                              },
                              itemBuilder:
                                  (_) => const [
                                    PopupMenuItem(
                                      value: 'remove',
                                      child: Text('Foto verwijderen'),
                                    ),
                                  ],
                            ),
                          ],
                        ],
                      ),
                      const Spacer(),
                      Text(
                        'PAARDPROFIEL',
                        style: TextStyle(
                          color: _roseSoftTone,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.7,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        display,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: (compact
                                ? Theme.of(context).textTheme.displaySmall
                                : Theme.of(context).textTheme.displayMedium)
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              height: 1.02,
                              letterSpacing: -1,
                            ),
                      ),
                      if (official.isNotEmpty &&
                          official.toLowerCase() != display.toLowerCase()) ...[
                        const SizedBox(height: 6),
                        Text(
                          official,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: Colors.white70),
                        ),
                      ],
                      if (!compactIdentity && chips.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [for (final chip in chips) _heroChip(chip)],
                        ),
                      ],
                      if (!compactIdentity) ...[
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            if (horse['can_edit'] == true)
                              FilledButton.icon(
                                onPressed:
                                    _busy
                                        ? null
                                        : () => _showHorseEditor(horse: horse),
                                icon: Icon(Icons.edit_outlined),
                                label: Text('Profiel bewerken'),
                              ),
                            if (horse['can_edit'] == true)
                              OutlinedButton.icon(
                                onPressed: _busy ? null : _pickProfilePhoto,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: .55),
                                  ),
                                  backgroundColor: Colors.black.withValues(
                                    alpha: .24,
                                  ),
                                ),
                                icon: Icon(Icons.add_a_photo_outlined),
                                label: Text(
                                  horse['profile_media_asset_id'] == null
                                      ? 'Foto toevoegen'
                                      : 'Foto wijzigen',
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _heroImage(String horseId) =>
      _heroPhotoUrl == null
          ? _horseFallbackImage()
          : Image.network(
            _heroPhotoUrl!,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => _horseFallbackImage(),
          );

  Widget _heroAction({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) => TextButton.icon(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: Colors.black.withValues(alpha: .32),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    icon: Icon(icon, size: 19),
    label: Text(label),
  );

  Widget _heroChip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .34),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.white.withValues(alpha: .3)),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _profileNavigation() => Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: _panelTone,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _warmBorderTone),
    ),
    child: Row(
      children: [
        Expanded(
          child: _profileTab(
            icon: Icons.calendar_month_outlined,
            label: 'Planning',
            selected: _profileTabIndex == 0,
            onPressed: () => setState(() => _profileTabIndex = 0),
          ),
        ),
        Expanded(
          child: _profileTab(
            icon: Icons.restaurant_menu_outlined,
            label: 'Voeding',
            selected: _profileTabIndex == 1,
            onPressed: () => setState(() => _profileTabIndex = 1),
          ),
        ),
        Expanded(
          child: _profileTab(
            icon: Icons.dashboard_outlined,
            label: 'Overzicht',
            selected: _profileTabIndex == 2,
            onPressed: () => setState(() => _profileTabIndex = 2),
          ),
        ),
      ],
    ),
  );

  Widget _profileTab({
    required IconData icon,
    required String label,
    bool selected = false,
    VoidCallback? onPressed,
  }) => InkWell(
    onTap: selected ? null : onPressed,
    borderRadius: BorderRadius.circular(13),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      decoration: BoxDecoration(
        color: selected ? _roseBronzeTone : Colors.transparent,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 19, color: selected ? _canvasTone : _mutedTone),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? _canvasTone : _mutedTone,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _sectionHeading(String title, String body) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 6),
      Text(body, style: TextStyle(color: _mutedTone, height: 1.45)),
    ],
  );

  Widget _dailyConnectionsCard() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _panelTone,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _warmBorderTone),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dagelijks ritme',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 7),
        Text(
          'Training, planning en voeding blijven verbonden met het paardprofiel. AVARYN toont alleen signalen die werkelijk beschikbaar zijn.',
          style: TextStyle(color: _mutedTone, height: 1.45),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            OutlinedButton.icon(
              onPressed: () => setState(() => _profileTabIndex = 0),
              icon: Icon(Icons.calendar_month_outlined),
              label: Text('Planning'),
            ),
            OutlinedButton.icon(
              onPressed: () => setState(() => _profileTabIndex = 1),
              icon: Icon(Icons.restaurant_menu_outlined),
              label: Text('Voeding'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _planningTab(Map<String, dynamic> horse) {
    final visible = _visibleScheduleItems();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeading(
          'Planning',
          'Activiteiten van alleen ${horse['display_name'] ?? 'dit paard'}.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChoiceChip(
              label: Text('Lijst'),
              selected: !_scheduleAgenda,
              onSelected: (_) => setState(() => _scheduleAgenda = false),
            ),
            ChoiceChip(
              label: Text('Agenda'),
              selected: _scheduleAgenda,
              onSelected: (_) => setState(() => _scheduleAgenda = true),
            ),
            if (_scheduleAgenda)
              for (final period in const [
                (0, 'Dag'),
                (1, 'Week'),
                (2, 'Maand'),
              ])
                ChoiceChip(
                  label: Text(period.$2),
                  selected: _schedulePeriodMode == period.$1,
                  onSelected:
                      (_) => setState(() => _schedulePeriodMode = period.$1),
                ),
          ],
        ),
        if (_scheduleAgenda) ...[
          const SizedBox(height: 12),
          _schedulePeriodControls(),
        ],
        const SizedBox(height: 16),
        if (horse['can_edit'] == true)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _busy ? null : () => _showScheduleEditor(),
              icon: Icon(Icons.add),
              label: Text('Activiteit toevoegen'),
            ),
          ),
        const SizedBox(height: 16),
        if (visible.isEmpty)
          _domainEmptyCard(
            Icons.calendar_month_outlined,
            'Nog geen activiteiten gepland',
            'Activiteiten die bij dit paard horen verschijnen hier chronologisch.',
          )
        else
          for (var index = 0; index < visible.length; index++) ...[
            if (index == 0 ||
                !_sameDay(
                  _scheduleDate(visible[index - 1]),
                  _scheduleDate(visible[index]),
                )) ...[
              if (index > 0) const SizedBox(height: 18),
              Text(
                _displayScheduleDay(_scheduleDate(visible[index])),
                style: TextStyle(
                  color: _roseSoftTone,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
            ],
            _scheduleItemCard(visible[index], horse['can_edit'] == true),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget _schedulePeriodControls() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: _panelTone,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _warmBorderTone),
    ),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Vorige periode',
          onPressed: () => _moveSchedulePeriod(-1),
          icon: Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            _schedulePeriodLabel(),
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _scheduleFocus = DateTime.now()),
          child: Text('Vandaag'),
        ),
        IconButton(
          tooltip: 'Volgende periode',
          onPressed: () => _moveSchedulePeriod(1),
          icon: Icon(Icons.chevron_right),
        ),
      ],
    ),
  );

  void _moveSchedulePeriod(int direction) => setState(() {
    _scheduleFocus = switch (_schedulePeriodMode) {
      0 => _scheduleFocus.add(Duration(days: direction)),
      1 => _scheduleFocus.add(Duration(days: 7 * direction)),
      _ => DateTime(
        _scheduleFocus.year,
        _scheduleFocus.month + direction,
        _scheduleFocus.day.clamp(1, 28).toInt(),
      ),
    };
  });

  String _schedulePeriodLabel() {
    if (_schedulePeriodMode == 0) return _displayScheduleDay(_scheduleFocus);
    if (_schedulePeriodMode == 1) {
      final monday = _scheduleFocus.subtract(
        Duration(days: _scheduleFocus.weekday - 1),
      );
      final sunday = monday.add(const Duration(days: 6));
      return '${monday.day}-${sunday.day} ${_monthLabel(sunday.month)} ${sunday.year}';
    }
    return '${_monthLabel(_scheduleFocus.month)} ${_scheduleFocus.year}';
  }

  List<Map<String, dynamic>> _visibleScheduleItems() {
    final rows = [..._horseSchedule]..sort(
      (left, right) => _scheduleDate(left).compareTo(_scheduleDate(right)),
    );
    if (!_scheduleAgenda) {
      final now = DateTime.now();
      return rows
          .where(
            (row) =>
                row['state']?.toString() != 'cancelled' &&
                !_scheduleDate(row).isBefore(now),
          )
          .toList(growable: false);
    }
    return rows
        .where((row) {
          final date = _scheduleDate(row);
          if (_schedulePeriodMode == 0) return _sameDay(date, _scheduleFocus);
          if (_schedulePeriodMode == 1) {
            final start = DateTime(
              _scheduleFocus.year,
              _scheduleFocus.month,
              _scheduleFocus.day,
            ).subtract(Duration(days: _scheduleFocus.weekday - 1));
            return !date.isBefore(start) &&
                date.isBefore(start.add(const Duration(days: 7)));
          }
          return date.year == _scheduleFocus.year &&
              date.month == _scheduleFocus.month;
        })
        .toList(growable: false);
  }

  DateTime _scheduleDate(Map<String, dynamic> row) =>
      DateTime.tryParse(
        row['scheduled_start_at']?.toString() ?? '',
      )?.toLocal() ??
      DateTime.fromMillisecondsSinceEpoch(0);

  bool _sameDay(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;

  String _displayScheduleDay(DateTime value) =>
      '${value.day} ${_monthLabel(value.month)} ${value.year}';

  String _monthLabel(int month) =>
      const [
        'januari',
        'februari',
        'maart',
        'april',
        'mei',
        'juni',
        'juli',
        'augustus',
        'september',
        'oktober',
        'november',
        'december',
      ][month - 1];

  Widget _scheduleItemCard(Map<String, dynamic> item, bool canEdit) {
    final start = _scheduleDate(item);
    final terminal = const {
      'completed',
      'skipped',
      'cancelled',
    }.contains(item['state']);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panelTone,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _warmBorderTone),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: _panelSoftTone,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _roseSoftTone,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title']?.toString() ?? 'Activiteit',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_scheduleKindLabel(item['item_kind'])} · ${_statusLabel(item['state'])}',
                  style: TextStyle(color: _mutedTone),
                ),
                if ((_textValue(item['instruction'])).isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    _textValue(item['instruction']),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (canEdit)
            PopupMenuButton<String>(
              tooltip: 'Activiteit beheren',
              onSelected: (action) {
                if (action == 'edit')
                  unawaited(_showScheduleEditor(item: item));
                if (action == 'complete')
                  unawaited(_setScheduleState(item, 'completed'));
                if (action == 'cancel')
                  unawaited(_setScheduleState(item, 'cancelled'));
              },
              itemBuilder:
                  (_) => [
                    if (!terminal)
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Bewerken'),
                      ),
                    if (!terminal)
                      const PopupMenuItem(
                        value: 'complete',
                        child: Text('Voltooien'),
                      ),
                    if (!terminal)
                      const PopupMenuItem(
                        value: 'cancel',
                        child: Text('Annuleren'),
                      ),
                  ],
            ),
        ],
      ),
    );
  }

  Future<void> _setScheduleState(
    Map<String, dynamic> item,
    String state,
  ) async {
    await _saveScheduleItem(
      item: item,
      title: _textValue(item['title']),
      instruction: _textValue(item['instruction']),
      itemKind: item['item_kind']?.toString() ?? 'task',
      priority: item['priority']?.toString() ?? 'normal',
      start: DateTime.parse(item['scheduled_start_at'].toString()),
      end:
          item['scheduled_end_at'] == null
              ? null
              : DateTime.parse(item['scheduled_end_at'].toString()),
      state: state,
      stateReason:
          state == 'cancelled' ? 'Geannuleerd vanuit het paardprofiel.' : null,
    );
  }

  Future<void> _showScheduleEditor({Map<String, dynamic>? item}) async {
    final instruction = _controller(item?['instruction']);
    var kind = item?['item_kind']?.toString() ?? 'training';
    var priority = item?['priority']?.toString() ?? 'normal';
    var start =
        item == null
            ? DateTime.now().add(const Duration(hours: 1))
            : DateTime.parse(item['scheduled_start_at'].toString()).toLocal();
    var end =
        item?['scheduled_end_at'] == null
            ? start.add(const Duration(hours: 1))
            : DateTime.parse(item!['scheduled_end_at'].toString()).toLocal();
    var saving = false;
    String? error;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _panelTone,
      builder:
          (sheetContext) => _horseModalTheme(
            sheetContext,
            StatefulBuilder(
              builder:
                  (sheetContext, setSheetState) => Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      22,
                      20,
                      MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
                    ),
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            item == null
                                ? 'Activiteit toevoegen'
                                : 'Activiteit bewerken',
                            style: Theme.of(sheetContext)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Deze activiteit blijft rechtstreeks aan dit paard gekoppeld.',
                            style: TextStyle(color: _mutedTone),
                          ),
                          const SizedBox(height: 20),
                          DropdownButtonFormField<String>(
                            initialValue: kind,
                            decoration: const InputDecoration(
                              labelText: 'Type',
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'training',
                                child: Text('Training'),
                              ),
                              DropdownMenuItem(
                                value: 'care',
                                child: Text('Verzorging'),
                              ),
                              DropdownMenuItem(
                                value: 'task',
                                child: Text('Taak'),
                              ),
                              DropdownMenuItem(
                                value: 'farrier',
                                child: Text('Hoefsmid'),
                              ),
                              DropdownMenuItem(
                                value: 'veterinary',
                                child: Text('Dierenarts'),
                              ),
                              DropdownMenuItem(
                                value: 'competition',
                                child: Text('Wedstrijd'),
                              ),
                              DropdownMenuItem(
                                value: 'transport',
                                child: Text('Transport'),
                              ),
                              DropdownMenuItem(
                                value: 'other',
                                child: Text('Overig'),
                              ),
                              if (item?['item_kind'] == 'feeding')
                                DropdownMenuItem(
                                  value: 'feeding',
                                  child: Text('Voeding (bestaand)'),
                                ),
                            ],
                            onChanged:
                                (value) =>
                                    setSheetState(() => kind = value ?? kind),
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            initialValue: priority,
                            decoration: const InputDecoration(
                              labelText: 'Prioriteit',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'normal',
                                child: Text('Normaal'),
                              ),
                              DropdownMenuItem(
                                value: 'high',
                                child: Text('Hoog'),
                              ),
                            ],
                            onChanged:
                                (value) => setSheetState(
                                  () => priority = value ?? priority,
                                ),
                          ),
                          const SizedBox(height: 14),
                          _scheduleRangeEditor(
                            start: start,
                            end: end,
                            onChanged: (selection) {
                              if (!sheetContext.mounted) return;
                              setSheetState(() {
                                start = selection.start;
                                end = selection.end;
                                error = null;
                              });
                            },
                          ),
                          const SizedBox(height: 14),
                          _field(instruction, 'Notitie (optioneel)', lines: 3),
                          if (error != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              error!,
                              style: TextStyle(
                                color: Theme.of(sheetContext).colorScheme.error,
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed:
                                      saving
                                          ? null
                                          : () => Navigator.pop(sheetContext),
                                  child: Text('Annuleren'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  onPressed:
                                      saving
                                          ? null
                                          : () async {
                                            if (end.isBefore(start)) {
                                              setSheetState(
                                                () =>
                                                    error =
                                                        'De eindtijd mag niet vóór de starttijd liggen.',
                                              );
                                              return;
                                            }
                                            setSheetState(() => saving = true);
                                            try {
                                              await _saveScheduleItem(
                                                item: item,
                                                title: _scheduleKindLabel(kind),
                                                instruction:
                                                    instruction.text.trim(),
                                                itemKind: kind,
                                                priority: priority,
                                                start: start,
                                                end: end,
                                                state:
                                                    item?['state']
                                                        ?.toString() ??
                                                    'planned',
                                                stateReason:
                                                    item?['state_reason']
                                                        ?.toString(),
                                              );
                                              if (sheetContext.mounted)
                                                Navigator.pop(sheetContext);
                                            } catch (caught) {
                                              if (!sheetContext.mounted) return;
                                              setSheetState(() {
                                                saving = false;
                                                error = _friendlyError(caught);
                                              });
                                            }
                                          },
                                  child: Text(saving ? 'Opslaan…' : 'Opslaan'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
            ),
          ),
    );
    instruction.dispose();
  }

  Widget _scheduleRangeEditor({
    required DateTime start,
    required DateTime end,
    required ValueChanged<_ScheduleRangeSelection> onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      onPressed: () async {
        final picked = await _showScheduleRangePlanner(start: start, end: end);
        if (picked != null) onChanged(picked);
      },
      icon: Icon(Icons.date_range_outlined),
      label: Text(
        _scheduleRangeSummary(start, end),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );

  String _scheduleRangeSummary(DateTime start, DateTime end) {
    final startDay =
        '${start.day} ${_shortMonthLabel(start.month)} ${start.year}';
    if (_sameDay(start, end)) {
      return '$startDay · ${_timeLabel(start)} – ${_timeLabel(end)}';
    }
    final endDay = '${end.day} ${_shortMonthLabel(end.month)} ${end.year}';
    return '$startDay ${_timeLabel(start)} → $endDay ${_timeLabel(end)}';
  }

  String _shortMonthLabel(int month) =>
      const [
        'jan',
        'feb',
        'mrt',
        'apr',
        'mei',
        'jun',
        'jul',
        'aug',
        'sep',
        'okt',
        'nov',
        'dec',
      ][month - 1];

  Future<TimeOfDay?> _pickTime24(TimeOfDay initial) async {
    FocusManager.instance.primaryFocus?.unfocus();
    var hour = initial.hour;
    var minute = initial.minute;
    final hourController = FixedExtentScrollController(initialItem: hour);
    final minuteController = FixedExtentScrollController(initialItem: minute);
    final picked = await showModalBottomSheet<TimeOfDay>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _panelTone,
      builder:
          (sheetContext) => _horseModalTheme(
            sheetContext,
            StatefulBuilder(
              builder:
                  (sheetContext, setSheetState) => AnimatedPadding(
                    duration: const Duration(milliseconds: 180),
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Tijd kiezen',
                            style: Theme.of(sheetContext).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 220,
                            child: Row(
                              children: [
                                Expanded(
                                  child: _timeWheel(
                                    controller: hourController,
                                    count: 24,
                                    semanticsLabel: 'Uur',
                                    onChanged:
                                        (value) =>
                                            setSheetState(() => hour = value),
                                  ),
                                ),
                                Text(
                                  ':',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Expanded(
                                  child: _timeWheel(
                                    controller: minuteController,
                                    count: 60,
                                    semanticsLabel: 'Minuut',
                                    onChanged:
                                        (value) =>
                                            setSheetState(() => minute = value),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.pop(sheetContext),
                                  child: Text('Annuleren'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  onPressed:
                                      () => Navigator.pop(
                                        sheetContext,
                                        TimeOfDay(hour: hour, minute: minute),
                                      ),
                                  child: Text('Kiezen'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
            ),
          ),
    );
    hourController.dispose();
    minuteController.dispose();
    return picked;
  }

  Widget _timeWheel({
    required FixedExtentScrollController controller,
    required int count,
    required String semanticsLabel,
    required ValueChanged<int> onChanged,
  }) => Semantics(
    label: semanticsLabel,
    child: ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: 48,
      physics: const FixedExtentScrollPhysics(),
      diameterRatio: 1.35,
      onSelectedItemChanged: onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: count,
        builder:
            (context, index) => Center(
              child: Text(
                index.toString().padLeft(2, '0'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
      ),
    ),
  );

  List<Map<String, dynamic>> _mergedScheduleItems() {
    final selectedName = _selected?['display_name']?.toString() ?? 'Paard';
    final byId = <String, Map<String, dynamic>>{};
    for (final source in [_overviewSchedule, _horseSchedule]) {
      for (final raw in source) {
        if (raw['state']?.toString() == 'cancelled') continue;
        final id = raw['schedule_item_id']?.toString() ?? '';
        if (id.isEmpty) continue;
        final row = Map<String, dynamic>.from(raw);
        if (_textValue(row['horse_name']).isEmpty &&
            row['horse_id']?.toString() == _selectedHorseId) {
          row['horse_name'] = selectedName;
        }
        byId[id] = {...?byId[id], ...row};
      }
    }
    return byId.values.toList(growable: false)..sort(
      (left, right) => _scheduleDate(left).compareTo(_scheduleDate(right)),
    );
  }

  List<Map<String, dynamic>> _scheduleItemsForDay(
    DateTime day,
    List<Map<String, dynamic>> rows,
  ) => rows
      .where((row) => _sameDay(_scheduleDate(row), day))
      .toList(growable: false);

  Future<_ScheduleRangeSelection?> _showScheduleRangePlanner({
    required DateTime start,
    required DateTime end,
  }) async {
    var selectedStart = start;
    var selectedEnd =
        end.isBefore(start) ? start.add(const Duration(hours: 1)) : end;
    var focusDay = DateTime(start.year, start.month, start.day);
    var month = DateTime(start.year, start.month);
    var multiDay = !_sameDay(start, selectedEnd);
    var waitingForRangeEnd = false;
    String? validation;
    final rows = _mergedScheduleItems();
    return showModalBottomSheet<_ScheduleRangeSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _panelTone,
      builder:
          (sheetContext) => _horseModalTheme(
            sheetContext,
            StatefulBuilder(
              builder: (sheetContext, setSheetState) {
                final dayRows = _scheduleItemsForDay(focusDay, rows);
                return FractionallySizedBox(
                  heightFactor: .94,
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Planning kiezen',
                              style: Theme.of(sheetContext)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Sluiten',
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        multiDay
                            ? (waitingForRangeEnd
                                ? 'Kies nu de einddatum.'
                                : 'Meerdaagse periode geselecteerd.')
                            : 'Kies één dag en daarna direct Van en Tot.',
                        style: TextStyle(color: _mutedTone),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Meerdere dagen'),
                        subtitle: Text('Gebruik een start- en einddatum.'),
                        value: multiDay,
                        onChanged: (value) {
                          setSheetState(() {
                            multiDay = value;
                            waitingForRangeEnd = value;
                            validation = null;
                            if (!value) {
                              final duration = selectedEnd.difference(
                                selectedStart,
                              );
                              final safeDuration =
                                  duration.isNegative ||
                                          duration == Duration.zero
                                      ? const Duration(hours: 1)
                                      : duration;
                              selectedEnd = selectedStart.add(safeDuration);
                              if (!_sameDay(selectedStart, selectedEnd)) {
                                selectedEnd = DateTime(
                                  selectedStart.year,
                                  selectedStart.month,
                                  selectedStart.day,
                                  selectedEnd.hour,
                                  selectedEnd.minute,
                                );
                                if (selectedEnd.isBefore(selectedStart)) {
                                  selectedEnd = selectedStart.add(
                                    const Duration(hours: 1),
                                  );
                                }
                              }
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 6),
                      _agendaMonthPicker(
                        month: month,
                        focusDay: focusDay,
                        selectedStartDay: selectedStart,
                        selectedEndDay: selectedEnd,
                        rows: rows,
                        onPrevious:
                            () => setSheetState(
                              () =>
                                  month = DateTime(month.year, month.month - 1),
                            ),
                        onNext:
                            () => setSheetState(
                              () =>
                                  month = DateTime(month.year, month.month + 1),
                            ),
                        onSelected: (day) {
                          setSheetState(() {
                            focusDay = day;
                            month = DateTime(day.year, day.month);
                            validation = null;
                            final duration = selectedEnd.difference(
                              selectedStart,
                            );
                            final safeDuration =
                                duration.isNegative || duration == Duration.zero
                                    ? const Duration(hours: 1)
                                    : duration;
                            if (!multiDay) {
                              selectedStart = DateTime(
                                day.year,
                                day.month,
                                day.day,
                                selectedStart.hour,
                                selectedStart.minute,
                              );
                              selectedEnd = selectedStart.add(safeDuration);
                              if (!_sameDay(selectedStart, selectedEnd)) {
                                selectedEnd = DateTime(
                                  day.year,
                                  day.month,
                                  day.day,
                                  selectedEnd.hour,
                                  selectedEnd.minute,
                                );
                                if (selectedEnd.isBefore(selectedStart)) {
                                  selectedEnd = selectedStart.add(
                                    const Duration(hours: 1),
                                  );
                                }
                              }
                            } else if (!waitingForRangeEnd) {
                              selectedStart = DateTime(
                                day.year,
                                day.month,
                                day.day,
                                selectedStart.hour,
                                selectedStart.minute,
                              );
                              if (selectedEnd.isBefore(selectedStart)) {
                                selectedEnd = selectedStart.add(safeDuration);
                              }
                              waitingForRangeEnd = true;
                            } else {
                              final proposedEnd = DateTime(
                                day.year,
                                day.month,
                                day.day,
                                selectedEnd.hour,
                                selectedEnd.minute,
                              );
                              if (proposedEnd.isBefore(selectedStart)) {
                                selectedStart = DateTime(
                                  day.year,
                                  day.month,
                                  day.day,
                                  selectedStart.hour,
                                  selectedStart.minute,
                                );
                                selectedEnd = selectedStart.add(safeDuration);
                              } else {
                                selectedEnd = proposedEnd;
                                waitingForRangeEnd = false;
                              }
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _displayScheduleDay(focusDay),
                        style: Theme.of(sheetContext).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      _agendaDayTimeline(dayRows),
                      const SizedBox(height: 16),
                      Text(
                        multiDay
                            ? '${_displayScheduleDay(selectedStart)} — ${_displayScheduleDay(selectedEnd)}'
                            : _displayScheduleDay(selectedStart),
                        style: Theme.of(sheetContext).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await _pickTime24(
                                  TimeOfDay.fromDateTime(selectedStart),
                                );
                                if (picked == null || !sheetContext.mounted)
                                  return;
                                setSheetState(() {
                                  final duration = selectedEnd.difference(
                                    selectedStart,
                                  );
                                  final safeDuration =
                                      duration.isNegative ||
                                              duration == Duration.zero
                                          ? const Duration(hours: 1)
                                          : duration;
                                  selectedStart = DateTime(
                                    selectedStart.year,
                                    selectedStart.month,
                                    selectedStart.day,
                                    picked.hour,
                                    picked.minute,
                                  );
                                  if (!multiDay ||
                                      selectedEnd.isBefore(selectedStart)) {
                                    selectedEnd = selectedStart.add(
                                      safeDuration,
                                    );
                                  }
                                  validation = null;
                                });
                              },
                              icon: Icon(Icons.schedule),
                              label: Text('Van · ${_timeLabel(selectedStart)}'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await _pickTime24(
                                  TimeOfDay.fromDateTime(selectedEnd),
                                );
                                if (picked == null || !sheetContext.mounted)
                                  return;
                                setSheetState(() {
                                  selectedEnd = DateTime(
                                    selectedEnd.year,
                                    selectedEnd.month,
                                    selectedEnd.day,
                                    picked.hour,
                                    picked.minute,
                                  );
                                  validation =
                                      selectedEnd.isBefore(selectedStart)
                                          ? 'Einde moet op of na Start liggen.'
                                          : null;
                                });
                              },
                              icon: Icon(Icons.schedule_outlined),
                              label: Text('Tot · ${_timeLabel(selectedEnd)}'),
                            ),
                          ),
                        ],
                      ),
                      if (validation != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          validation!,
                          style: TextStyle(
                            color: Theme.of(sheetContext).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              child: Text('Annuleren'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed:
                                  selectedEnd.isBefore(selectedStart)
                                      ? null
                                      : () => Navigator.pop(
                                        sheetContext,
                                        _ScheduleRangeSelection(
                                          start: selectedStart,
                                          end: selectedEnd,
                                        ),
                                      ),
                              child: Text('Periode kiezen'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
    );
  }

  Widget _agendaMonthPicker({
    required DateTime month,
    required DateTime focusDay,
    required DateTime selectedStartDay,
    required DateTime selectedEndDay,
    required List<Map<String, dynamic>> rows,
    required VoidCallback onPrevious,
    required VoidCallback onNext,
    required ValueChanged<DateTime> onSelected,
  }) {
    final first = DateTime(month.year, month.month, 1);
    final leading = first.weekday - 1;
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final activeDays =
        rows
            .map(_scheduleDate)
            .where(
              (date) => date.year == month.year && date.month == month.month,
            )
            .map((date) => date.day)
            .toSet();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panelSoftTone,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _warmBorderTone),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Vorige maand',
                onPressed: onPrevious,
                icon: Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '${_monthLabel(month.month)} ${month.year}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Volgende maand',
                onPressed: onNext,
                icon: Icon(Icons.chevron_right),
              ),
            ],
          ),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.08,
            children: [
              for (final label in const [
                'ma',
                'di',
                'wo',
                'do',
                'vr',
                'za',
                'zo',
              ])
                Center(
                  child: Text(
                    label,
                    style: TextStyle(color: _mutedTone, fontSize: 11),
                  ),
                ),
              for (var cell = 0; cell < leading + days; cell++)
                if (cell < leading)
                  const SizedBox.shrink()
                else
                  Builder(
                    builder: (context) {
                      final day = cell - leading + 1;
                      final date = DateTime(month.year, month.month, day);
                      final focused = _sameDay(date, focusDay);
                      final dayValue = DateTime(
                        date.year,
                        date.month,
                        date.day,
                      );
                      final rangeStart = DateTime(
                        selectedStartDay.year,
                        selectedStartDay.month,
                        selectedStartDay.day,
                      );
                      final rangeEnd = DateTime(
                        selectedEndDay.year,
                        selectedEndDay.month,
                        selectedEndDay.day,
                      );
                      final inRange =
                          !dayValue.isBefore(rangeStart) &&
                          !dayValue.isAfter(rangeEnd);
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => onSelected(date),
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color:
                                focused
                                    ? _roseBronzeTone
                                    : inRange
                                    ? _roseBronzeTone.withValues(alpha: .22)
                                    : null,
                            borderRadius: BorderRadius.circular(12),
                            border:
                                inRange && !focused
                                    ? Border.all(
                                      color: _roseBronzeTone.withValues(
                                        alpha: .5,
                                      ),
                                    )
                                    : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$day',
                                style: TextStyle(
                                  color: focused ? Colors.white : _inkTone,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      activeDays.contains(day)
                                          ? (focused
                                              ? Colors.white
                                              : _roseSoftTone)
                                          : Colors.transparent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _agendaDayTimeline(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Text(
          'Geen zichtbare activiteiten op deze dag. De dag is vrij.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _mutedTone),
        ),
      );
    }
    final entries = <Widget>[];
    var cursor = DateTime(
      _scheduleDate(rows.first).year,
      _scheduleDate(rows.first).month,
      _scheduleDate(rows.first).day,
      7,
    );
    for (final row in rows) {
      final start = _scheduleDate(row);
      final end =
          DateTime.tryParse(
            row['scheduled_end_at']?.toString() ?? '',
          )?.toLocal() ??
          start.add(const Duration(hours: 1));
      if (start.isAfter(cursor.add(const Duration(minutes: 15)))) {
        entries.add(_agendaFreeBlock(cursor, start));
      }
      entries.add(_agendaActivityBlock(row, start, end));
      if (end.isAfter(cursor)) cursor = end;
    }
    final dayEnd = DateTime(cursor.year, cursor.month, cursor.day, 21);
    if (dayEnd.isAfter(cursor.add(const Duration(minutes: 15)))) {
      entries.add(_agendaFreeBlock(cursor, dayEnd));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < entries.length; index++) ...[
          entries[index],
          if (index != entries.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _agendaFreeBlock(DateTime start, DateTime end) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _warmBorderTone),
    ),
    child: Text(
      '${_timeLabel(start)}–${_timeLabel(end)} · Vrij',
      style: TextStyle(color: _mutedTone),
    ),
  );

  Widget _agendaActivityBlock(
    Map<String, dynamic> row,
    DateTime start,
    DateTime end,
  ) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _roseBronzeTone.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _roseBronzeTone.withValues(alpha: .55)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 82,
          child: Text(
            '${_timeLabel(start)}–${_timeLabel(end)}',
            style: TextStyle(color: _roseSoftTone, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _textValue(row['title']).isEmpty
                    ? _scheduleKindLabel(row['item_kind'])
                    : _textValue(row['title']),
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                '${_scheduleKindLabel(row['item_kind'])} · ${_textValue(row['horse_name']).isEmpty ? 'Paard' : row['horse_name']}',
                style: TextStyle(color: _mutedTone),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  String _timeLabel(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  Future<void> _saveScheduleItem({
    required Map<String, dynamic>? item,
    required String title,
    required String instruction,
    required String itemKind,
    required String priority,
    required DateTime start,
    required DateTime? end,
    required String state,
    required String? stateReason,
  }) async {
    final horseId = _selectedHorseId;
    if (horseId == null || _busy) return;
    setState(() => _busy = true);
    try {
      await _client.rpc(
        'upsert_canonical_horse_schedule_item',
        params: {
          'p_horse_id': horseId,
          'p_schedule_item_id': item?['schedule_item_id'],
          'p_expected_row_version': item?['row_version'],
          'p_item_kind': itemKind,
          'p_title': title,
          'p_instruction': instruction,
          'p_priority': priority,
          'p_scheduled_start_at': start.toUtc().toIso8601String(),
          'p_scheduled_end_at': end?.toUtc().toIso8601String(),
          'p_source_timezone': 'Europe/Amsterdam',
          'p_state': state,
          'p_state_reason': stateReason,
          'p_request_id': _uuid.v4(),
        },
      );
      await _load(selectHorseId: horseId);
      _showNotice('Planning bijgewerkt.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _scheduleKindLabel(dynamic value) => switch (value?.toString()) {
    'training' => 'Training',
    'care' => 'Verzorging',
    'task' => 'Taak',
    'farrier' => 'Hoefsmid',
    'veterinary' => 'Dierenarts',
    'competition' => 'Wedstrijd',
    'transport' => 'Transport',
    'other' => 'Overig',
    'feeding' => 'Voeding',
    _ => 'Overig',
  };

  Widget _feedingTab(Map<String, dynamic> horse) {
    final plans = _rows(_horseFeeding['plans']);
    final standardPlan = _preferredFeedingPlan(plans, 'standard');
    final temporaryPlans = plans
        .where(
          (plan) =>
              plan['plan_type']?.toString() == 'temporary' &&
              plan['status']?.toString() != 'retired',
        )
        .toList(growable: false);
    final active = _activeFeedingPlan(
      standardPlan: standardPlan,
      temporaryPlans: temporaryPlans,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeading(
          'Voeding',
          'Basisvoeding en tijdelijke schema’s van alleen ${horse['display_name'] ?? 'dit paard'}.',
        ),
        const SizedBox(height: 16),
        _activeFeedingSummary(active),
        const SizedBox(height: 16),
        if (horse['can_edit'] == true)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed:
                    _busy
                        ? null
                        : () => _showFeedingRoundEditor(
                          planType: 'standard',
                          plan: standardPlan,
                        ),
                icon: Icon(Icons.restaurant_menu_outlined),
                label: Text(
                  standardPlan == null
                      ? 'Basisvoeding toevoegen'
                      : 'Basisvoeding bewerken',
                ),
              ),
              OutlinedButton.icon(
                onPressed:
                    _busy
                        ? null
                        : () => _showFeedingRoundEditor(planType: 'temporary'),
                icon: Icon(Icons.event_repeat_outlined),
                label: Text('Tijdelijk schema'),
              ),
            ],
          ),
        const SizedBox(height: 18),
        if (standardPlan == null && temporaryPlans.isEmpty)
          _domainEmptyCard(
            Icons.restaurant_menu_outlined,
            'Nog geen voedingsplan',
            'Leg eerst de basisvoeding vast. Een tijdelijk schema laat het basisplan intact.',
          )
        else ...[
          Text(
            'Basisvoeding',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (standardPlan != null) ...[
            _feedingPlanCard(standardPlan, horse['can_edit'] == true),
            const SizedBox(height: 12),
          ] else
            _domainEmptyCard(
              Icons.restaurant_menu_outlined,
              'Nog geen Basisvoeding',
              'Voeg een product toe aan Ochtend, Middag of Avond.',
            ),
          const SizedBox(height: 10),
          Text(
            'Tijdelijke schema’s',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          for (final plan in temporaryPlans) ...[
            _feedingPlanCard(plan, horse['can_edit'] == true),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }

  Map<String, dynamic>? _preferredFeedingPlan(
    List<Map<String, dynamic>> plans,
    String type,
  ) {
    final candidates = plans
        .where(
          (plan) =>
              plan['plan_type']?.toString() == type &&
              plan['status']?.toString() != 'retired',
        )
        .toList(growable: false);
    candidates.sort((left, right) {
      final leftActive = left['status']?.toString() == 'active' ? 0 : 1;
      final rightActive = right['status']?.toString() == 'active' ? 0 : 1;
      if (leftActive != rightActive) return leftActive - rightActive;
      final leftItems = _feedingPlanItems(left).isNotEmpty ? 0 : 1;
      final rightItems = _feedingPlanItems(right).isNotEmpty ? 0 : 1;
      if (leftItems != rightItems) return leftItems - rightItems;
      final leftDate = _dateValue(left['effective_from']) ?? DateTime(1970);
      final rightDate = _dateValue(right['effective_from']) ?? DateTime(1970);
      final dateOrder = rightDate.compareTo(leftDate);
      if (dateOrder != 0) return dateOrder;
      return (left['feeding_plan_id']?.toString() ?? '').compareTo(
        right['feeding_plan_id']?.toString() ?? '',
      );
    });
    return candidates.isEmpty ? null : candidates.first;
  }

  Map<String, dynamic>? _activeFeedingPlan({
    required Map<String, dynamic>? standardPlan,
    required List<Map<String, dynamic>> temporaryPlans,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final activeTemporary = temporaryPlans
      .where((plan) {
        if (plan['status']?.toString() != 'active' ||
            _feedingPlanItems(plan).isEmpty) {
          return false;
        }
        final from = _dateValue(plan['effective_from']);
        final until = _dateValue(plan['effective_until']);
        return from != null &&
            until != null &&
            !today.isBefore(DateTime(from.year, from.month, from.day)) &&
            !today.isAfter(DateTime(until.year, until.month, until.day));
      })
      .toList(growable: false)..sort((left, right) {
      final leftDate = _dateValue(left['effective_from']) ?? DateTime(1970);
      final rightDate = _dateValue(right['effective_from']) ?? DateTime(1970);
      return rightDate.compareTo(leftDate);
    });
    if (activeTemporary.isNotEmpty) return activeTemporary.first;
    return standardPlan != null && _feedingPlanItems(standardPlan).isNotEmpty
        ? standardPlan
        : null;
  }

  List<Map<String, dynamic>> _feedingPlanItems(Map<String, dynamic>? plan) =>
      _rows(_feedingDisplayVersion(plan)?['items']);

  Widget _activeFeedingSummary(Map<String, dynamic>? plan) {
    if (plan == null) {
      return _domainEmptyCard(
        Icons.info_outline,
        'Geen actief schema',
        'Er is nu geen actief basis- of tijdelijk voedingsschema.',
      );
    }
    final temporary = plan['plan_type'] == 'temporary';
    final items = _feedingPlanItems(plan);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _roseBronzeTone.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _roseBronzeTone.withValues(alpha: .6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACTIEF SCHEMA',
            style: TextStyle(
              color: _roseSoftTone,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            plan['name']?.toString() ??
                (temporary ? 'Tijdelijk schema' : 'Basisvoeding'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            temporary
                ? 'Geldig van ${_displayDate(plan['effective_from'])} tot en met ${_displayDate(plan['effective_until'])}. Daarna wordt het basisplan hervat.'
                : 'Basisplan vanaf ${_displayDate(plan['effective_from'])}.',
            style: TextStyle(color: _mutedTone, height: 1.4),
          ),
          const SizedBox(height: 12),
          for (final round in const ['morning', 'afternoon', 'evening']) ...[
            Text(
              _feedingRoundLabel(round),
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            if (items.where((item) => item['round_code'] == round).isEmpty)
              Text('Geen producten', style: TextStyle(color: _mutedTone))
            else
              for (final item in items.where(
                (item) => item['round_code'] == round,
              ))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• ${_feedingProductTypeLabel(_feedingProductType(item))}'
                    '${_feedingProductDescription(item).isEmpty ? '' : ' — ${_feedingProductDescription(item)}'}'
                    ' — ${item['planned_quantity']} ${_feedingUnitLabel(item['unit_code'])}',
                  ),
                ),
            if (round != 'evening') const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _feedingPlanCard(Map<String, dynamic> plan, bool canEdit) {
    final versions = _rows(plan['versions']);
    final activeVersionId = plan['active_version_id']?.toString();
    final temporary = plan['plan_type']?.toString() == 'temporary';
    final version = versions.cast<Map<String, dynamic>?>().firstWhere(
      (value) =>
          value?['feeding_plan_version_id']?.toString() == activeVersionId,
      orElse: () => versions.isEmpty ? null : versions.first,
    );
    final items = _rows(version?['items']);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _panelTone,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _warmBorderTone),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            plan['name']?.toString() ?? 'Voedingsplan',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${_statusLabel(plan['status'])} · ${_displayDate(plan['effective_from'])}${plan['effective_until'] == null ? '' : ' – ${_displayDate(plan['effective_until'])}'}',
            style: TextStyle(color: _mutedTone),
          ),
          if (temporary && canEdit) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  onPressed:
                      _busy
                          ? null
                          : () => _showFeedingRoundEditor(
                            planType: 'temporary',
                            plan: plan,
                            initialRound: _firstPopulatedFeedingRound(plan),
                          ),
                  icon: Icon(Icons.edit_outlined),
                  label: Text('Wijzigen'),
                ),
                TextButton.icon(
                  onPressed:
                      _busy ? null : () => _showTemporaryPlanEndEditor(plan),
                  icon: Icon(Icons.event_busy_outlined),
                  label: Text('Eerder beëindigen'),
                ),
                TextButton.icon(
                  onPressed:
                      _busy ? null : () => _confirmRemoveTemporaryPlan(plan),
                  icon: Icon(Icons.delete_outline),
                  label: Text('Verwijderen'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          for (final round in const ['morning', 'afternoon', 'evening']) ...[
            _feedingRoundCard(
              plan: plan,
              round: round,
              items: items
                  .where((item) => item['round_code']?.toString() == round)
                  .toList(growable: false),
              canEdit: canEdit,
            ),
            if (round != 'evening') const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  String _firstPopulatedFeedingRound(Map<String, dynamic> plan) {
    final items = _feedingPlanItems(plan);
    for (final round in const ['morning', 'afternoon', 'evening']) {
      if (items.any((item) => item['round_code']?.toString() == round)) {
        return round;
      }
    }
    return 'morning';
  }

  Widget _feedingRoundCard({
    required Map<String, dynamic> plan,
    required String round,
    required List<Map<String, dynamic>> items,
    required bool canEdit,
  }) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _panelSoftTone,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _warmBorderTone),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _feedingRoundLabel(round),
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (canEdit)
              TextButton.icon(
                onPressed:
                    () => _showFeedingRoundEditor(
                      planType: plan['plan_type']?.toString() ?? 'standard',
                      plan: plan,
                      initialRound: round,
                    ),
                icon: Icon(items.isEmpty ? Icons.add : Icons.edit_outlined),
                label: Text(items.isEmpty ? 'Toevoegen' : 'Bewerken'),
              ),
          ],
        ),
        if (items.isEmpty)
          Text(
            '${_feedingRoundLabel(round)}voeding toevoegen',
            style: TextStyle(color: _mutedTone),
          )
        else
          for (final item in items) ...[
            const SizedBox(height: 8),
            _feedingProductRow(item),
          ],
      ],
    ),
  );

  Widget _feedingProductRow(Map<String, dynamic> item) {
    final type = _feedingProductType(item);
    final description = _feedingProductDescription(item);
    final note = _textValue(item['instruction']);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.restaurant_outlined, size: 18, color: _roseBronzeTone),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            '${_feedingProductTypeLabel(type)}${description.isEmpty ? '' : ' · $description'}\n'
            '${item['planned_quantity']} ${_feedingUnitLabel(item['unit_code'])}'
            '${note.isEmpty ? '' : '\n$note'}',
          ),
        ),
      ],
    );
  }

  Future<void> _showFeedingRoundEditor({
    required String planType,
    Map<String, dynamic>? plan,
    String initialRound = 'morning',
  }) async {
    var round = initialRound;
    var from = _dateValue(plan?['effective_from'])?.toLocal() ?? DateTime.now();
    var until =
        _dateValue(plan?['effective_until'])?.toLocal() ??
        DateTime.now().add(const Duration(days: 7));
    var products = _feedingDraftsForRound(plan, round);
    var saving = false;
    String? error;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _panelTone,
      builder:
          (sheetContext) => _horseModalTheme(
            sheetContext,
            StatefulBuilder(
              builder:
                  (sheetContext, setSheetState) => FractionallySizedBox(
                    heightFactor: .94,
                    child: ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        18,
                        18,
                        18,
                        MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
                      ),
                      children: [
                        Text(
                          planType == 'standard'
                              ? 'Basisvoeding invoeren'
                              : 'Tijdelijk voerschema',
                          style: Theme.of(sheetContext).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Voeg alle producten voor één dagdeel direct toe. Opslaan gebeurt als één geheel.',
                          style: TextStyle(color: _mutedTone),
                        ),
                        const SizedBox(height: 14),
                        if (planType == 'temporary') ...[
                          _dateField(
                            label: 'Geldig van',
                            value: from,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(
                              const Duration(days: 730),
                            ),
                            onChanged: (value) {
                              if (value != null && sheetContext.mounted) {
                                setSheetState(() => from = value);
                              }
                            },
                          ),
                          _dateField(
                            label: 'Geldig tot en met',
                            value: until,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(
                              const Duration(days: 730),
                            ),
                            onChanged: (value) {
                              if (value != null && sheetContext.mounted) {
                                setSheetState(() => until = value);
                              }
                            },
                          ),
                        ],
                        DropdownButtonFormField<String>(
                          initialValue: round,
                          decoration: const InputDecoration(
                            labelText: 'Dagdeel',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'morning',
                              child: Text('Ochtend'),
                            ),
                            DropdownMenuItem(
                              value: 'afternoon',
                              child: Text('Middag'),
                            ),
                            DropdownMenuItem(
                              value: 'evening',
                              child: Text('Avond'),
                            ),
                          ],
                          onChanged:
                              saving
                                  ? null
                                  : (value) {
                                    if (value == null || value == round) return;
                                    for (final product in products)
                                      product.dispose();
                                    setSheetState(() {
                                      round = value;
                                      products = _feedingDraftsForRound(
                                        plan,
                                        round,
                                      );
                                      error = null;
                                    });
                                  },
                        ),
                        const SizedBox(height: 12),
                        for (
                          var index = 0;
                          index < products.length;
                          index++
                        ) ...[
                          _feedingProductEditor(
                            product: products[index],
                            index: index,
                            canRemove: products.length > 1,
                            onChanged: () => setSheetState(() {}),
                            onRemove: () {
                              final removed = products.removeAt(index);
                              removed.dispose();
                              setSheetState(() => error = null);
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                        OutlinedButton.icon(
                          onPressed:
                              saving
                                  ? null
                                  : () => setSheetState(
                                    () => products.add(_FeedingProductDraft()),
                                  ),
                          icon: Icon(Icons.add),
                          label: Text('Nog een product toevoegen'),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            error!,
                            style: TextStyle(
                              color: Theme.of(sheetContext).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed:
                                    saving
                                        ? null
                                        : () => Navigator.pop(sheetContext),
                                child: Text('Annuleren'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed:
                                    saving
                                        ? null
                                        : () async {
                                          final validation =
                                              _validateFeedingDrafts(
                                                products,
                                                planType: planType,
                                                from: from,
                                                until: until,
                                              );
                                          if (validation != null) {
                                            setSheetState(
                                              () => error = validation,
                                            );
                                            return;
                                          }
                                          setSheetState(() {
                                            saving = true;
                                            error = null;
                                          });
                                          try {
                                            await _saveFeedingRound(
                                              planType: planType,
                                              plan: plan,
                                              round: round,
                                              from: from,
                                              until:
                                                  planType == 'temporary'
                                                      ? until
                                                      : null,
                                              products: products,
                                            );
                                            if (sheetContext.mounted) {
                                              Navigator.pop(sheetContext);
                                            }
                                          } catch (caught) {
                                            if (!sheetContext.mounted) return;
                                            setSheetState(() {
                                              saving = false;
                                              error = _friendlyError(caught);
                                            });
                                          }
                                        },
                                child: Text(saving ? 'Opslaan…' : 'Opslaan'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
            ),
          ),
    );
    for (final product in products) product.dispose();
  }

  List<_FeedingProductDraft> _feedingDraftsForRound(
    Map<String, dynamic>? plan,
    String round,
  ) {
    final version = _feedingDisplayVersion(plan);
    final items = _rows(version?['items'])
        .where((item) => item['round_code']?.toString() == round)
        .toList(growable: false);
    if (items.isEmpty) return [_FeedingProductDraft()];
    return items
        .map((item) {
          final quantity = item['planned_quantity']?.toString() ?? '';
          return _FeedingProductDraft(
            itemId: item['feeding_plan_item_id']?.toString(),
            expectedRowVersion: int.tryParse(
              item['row_version']?.toString() ?? '',
            ),
            productType: _feedingProductType(item),
            description: _feedingProductDescription(item),
            quantity:
                quantity.endsWith('.0000')
                    ? quantity.substring(0, quantity.length - 5)
                    : quantity,
            unitCode:
                _feedingKnownUnits.contains(item['unit_code']?.toString())
                    ? item['unit_code'].toString()
                    : 'kg',
            note: _textValue(item['instruction']),
          );
        })
        .toList(growable: true);
  }

  Map<String, dynamic>? _feedingDisplayVersion(Map<String, dynamic>? plan) {
    if (plan == null) return null;
    final versions = _rows(plan['versions']);
    final activeId = plan['active_version_id']?.toString();
    return versions.cast<Map<String, dynamic>?>().firstWhere(
      (version) => version?['feeding_plan_version_id']?.toString() == activeId,
      orElse: () => versions.isEmpty ? null : versions.first,
    );
  }

  Widget _feedingProductEditor({
    required _FeedingProductDraft product,
    required int index,
    required bool canRemove,
    required VoidCallback onChanged,
    required VoidCallback onRemove,
  }) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _panelSoftTone,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _warmBorderTone),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Product ${index + 1}',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (canRemove)
              IconButton(
                tooltip: 'Productregel verwijderen',
                onPressed: onRemove,
                icon: Icon(Icons.delete_outline),
              ),
          ],
        ),
        DropdownButtonFormField<String>(
          initialValue: product.productType,
          decoration: const InputDecoration(labelText: 'Productsoort'),
          items: const [
            DropdownMenuItem(value: 'pellet', child: Text('Brok')),
            DropdownMenuItem(value: 'muesli', child: Text('Muesli')),
            DropdownMenuItem(value: 'mash', child: Text('Mash')),
            DropdownMenuItem(value: 'roughage', child: Text('Hooi / ruwvoer')),
            DropdownMenuItem(value: 'supplement', child: Text('Supplement')),
            DropdownMenuItem(value: 'medication', child: Text('Medicatie')),
            DropdownMenuItem(value: 'oil', child: Text('Olie')),
            DropdownMenuItem(value: 'other', child: Text('Anders')),
          ],
          onChanged: (value) {
            product.productType = value ?? product.productType;
            onChanged();
          },
        ),
        const SizedBox(height: 10),
        _field(product.descriptionController, 'Merk / productomschrijving'),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: product.quantityController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                ],
                decoration: const InputDecoration(labelText: 'Hoeveelheid *'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: product.unitCode,
                decoration: const InputDecoration(labelText: 'Eenheid'),
                items: const [
                  DropdownMenuItem(value: 'g', child: Text('gram')),
                  DropdownMenuItem(value: 'kg', child: Text('kilogram')),
                  DropdownMenuItem(value: 'ml', child: Text('milliliter')),
                  DropdownMenuItem(value: 'l', child: Text('liter')),
                  DropdownMenuItem(value: 'scoop', child: Text('maatschep')),
                  DropdownMenuItem(value: 'portion', child: Text('portie')),
                  DropdownMenuItem(value: 'piece', child: Text('stuk')),
                  DropdownMenuItem(value: 'bale', child: Text('baal')),
                ],
                onChanged: (value) {
                  product.unitCode = value ?? product.unitCode;
                  onChanged();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _field(product.noteController, 'Notitie (optioneel)', lines: 2),
      ],
    ),
  );

  String? _validateFeedingDrafts(
    List<_FeedingProductDraft> products, {
    required String planType,
    required DateTime from,
    required DateTime until,
  }) {
    if (planType == 'temporary' && until.isBefore(from)) {
      return 'De einddatum mag niet vóór de begindatum liggen.';
    }
    if (products.isEmpty) return 'Voeg minimaal één product toe.';
    for (final product in products) {
      final quantity = double.tryParse(
        product.quantityController.text.trim().replaceAll(',', '.'),
      );
      if (quantity == null || quantity <= 0) {
        return 'Vul voor ieder product een geldige positieve hoeveelheid in.';
      }
    }
    return null;
  }

  Future<void> _saveFeedingRound({
    required String planType,
    required Map<String, dynamic>? plan,
    required String round,
    required DateTime from,
    required DateTime? until,
    required List<_FeedingProductDraft> products,
    String? successMessage,
  }) async {
    final horseId = _selectedHorseId;
    if (horseId == null || _busy) return;
    setState(() => _busy = true);
    try {
      await _client.rpc(
        'save_canonical_horse_feeding_round',
        params: {
          'p_horse_id': horseId,
          'p_plan_type': planType,
          'p_feeding_plan_id': plan?['feeding_plan_id'],
          'p_expected_plan_row_version': plan?['row_version'],
          'p_round_code': round,
          'p_effective_from': _dateIso(from),
          'p_effective_until': _dateIso(until),
          'p_products': [
            for (final product in products)
              {
                if (product.itemId != null) 'item_id': product.itemId,
                if (product.expectedRowVersion != null)
                  'expected_row_version': product.expectedRowVersion,
                'product_type': product.productType,
                'description': product.descriptionController.text.trim(),
                'quantity': double.parse(
                  product.quantityController.text.trim().replaceAll(',', '.'),
                ),
                'unit_code': product.unitCode,
                'note': product.noteController.text.trim(),
              },
          ],
          'p_request_id': _uuid.v4(),
        },
      );
      await _load(selectHorseId: horseId);
      _showNotice(
        successMessage ?? '${_feedingRoundLabel(round)}voeding opgeslagen.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showTemporaryPlanEndEditor(Map<String, dynamic> plan) async {
    final from = _dateValue(plan['effective_from'])?.toLocal();
    final currentUntil = _dateValue(plan['effective_until'])?.toLocal();
    if (from == null || currentUntil == null || !currentUntil.isAfter(from)) {
      _showNotice(
        'Voor dit schema is geen eerdere geldige einddatum mogelijk.',
      );
      return;
    }
    final latestEarlierDate = currentUntil.subtract(const Duration(days: 1));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var selectedUntil =
        today.isBefore(from)
            ? from
            : today.isAfter(latestEarlierDate)
            ? latestEarlierDate
            : today;
    String? error;
    final confirmed = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _panelTone,
      builder:
          (sheetContext) => _horseModalTheme(
            sheetContext,
            StatefulBuilder(
              builder:
                  (sheetContext, setSheetState) => Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      22,
                      20,
                      MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
                    ),
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Tijdelijk schema eerder beëindigen',
                            style: Theme.of(sheetContext)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Na deze laatste dag wordt automatisch de Basisvoeding getoond.',
                            style: TextStyle(color: _mutedTone),
                          ),
                          const SizedBox(height: 18),
                          _dateField(
                            label: 'Laatste dag tijdelijk schema',
                            value: selectedUntil,
                            firstDate: from,
                            lastDate: latestEarlierDate,
                            onChanged: (value) {
                              if (value != null && sheetContext.mounted) {
                                setSheetState(() {
                                  selectedUntil = value;
                                  error = null;
                                });
                              }
                            },
                          ),
                          if (!today.isBefore(from) &&
                              !today.isAfter(latestEarlierDate))
                            TextButton.icon(
                              onPressed:
                                  () => setSheetState(() {
                                    selectedUntil = today;
                                    error = null;
                                  }),
                              icon: Icon(Icons.today_outlined),
                              label: Text('Vandaag stoppen'),
                            ),
                          if (error != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              error!,
                              style: TextStyle(
                                color: Theme.of(sheetContext).colorScheme.error,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.pop(sheetContext),
                                  child: Text('Annuleren'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () {
                                    if (selectedUntil.isBefore(from) ||
                                        !selectedUntil.isBefore(currentUntil)) {
                                      setSheetState(
                                        () =>
                                            error =
                                                'Kies een einddatum vóór de huidige einddatum.',
                                      );
                                      return;
                                    }
                                    Navigator.pop(sheetContext, selectedUntil);
                                  },
                                  child: Text('Bevestigen'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
            ),
          ),
    );
    if (confirmed == null) return;
    await _endTemporaryFeedingPlan(plan, confirmed);
  }

  Future<void> _endTemporaryFeedingPlan(
    Map<String, dynamic> plan,
    DateTime until,
  ) async {
    if (_feedingPlanItems(plan).isEmpty) {
      _showNotice(
        'Dit tijdelijke schema bevat nog geen voeding om te bewaren.',
      );
      return;
    }
    final round = _firstPopulatedFeedingRound(plan);
    final products = _feedingDraftsForRound(plan, round);
    try {
      await _saveFeedingRound(
        planType: 'temporary',
        plan: plan,
        round: round,
        from: _dateValue(plan['effective_from'])?.toLocal() ?? until,
        until: until,
        products: products,
        successMessage:
            'Tijdelijk schema eindigt op ${_displayDate(_dateIso(until))}.',
      );
    } finally {
      for (final product in products) product.dispose();
    }
  }

  Future<void> _confirmRemoveTemporaryPlan(Map<String, dynamic> plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => _horseModalTheme(
            dialogContext,
            AlertDialog(
              title: Text('Tijdelijk schema verwijderen?'),
              content: Text(
                'Het tijdelijke schema verdwijnt uit het actieve overzicht. De Basisvoeding blijft behouden.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text('Annuleren'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text('Verwijderen'),
                ),
              ],
            ),
          ),
    );
    if (confirmed == true) await _retireFeedingPlan(plan);
  }

  static const _feedingKnownUnits = {
    'g',
    'kg',
    'ml',
    'l',
    'scoop',
    'portion',
    'piece',
    'bale',
  };

  String _feedingProductType(Map<String, dynamic> item) {
    final variant = item['product_variant']?.toString();
    if (const {
      'pellet',
      'muesli',
      'mash',
      'roughage',
      'supplement',
      'medication',
      'oil',
      'other',
    }.contains(variant))
      return variant!;
    return switch (item['item_category']?.toString()) {
      'hay' => 'roughage',
      'supplement' => 'supplement',
      'medication' => 'medication',
      _ => 'other',
    };
  }

  String _feedingProductDescription(Map<String, dynamic> item) {
    final variant = item['product_variant']?.toString();
    if (const {
      'pellet',
      'muesli',
      'mash',
      'roughage',
      'supplement',
      'medication',
      'oil',
      'other',
    }.contains(variant))
      return _textValue(item['product_brand']);
    return _textValue(item['product_name']);
  }

  String _feedingProductTypeLabel(String value) => switch (value) {
    'pellet' => 'Brok',
    'muesli' => 'Muesli',
    'mash' => 'Mash',
    'roughage' => 'Hooi / ruwvoer',
    'supplement' => 'Supplement',
    'medication' => 'Medicatie',
    'oil' => 'Olie',
    _ => 'Anders',
  };

  String _feedingUnitLabel(dynamic value) => switch (value?.toString()) {
    'g' => 'gram',
    'kg' => 'kilogram',
    'ml' => 'milliliter',
    'l' => 'liter',
    'scoop' => 'maatschep',
    'portion' => 'portie',
    'piece' => 'stuk',
    'bale' => 'baal',
    _ => value?.toString() ?? '',
  };

  Future<void> _showFeedingPlanEditor(String planType) async {
    var from = DateTime.now();
    var until = DateTime.now().add(const Duration(days: 7));
    String? error;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _panelTone,
      builder:
          (sheetContext) => _horseModalTheme(
            sheetContext,
            StatefulBuilder(
              builder:
                  (sheetContext, setSheetState) => Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      22,
                      20,
                      MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            planType == 'standard'
                                ? 'Basisvoeding'
                                : 'Tijdelijk schema',
                            style: Theme.of(sheetContext)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            planType == 'standard'
                                ? 'Het normale terugkerende schema van dit paard.'
                                : 'Het basisplan blijft intact en wordt na de einddatum hervat.',
                            style: TextStyle(color: _mutedTone),
                          ),
                          const SizedBox(height: 20),
                          _dateField(
                            label: 'Geldig van',
                            value: from,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(
                              const Duration(days: 730),
                            ),
                            onChanged: (value) {
                              if (!sheetContext.mounted) return;
                              setSheetState(() => from = value ?? from);
                            },
                          ),
                          if (planType == 'temporary')
                            _dateField(
                              label: 'Geldig tot en met',
                              value: until,
                              firstDate: from,
                              lastDate: DateTime.now().add(
                                const Duration(days: 730),
                              ),
                              onChanged: (value) {
                                if (!sheetContext.mounted) return;
                                setSheetState(() => until = value ?? until);
                              },
                            ),
                          if (error != null)
                            Text(
                              error!,
                              style: TextStyle(
                                color: Theme.of(sheetContext).colorScheme.error,
                              ),
                            ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () async {
                              if (planType == 'temporary' &&
                                  until.isBefore(from)) {
                                setSheetState(
                                  () =>
                                      error = 'Controleer de geldige periode.',
                                );
                                return;
                              }
                              try {
                                await _createFeedingPlan(
                                  planType,
                                  planType == 'standard'
                                      ? 'Basisvoeding'
                                      : 'Tijdelijk schema',
                                  planType == 'standard'
                                      ? 'Voedingsschema opgeslagen'
                                      : 'Tijdelijke aanpassing opgeslagen',
                                  from,
                                  planType == 'temporary' ? until : null,
                                );
                                if (sheetContext.mounted)
                                  Navigator.pop(sheetContext);
                              } catch (caught) {
                                if (!sheetContext.mounted) return;
                                setSheetState(
                                  () => error = _friendlyError(caught),
                                );
                              }
                            },
                            child: Text('Opslaan'),
                          ),
                        ],
                      ),
                    ),
                  ),
            ),
          ),
    );
  }

  Future<void> _createFeedingPlan(
    String type,
    String name,
    String reason,
    DateTime from,
    DateTime? until,
  ) async {
    final horseId = _selectedHorseId;
    if (horseId == null || _busy) return;
    setState(() => _busy = true);
    try {
      await _client.rpc(
        'create_canonical_horse_feeding_plan',
        params: {
          'p_horse_id': horseId,
          'p_plan_type': type,
          'p_name': name,
          'p_effective_from': _dateIso(from),
          'p_effective_until': until == null ? null : _dateIso(until),
          'p_change_reason': reason,
          'p_request_id': _uuid.v4(),
        },
      );
      await _load(selectHorseId: horseId);
      _showNotice('Voedingsschema aangemaakt. Voeg nu voerbeurten toe.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showFeedingItemEditor(
    Map<String, dynamic> plan,
    Map<String, dynamic> version,
  ) async {
    final product = _controller();
    final quantity = _controller();
    final instruction = _controller();
    const category = 'feed';
    var unit = 'kg';
    var round = 'morning';
    var time = const TimeOfDay(hour: 8, minute: 0);
    String? error;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _panelTone,
      builder:
          (sheetContext) => _horseModalTheme(
            sheetContext,
            StatefulBuilder(
              builder:
                  (sheetContext, setSheetState) => Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      22,
                      20,
                      MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
                    ),
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Voerbeurt toevoegen',
                            style: Theme.of(sheetContext)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 20),
                          DropdownButtonFormField<String>(
                            initialValue: round,
                            decoration: const InputDecoration(
                              labelText: 'Moment',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'morning',
                                child: Text('Ochtend'),
                              ),
                              DropdownMenuItem(
                                value: 'afternoon',
                                child: Text('Middag'),
                              ),
                              DropdownMenuItem(
                                value: 'evening',
                                child: Text('Avond'),
                              ),
                            ],
                            onChanged:
                                (value) => setSheetState(() {
                                  round = value ?? round;
                                  time = switch (round) {
                                    'morning' => const TimeOfDay(
                                      hour: 8,
                                      minute: 0,
                                    ),
                                    'afternoon' => const TimeOfDay(
                                      hour: 13,
                                      minute: 0,
                                    ),
                                    _ => const TimeOfDay(hour: 18, minute: 0),
                                  };
                                }),
                          ),
                          const SizedBox(height: 14),
                          _field(
                            product,
                            'Product of omschrijving',
                            required: true,
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _field(
                                  quantity,
                                  'Hoeveelheid',
                                  required: true,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: unit,
                                  decoration: const InputDecoration(
                                    labelText: 'Eenheid',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'g',
                                      child: Text('g'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'kg',
                                      child: Text('kg'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'ml',
                                      child: Text('ml'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'l',
                                      child: Text('l'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'scoop',
                                      child: Text('schep'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'portion',
                                      child: Text('portie'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'piece',
                                      child: Text('stuk'),
                                    ),
                                  ],
                                  onChanged:
                                      (value) => setSheetState(
                                        () => unit = value ?? unit,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await _pickTime24(time);
                              if (picked != null)
                                setSheetState(() => time = picked);
                            },
                            icon: Icon(Icons.schedule),
                            label: Text(
                              'Tijdstip · ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                            ),
                          ),
                          const SizedBox(height: 14),
                          _field(instruction, 'Notitie (optioneel)', lines: 3),
                          if (error != null)
                            Text(
                              error!,
                              style: TextStyle(
                                color: Theme.of(sheetContext).colorScheme.error,
                              ),
                            ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () async {
                              final parsedQuantity = double.tryParse(
                                quantity.text.replaceAll(',', '.'),
                              );
                              if (product.text.trim().isEmpty ||
                                  parsedQuantity == null ||
                                  parsedQuantity <= 0) {
                                setSheetState(
                                  () =>
                                      error =
                                          'Vul een product en geldige hoeveelheid in.',
                                );
                                return;
                              }
                              try {
                                await _saveFeedingItem(
                                  version,
                                  category,
                                  product.text.trim(),
                                  parsedQuantity,
                                  unit,
                                  round,
                                  time,
                                  instruction.text.trim(),
                                );
                                if (sheetContext.mounted)
                                  Navigator.pop(sheetContext);
                              } catch (caught) {
                                setSheetState(
                                  () => error = _friendlyError(caught),
                                );
                              }
                            },
                            child: Text('Opslaan'),
                          ),
                        ],
                      ),
                    ),
                  ),
            ),
          ),
    );
    product.dispose();
    quantity.dispose();
    instruction.dispose();
  }

  Future<void> _saveFeedingItem(
    Map<String, dynamic> version,
    String category,
    String product,
    double quantity,
    String unit,
    String round,
    TimeOfDay time,
    String instruction,
  ) async {
    final horseId = _selectedHorseId;
    if (horseId == null || _busy) return;
    setState(() => _busy = true);
    try {
      await _client.rpc(
        'upsert_canonical_horse_feeding_item',
        params: {
          'p_horse_id': horseId,
          'p_feeding_plan_version_id': version['feeding_plan_version_id'],
          'p_feeding_plan_item_id': null,
          'p_expected_row_version': null,
          'p_item_category': category,
          'p_product_brand': null,
          'p_product_name': product,
          'p_product_variant': null,
          'p_planned_quantity': quantity,
          'p_unit_code': unit,
          'p_offering_method': category == 'hay' ? 'hay_net' : 'bucket',
          'p_round_code': round,
          'p_local_time':
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00',
          'p_weekdays': null,
          'p_interval_days': null,
          'p_override_key': '$round-${_uuid.v4()}',
          'p_instruction': instruction.isEmpty ? null : instruction,
          'p_request_id': _uuid.v4(),
        },
      );
      await _load(selectHorseId: horseId);
      _showNotice('Voerbeurt toegevoegd.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _transitionFeedingVersion(
    Map<String, dynamic> version,
    String action,
  ) async {
    final horseId = _selectedHorseId;
    if (horseId == null || _busy) return;
    setState(() => _busy = true);
    try {
      await _client.rpc(
        'transition_canonical_horse_feeding_version',
        params: {
          'p_horse_id': horseId,
          'p_feeding_plan_version_id': version['feeding_plan_version_id'],
          'p_expected_row_version': version['row_version'],
          'p_action': action,
          'p_request_id': _uuid.v4(),
        },
      );
      await _load(selectHorseId: horseId);
      _showNotice(
        action == 'approve'
            ? 'Schema is klaar voor activering.'
            : 'Voedingsschema geactiveerd.',
      );
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retireFeedingPlan(Map<String, dynamic> plan) async {
    final horseId = _selectedHorseId;
    if (horseId == null || _busy) return;
    setState(() => _busy = true);
    try {
      await _client.rpc(
        'retire_canonical_horse_feeding_plan',
        params: {
          'p_horse_id': horseId,
          'p_feeding_plan_id': plan['feeding_plan_id'],
          'p_expected_row_version': plan['row_version'],
          'p_request_id': _uuid.v4(),
        },
      );
      await _load(selectHorseId: horseId);
      _showNotice(
        'Tijdelijk schema verwijderd; het actieve schema is bijgewerkt.',
      );
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _domainEmptyCard(IconData icon, String title, String body) =>
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: _panelTone,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _warmBorderTone),
        ),
        child: Column(
          children: [
            Icon(icon, color: _roseBronzeTone, size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 7),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(color: _mutedTone, height: 1.45),
            ),
          ],
        ),
      );

  String _feedingRoundLabel(dynamic value) => switch (value?.toString()) {
    'morning' => 'Ochtend',
    'afternoon' => 'Middag',
    'evening' => 'Avond',
    'extra' => 'Extra voerbeurt',
    _ => value?.toString() ?? 'Voerbeurt',
  };

  String _textValue(dynamic value) => value?.toString().trim() ?? '';

  String _ageLabel(dynamic value) {
    final born = _dateValue(value);
    if (born == null) return '';
    final now = DateTime.now();
    var years = now.year - born.year;
    if (now.month < born.month ||
        (now.month == born.month && now.day < born.day)) {
      years -= 1;
    }
    return years < 0 ? '' : '$years jaar';
  }

  String _sexLabel(dynamic value) => switch (value?.toString()) {
    'mare' => 'Merrie',
    'gelding' => 'Ruin',
    'stallion' => 'Hengst',
    _ => '',
  };

  String _relationshipLabel(dynamic value) => switch (value?.toString()) {
    'rider' => 'Ruiter',
    'trainer' => 'Trainer',
    'groom' => 'Verzorger',
    'veterinarian' => 'Dierenarts',
    'farrier' => 'Hoefsmid',
    _ => 'Betrokkene',
  };

  String _permissionLabel(dynamic value) => switch (value?.toString()) {
    'horse.view' => 'Bekijken',
    'horse.edit' => 'Profiel wijzigen',
    'horse.manage' => 'Betrokkenen beheren',
    'horse.assign' => 'Toegang toewijzen',
    'horse.share' => 'Delen',
    _ => 'Beperkte bevoegdheid',
  };

  String _linkTypeLabel(dynamic value) => switch (value?.toString()) {
    'resident' => 'Verblijf',
    'training' => 'Training',
    'boarding' => 'Stalling',
    'care' => 'Verzorging',
    _ => 'Stalkoppeling',
  };

  String _statusLabel(dynamic value) => switch (value?.toString()) {
    'active' => 'Actief',
    'proposed' => 'In afwachting',
    'pending' => 'In afwachting',
    'accepted' => 'Geaccepteerd',
    'ended' => 'Beëindigd',
    'revoked' => 'Ingetrokken',
    'archived' => 'Gearchiveerd',
    _ => 'Vastgelegd',
  };

  String _auditLabel(dynamic value) => switch (value?.toString()) {
    'horse.created' => 'Paard toegevoegd',
    'horse.updated' => 'Profiel bijgewerkt',
    'horse.access_changed' => 'Toegang gewijzigd',
    'horse.authority_transfer_started' => 'Overdracht gestart',
    'horse.authority_transferred' => 'Hoofdbeheer overgedragen',
    _ => 'Wijziging vastgelegd',
  };

  Widget _informationCard({
    required String title,
    required IconData icon,
    required List<(String, String)> facts,
    required String emptyMessage,
    required VoidCallback? onEdit,
  }) {
    final visible = facts.where((fact) => fact.$2.trim().isNotEmpty).toList();
    return Card(
      elevation: 0,
      color: _panelTone,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: _warmBorderTone),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (onEdit != null)
                  TextButton(
                    onPressed: _busy ? null : onEdit,
                    child: Text(visible.isEmpty ? 'Aanvullen' : 'Wijzigen'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (visible.isEmpty)
              Text(emptyMessage)
            else
              Wrap(
                spacing: 28,
                runSpacing: 16,
                children: [
                  for (final fact in visible)
                    SizedBox(
                      width: fact.$1 == 'Notities' ? 440 : 190,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fact.$1,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(height: 3),
                          Text(fact.$2),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _authorityCard(
    Map<String, dynamic> horse,
    Map<String, dynamic> workspace,
  ) {
    final delegations = _rows(workspace['delegations']);
    final pending =
        workspace['pending_transfer'] is Map
            ? _map(workspace['pending_transfer'])
            : null;
    return Card(
      elevation: 0,
      color: _panelTone,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: _warmBorderTone),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Beheer van het paard',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Chip(
                  label: Text(
                    horse['is_primary_authority'] == true
                        ? 'Hoofdbeheerder'
                        : 'Beperkte toegang',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Er is precies één hoofdbeheerder. Alleen die persoon kan het hoofdbeheer overdragen of andere beheerders toevoegen.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (horse['is_primary_authority'] == true)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _addDelegation,
                    icon: Icon(Icons.person_add_alt),
                    label: Text('Beheerder toevoegen'),
                  ),
                if (horse['can_transfer'] == true && pending == null)
                  FilledButton.icon(
                    onPressed: _busy ? null : _startTransfer,
                    icon: Icon(Icons.swap_horiz),
                    label: Text('Hoofdbeheer overdragen'),
                  ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _receiveTransfer,
                  icon: Icon(Icons.input),
                  label: Text('Overdracht ontvangen'),
                ),
              ],
            ),
            if (pending != null) ...[
              const Divider(height: 28),
              Text('Open overdracht naar ${pending['recipient_name']}'),
              Text('Verloopt: ${_displayDateTime(pending['expires_at'])}'),
              TextButton.icon(
                onPressed:
                    _busy
                        ? null
                        : () => _endRecord('revoke_horse_authority_transfer', {
                          'p_transfer_id': pending['id'],
                          'p_expected_row_version': pending['row_version'],
                        }),
                icon: Icon(Icons.cancel_outlined),
                label: Text('Overdracht intrekken'),
              ),
            ],
            if (delegations.isNotEmpty) ...[
              const Divider(height: 28),
              Text(
                'Gemachtigde beheerders',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final delegation in delegations)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    delegation['profile_name']?.toString() ?? 'Profiel',
                  ),
                  subtitle: Text(
                    '${(delegation['permission_codes'] as List?)?.map(_permissionLabel).join(', ') ?? ''}\nGeldig tot ${_displayDateTime(delegation['valid_until'])}',
                  ),
                  isThreeLine: true,
                  trailing:
                      delegation['status'] == 'active' &&
                              horse['is_primary_authority'] == true
                          ? IconButton(
                            tooltip: 'Machtiging beëindigen',
                            icon: Icon(Icons.person_remove_outlined),
                            onPressed:
                                _busy
                                    ? null
                                    : () => _endRecord(
                                      'end_horse_delegated_administrator',
                                      {
                                        'p_delegation_id': delegation['id'],
                                        'p_expected_row_version':
                                            delegation['row_version'],
                                        'p_reason_code': 'AUTHORITY_REVOKED',
                                      },
                                    ),
                          )
                          : null,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _organizationLinksCard(
    Map<String, dynamic> horse,
    List<Map<String, dynamic>> links,
  ) => Card(
    elevation: 0,
    color: _panelTone,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: _warmBorderTone),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Paard-stalkoppelingen',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (horse['can_manage'] == true)
                IconButton(
                  onPressed: _busy ? null : _proposeOrganizationLink,
                  icon: Icon(Icons.add_link),
                  tooltip: 'Koppeling aanvragen',
                ),
            ],
          ),
          Text(
            'Een koppeling wordt pas actief nadat zowel het paardbeheer als de stal deze bevestigt. De koppeling geeft zelf geen toegang.',
          ),
          const SizedBox(height: 8),
          if (links.isEmpty)
            Text('Geen organisatiekoppelingen voor dit paard.')
          else
            for (final link in links)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.business_outlined),
                title: Text(
                  link['organization_name']?.toString() ?? 'Stalorganisatie',
                ),
                subtitle: Text(
                  '${_linkTypeLabel(link['link_type'])} · ${_statusLabel(link['status'])}\nPaard ${link['horse_confirmed'] == true ? 'bevestigd' : 'wacht op bevestiging'} · stal ${link['organization_confirmed'] == true ? 'bevestigd' : 'wacht op bevestiging'}',
                ),
                trailing:
                    horse['can_manage'] == true
                        ? Wrap(
                          spacing: 2,
                          children: [
                            if (link['status'] == 'proposed' &&
                                link['initiating_context'] == 'organization')
                              PopupMenuButton<String>(
                                onSelected:
                                    (value) =>
                                        _respondOrganizationLink(link, value),
                                itemBuilder:
                                    (_) => const [
                                      PopupMenuItem(
                                        value: 'accept',
                                        child: Text('Bevestigen'),
                                      ),
                                      PopupMenuItem(
                                        value: 'reject',
                                        child: Text('Weigeren'),
                                      ),
                                    ],
                              ),
                            if (link['status'] == 'proposed' &&
                                link['initiating_context'] == 'horse')
                              IconButton(
                                onPressed:
                                    _busy
                                        ? null
                                        : () => _respondOrganizationLink(
                                          link,
                                          'withdraw',
                                        ),
                                icon: Icon(Icons.cancel_outlined),
                                tooltip: 'Aanvraag intrekken',
                              ),
                            if (link['status'] == 'active') ...[
                              IconButton(
                                onPressed:
                                    _busy
                                        ? null
                                        : () =>
                                            _grantOrganizationRoleHorseAccess(
                                              link,
                                            ),
                                icon: Icon(Icons.key_outlined),
                                tooltip: 'Toegang verlenen',
                              ),
                              IconButton(
                                onPressed:
                                    _busy
                                        ? null
                                        : () => _respondOrganizationLink(
                                          link,
                                          'end',
                                        ),
                                icon: Icon(Icons.link_off),
                                tooltip: 'Koppeling beëindigen',
                              ),
                            ],
                          ],
                        )
                        : null,
              ),
        ],
      ),
    ),
  );

  Widget _recordsCard(
    String title,
    String explanation,
    List<Map<String, dynamic>> rows,
    VoidCallback? add,
    String Function(Map<String, dynamic>) label, {
    String? endRpc,
    String? idParam,
  }) => Card(
    elevation: 0,
    color: _panelTone,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: _warmBorderTone),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (add != null)
                IconButton(
                  onPressed: _busy ? null : add,
                  icon: Icon(Icons.add),
                  tooltip: 'Toevoegen',
                ),
            ],
          ),
          Text(explanation),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            Text('Geen registraties.')
          else
            for (final row in rows)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(label(row)),
                subtitle: Text(
                  '${_statusLabel(row['status'])} · vanaf ${_displayDateTime(row['valid_from'])}',
                ),
                trailing:
                    endRpc != null &&
                            row['status'] == 'active' &&
                            _selected?['can_manage'] == true
                        ? IconButton(
                          icon: Icon(Icons.close),
                          tooltip: 'Beëindigen',
                          onPressed:
                              _busy
                                  ? null
                                  : () => _endRecord(endRpc, {
                                    idParam!: row['id'],
                                    'p_expected_row_version':
                                        row['row_version'],
                                  }),
                        )
                        : null,
              ),
        ],
      ),
    ),
  );

  Widget _auditCard(List<Map<String, dynamic>> audit) => Card(
    elevation: 0,
    color: _panelTone,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: _warmBorderTone),
    ),
    child: ExpansionTile(
      title: Text('Historie'),
      subtitle: Text('Vastgelegde wijzigingen en beheeracties'),
      children:
          audit.isEmpty
              ? const [ListTile(title: Text('Geen zichtbare gebeurtenissen.'))]
              : audit
                  .take(20)
                  .map(
                    (event) => ListTile(
                      title: Text(_auditLabel(event['event_type'])),
                      subtitle: Text(_displayDateTime(event['occurred_at'])),
                    ),
                  )
                  .toList(growable: false),
    ),
  );
}

class _AvarynWordmark extends StatelessWidget {
  const _AvarynWordmark({this.compact = false, this.onHero = false});

  final bool compact;
  final bool onHero;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = onHero ? Colors.white : colors.onSurface;
    final background =
        onHero
            ? Colors.black.withValues(alpha: .3)
            : colors.surfaceContainerHigh;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 28 : 34,
          height: compact ? 28 : 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: const Color(0xFFC98980)),
          ),
          child: Text(
            'A',
            style: TextStyle(
              color: foreground,
              fontSize: compact ? 14 : 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Text(
          'A V A R Y N',
          style: TextStyle(
            color: foreground,
            fontSize: compact ? 11 : 13,
            fontWeight: FontWeight.w700,
            letterSpacing: compact ? 1.2 : 1.7,
          ),
        ),
      ],
    );
  }
}

class _AvarynHorseHeadPainter extends CustomPainter {
  const _AvarynHorseHeadPainter({
    required this.backgroundColor,
    required this.silhouetteColor,
  });

  final Color backgroundColor;
  final Color silhouetteColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor);
    final side = size.width < size.height ? size.width : size.height;
    canvas.save();
    canvas.translate((size.width - side) / 2, (size.height - side) / 2);
    final silhouette =
        Paint()
          ..color = silhouetteColor
          ..isAntiAlias = true;
    final horse =
        Path()
          ..moveTo(side * .17, side * .92)
          ..cubicTo(
            side * .22,
            side * .82,
            side * .21,
            side * .73,
            side * .23,
            side * .64,
          )
          ..cubicTo(
            side * .24,
            side * .59,
            side * .26,
            side * .55,
            side * .29,
            side * .51,
          )
          ..cubicTo(
            side * .30,
            side * .48,
            side * .30,
            side * .45,
            side * .30,
            side * .42,
          )
          ..cubicTo(
            side * .34,
            side * .43,
            side * .36,
            side * .40,
            side * .36,
            side * .36,
          )
          ..cubicTo(
            side * .40,
            side * .37,
            side * .43,
            side * .32,
            side * .46,
            side * .27,
          )
          ..cubicTo(
            side * .45,
            side * .22,
            side * .45,
            side * .16,
            side * .46,
            side * .12,
          )
          ..cubicTo(
            side * .47,
            side * .09,
            side * .49,
            side * .06,
            side * .51,
            side * .07,
          )
          ..cubicTo(
            side * .54,
            side * .11,
            side * .56,
            side * .18,
            side * .56,
            side * .24,
          )
          ..cubicTo(
            side * .58,
            side * .21,
            side * .60,
            side * .16,
            side * .63,
            side * .12,
          )
          ..cubicTo(
            side * .65,
            side * .09,
            side * .67,
            side * .08,
            side * .68,
            side * .11,
          )
          ..cubicTo(
            side * .70,
            side * .16,
            side * .69,
            side * .23,
            side * .66,
            side * .29,
          )
          ..cubicTo(
            side * .71,
            side * .34,
            side * .73,
            side * .39,
            side * .73,
            side * .46,
          )
          ..cubicTo(
            side * .74,
            side * .53,
            side * .79,
            side * .58,
            side * .85,
            side * .61,
          )
          ..cubicTo(
            side * .90,
            side * .63,
            side * .93,
            side * .65,
            side * .92,
            side * .69,
          )
          ..cubicTo(
            side * .91,
            side * .73,
            side * .87,
            side * .75,
            side * .82,
            side * .75,
          )
          ..cubicTo(
            side * .74,
            side * .76,
            side * .68,
            side * .72,
            side * .61,
            side * .67,
          )
          ..cubicTo(
            side * .57,
            side * .75,
            side * .56,
            side * .84,
            side * .63,
            side * .92,
          )
          ..close();
    canvas.drawPath(horse, silhouette);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AvarynHorseHeadPainter oldDelegate) =>
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.silhouetteColor != silhouetteColor;
}

class _SectionIntro extends StatelessWidget {
  const _SectionIntro({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(body),
      ],
    ),
  );
}

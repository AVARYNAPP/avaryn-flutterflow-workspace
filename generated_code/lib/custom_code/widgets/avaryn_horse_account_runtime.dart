// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class AvarynHorseAccountRuntime extends StatefulWidget {
  const AvarynHorseAccountRuntime({super.key, this.width, this.height});

  final double? width;
  final double? height;

  @override
  State<AvarynHorseAccountRuntime> createState() =>
      _AvarynHorseAccountRuntimeState();
}

class _AvarynHorseAccountRuntimeState extends State<AvarynHorseAccountRuntime> {
  final _uuid = const Uuid();
  StreamSubscription<AuthState>? _authSubscription;
  List<Map<String, dynamic>> _horses = const [];
  Map<String, String> _photoUrls = const {};
  Map<String, dynamic>? _workspace;
  String? _selectedHorseId;
  bool _loading = true;
  bool _busy = false;
  String? _error;

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
    super.dispose();
  }

  List<Map<String, dynamic>> _rows(dynamic value) => value is List
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
          _workspace = null;
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
      final wanted = selectHorseId ?? _selectedHorseId;
      final selected = horses.any((horse) => horse['horse_id'] == wanted)
          ? wanted
          : horses.isEmpty
              ? null
              : horses.first['horse_id']?.toString();
      Map<String, dynamic>? workspace;
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
      }
      if (!mounted) return;
      setState(() {
        _horses = horses;
        _photoUrls = photoUrls;
        _selectedHorseId = selected;
        _workspace = workspace;
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
    final storageUri = Uri.tryParse(_client.storage.url);
    if (storageUri == null || storageUri.scheme != 'https') return const {};
    final entries = await Future.wait(
      horses.map((horse) async {
        final horseId = horse['horse_id']?.toString() ?? '';
        final assetId = horse['profile_media_asset_id']?.toString() ?? '';
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
          final data = _map(response.data);
          final uri = Uri.tryParse(
            data['signed_download_url']?.toString() ?? '',
          );
          if (response.status != 200 ||
              uri == null ||
              uri.scheme != 'https' ||
              uri.host.toLowerCase() != storageUri.host.toLowerCase() ||
              uri.port != storageUri.port ||
              !uri.path.startsWith('/storage/v1/object/sign/horse-media/')) {
            return null;
          }
          return MapEntry(horseId, uri.toString());
        } catch (_) {
          return null;
        }
      }),
    );
    return Map.fromEntries(entries.whereType<MapEntry<String, String>>());
  }

  Future<void> _selectHorse(String id) async {
    setState(() {
      _selectedHorseId = id;
      _workspace = null;
      _loading = true;
    });
    await _load(selectHorseId: id);
  }

  String _friendlyError(Object error) {
    final raw = error.toString();
    if (raw.contains('STALE_')) {
      return 'Deze gegevens zijn intussen gewijzigd. Ververs en probeer opnieuw.';
    }
    if (raw.contains('PRIMARY_HORSE_AUTHORITY_REQUIRED')) {
      return 'Alleen de primaire Horse Authority kan dit uitvoeren.';
    }
    if (raw.contains('TRANSFER_NOT_AVAILABLE')) {
      return 'Deze overdracht is niet beschikbaar, verlopen of al afgehandeld.';
    }
    if (raw.contains('ACTIVE_VERIFIED_TARGET_REQUIRED')) {
      return 'Gebruik het bevestigde e-mailadres van een actief AVARYN-profiel.';
    }
    if (raw.contains('HORSE_PERMISSION_DENIED') ||
        raw.contains('insufficient_privilege')) {
      return 'Je hebt niet de vereiste expliciete bevoegdheid.';
    }
    return 'De beveiligde verbinding is niet beschikbaar. Controleer je internetverbinding en ververs.';
  }

  Future<void> _mutate(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
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

  DateTime? _date(String value) =>
      value.trim().isEmpty ? null : DateTime.tryParse(value.trim());

  Future<void> _showHorseEditor({Map<String, dynamic>? horse}) async {
    final displayName = _controller(horse?['display_name']);
    final officialName = _controller(horse?['official_name']);
    final birthDate = _controller(horse?['birth_date']);
    final breed = _controller(horse?['breed']);
    final discipline = _controller(horse?['discipline']);
    final level = _controller(horse?['level']);
    final color = _controller(horse?['color']);
    final notes = _controller(horse?['notes']);
    final chip = _controller(horse?['chip_number']);
    final passport = _controller(horse?['passport_number']);
    final passportUntil = _controller(horse?['passport_valid_until']);
    var sex = horse?['sex']?.toString() ?? 'unknown';
    var status = horse?['lifecycle_status']?.toString() ?? 'active';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            horse == null ? 'Paard toevoegen' : 'Paard bewerken',
          ),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(displayName, 'Roepnaam *'),
                  _field(officialName, 'Officiële naam'),
                  _field(birthDate, 'Geboortedatum (JJJJ-MM-DD)'),
                  DropdownButtonFormField<String>(
                    initialValue: sex,
                    decoration: const InputDecoration(
                      labelText: 'Geslacht',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'unknown',
                        child: Text('Onbekend'),
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
                    onChanged: (value) => setDialogState(
                      () => sex = value ?? 'unknown',
                    ),
                  ),
                  _field(breed, 'Ras'),
                  _field(discipline, 'Discipline'),
                  _field(level, 'Niveau'),
                  _field(color, 'Kleur'),
                  _field(chip, 'Chipnummer'),
                  _field(passport, 'Paspoortnummer'),
                  _field(
                    passportUntil,
                    'Paspoort geldig t/m (JJJJ-MM-DD)',
                  ),
                  _field(notes, 'Notities', lines: 3),
                  if (horse != null)
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(
                        labelText: 'Status',
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
                      onChanged: (value) => setDialogState(
                        () => status = value ?? 'active',
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuleren'),
            ),
            FilledButton(
              onPressed: () {
                if (displayName.text.trim().isEmpty) return;
                Navigator.pop(context, true);
              },
              child: const Text('Opslaan'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    await _mutate(() async {
      if (horse == null) {
        final result = _rows(
          await _client.rpc(
            'create_canonical_horse_profile',
            params: {
              'p_display_name': displayName.text.trim(),
              'p_official_name': officialName.text.trim(),
              'p_birth_date':
                  _date(birthDate.text)?.toIso8601String().split('T').first,
              'p_sex': sex,
              'p_breed': breed.text.trim(),
              'p_discipline': discipline.text.trim(),
              'p_level': level.text.trim(),
              'p_color': color.text.trim(),
              'p_notes': notes.text.trim(),
              'p_chip_number': chip.text.trim(),
              'p_passport_number': passport.text.trim(),
              'p_passport_valid_until':
                  _date(passportUntil.text)?.toIso8601String().split('T').first,
              'p_correlation_id': _uuid.v4(),
            },
          ),
        );
        if (result.isNotEmpty) {
          _selectedHorseId = result.first['horse_id']?.toString();
        }
      } else {
        await _client.rpc(
          'update_canonical_horse_profile',
          params: {
            'p_horse_id': horse['horse_id'],
            'p_expected_row_version': horse['row_version'],
            'p_display_name': displayName.text.trim(),
            'p_official_name': officialName.text.trim(),
            'p_birth_date':
                _date(birthDate.text)?.toIso8601String().split('T').first,
            'p_sex': sex,
            'p_breed': breed.text.trim(),
            'p_discipline': discipline.text.trim(),
            'p_level': level.text.trim(),
            'p_color': color.text.trim(),
            'p_notes': notes.text.trim(),
            'p_chip_number': chip.text.trim(),
            'p_passport_number': passport.text.trim(),
            'p_passport_valid_until':
                _date(passportUntil.text)?.toIso8601String().split('T').first,
            'p_lifecycle_status': status,
            'p_correlation_id': _uuid.v4(),
          },
        );
      }
    });
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int lines = 1,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          maxLines: lines,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
      );

  Future<String?> _askText(
    String title,
    String label, {
    String initial = '',
    String confirm = 'Doorgaan',
  }) async {
    final controller = _controller(initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
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
            child: const Text('Annuleren'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(confirm),
          ),
        ],
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
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Beheerder machtigen'),
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
                      onChanged: (checked) => setDialogState(() {
                        checked == true
                            ? permissions.add(permission)
                            : permissions.remove(permission);
                      }),
                    ),
                  const Text(
                    'Horse Authority overdragen is nooit delegeerbaar.',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuleren'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Machtigen'),
            ),
          ],
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
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Expliciete paardtoegang verlenen'),
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
                  onChanged: (value) => setDialogState(
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
                  onChanged: (value) => setDialogState(
                    () => permission = value ?? permission,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Deze grant geldt alleen voor dit paard, deze stalrol en deze capability. De koppeling zelf geeft nul toegang.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuleren'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Verlenen'),
            ),
          ],
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
      'Horse Authority overdragen',
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
      builder: (context) => AlertDialog(
        title: const Text('Eenmalige overdrachtcode'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Deel deze code uitsluitend via een veilig kanaal met de bedoelde ontvanger. AVARYN toont hem niet opnieuw.',
              ),
              const SizedBox(height: 16),
              SelectableText(
                token!,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              const SizedBox(height: 12),
              Text('Geldig tot: ${_displayDateTime(expiresAt)}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async =>
                Clipboard.setData(ClipboardData(text: token!)),
            child: const Text('Code kopiëren'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ik heb de code veilig gedeeld'),
          ),
        ],
      ),
    );
  }

  Future<void> _receiveTransfer() async {
    final token = await _askText(
      'Overdracht ontvangen',
      'Plak de eenmalige transfertoken',
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
        builder: (context) => AlertDialog(
          title: const Text('Horse Authority-overdracht'),
          content: Text(
            'Paard: ${item['horse_name']}\nGeldig tot: ${_displayDateTime(item['expires_at'])}\n\nNa acceptatie ben jij de enige primaire Horse Authority.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'decline'),
              child: const Text('Weigeren'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'accept'),
              child: const Text('Accepteren'),
            ),
          ],
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ColoredBox(
        color: colors.surface,
        child: Column(
          children: [
            if (_error != null)
              MaterialBanner(
                content: Text(_error!),
                actions: [
                  TextButton(onPressed: _load, child: const Text('Verversen')),
                ],
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _horses.isEmpty
                      ? _emptyState(colors)
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final list = _horseList(colors);
                            final detail = _horseDetail(colors);
                            return constraints.maxWidth >= 880
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      SizedBox(width: 300, child: list),
                                      const VerticalDivider(width: 1),
                                      Expanded(child: detail),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      SizedBox(height: 190, child: list),
                                      const Divider(height: 1),
                                      Expanded(child: detail),
                                    ],
                                  );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(ColorScheme colors) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.pets_outlined, size: 54, color: colors.primary),
                const SizedBox(height: 16),
                Text(
                  'Nog geen paarden',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Een paard staat zelfstandig in AVARYN. Een stal of organisatie is niet vereist.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _showHorseEditor(),
                  icon: const Icon(Icons.add),
                  label: const Text('Eerste paard toevoegen'),
                ),
                TextButton.icon(
                  onPressed: _busy ? null : _receiveTransfer,
                  icon: const Icon(Icons.input),
                  label: const Text('Authority-overdracht ontvangen'),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _horseList(ColorScheme colors) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : () => _showHorseEditor(),
                    icon: const Icon(Icons.add),
                    label: const Text('Paard'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _busy ? null : _receiveTransfer,
                  tooltip: 'Overdracht ontvangen',
                  icon: const Icon(Icons.input),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _horses.length,
              itemBuilder: (context, index) {
                final horse = _horses[index];
                final id = horse['horse_id']?.toString() ?? '';
                return ListTile(
                  selected: id == _selectedHorseId,
                  leading: CircleAvatar(
                    backgroundImage: _photoUrls[id] == null
                        ? null
                        : NetworkImage(_photoUrls[id]!),
                    child: _photoUrls[id] == null
                        ? Text(
                            (horse['display_name']?.toString() ?? '?')
                                .characters
                                .first
                                .toUpperCase(),
                          )
                        : null,
                  ),
                  title: Text(horse['display_name']?.toString() ?? 'Paard'),
                  subtitle: Text(
                    horse['is_primary_authority'] == true
                        ? 'Primaire authority'
                        : horse['can_edit'] == true
                            ? 'Gemachtigd beheer'
                            : 'Expliciete toegang',
                  ),
                  trailing: horse['lifecycle_status'] == 'archived'
                      ? const Icon(Icons.archive_outlined)
                      : null,
                  onTap: () => _selectHorse(id),
                );
              },
            ),
          ),
        ],
      );

  Widget _horseDetail(ColorScheme colors) {
    final horse = _selected;
    if (horse == null) return const Center(child: Text('Selecteer een paard.'));
    final workspace = _workspace ?? const <String, dynamic>{};
    return RefreshIndicator(
      onRefresh: () => _load(selectHorseId: _selectedHorseId),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    horse['display_name']?.toString() ?? 'Paard',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    horse['official_name']?.toString().isNotEmpty == true
                        ? horse['official_name'].toString()
                        : 'Geen officiële naam',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              if (horse['can_edit'] == true)
                OutlinedButton.icon(
                  onPressed:
                      _busy ? null : () => _showHorseEditor(horse: horse),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Bewerken'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _profileCard(horse),
          const SizedBox(height: 14),
          _authorityCard(horse, workspace),
          const SizedBox(height: 14),
          _organizationLinksCard(horse, _rows(workspace['organization_links'])),
          const SizedBox(height: 14),
          _recordsCard(
            'Eigenaren',
            'Juridisch/contractueel eigendom staat los van Horse Authority en verleent geen toegang.',
            _rows(workspace['person_ownerships']),
            horse['can_manage'] == true ? _addOwner : null,
            (row) => '${row['profile_name']} · ${row['percentage']}%',
            endRpc: 'end_horse_person_ownership',
            idParam: 'p_ownership_id',
          ),
          const SizedBox(height: 14),
          _recordsCard(
            'Relaties',
            'Ruiter, trainer en verzorgers krijgen door deze registratie geen impliciete bevoegdheid.',
            _rows(workspace['relationships']),
            horse['can_manage'] == true ? _addRelationship : null,
            (row) => '${row['profile_name']} · ${row['relationship_type']}',
            endRpc: 'end_horse_person_relationship',
            idParam: 'p_relationship_id',
          ),
          const SizedBox(height: 14),
          _recordsCard(
            'Organisatie- en verblijfsregistraties',
            'Een stal, verblijf of organisatie-eigendom verleent nooit automatisch toegang.',
            [
              ..._rows(workspace['organization_ownerships']),
              ..._rows(workspace['residencies']),
            ],
            null,
            (row) =>
                '${row['organization_name']} · ${row.containsKey('percentage') ? '${row['percentage']}%' : 'verblijf'}',
          ),
          const SizedBox(height: 14),
          _auditCard(_rows(workspace['audit'])),
          const SizedBox(height: 90),
        ],
      ),
    );
  }

  Widget _profileCard(Map<String, dynamic> horse) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 28,
            runSpacing: 14,
            children: [
              _fact('Geboortedatum', horse['birth_date']),
              _fact('Geslacht', horse['sex']),
              _fact('Ras', horse['breed']),
              _fact('Discipline', horse['discipline']),
              _fact('Niveau', horse['level']),
              _fact('Kleur', horse['color']),
              _fact('Chipnummer', horse['chip_number']),
              _fact('Paspoort', horse['passport_number']),
              _fact('Paspoort geldig', horse['passport_valid_until']),
              _fact('Status', horse['lifecycle_status']),
              if (horse['legacy_stable_id'] != null)
                _fact('Planning & Voeding', 'gekoppeld'),
            ],
          ),
        ),
      );

  Widget _fact(String label, dynamic value) => SizedBox(
        width: 170,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            Text(
              value?.toString().trim().isNotEmpty == true
                  ? value.toString()
                  : '—',
            ),
          ],
        ),
      );

  Widget _authorityCard(
    Map<String, dynamic> horse,
    Map<String, dynamic> workspace,
  ) {
    final delegations = _rows(workspace['delegations']);
    final pending = workspace['pending_transfer'] is Map
        ? _map(workspace['pending_transfer'])
        : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_user_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Horse Authority',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Chip(
                  label: Text(
                    horse['is_primary_authority'] == true
                        ? 'Primair'
                        : 'Begrensde toegang',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Er is exact één primaire authority. Alleen die persoon kan authority overdragen of beheerders machtigen.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (horse['is_primary_authority'] == true)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _addDelegation,
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Beheerder machtigen'),
                  ),
                if (horse['can_transfer'] == true && pending == null)
                  FilledButton.icon(
                    onPressed: _busy ? null : _startTransfer,
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Authority overdragen'),
                  ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _receiveTransfer,
                  icon: const Icon(Icons.input),
                  label: const Text('Overdracht ontvangen'),
                ),
              ],
            ),
            if (pending != null) ...[
              const Divider(height: 28),
              Text('Open overdracht naar ${pending['recipient_name']}'),
              Text('Verloopt: ${_displayDateTime(pending['expires_at'])}'),
              TextButton.icon(
                onPressed: _busy
                    ? null
                    : () => _endRecord('revoke_horse_authority_transfer', {
                          'p_transfer_id': pending['id'],
                          'p_expected_row_version': pending['row_version'],
                        }),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Overdracht intrekken'),
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
                    '${(delegation['permission_codes'] as List?)?.join(', ') ?? ''}\nGeldig tot ${_displayDateTime(delegation['valid_until'])}',
                  ),
                  isThreeLine: true,
                  trailing: delegation['status'] == 'active' &&
                          horse['is_primary_authority'] == true
                      ? IconButton(
                          tooltip: 'Machtiging beëindigen',
                          icon: const Icon(Icons.person_remove_outlined),
                          onPressed: _busy
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
  ) =>
      Card(
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
                      icon: const Icon(Icons.add_link),
                      tooltip: 'Koppeling aanvragen',
                    ),
                ],
              ),
              const Text(
                'Een koppeling wordt pas actief na bevestiging door Horse Authority én de bevoegde stalcontext en verleent zelf geen toegang.',
              ),
              const SizedBox(height: 8),
              if (links.isEmpty)
                const Text('Geen organisatiekoppelingen voor dit paard.')
              else
                for (final link in links)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.business_outlined),
                    title: Text(
                      link['organization_name']?.toString() ??
                          'Stalorganisatie',
                    ),
                    subtitle: Text(
                      '${link['link_type']} · ${link['status']} · horse ${link['horse_confirmed'] == true ? 'bevestigd' : 'wacht'} · stal ${link['organization_confirmed'] == true ? 'bevestigd' : 'wacht'}',
                    ),
                    trailing: horse['can_manage'] == true
                        ? Wrap(
                            spacing: 2,
                            children: [
                              if (link['status'] == 'proposed' &&
                                  link['initiating_context'] == 'organization')
                                PopupMenuButton<String>(
                                  onSelected: (value) =>
                                      _respondOrganizationLink(link, value),
                                  itemBuilder: (_) => const [
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
                                  onPressed: _busy
                                      ? null
                                      : () => _respondOrganizationLink(
                                            link,
                                            'withdraw',
                                          ),
                                  icon: const Icon(Icons.cancel_outlined),
                                  tooltip: 'Aanvraag intrekken',
                                ),
                              if (link['status'] == 'active') ...[
                                IconButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _grantOrganizationRoleHorseAccess(
                                            link,
                                          ),
                                  icon: const Icon(Icons.key_outlined),
                                  tooltip: 'Expliciete horse grant',
                                ),
                                IconButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _respondOrganizationLink(
                                            link,
                                            'end',
                                          ),
                                  icon: const Icon(Icons.link_off),
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
  }) =>
      Card(
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
                      icon: const Icon(Icons.add),
                      tooltip: 'Toevoegen',
                    ),
                ],
              ),
              Text(explanation),
              const SizedBox(height: 8),
              if (rows.isEmpty)
                const Text('Geen registraties.')
              else
                for (final row in rows)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(label(row)),
                    subtitle: Text(
                      '${row['status']} · vanaf ${_displayDateTime(row['valid_from'])}',
                    ),
                    trailing: endRpc != null &&
                            row['status'] == 'active' &&
                            _selected?['can_manage'] == true
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Beëindigen',
                            onPressed: _busy
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
        child: ExpansionTile(
          title: const Text('Audit & historie'),
          subtitle: const Text('Append-only beveiligingshistorie'),
          children: audit.isEmpty
              ? const [ListTile(title: Text('Geen zichtbare gebeurtenissen.'))]
              : audit
                  .take(20)
                  .map(
                    (event) => ListTile(
                      title: Text(
                        event['event_type']?.toString() ?? 'Gebeurtenis',
                      ),
                      subtitle: Text(
                        '${_displayDateTime(event['occurred_at'])} · ${event['reason_code'] ?? ''}',
                      ),
                    ),
                  )
                  .toList(growable: false),
        ),
      );
}

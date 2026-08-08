import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class AvarynStableAccountRuntime extends StatefulWidget {
  const AvarynStableAccountRuntime({super.key, this.width, this.height});

  final double? width;
  final double? height;

  @override
  State<AvarynStableAccountRuntime> createState() =>
      _AvarynStableAccountRuntimeState();
}

class _AvarynStableAccountRuntimeState
    extends State<AvarynStableAccountRuntime> {
  final _uuid = const Uuid();
  StreamSubscription<AuthState>? _authSubscription;
  List<Map<String, dynamic>> _organizations = const [];
  Map<String, dynamic>? _workspace;
  String? _selectedOrganizationId;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _authSubscription = _client.auth.onAuthStateChange.listen((_) {
      if (mounted) unawaited(_load());
    });
    unawaited(_load());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final invitation = Uri.base.queryParameters['invitation'];
      final transfer = Uri.base.queryParameters['organization_transfer'];
      if (invitation != null && invitation.isNotEmpty) {
        unawaited(_respondToInvitation(initialToken: invitation));
      } else if (transfer != null && transfer.isNotEmpty) {
        unawaited(_respondToTransfer(initialToken: transfer));
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
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

  Map<String, dynamic> _first(dynamic value) {
    final rows = _rows(value);
    return rows.isEmpty ? <String, dynamic>{} : rows.first;
  }

  List<Map<String, dynamic>> _workspaceRows(String key) =>
      _rows(_workspace?[key]);

  Map<String, dynamic> get _organization => _map(_workspace?['organization']);

  Map<String, dynamic> get _capabilities => _map(_workspace?['capabilities']);

  bool _can(String code) => _capabilities[code] == true;

  Future<void> _load({String? selectOrganizationId}) async {
    if (_client.auth.currentSession == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _organizations = const [];
          _workspace = null;
          _selectedOrganizationId = null;
          _error = 'Meld je opnieuw aan om je stalaccounts te bekijken.';
        });
      }
      return;
    }
    if (mounted) setState(() => _loading = true);
    try {
      final organizations = _rows(await _client.rpc('list_stable_accounts'));
      final wanted = selectOrganizationId ?? _selectedOrganizationId;
      final selected =
          organizations.any(
                (organization) => organization['organization_id'] == wanted,
              )
              ? wanted
              : organizations.isEmpty
              ? null
              : organizations.first['organization_id']?.toString();
      Map<String, dynamic>? workspace;
      if (selected != null) {
        workspace = _map(
          await _client.rpc(
            'get_stable_account_workspace',
            params: {'p_organization_id': selected},
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _organizations = organizations;
        _selectedOrganizationId = selected;
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

  Future<void> _mutate(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
      await _load(selectOrganizationId: _selectedOrganizationId);
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyError(Object error) {
    final raw = error.toString();
    if (raw.contains('STALE_')) {
      return 'Deze gegevens zijn intussen gewijzigd. Ververs en probeer opnieuw.';
    }
    if (raw.contains('INVITATION_NOT_AVAILABLE') ||
        raw.contains('TRANSFER_NOT_AVAILABLE')) {
      return 'Deze eenmalige link is niet beschikbaar, verlopen of al afgehandeld.';
    }
    if (raw.contains('PRIMARY_ORGANIZATION_ADMIN_REQUIRED')) {
      return 'Alleen de primaire Organization Authority kan dit uitvoeren.';
    }
    if (raw.contains('PERMISSION_GRANT_EXCEEDS_ACTOR')) {
      return 'Je kunt geen bevoegdheid verlenen die buiten je eigen scope valt.';
    }
    if (raw.contains('ORGANIZATION_PERMISSION_REQUIRED') ||
        raw.contains('HORSE_PERMISSION_DENIED') ||
        raw.contains('insufficient_privilege')) {
      return 'Je hebt niet de vereiste expliciete bevoegdheid.';
    }
    if (raw.contains('SocketException') || raw.contains('Failed host lookup')) {
      return 'Je bent offline. Organisatiegegevens blijven gesloten tot de verbinding hersteld is.';
    }
    return 'De beveiligde verbinding is niet beschikbaar. Ververs en probeer opnieuw.';
  }

  TextEditingController _controller([dynamic value]) =>
      TextEditingController(text: value?.toString() ?? '');

  Future<Map<String, String>?> _textDialog({
    required String title,
    required Map<String, String> fields,
    String confirm = 'Opslaan',
  }) async {
    final controllers = {
      for (final entry in fields.entries)
        entry.key: TextEditingController(text: entry.value),
    };
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: controllers.entries
                      .map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextField(
                            controller: entry.value,
                            maxLines: entry.key == 'Omschrijving' ? 3 : 1,
                            decoration: InputDecoration(labelText: entry.key),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuleren'),
              ),
              FilledButton(
                onPressed:
                    () => Navigator.pop(context, {
                      for (final entry in controllers.entries)
                        entry.key: entry.value.text.trim(),
                    }),
                child: Text(confirm),
              ),
            ],
          ),
    );
    for (final controller in controllers.values) {
      controller.dispose();
    }
    return result;
  }

  Future<void> _createStable() async {
    final values = await _textDialog(
      title: 'Stalaccount aanmaken',
      fields: const {'Naam': '', 'Omschrijving': ''},
      confirm: 'Stal aanmaken',
    );
    if (values == null || values['Naam']!.isEmpty) return;
    await _mutate(() async {
      final created = _first(
        await _client.rpc(
          'create_stable_account',
          params: {
            'p_name': values['Naam'],
            'p_description': values['Omschrijving'],
            'p_correlation_id': _uuid.v4(),
          },
        ),
      );
      _selectedOrganizationId = created['organization_id']?.toString();
    });
  }

  Future<void> _editStable() async {
    final values = await _textDialog(
      title: 'Stalprofiel bewerken',
      fields: {
        'Naam': _organization['name']?.toString() ?? '',
        'Omschrijving': _organization['description']?.toString() ?? '',
      },
    );
    if (values == null || values['Naam']!.isEmpty) return;
    await _mutate(() async {
      await _client.rpc(
        'update_organization',
        params: {
          'p_organization_id': _selectedOrganizationId,
          'p_expected_row_version': _organization['row_version'],
          'p_name': values['Naam'],
          'p_description': values['Omschrijving'],
          'p_status': _organization['status'],
          'p_correlation_id': _uuid.v4(),
        },
      );
    });
  }

  Future<void> _inviteMember() async {
    final roles = _workspaceRows('roles')
        .where(
          (role) => role['is_reserved'] != true && role['status'] == 'active',
        )
        .toList(growable: false);
    if (roles.isEmpty) return;
    final email = _controller();
    var roleCode = roles.first['code']?.toString() ?? '';
    final accepted = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Persoon uitnodigen'),
                  content: SizedBox(
                    width: 520,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Bevestigd AVARYN-e-mailadres',
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: roleCode,
                          decoration: const InputDecoration(
                            labelText: 'Veilige roltemplate',
                          ),
                          items: roles
                              .map(
                                (role) => DropdownMenuItem(
                                  value: role['code']?.toString(),
                                  child: Text(role['name']?.toString() ?? ''),
                                ),
                              )
                              .toList(growable: false),
                          onChanged:
                              (value) => setDialogState(
                                () => roleCode = value ?? roleCode,
                              ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'De uitnodiging activeert pas na bevestiging van de juiste geverifieerde identiteit. De link is eenmalig en 7 dagen geldig.',
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
                      child: const Text('Uitnodigen'),
                    ),
                  ],
                ),
          ),
    );
    final targetEmail = email.text.trim();
    email.dispose();
    if (accepted != true || targetEmail.isEmpty) return;
    await _mutate(() async {
      final invitation = _first(
        await _client.rpc(
          'create_stable_invitation_by_role_code',
          params: {
            'p_organization_id': _selectedOrganizationId,
            'p_role_code': roleCode,
            'p_target_email': targetEmail,
            'p_expires_at':
                DateTime.now()
                    .toUtc()
                    .add(const Duration(days: 7))
                    .toIso8601String(),
            'p_correlation_id': _uuid.v4(),
          },
        ),
      );
      final token = invitation['invitation_token']?.toString() ?? '';
      if (token.isNotEmpty) {
        final link =
            Uri.base
                .replace(
                  path: '/uitnodiging',
                  queryParameters: {'invitation': token},
                )
                .toString();
        await Clipboard.setData(ClipboardData(text: link));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Eenmalige uitnodigingslink gekopieerd. Deel hem alleen met de bedoelde ontvanger.',
              ),
            ),
          );
        }
      }
    });
  }

  Future<void> _respondToInvitation({String? initialToken}) async {
    final values =
        initialToken == null
            ? await _textDialog(
              title: 'Uitnodiging openen',
              fields: const {'Eenmalige code': ''},
              confirm: 'Controleren',
            )
            : {'Eenmalige code': initialToken};
    final token = values?['Eenmalige code']?.trim() ?? '';
    if (token.isEmpty || !mounted) return;
    final preview = _rows(
      await _client.rpc(
        'preview_organization_invitation',
        params: {'p_invitation_token': token},
      ),
    );
    if (preview.isEmpty) {
      setState(
        () =>
            _error =
                'Deze uitnodiging hoort niet bij je bevestigde account of is verlopen.',
      );
      return;
    }
    final item = preview.first;
    if (!mounted) return;
    final action = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Staluitnodiging'),
            content: Text(
              'Je bent uitgenodigd voor ${item['organization_name']} als ${item['role_name']}. Een membership geeft alleen de getoonde expliciete capabilities.',
            ),
            actions: [
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
        'respond_stable_invitation',
        params: {
          'p_invitation_token': token,
          'p_action': action,
          'p_correlation_id': _uuid.v4(),
        },
      );
    });
  }

  Future<void> _revokeInvitation(Map<String, dynamic> invitation) async {
    await _mutate(() async {
      await _client.rpc(
        'revoke_organization_invitation',
        params: {
          'p_invitation_id': invitation['id'],
          'p_expected_row_version': invitation['row_version'],
          'p_correlation_id': _uuid.v4(),
        },
      );
    });
  }

  Future<void> _setMembershipStatus(
    Map<String, dynamic> membership,
    String status,
  ) async {
    await _mutate(() async {
      await _client.rpc(
        'set_organization_membership_status',
        params: {
          'p_membership_id': membership['id'],
          'p_expected_row_version': membership['row_version'],
          'p_status': status,
          'p_reason_code': status == 'ended' ? 'membership_ended' : null,
          'p_correlation_id': _uuid.v4(),
        },
      );
    });
  }

  static const _editablePermissions = <String>[
    'organization.view',
    'organization.edit',
    'organization.memberships.view',
    'organization.memberships.manage',
    'organization.roles.view',
    'organization.roles.manage',
    'organization.audit.view',
    'organization.invitations.manage',
    'organization.horse_links.manage',
    'organization.residencies.manage',
    'organization.planning.view',
    'organization.planning.execute',
    'organization.feeding.view',
    'organization.feeding.edit',
  ];

  Future<void> _editRolePermissions(Map<String, dynamic> role) async {
    if (role['is_reserved'] == true) return;
    final original = _rowsOfStrings(role['permissions']).toSet();
    final selected = {...original};
    final accepted = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text('Capabilities · ${role['name']}'),
                  content: SizedBox(
                    width: 620,
                    height: 480,
                    child: ListView(
                      children: _editablePermissions
                          .map(
                            (permission) => CheckboxListTile(
                              value: selected.contains(permission),
                              title: Text(permission),
                              subtitle: const Text(
                                'Server-side, organization-scoped capability',
                              ),
                              onChanged:
                                  (value) => setDialogState(() {
                                    value == true
                                        ? selected.add(permission)
                                        : selected.remove(permission);
                                  }),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Annuleren'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Opslaan'),
                    ),
                  ],
                ),
          ),
    );
    if (accepted != true) return;
    await _mutate(() async {
      var rowVersion = (role['row_version'] as num).toInt();
      for (final permission in _editablePermissions) {
        final wasGranted = original.contains(permission);
        final shouldGrant = selected.contains(permission);
        if (wasGranted == shouldGrant) continue;
        final result = _first(
          await _client.rpc(
            'set_organization_role_permission',
            params: {
              'p_role_id': role['id'],
              'p_expected_role_row_version': rowVersion,
              'p_permission_code': permission,
              'p_grant': shouldGrant,
              'p_correlation_id': _uuid.v4(),
            },
          ),
        );
        rowVersion = (result['role_row_version'] as num).toInt();
      }
    });
  }

  List<String> _rowsOfStrings(dynamic value) =>
      value is List
          ? value.map((item) => item.toString()).toList(growable: false)
          : const [];

  Future<void> _proposeHorseLink() async {
    final values = await _textDialog(
      title: 'Paard-stalkoppeling aanvragen',
      fields: const {
        'Canonical horse UUID': '',
        'Linktype': 'training_provider',
      },
      confirm: 'Aanvragen',
    );
    if (values == null || values['Canonical horse UUID']!.isEmpty) return;
    await _mutate(() async {
      await _client.rpc(
        'propose_organization_horse_link',
        params: {
          'p_horse_id': values['Canonical horse UUID'],
          'p_organization_id': _selectedOrganizationId,
          'p_link_type_code': values['Linktype'],
          'p_initiating_context': 'organization',
          'p_correlation_id': _uuid.v4(),
        },
      );
    });
  }

  Future<void> _respondToLink(Map<String, dynamic> link, String action) async {
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

  Future<void> _grantHorseAccess(Map<String, dynamic> link) async {
    final roles = _workspaceRows('roles')
        .where(
          (role) => role['is_reserved'] != true && role['status'] == 'active',
        )
        .toList(growable: false);
    if (roles.isEmpty) return;
    var roleId = roles.first['id']?.toString() ?? '';
    var permission = 'horse.view';
    final accepted = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Expliciete paardtoegang'),
                  content: SizedBox(
                    width: 520,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: roleId,
                          decoration: const InputDecoration(
                            labelText: 'Organisatierol',
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
                        const Text(
                          'Alleen Horse Authority kan dit verlenen. De actieve link alleen geeft nul toegang.',
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
    if (accepted != true) return;
    await _mutate(() async {
      await _client.rpc(
        'grant_horse_organization_role_permission',
        params: {
          'p_horse_id': link['horse_id'],
          'p_role_id': roleId,
          'p_permission_code': permission,
          'p_link_id': link['id'],
          'p_valid_from': DateTime.now().toUtc().toIso8601String(),
          'p_valid_until':
              DateTime.now()
                  .toUtc()
                  .add(const Duration(days: 90))
                  .toIso8601String(),
          'p_reason_code': 'LINK_BOUND',
          'p_correlation_id': _uuid.v4(),
        },
      );
    });
  }

  Future<void> _startResidency() async {
    final values = await _textDialog(
      title: 'Verblijf vastleggen',
      fields: const {'Canonical horse UUID': ''},
      confirm: 'Vastleggen',
    );
    if (values == null || values['Canonical horse UUID']!.isEmpty) return;
    await _mutate(() async {
      await _client.rpc(
        'switch_horse_residency',
        params: {
          'p_horse_id': values['Canonical horse UUID'],
          'p_stable_organization_id': _selectedOrganizationId,
          'p_valid_from': DateTime.now().toUtc().toIso8601String(),
          'p_correlation_id': _uuid.v4(),
        },
      );
    });
  }

  Future<void> _endResidency(Map<String, dynamic> residency) async {
    await _mutate(() async {
      await _client.rpc(
        'end_horse_residency',
        params: {
          'p_residency_id': residency['id'],
          'p_expected_row_version': residency['row_version'],
          'p_correlation_id': _uuid.v4(),
        },
      );
    });
  }

  Future<void> _startTransfer() async {
    final values = await _textDialog(
      title: 'Organization Authority overdragen',
      fields: const {'Bevestigd e-mailadres ontvanger': ''},
      confirm: 'Transfer starten',
    );
    if (values == null || values.values.first.isEmpty) return;
    await _mutate(() async {
      final transfer = _first(
        await _client.rpc(
          'initiate_organization_authority_transfer_by_email',
          params: {
            'p_organization_id': _selectedOrganizationId,
            'p_recipient_email': values.values.first,
            'p_correlation_id': _uuid.v4(),
          },
        ),
      );
      final token = transfer['transfer_token']?.toString() ?? '';
      if (token.isNotEmpty) {
        final link =
            Uri.base
                .replace(
                  path: '/stallen',
                  queryParameters: {'organization_transfer': token},
                )
                .toString();
        await Clipboard.setData(ClipboardData(text: link));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Eenmalige transferlink gekopieerd. AVARYN toont deze niet opnieuw.',
              ),
            ),
          );
        }
      }
    });
  }

  Future<void> _respondToTransfer({String? initialToken}) async {
    final values =
        initialToken == null
            ? await _textDialog(
              title: 'Authority-transfer openen',
              fields: const {'Eenmalige code': ''},
              confirm: 'Controleren',
            )
            : {'Eenmalige code': initialToken};
    final token = values?['Eenmalige code']?.trim() ?? '';
    if (token.isEmpty || !mounted) return;
    final preview = _rows(
      await _client.rpc(
        'preview_organization_authority_transfer',
        params: {'p_transfer_token': token},
      ),
    );
    if (preview.isEmpty) {
      setState(
        () =>
            _error = 'Deze transfer hoort niet bij je account of is verlopen.',
      );
      return;
    }
    final item = preview.first;
    if (!mounted) return;
    final action = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Organization Authority-transfer'),
            content: Text(
              'Wil je de primaire Organization Authority van ${item['organization_name']} overnemen? De overdracht is atomair.',
            ),
            actions: [
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
        'respond_stable_authority_transfer',
        params: {
          'p_transfer_token': token,
          'p_action': action,
          'p_correlation_id': _uuid.v4(),
        },
      );
    });
  }

  Future<void> _revokeTransfer(Map<String, dynamic> transfer) async {
    await _mutate(() async {
      await _client.rpc(
        'revoke_organization_authority_transfer',
        params: {
          'p_transfer_id': transfer['id'],
          'p_expected_row_version': transfer['row_version'],
          'p_correlation_id': _uuid.v4(),
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading && _workspace == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Column(
        children: [
          if (_error != null)
            MaterialBanner(
              content: Text(_error!),
              actions: [
                TextButton(
                  onPressed: () => _load(),
                  child: const Text('Verversen'),
                ),
              ],
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;
                  final list = _organizationList(theme);
                  final detail =
                      _workspace == null ? _emptyState(theme) : _detail(theme);
                  return wide
                      ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(width: 300, child: list),
                          const VerticalDivider(width: 1),
                          Expanded(child: detail),
                        ],
                      )
                      : ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          SizedBox(height: 210, child: list),
                          if (_workspace != null)
                            detail
                          else
                            _emptyState(theme),
                        ],
                      );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _organizationList(ThemeData theme) => Material(
    color: theme.colorScheme.surface,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Mijn stalaccounts',
                style: theme.textTheme.titleLarge,
              ),
            ),
            IconButton(
              onPressed: _busy ? null : _createStable,
              icon: const Icon(Icons.add_business),
              tooltip: 'Stalaccount aanmaken',
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_organizations.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Nog geen stalaccount. Een stal kan zelfstandig zonder paarden of extra leden bestaan.',
            ),
          ),
        for (final organization in _organizations)
          Card(
            color:
                organization['organization_id'] == _selectedOrganizationId
                    ? theme.colorScheme.secondaryContainer
                    : null,
            child: ListTile(
              leading: const Icon(Icons.home_work_outlined),
              title: Text(organization['name']?.toString() ?? 'Stalaccount'),
              subtitle: Text(
                organization['is_primary_authority'] == true
                    ? 'Primaire Organization Authority'
                    : 'Actief membership · expliciete capabilities',
              ),
              onTap:
                  () => _load(
                    selectOrganizationId:
                        organization['organization_id']?.toString(),
                  ),
            ),
          ),
        const Divider(height: 28),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _respondToInvitation(),
          icon: const Icon(Icons.mark_email_read_outlined),
          label: const Text('Uitnodiging openen'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _respondToTransfer(),
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Authority-transfer openen'),
        ),
      ],
    ),
  );

  Widget _emptyState(ThemeData theme) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.home_work_outlined,
            size: 54,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(height: 16),
          Text('Zelfstandig stalaccount', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            'Alleen personen loggen in. De stal heeft geen gedeelde credentials en krijgt geen impliciete paardtoegang.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _createStable,
            icon: const Icon(Icons.add),
            label: const Text('Stalaccount aanmaken'),
          ),
        ],
      ),
    ),
  );

  Widget _detail(ThemeData theme) => ListView(
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
                _organization['name']?.toString() ?? 'Stalaccount',
                style: theme.textTheme.headlineSmall,
              ),
              Text(
                'Canonical organisatie · authority v${_organization['access_version']} · rij v${_organization['row_version']}',
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              if (_can('organization.edit'))
                OutlinedButton.icon(
                  onPressed: _busy ? null : _editStable,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Bewerken'),
                ),
              if (_organization['is_primary_authority'] == true)
                FilledButton.icon(
                  onPressed: _busy ? null : _startTransfer,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Authority overdragen'),
                ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 16),
      _noticeCard(theme),
      const SizedBox(height: 16),
      _membersCard(theme),
      const SizedBox(height: 16),
      _rolesCard(theme),
      const SizedBox(height: 16),
      _linksCard(theme),
      const SizedBox(height: 16),
      _residenciesCard(theme),
      const SizedBox(height: 16),
      _authorityCard(theme),
      const SizedBox(height: 16),
      _auditCard(theme),
    ],
  );

  Widget _noticeCard(ThemeData theme) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Membership, rol, residency en een actieve paard-stalkoppeling geven nooit vanzelf paardtoegang. Iedere horse capability vereist een afzonderlijke grant van Horse Authority.',
            ),
          ),
        ],
      ),
    ),
  );

  Widget _sectionHeader(String title, {Widget? action}) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      if (action != null) action,
    ],
  );

  Widget _membersCard(ThemeData theme) {
    final memberships = _workspaceRows('memberships');
    final invitations = _workspaceRows('invitations');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionHeader(
              'Leden en uitnodigingen',
              action:
                  _can('organization.memberships.manage')
                      ? TextButton.icon(
                        onPressed: _busy ? null : _inviteMember,
                        icon: const Icon(Icons.person_add_alt),
                        label: const Text('Uitnodigen'),
                      )
                      : null,
            ),
            if (memberships.isEmpty)
              const Text('Geen leden zichtbaar binnen je capabilityscope.'),
            for (final membership in memberships)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline),
                title: Text(
                  membership['profile_name']?.toString() ?? 'Persoon',
                ),
                subtitle: Text(
                  '${membership['status']} · ${_rows(membership['roles']).map((role) => role['role_name']).join(', ')}',
                ),
                trailing:
                    _can('organization.memberships.manage') &&
                            membership['profile_id'] !=
                                _organization['primary_authority_profile_id']
                        ? PopupMenuButton<String>(
                          onSelected:
                              (value) =>
                                  _setMembershipStatus(membership, value),
                          itemBuilder:
                              (_) => const [
                                PopupMenuItem(
                                  value: 'suspended',
                                  child: Text('Schorsen'),
                                ),
                                PopupMenuItem(
                                  value: 'active',
                                  child: Text('Activeren'),
                                ),
                                PopupMenuItem(
                                  value: 'ended',
                                  child: Text('Beëindigen'),
                                ),
                              ],
                        )
                        : null,
              ),
            if (invitations.isNotEmpty) const Divider(),
            for (final invitation in invitations)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.mail_outline),
                title: Text(
                  '${invitation['role_name']} · ${invitation['status']}',
                ),
                subtitle: Text('Verloopt ${invitation['expires_at']}'),
                trailing:
                    invitation['status'] == 'pending'
                        ? IconButton(
                          onPressed:
                              _busy
                                  ? null
                                  : () => _revokeInvitation(invitation),
                          icon: const Icon(Icons.cancel_outlined),
                          tooltip: 'Intrekken',
                        )
                        : null,
              ),
          ],
        ),
      ),
    );
  }

  Widget _rolesCard(ThemeData theme) {
    final roles = _workspaceRows('roles');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionHeader('Rollen als capabilitytemplates'),
            if (roles.isEmpty)
              const Text('Geen rollen zichtbaar binnen je capabilityscope.'),
            for (final role in roles)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  role['is_reserved'] == true
                      ? Icons.admin_panel_settings
                      : Icons.badge_outlined,
                ),
                title: Text(role['name']?.toString() ?? 'Rol'),
                subtitle: Text(
                  _rowsOfStrings(role['permissions']).join(' · '),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing:
                    _can('organization.roles.manage') &&
                            role['is_reserved'] != true
                        ? IconButton(
                          onPressed:
                              _busy ? null : () => _editRolePermissions(role),
                          icon: const Icon(Icons.tune),
                          tooltip: 'Capabilities beheren',
                        )
                        : null,
              ),
          ],
        ),
      ),
    );
  }

  Widget _linksCard(ThemeData theme) {
    final links = _workspaceRows('horse_links');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionHeader(
              'Paard-stalkoppelingen',
              action:
                  _can('organization.horse_links.manage')
                      ? TextButton.icon(
                        onPressed: _busy ? null : _proposeHorseLink,
                        icon: const Icon(Icons.add_link),
                        label: const Text('Aanvragen'),
                      )
                      : null,
            ),
            if (links.isEmpty)
              const Text(
                'Nog geen koppelingen. Een stal kan zonder paarden bestaan.',
              ),
            for (final link in links)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.link),
                title: Text(
                  link['horse_name']?.toString().isNotEmpty == true
                      ? link['horse_name'].toString()
                      : 'Afgeschermd canonical paard',
                ),
                subtitle: Text(
                  '${link['link_type']} · ${link['status']} · horse ${link['horse_confirmed'] == true ? 'bevestigd' : 'wacht'} · stal ${link['organization_confirmed'] == true ? 'bevestigd' : 'wacht'}',
                ),
                trailing: Wrap(
                  spacing: 2,
                  children: [
                    if (link['status'] == 'proposed' &&
                        _can('organization.horse_links.manage'))
                      PopupMenuButton<String>(
                        onSelected: (value) => _respondToLink(link, value),
                        itemBuilder:
                            (_) => [
                              if (link['initiating_context'] ==
                                  'horse') ...const [
                                PopupMenuItem(
                                  value: 'accept',
                                  child: Text('Bevestigen'),
                                ),
                                PopupMenuItem(
                                  value: 'reject',
                                  child: Text('Weigeren'),
                                ),
                              ] else
                                const PopupMenuItem(
                                  value: 'withdraw',
                                  child: Text('Intrekken'),
                                ),
                            ],
                      ),
                    if (link['status'] == 'active') ...[
                      if (link['can_manage_horse'] == true)
                        IconButton(
                          onPressed:
                              _busy ? null : () => _grantHorseAccess(link),
                          icon: const Icon(Icons.key_outlined),
                          tooltip: 'Expliciete horse grant',
                        ),
                      if (_can('organization.horse_links.manage'))
                        IconButton(
                          onPressed:
                              _busy ? null : () => _respondToLink(link, 'end'),
                          icon: const Icon(Icons.link_off),
                          tooltip: 'Koppeling beëindigen',
                        ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _residenciesCard(ThemeData theme) {
    final residencies = _workspaceRows('residencies');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionHeader(
              'Verblijfshistorie',
              action:
                  _can('organization.residencies.manage')
                      ? TextButton.icon(
                        onPressed: _busy ? null : _startResidency,
                        icon: const Icon(Icons.bedroom_parent_outlined),
                        label: const Text('Vastleggen'),
                      )
                      : null,
            ),
            const Text(
              'Residency is fysiek verblijf, geen authority, eigendom, membership of toegang.',
            ),
            for (final residency in residencies)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history),
                title: Text(
                  residency['horse_name']?.toString().isNotEmpty == true
                      ? residency['horse_name'].toString()
                      : 'Afgeschermd canonical paard',
                ),
                subtitle: Text(
                  '${residency['status']} · vanaf ${residency['valid_from']}',
                ),
                trailing:
                    residency['status'] == 'active'
                        ? IconButton(
                          onPressed:
                              _busy ? null : () => _endResidency(residency),
                          icon: const Icon(Icons.stop_circle_outlined),
                          tooltip: 'Verblijf beëindigen',
                        )
                        : null,
              ),
          ],
        ),
      ),
    );
  }

  Widget _authorityCard(ThemeData theme) {
    final transfer = _map(_workspace?['pending_authority_transfer']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionHeader('Organization Authority'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.verified_user),
              title: Text(
                _organization['primary_authority_name']?.toString() ??
                    'Primaire authority',
              ),
              subtitle: const Text(
                'Exact één scalar authority; membership en operationele rol blijven afzonderlijk.',
              ),
            ),
            if (transfer.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.hourglass_top),
                title: Text('Pending naar ${transfer['recipient_name']}'),
                subtitle: Text('Eenmalig · verloopt ${transfer['expires_at']}'),
                trailing: IconButton(
                  onPressed: _busy ? null : () => _revokeTransfer(transfer),
                  icon: const Icon(Icons.cancel_outlined),
                  tooltip: 'Transfer intrekken',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _auditCard(ThemeData theme) {
    final audit = _workspaceRows('audit');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionHeader('Securityhistorie'),
            if (audit.isEmpty)
              const Text('Geen audit zichtbaar binnen je capabilityscope.'),
            for (final event in audit.take(12))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.shield_outlined, size: 20),
                title: Text(event['event_type']?.toString() ?? 'Securityevent'),
                subtitle: Text(
                  '${event['occurred_at']} · ${event['reason_code']}',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

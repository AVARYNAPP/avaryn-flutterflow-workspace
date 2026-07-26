import 'dart:convert';

import 'phase_4b_context_model.dart';
import 'phase_4b_management_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutterflow_generated/app_state.dart';
import 'package:flutterflow_generated/backend/schema/structs/index.dart';
import 'package:flutterflow_generated/flutter_flow/flutter_flow_theme.dart';
import 'package:flutterflow_generated/flutter_flow/flutter_flow_util.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

const int _phase4BLocalScopeSchemaVersion = 2;
const Duration _phase4BOfflineAuthorityMaximumAge = Duration(hours: 24);

String _phase4BString(dynamic value) => value is String ? value.trim() : '';
DateTime? _phase4BDate(dynamic value) =>
    value is DateTime
        ? value
        : value is String
        ? DateTime.tryParse(value)
        : null;

List<T> _phase4BCopyStructList<T extends BaseStruct>(
  Iterable<T> values,
  T Function(Map<String, dynamic>) decode,
) =>
    values
        .map(
          (value) =>
              decode(jsonDecode(value.serialize()) as Map<String, dynamic>),
        )
        .toList();

LocalAccountScopeDataStruct _phase4BCaptureOperationalScope(String authUserId) {
  final state = FFAppState();
  return LocalAccountScopeDataStruct(
    authUserId: authUserId,
    horses: _phase4BCopyStructList(
      state.horses,
      HorseProfileDataStruct.fromSerializableMap,
    ),
    selectedHorse: HorseProfileDataStruct.fromSerializableMap(
      jsonDecode(state.selectedHorse.serialize()) as Map<String, dynamic>,
    ),
    selectedHorseIndex: state.selectedHorseIndex,
    nextHorseId: state.nextHorseId,
    nextHorseIndex: state.nextHorseIndex,
    horseSeedVersion: state.horseSeedVersion,
    passportPrototypeVersion: state.passportPrototypeVersion,
    activities: _phase4BCopyStructList(
      state.activities,
      ActivityDataStruct.fromSerializableMap,
    ),
    nextActivityId: state.nextActivityId,
    currentLocalUserId: state.currentLocalUserId,
    currentLocalStableId: state.currentLocalStableId,
    horseFeedingPlans: _phase4BCopyStructList(
      state.horseFeedingPlans,
      HorseFeedingPlanDataStruct.fromSerializableMap,
    ),
    temporaryFeedingSchedules: _phase4BCopyStructList(
      state.temporaryFeedingSchedules,
      TemporaryFeedingScheduleDataStruct.fromSerializableMap,
    ),
    nextFeedingItemId: state.nextFeedingItemId,
    nextTemporaryFeedingScheduleId: state.nextTemporaryFeedingScheduleId,
    feedingRoundConfigs: _phase4BCopyStructList(
      state.feedingRoundConfigs,
      FeedingRoundConfigDataStruct.fromSerializableMap,
    ),
    feedingAssignmentExceptions: _phase4BCopyStructList(
      state.feedingAssignmentExceptions,
      FeedingAssignmentExceptionDataStruct.fromSerializableMap,
    ),
    feedingExecutionRecords: _phase4BCopyStructList(
      state.feedingExecutionRecords,
      FeedingExecutionRecordDataStruct.fromSerializableMap,
    ),
    nextFeedingAssignmentExceptionId: state.nextFeedingAssignmentExceptionId,
    nextFeedingExecutionRecordId: state.nextFeedingExecutionRecordId,
    selectedCloudStableId: state.selectedCloudStableId,
    localStableCloudLinks: _phase4BCopyStructList(
      state.localStableCloudLinks,
      LocalStableCloudLinkDataStruct.fromSerializableMap,
    ),
    stableMembershipCaches: _phase4BCopyStructList(
      state.stableMembershipCaches,
      StableMembershipCacheDataStruct.fromSerializableMap,
    ),
    schemaVersion: _phase4BLocalScopeSchemaVersion,
    updatedAt: DateTime.now().toUtc(),
  );
}

void _phase4BClearSensitiveWorkingSet({String accessStatus = ''}) {
  final state = FFAppState();
  state.update(() {
    state.horses = <HorseProfileDataStruct>[];
    state.selectedHorse = HorseProfileDataStruct();
    state.selectedHorseIndex = 0;
    state.activities = <ActivityDataStruct>[];
    state.selectedActivity = ActivityDataStruct();
    state.selectedActivityIndex = 0;
    state.horseFeedingPlans = <HorseFeedingPlanDataStruct>[];
    state.temporaryFeedingSchedules = <TemporaryFeedingScheduleDataStruct>[];
    state.feedingRoundConfigs = <FeedingRoundConfigDataStruct>[];
    state.feedingAssignmentExceptions =
        <FeedingAssignmentExceptionDataStruct>[];
    state.feedingExecutionRecords = <FeedingExecutionRecordDataStruct>[];
    state.currentLocalStableId = '';
    state.selectedFeedingDateKey = '';
    state.selectedFeedingRoundId = 'morning';
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
    state.stableAccessStatus = accessStatus;
  });
}

LocalAccountScopeDataStruct? _phase4BMasterScope(String authUserId) {
  for (final scope in FFAppState().phase4BAccountOperationalBackups) {
    if (scope.authUserId == authUserId) return scope;
  }
  return null;
}

void _phase4BSaveMasterScope(LocalAccountScopeDataStruct scope) {
  final scopes = List<LocalAccountScopeDataStruct>.from(
    FFAppState().phase4BAccountOperationalBackups,
  )..removeWhere((candidate) => candidate.authUserId == scope.authUserId);
  scopes.add(scope);
  FFAppState().phase4BAccountOperationalBackups = scopes;
}

LocalAccountScopeDataStruct _phase4BSaveCurrentOperationalScope(
  String authUserId,
) {
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
  final current = _phase4BCaptureOperationalScope(authUserId);
  final existing = _phase4BMasterScope(authUserId);
  final plan = phase4BPlanSerializedOperationalMasterSave(
    current: current,
    existing: existing,
    toSerializableMap:
        (scope) => jsonDecode(scope.serialize()) as Map<String, dynamic>,
    fromSerializableMap: LocalAccountScopeDataStruct.fromSerializableMap,
  );
  if (plan.shouldPersist) _phase4BSaveMasterScope(plan.master);
  return plan.master;
}

String _phase4BStableIdForHorse(
  HorseProfileDataStruct horse,
  String fallback,
) => horse.stableId.trim().isEmpty ? fallback : horse.stableId;

LocalStableCloudLinkDataStruct? _phase4BLinkFor(
  String authUserId,
  String cloudStableId,
) {
  for (final link in FFAppState().localStableCloudLinks) {
    if (link.authUserId == authUserId &&
        link.cloudStableId == cloudStableId &&
        link.confirmed) {
      return link;
    }
  }
  return null;
}

void _phase4BLoadLinkedOperationalContext(
  LocalAccountScopeDataStruct master,
  LocalStableCloudLinkDataStruct? link,
) {
  if (link == null || link.localStableId.trim().isEmpty) {
    _phase4BClearSensitiveWorkingSet(accessStatus: 'unlinked');
    return;
  }
  final localStableId = link.localStableId;
  final horses =
      master.horses
          .where(
            (horse) =>
                _phase4BStableIdForHorse(horse, master.currentLocalStableId) ==
                localStableId,
          )
          .toList();
  HorseProfileDataStruct selected = HorseProfileDataStruct();
  var selectedIndex = 0;
  for (var index = 0; index < horses.length; index++) {
    if (horses[index].id == link.selectedHorseId) {
      selected = horses[index];
      selectedIndex = index;
      break;
    }
  }
  if (selected.id == 0 && horses.isNotEmpty) selected = horses.first;

  final state = FFAppState();
  state.update(() {
    // The local stable identifier remains local and is never replaced by a
    // cloud UUID.
    state.currentLocalStableId = localStableId;
    state.horses = horses;
    state.selectedHorse = selected;
    state.selectedHorseIndex = selectedIndex;
    state.activities =
        master.activities
            .where((item) => item.stableId == localStableId)
            .toList();
    state.horseFeedingPlans =
        master.horseFeedingPlans
            .where((item) => item.stableId == localStableId)
            .toList();
    state.temporaryFeedingSchedules =
        master.temporaryFeedingSchedules
            .where((item) => item.stableId == localStableId)
            .toList();
    state.feedingRoundConfigs =
        master.feedingRoundConfigs
            .where((item) => item.stableId == localStableId)
            .toList();
    state.feedingAssignmentExceptions =
        master.feedingAssignmentExceptions
            .where((item) => item.stableId == localStableId)
            .toList();
    state.feedingExecutionRecords =
        master.feedingExecutionRecords
            .where((item) => item.stableId == localStableId)
            .toList();
    state.stableAccessStatus = 'active';
  });
}

class AvarynStableRuntime extends StatefulWidget {
  const AvarynStableRuntime({
    super.key,
    this.width,
    this.height,
    required this.mode,
    this.initialStableMemberId = '',
  });

  final double? width;
  final double? height;
  final String mode;
  final String initialStableMemberId;

  @override
  State<AvarynStableRuntime> createState() => _AvarynStableRuntimeState();
}

class _AvarynStableRuntimeState extends State<AvarynStableRuntime>
    implements Phase4BManagementGateway {
  final _client = Supabase.instance.client;
  final _name = TextEditingController();
  final _timezone = TextEditingController(text: 'Europe/Amsterdam');
  final _email = TextEditingController();
  final _displayName = TextEditingController();
  final _functionTitle = TextEditingController();
  final _localStableId = TextEditingController();
  final _stableName = TextEditingController();
  final _stableTimezone = TextEditingController();

  bool _busy = false;
  bool _loading = true;
  bool _offline = false;
  String _error = '';
  String _notice = '';
  String _transientInvitationToken = '';
  String _transientShareLink = '';
  List<Map<String, dynamic>> _memberships = const [];
  List<Map<String, dynamic>> _directory = const [];
  List<Map<String, dynamic>> _invitations = const [];
  List<Map<String, dynamic>> _managementMembers = const [];
  Map<String, dynamic>? _invitationPreview;
  String _selectedManagementMemberId = '';
  String _memberSelectionError = '';
  String _linkMembershipId = '';
  Phase4BRole _selectedInviteRole = Phase4BRole.member;
  Phase4BRole _selectedReplacementRole = Phase4BRole.member;
  late final Phase4BManagementController _management;
  late final Phase4BMemberSelectionCoordinator _memberSelection;

  @override
  void initState() {
    super.initState();
    _management = Phase4BManagementController(
      gateway: this,
      actorRole: Phase4BRole.viewer,
      online: true,
      personalWorkspace: false,
    );
    _memberSelection = Phase4BMemberSelectionCoordinator(
      initialStableMemberId: widget.initialStableMemberId,
      requireExplicitSelection: widget.mode == 'memberDetails',
    );
    _readTransientToken();
    _load();
  }

  @override
  void dispose() {
    _transientInvitationToken = '';
    _transientShareLink = '';
    _name.dispose();
    _timezone.dispose();
    _email.dispose();
    _displayName.dispose();
    _functionTitle.dispose();
    _localStableId.dispose();
    _stableName.dispose();
    _stableTimezone.dispose();
    super.dispose();
  }

  void _readTransientToken() {
    final fragment = Uri.base.fragment;
    final query =
        fragment.contains('?')
            ? fragment.substring(fragment.indexOf('?') + 1)
            : fragment;
    final token = Uri.splitQueryString(query)['token'] ?? '';
    if (token.length >= 40 && token.length <= 128) {
      _transientInvitationToken = token;
    }
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final user = _client.auth.currentUser;
    if (user == null) {
      if (widget.mode == 'invitation') await _previewInvitation();
      _loading = false;
      if (mounted) setState(() {});
      return;
    }
    _displayName.text =
        FFAppState().currentAuthProfile.displayName.trim().isEmpty
            ? 'AVARYN-gebruiker'
            : FFAppState().currentAuthProfile.displayName;
    try {
      final rows = await _client
          .from('stable_memberships')
          .select(
            'id,stable_id,stable_member_id,role,status,row_version,'
            'stables!inner(id,name,kind,status,timezone,locale)',
          )
          .eq('status', 'active');
      _memberships = List<Map<String, dynamic>>.from(rows);
      _offline = false;
      _cacheMemberships(user.id, _memberships);
      if (FFAppState().selectedCloudStableId.isNotEmpty &&
          !_memberships.any(
            (row) => row['stable_id'] == FFAppState().selectedCloudStableId,
          )) {
        _phase4BClearSensitiveWorkingSet(accessStatus: 'removed');
        FFAppState().selectedCloudStableId = '';
      }
      if (widget.mode == 'members') await _loadDirectory();
      if (widget.mode == 'pendingInvitations') await _loadInvitations();
      if (widget.mode == 'invitation') await _previewInvitation();
      if (const {
        'stableDetails',
        'members',
        'memberDetails',
        'roles',
        'invite',
      }.contains(widget.mode)) {
        await _loadManagementMembers();
      }
    } on PostgrestException catch (error) {
      if (error.code == '401' || error.code == '403' || error.code == '42501') {
        _phase4BClearSensitiveWorkingSet(accessStatus: 'access_denied');
      }
      _offline = true;
      _memberships = _validCachedMemberships(user.id);
      _error =
          _memberships.isEmpty
              ? 'Je staltoegang kon niet veilig worden gecontroleerd.'
              : 'Offline: stalgegevens zijn tijdelijk alleen-lezen.';
    } catch (_) {
      _offline = true;
      _memberships = _validCachedMemberships(user.id);
      _error = 'Geen verbinding. Autoriteitswijzigingen zijn uitgeschakeld.';
    }
    _syncManagementController();
    _loading = false;
    if (mounted) setState(() {});
  }

  void _cacheMemberships(String authUserId, List<Map<String, dynamic>> rows) {
    final caches =
        rows.map((row) {
          final stable = Map<String, dynamic>.from(row['stables'] as Map);
          return StableMembershipCacheDataStruct(
            authUserId: authUserId,
            stableId: _phase4BString(row['stable_id']),
            stableName: _phase4BString(stable['name']),
            stableKind: _phase4BString(stable['kind']),
            membershipId: _phase4BString(row['id']),
            stableMemberId: _phase4BString(row['stable_member_id']),
            role: _phase4BString(row['role']),
            status: _phase4BString(row['status']),
            lastValidatedAt: DateTime.now().toUtc(),
          );
        }).toList();
    FFAppState().stableMembershipCaches = [
      ...FFAppState().stableMembershipCaches.where(
        (cache) => cache.authUserId != authUserId,
      ),
      ...caches,
    ];
    FFAppState().lastMembershipValidatedAt = DateTime.now().toUtc();
  }

  List<Map<String, dynamic>> _validCachedMemberships(String authUserId) {
    final now = DateTime.now().toUtc();
    return FFAppState().stableMembershipCaches
        .where(
          (cache) =>
              cache.authUserId == authUserId &&
              cache.status == 'active' &&
              cache.lastValidatedAt != null &&
              now.difference(cache.lastValidatedAt!) <=
                  _phase4BOfflineAuthorityMaximumAge,
        )
        .map(
          (cache) => {
            'id': cache.membershipId,
            'stable_id': cache.stableId,
            'stable_member_id': cache.stableMemberId,
            'role': cache.role,
            'status': cache.status,
            'stables': {
              'id': cache.stableId,
              'name': cache.stableName,
              'kind': cache.stableKind,
              'status': 'active',
            },
          },
        )
        .toList();
  }

  Map<String, dynamic>? get _selectedMembership {
    final selected = FFAppState().selectedCloudStableId;
    for (final membership in _memberships) {
      if (membership['stable_id'] == selected) return membership;
    }
    return null;
  }

  String get _selectedRole => _phase4BString(_selectedMembership?['role']);
  bool get _isManager => _selectedRole == 'owner' || _selectedRole == 'admin';
  bool get _isOwner => _selectedRole == 'owner';
  bool get _canMutateAuthority => !_offline && _isManager;
  bool get _isPersonalWorkspace =>
      (_selectedMembership?['stables'] as Map?)?['kind'] == 'personal';

  Phase4BRole _role(String? value) => Phase4BRole.values.firstWhere(
    (role) => role.name == value,
    orElse: () => Phase4BRole.viewer,
  );

  Map<String, dynamic>? get _selectedManagementMember {
    for (final member in _managementMembers) {
      if (member['stable_member_id'] == _selectedManagementMemberId) {
        return member;
      }
    }
    return null;
  }

  void _syncManagementController() {
    _management
      ..actorRole = _role(_selectedRole)
      ..online = !_offline
      ..personalWorkspace = _isPersonalWorkspace;
    final allowedInvites = _management.allowedInvitationRoles;
    if (!allowedInvites.contains(_selectedInviteRole) &&
        allowedInvites.isNotEmpty) {
      _selectedInviteRole = allowedInvites.first;
    }
  }

  void _applyManagementFeedback() {
    _busy = _management.busy;
    _error = _management.error;
    _notice = _management.notice;
    final transientLink = _management.takeTransientInvitationLink();
    if (transientLink.isNotEmpty) _transientShareLink = transientLink;
    _syncManagementController();
    if (mounted) setState(() {});
  }

  Future<void> _switchStable(Map<String, dynamic> membership) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    final user = _client.auth.currentUser;
    if (user == null) {
      _phase4BClearSensitiveWorkingSet(accessStatus: 'signed_out');
      return;
    }

    final authId = user.id;
    late LocalAccountScopeDataStruct master;
    try {
      // Persist the current filtered working set into the account master before
      // every switch. An existing master is merged, never silently reused.
      master = _phase4BSaveCurrentOperationalScope(authId);
    } catch (_) {
      _error =
          'De huidige lokale stal kon niet veilig worden opgeslagen. Wisselen is gestopt.';
      if (mounted) setState(() => _busy = false);
      return;
    }
    // Clear before network validation so a previous stable can never flash.
    _phase4BClearSensitiveWorkingSet(accessStatus: 'validating');
    final stableId = _phase4BString(membership['stable_id']);
    try {
      final validation =
          await _client
              .from('stable_memberships')
              .select('id,status,role')
              .eq('stable_id', stableId)
              .eq('user_id', authId)
              .eq('status', 'active')
              .maybeSingle();
      if (validation == null) {
        throw const PostgrestException(message: 'ACCESS_REMOVED', code: '403');
      }
      await _client.rpc(
        'set_selected_stable',
        params: {
          'p_stable_id': stableId,
          'p_workspace_mode':
              (membership['stables'] as Map?)?['kind'] == 'personal'
                  ? 'personal'
                  : 'stable',
        },
      );
      FFAppState().selectedCloudStableId = stableId;
      FFAppState().lastMembershipValidatedAt = DateTime.now().toUtc();
      final link = _phase4BLinkFor(authId, stableId);
      _phase4BLoadLinkedOperationalContext(master, link);
      if (mounted) context.goNamed('TodayDashboardPage');
    } on PostgrestException catch (error) {
      final denied =
          error.code == '401' || error.code == '403' || error.code == '42501';
      _phase4BClearSensitiveWorkingSet(
        accessStatus: denied ? 'access_denied' : 'offline',
      );
      if (denied) FFAppState().selectedCloudStableId = '';
      _error =
          denied
              ? 'Je toegang tot deze stal is verwijderd of geschorst.'
              : 'Stalwisselen vereist een online lidmaatschapscontrole.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createStable({required bool personal}) async {
    if (_busy || _offline) return;
    final name = _name.text.trim();
    if (name.isEmpty || _timezone.text.trim().isEmpty) {
      setState(() => _error = 'Vul een naam en tijdzone in.');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final result = await _client.rpc(
        'create_stable',
        params: {
          'p_name': name,
          'p_timezone': _timezone.text.trim(),
          'p_kind': personal ? 'personal' : 'organization',
          'p_locale': 'nl',
          'p_creation_request_id': const Uuid().v4(),
          'p_owner_display_name': _displayName.text.trim(),
          'p_owner_function_title': null,
        },
      );
      final stableId = _phase4BString(result['stable_id']);
      await _load();
      final membership = _memberships.firstWhere(
        (row) => row['stable_id'] == stableId,
      );
      await _switchStable(membership);
    } on PostgrestException catch (error) {
      _error =
          error.code == '42501'
              ? 'Je sessie is verlopen. Log opnieuw in.'
              : 'De workspace kon niet veilig worden aangemaakt.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _previewInvitation() async {
    if (_transientInvitationToken.isEmpty) return;
    try {
      final response = await _client.functions.invoke(
        'stable-invitations',
        body: {'action': 'preview', 'token': _transientInvitationToken},
      );
      _invitationPreview = Map<String, dynamic>.from(response.data as Map);
    } catch (_) {
      _invitationPreview = {'status': 'unavailable'};
    }
    if (mounted) setState(() {});
  }

  Future<void> _respondInvitation(bool accept) async {
    if (_busy || _offline || _transientInvitationToken.isEmpty) return;
    setState(() => _busy = true);
    try {
      final response = await _client.functions.invoke(
        'stable-invitations',
        body: {
          'action': accept ? 'accept' : 'decline',
          'token': _transientInvitationToken,
          'display_name': _displayName.text.trim(),
          'function_title': _functionTitle.text.trim(),
          'request_id': const Uuid().v4(),
        },
      );
      if (response.status != 200) throw StateError('invite response failed');
      _transientInvitationToken = '';
      _notice =
          accept
              ? 'Uitnodiging geaccepteerd. Kies de stal om verder te gaan.'
              : 'Uitnodiging geweigerd.';
      await _load();
    } catch (_) {
      _error =
          'Deze uitnodiging is ongeldig, verlopen, ingetrokken of hoort bij een ander bevestigd account.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createInvitation() async {
    await _runManagement(
      () => _management.createInvitation(
        stableId: FFAppState().selectedCloudStableId,
        email: _email.text,
        role: _selectedInviteRole,
        requestId: const Uuid().v4(),
      ),
    );
  }

  Future<void> _copyTransientLink() async {
    if (_transientShareLink.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _transientShareLink));
    if (!mounted) return;
    setState(() {
      _transientShareLink = '';
      _notice =
          'Link gekopieerd en uit het scherm gewist. Deel hem via een veilig kanaal.';
    });
  }

  Future<void> _loadDirectory() async {
    final stableId = FFAppState().selectedCloudStableId;
    if (stableId.isEmpty) return;
    final rows = await _client.rpc(
      'list_stable_member_directory',
      params: {'p_stable_id': stableId},
    );
    _directory = List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> _loadInvitations() async {
    if (!_isManager) return;
    final rows = await _client
        .from('stable_invitations')
        .select('id,offered_role,status,expires_at,last_sent_at,resend_count')
        .eq('stable_id', FFAppState().selectedCloudStableId)
        .eq('status', 'pending');
    _invitations = List<Map<String, dynamic>>.from(rows);
  }

  Future<void> _loadManagementMembers() async {
    final stableId = FFAppState().selectedCloudStableId;
    final selected = _selectedMembership;
    if (stableId.isEmpty || selected == null) {
      _managementMembers = const [];
      return;
    }
    final stable = Map<String, dynamic>.from(selected['stables'] as Map);
    _stableName.text = _phase4BString(stable['name']);
    _stableTimezone.text =
        _phase4BString(stable['timezone']).isEmpty
            ? 'Europe/Amsterdam'
            : _phase4BString(stable['timezone']);
    if (!_isManager) {
      _managementMembers = const [];
      return;
    }
    final rosterRows = List<Map<String, dynamic>>.from(
      await _client
          .from('stable_members')
          .select('id,display_name,function_title,status')
          .eq('stable_id', stableId),
    );
    final membershipRows = List<Map<String, dynamic>>.from(
      await _client
          .from('stable_memberships')
          .select('id,user_id,stable_member_id,role,status,row_version')
          .eq('stable_id', stableId),
    );
    _managementMembers =
        rosterRows.map((member) {
          Map<String, dynamic>? membership;
          for (final candidate in membershipRows) {
            if (candidate['stable_member_id'] == member['id']) {
              membership = candidate;
              break;
            }
          }
          return {
            'stable_id': stableId,
            'stable_member_id': member['id'],
            'display_name': member['display_name'],
            'function_title': member['function_title'],
            'member_status': member['status'],
            'membership_id': membership?['id'],
            'user_id': membership?['user_id'],
            'role': membership?['role'],
            'membership_status': membership?['status'],
            'row_version': membership?['row_version'],
          };
        }).toList();
    _memberSelection.resolve(
      selectedStableId: stableId,
      candidates: _managementMembers
          .map(
            (member) => Phase4BMemberCandidate(
              stableId: _phase4BString(member['stable_id']),
              stableMemberId: _phase4BString(member['stable_member_id']),
            ),
          )
          .toList(growable: false),
    );
    _selectedManagementMemberId = _memberSelection.selectedStableMemberId;
    _memberSelectionError = _memberSelection.error;
  }

  void _confirmLocalLink() {
    final user = _client.auth.currentUser;
    final cloudStableId = FFAppState().selectedCloudStableId;
    final localStableId = _localStableId.text.trim();
    if (user == null || cloudStableId.isEmpty || localStableId.isEmpty) {
      setState(() => _error = 'Kies eerst een cloudstal en lokale stal.');
      return;
    }
    final links = List<LocalStableCloudLinkDataStruct>.from(
      FFAppState().localStableCloudLinks,
    )..removeWhere(
      (link) =>
          link.authUserId == user.id && link.cloudStableId == cloudStableId,
    );
    links.add(
      LocalStableCloudLinkDataStruct(
        authUserId: user.id,
        cloudStableId: cloudStableId,
        localStableId: localStableId,
        selectedHorseId: 0,
        confirmed: true,
        linkedAt: DateTime.now().toUtc(),
      ),
    );
    FFAppState().localStableCloudLinks = links;
    final master =
        _phase4BMasterScope(user.id) ??
        _phase4BCaptureOperationalScope(user.id);
    _phase4BSaveMasterScope(master);
    _phase4BLoadLinkedOperationalContext(master, links.last);
    setState(() => _notice = 'Lokale stal expliciet gekoppeld.');
  }

  @override
  Future<Object?> rpc(String name, Map<String, Object?> parameters) async {
    try {
      return await _client.rpc(name, params: parameters);
    } on PostgrestException catch (error) {
      throw Phase4BServerException(error.code ?? 'SERVER_REJECTED');
    }
  }

  @override
  Future<Map<String, Object?>> invitation(
    String action,
    Map<String, Object?> parameters,
  ) async {
    try {
      final response = await _client.functions.invoke(
        'stable-invitations',
        body: {'action': action, ...parameters},
      );
      final data =
          response.data is Map
              ? Map<String, Object?>.from(response.data as Map)
              : <String, Object?>{};
      if (response.status != 200) {
        throw Phase4BServerException(
          _phase4BString(data['code']).isEmpty
              ? 'SERVER_REJECTED'
              : _phase4BString(data['code']),
        );
      }
      return data;
    } on FunctionException catch (error) {
      final details =
          error.details is Map
              ? Map<String, dynamic>.from(error.details as Map)
              : const <String, dynamic>{};
      throw Phase4BServerException(
        _phase4BString(details['code']).isEmpty
            ? '${error.status}'
            : _phase4BString(details['code']),
      );
    }
  }

  @override
  Future<void> refreshAuthority() => _load();

  @override
  void clearSensitiveAuthority() {
    FFAppState().selectedCloudStableId = '';
    _phase4BClearSensitiveWorkingSet(accessStatus: 'access_denied');
  }

  Future<void> _runManagement(Future<bool> Function() action) async {
    if (_management.busy) return;
    setState(() => _busy = true);
    await action();
    _applyManagementFeedback();
  }

  Future<bool> _confirmDestructive(String title, String detail) async {
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder:
              (dialogContext) => AlertDialog(
                title: Text(title),
                content: Text(detail),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Annuleren'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Expliciet bevestigen'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  Future<void> _changeSelectedRole() async {
    final target = _selectedManagementMember;
    final membershipId = _phase4BString(target?['membership_id']);
    if (target == null || membershipId.isEmpty) return;
    await _runManagement(
      () => _management.changeRole(
        membershipId: membershipId,
        targetRole: _role(_phase4BString(target['role'])),
        newRole: _selectedReplacementRole,
        requestId: const Uuid().v4(),
      ),
    );
  }

  Future<void> _suspendSelected() async {
    final target = _selectedManagementMember;
    final membershipId = _phase4BString(target?['membership_id']);
    if (target == null || membershipId.isEmpty) return;
    await _runManagement(
      () => _management.suspend(
        membershipId: membershipId,
        targetRole: _role(_phase4BString(target['role'])),
        requestId: const Uuid().v4(),
      ),
    );
  }

  Future<void> _removeSelected() async {
    final target = _selectedManagementMember;
    final membershipId = _phase4BString(target?['membership_id']);
    if (target == null || membershipId.isEmpty) return;
    final confirmed = await _confirmDestructive(
      'Lid verwijderen?',
      'Toegang wordt beëindigd. Terugkeer kan alleen via een nieuwe uitnodiging.',
    );
    if (!confirmed) return;
    await _runManagement(
      () => _management.remove(
        membershipId: membershipId,
        targetRole: _role(_phase4BString(target['role'])),
        requestId: const Uuid().v4(),
      ),
    );
  }

  Future<void> _leaveSelectedStable() async {
    final confirmed = await _confirmDestructive(
      'Stal verlaten?',
      'Je actieve toegang tot deze stal wordt beëindigd.',
    );
    if (!confirmed) return;
    await _runManagement(
      () => _management.leave(
        stableId: FFAppState().selectedCloudStableId,
        requestId: const Uuid().v4(),
      ),
    );
  }

  Future<void> _transferToSelected() async {
    final target = _selectedManagementMember;
    final membershipId = _phase4BString(target?['membership_id']);
    if (target == null || membershipId.isEmpty) return;
    final confirmed = await _confirmDestructive(
      'Eigendom overdragen?',
      'De doelgebruiker wordt owner en jij wordt admin. Dit gebeurt transactioneel.',
    );
    await _runManagement(
      () => _management.transferOwnership(
        stableId: FFAppState().selectedCloudStableId,
        targetMembershipId: membershipId,
        requestId: const Uuid().v4(),
        confirmed: confirmed,
      ),
    );
  }

  Future<void> _linkSelectedMember() async {
    final target = _selectedManagementMember;
    if (target == null || _linkMembershipId.isEmpty) return;
    Map<String, dynamic>? membershipTarget;
    for (final candidate in _managementMembers) {
      if (candidate['membership_id'] == _linkMembershipId) {
        membershipTarget = candidate;
        break;
      }
    }
    if (membershipTarget == null) return;
    await _runManagement(
      () => _management.linkAccountToMember(
        membershipId: _linkMembershipId,
        stableMemberId: _phase4BString(target!['stable_member_id']),
        targetRole: _role(_phase4BString(membershipTarget!['role'])),
        requestId: const Uuid().v4(),
      ),
    );
  }

  Future<void> _updateSelectedStable() async {
    await _runManagement(
      () => _management.updateStable(
        stableId: FFAppState().selectedCloudStableId,
        name: _stableName.text,
        timezone: _stableTimezone.text,
        locale: 'nl',
        requestId: const Uuid().v4(),
      ),
    );
  }

  Future<void> _archiveSelectedStable() async {
    final confirmed = await _confirmDestructive(
      'Stal archiveren?',
      'De stal wordt read-only en kan niet via de app worden hersteld.',
    );
    await _runManagement(
      () => _management.archiveStable(
        stableId: FFAppState().selectedCloudStableId,
        requestId: const Uuid().v4(),
        confirmed: confirmed,
      ),
    );
  }

  Future<void> _resendInvitation(String invitationId) async {
    await _runManagement(
      () => _management.resendInvitation(
        invitationId: invitationId,
        requestId: const Uuid().v4(),
      ),
    );
  }

  Future<void> _revokeInvitation(String invitationId) async {
    final confirmed = await _confirmDestructive(
      'Uitnodiging intrekken?',
      'De huidige uitnodigingslink wordt onmiddellijk ongeldig.',
    );
    if (!confirmed) return;
    await _runManagement(
      () => _management.revokeInvitation(
        invitationId: invitationId,
        requestId: const Uuid().v4(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            phase4BLayoutForWidth(constraints.maxWidth) ==
            Phase4BLayout.compact;
        final content = _content(theme, compact);
        return ColoredBox(
          color: theme.primaryBackground,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 20 : 40,
                vertical: compact ? 24 : 36,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: content,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _content(FlutterFlowTheme theme, bool compact) {
    if (widget.mode == 'selector') return _selector(theme, compact: true);
    final title = switch (widget.mode) {
      'handoff' => 'Kies hoe je AVARYN wilt gebruiken',
      'createStable' => 'Nieuwe stal aanmaken',
      'personalWorkspace' => 'Persoonlijke workspace',
      'invitation' => 'Uitnodiging',
      'stablePicker' => 'Stal kiezen',
      'stableDetails' => 'Staldetails',
      'members' => 'Leden en medewerkers',
      'memberDetails' => 'Medewerker',
      'invite' => 'Iemand uitnodigen',
      'pendingInvitations' => 'Openstaande uitnodigingen',
      'roles' => 'Rollen beheren',
      'access' => 'Staltoegang',
      'linkLocalStable' => 'Lokale stal koppelen',
      _ => 'Stalbeheer',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: theme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          _offline
              ? 'Offline · autoriteitsgegevens zijn alleen-lezen'
              : 'Veilige stalcontext · rollen komen uitsluitend uit Supabase',
          style: theme.bodyMedium.copyWith(color: theme.secondaryText),
        ),
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 16),
          _message(theme, _error, error: true),
        ],
        if (_notice.isNotEmpty) ...[
          const SizedBox(height: 16),
          _message(theme, _notice),
        ],
        const SizedBox(height: 24),
        _modeBody(theme, compact),
      ],
    );
  }

  Widget _modeBody(FlutterFlowTheme theme, bool compact) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return switch (widget.mode) {
      'handoff' => _handoff(theme, compact),
      'createStable' => _createForm(theme, personal: false),
      'personalWorkspace' => _createForm(theme, personal: true),
      'invitation' => _invitation(theme),
      'stablePicker' => _selector(theme, compact: compact),
      'stableDetails' => _stableDetails(theme),
      'members' => _memberList(theme),
      'memberDetails' => _memberDetails(theme),
      'invite' => _inviteForm(theme),
      'pendingInvitations' => _pendingList(theme),
      'roles' => _roles(theme),
      'access' => _access(theme),
      'linkLocalStable' => _linkForm(theme),
      _ => _stableDetails(theme),
    };
  }

  Widget _handoff(FlutterFlowTheme theme, bool compact) {
    final cards = [
      _actionCard(
        theme,
        'Een stal starten',
        'Maak na bevestiging een organisatie, owner-medewerker en lidmaatschap.',
        Icons.add_business_outlined,
        () => context.pushNamed('CreateStablePage'),
      ),
      _actionCard(
        theme,
        'Uitnodiging openen',
        'Accepteer nooit automatisch; een geldige link is vereist.',
        Icons.mark_email_unread_outlined,
        () => context.pushNamed('StableInvitationPage'),
      ),
      _actionCard(
        theme,
        'Alleen mijn paarden',
        'Maak expliciet een private workspace. Er wordt geen paard aangemaakt.',
        Icons.person_outline,
        () => context.pushNamed('PersonalWorkspacePage'),
      ),
    ];
    return compact
        ? Column(children: cards)
        : Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: cards
              .map((card) => Expanded(child: card))
              .toList(growable: false),
        );
  }

  Widget _createForm(FlutterFlowTheme theme, {required bool personal}) {
    if (personal && _name.text.isEmpty) _name.text = 'Mijn paarden';
    return _panel(
      theme,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Naam'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _timezone,
            decoration: const InputDecoration(labelText: 'Tijdzone'),
          ),
          const SizedBox(height: 16),
          Text(
            personal
                ? 'Uitnodigingen blijven uitgeschakeld. Er wordt geen paard of legacykoppeling gemaakt.'
                : 'Na aanmaken kies je afzonderlijk of een lokale stal gekoppeld mag worden.',
            style: theme.bodyMedium,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed:
                _busy || _offline
                    ? null
                    : () => _createStable(personal: personal),
            child: Text(_busy ? 'Bezig…' : 'Bevestigen en aanmaken'),
          ),
        ],
      ),
    );
  }

  Widget _invitation(FlutterFlowTheme theme) {
    final preview = _invitationPreview;
    if (_transientInvitationToken.isEmpty) {
      return _empty(
        theme,
        'Je hebt een uitnodigingslink nodig om bij een stal te komen.',
      );
    }
    if (preview == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (preview['status'] != 'pending') {
      return _empty(
        theme,
        'Deze uitnodiging is ongeldig, verlopen, ingetrokken of al gebruikt.',
      );
    }
    if (_client.auth.currentUser == null) {
      return _panel(
        theme,
        Column(
          children: [
            Text(
              '${preview['stable_name']} · rol ${preview['offered_role']}',
              style: theme.titleLarge,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.goNamed('AuthWelcomePage'),
              child: const Text('Eerst veilig inloggen'),
            ),
          ],
        ),
      );
    }
    return _panel(
      theme,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_phase4BString(preview['stable_name']), style: theme.titleLarge),
          Text('Aangeboden rol: ${preview['offered_role']}'),
          const SizedBox(height: 12),
          TextField(
            controller: _displayName,
            decoration: const InputDecoration(labelText: 'Naam in deze stal'),
          ),
          TextField(
            controller: _functionTitle,
            decoration: const InputDecoration(
              labelText: 'Operationele functietitel (optioneel)',
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _busy || _offline
                          ? null
                          : () => _respondInvitation(false),
                  child: const Text('Weigeren'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed:
                      _busy || _offline ? null : () => _respondInvitation(true),
                  child: const Text('Accepteren'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _selector(FlutterFlowTheme theme, {required bool compact}) {
    if (_memberships.isEmpty) {
      return _empty(theme, 'Nog geen actieve stal. Open onboarding.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children:
          _memberships.map((membership) {
            final stable = Map<String, dynamic>.from(
              membership['stables'] as Map,
            );
            final selected =
                membership['stable_id'] == FFAppState().selectedCloudStableId;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                selected: selected,
                tileColor: selected ? theme.accent2 : theme.secondaryBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: Icon(
                  stable['kind'] == 'personal'
                      ? Icons.person_outline
                      : Icons.home_work_outlined,
                ),
                title: Text(_phase4BString(stable['name'])),
                subtitle: Text(
                  '${membership['role']}${_offline ? ' · offline lezen' : ''}',
                ),
                trailing:
                    _busy
                        ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.chevron_right),
                onTap:
                    _busy || _offline ? null : () => _switchStable(membership),
              ),
            );
          }).toList(),
    );
  }

  Widget _stableDetails(FlutterFlowTheme theme) {
    final membership = _selectedMembership;
    if (membership == null)
      return _empty(theme, 'Kies eerst een actieve stal.');
    final stable = Map<String, dynamic>.from(membership['stables'] as Map);
    return _panel(
      theme,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_phase4BString(stable['name']), style: theme.titleLarge),
          Text('Type: ${stable['kind']} · jouw rol: ${membership['role']}'),
          const SizedBox(height: 16),
          if (_isManager) ...[
            TextField(
              controller: _stableName,
              decoration: const InputDecoration(labelText: 'Stalnaam'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _stableTimezone,
              decoration: const InputDecoration(labelText: 'Tijdzone'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed:
                  _management.busy || _offline ? null : _updateSelectedStable,
              child: const Text('Stalgegevens opslaan'),
            ),
          ],
          OutlinedButton(
            onPressed: () => context.pushNamed('StableMembersPage'),
            child: const Text('Leden en medewerkers'),
          ),
          OutlinedButton(
            onPressed: () => context.pushNamed('LinkLocalStablePage'),
            child: const Text('Lokale stal expliciet koppelen'),
          ),
          if (_isManager) ...[
            OutlinedButton(
              onPressed: () => context.pushNamed('ManageStableRolesPage'),
              child: const Text('Rollen en toegang beheren'),
            ),
            if (!_isPersonalWorkspace)
              OutlinedButton(
                onPressed: () => context.pushNamed('InviteStableMemberPage'),
                child: const Text('Medewerker uitnodigen'),
              ),
            if (!_isPersonalWorkspace)
              OutlinedButton(
                onPressed:
                    () => context.pushNamed('PendingStableInvitationsPage'),
                child: const Text('Openstaande uitnodigingen'),
              ),
          ],
          if (_isOwner)
            OutlinedButton(
              onPressed:
                  _management.busy || _offline ? null : _archiveSelectedStable,
              child: const Text('Stal archiveren'),
            ),
        ],
      ),
    );
  }

  Widget _memberList(FlutterFlowTheme theme) {
    if (_directory.isEmpty) {
      return _empty(theme, 'Geen actieve operationele medewerkers gevonden.');
    }
    return Column(
      children:
          _directory
              .map(
                (member) => ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_outline),
                  ),
                  title: Text(_phase4BString(member['display_name'])),
                  subtitle: Text(
                    _phase4BString(member['function_title']).isEmpty
                        ? 'Geen functietitel'
                        : _phase4BString(member['function_title']),
                  ),
                  onTap:
                      _isManager
                          ? () {
                            final route = _memberSelection.detailRoute(
                              _phase4BString(member['stable_member_id']),
                            );
                            context.pushNamed(
                              route.pageName,
                              queryParameters:
                                  {
                                    'stableMemberId': serializeParam(
                                      route.stableMemberId,
                                      ParamType.String,
                                    ),
                                  }.withoutNulls,
                            );
                          }
                          : null,
                ),
              )
              .toList(),
    );
  }

  Widget _memberDetails(FlutterFlowTheme theme) {
    if (_memberSelectionError.isNotEmpty) {
      return _empty(
        theme,
        'Deze medewerker bestaat niet (meer) binnen de geselecteerde stal.',
      );
    }
    return _managementPanel(theme, includeLeave: false);
  }

  Widget _inviteForm(FlutterFlowTheme theme) => _panel(
    theme,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'E-mailadres'),
        ),
        const SizedBox(height: 12),
        Text(
          _selectedRole == 'admin'
              ? 'Als admin kun je member of viewer uitnodigen.'
              : 'Als owner kun je admin, member of viewer beheren.',
        ),
        if (_management.allowedInvitationRoles.isNotEmpty) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<Phase4BRole>(
            initialValue: _selectedInviteRole,
            decoration: const InputDecoration(labelText: 'Aangeboden rol'),
            items:
                _management.allowedInvitationRoles
                    .map(
                      (role) =>
                          DropdownMenuItem(value: role, child: Text(role.name)),
                    )
                    .toList(),
            onChanged:
                _offline
                    ? null
                    : (role) {
                      if (role != null) {
                        setState(() => _selectedInviteRole = role);
                      }
                    },
          ),
        ],
        const SizedBox(height: 16),
        if (_management.allowedInvitationRoles.isNotEmpty)
          FilledButton(
            onPressed: _canMutateAuthority && !_busy ? _createInvitation : null,
            child: const Text('Veilige uitnodigingslink maken'),
          )
        else
          Text(
            _isPersonalWorkspace
                ? 'Persoonlijke workspaces hebben geen uitnodigingsbeheer.'
                : 'Je rol heeft geen uitnodigingsrechten.',
          ),
        if (_transientShareLink.isNotEmpty) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _copyTransientLink,
            icon: const Icon(Icons.copy),
            label: const Text('Eenmalig kopiëren en wissen'),
          ),
        ],
      ],
    ),
  );

  Widget _pendingList(FlutterFlowTheme theme) {
    if (!_isManager) return _empty(theme, 'Alleen owner/admin heeft toegang.');
    if (_invitations.isEmpty) {
      return _empty(theme, 'Geen openstaande uitnodigingen.');
    }
    return Column(
      children: [
        ..._invitations.map(
          (invitation) => ListTile(
            leading: const Icon(Icons.schedule_send_outlined),
            title: Text('Rol ${invitation['offered_role']}'),
            subtitle: Text(
              'Verloopt ${_phase4BDate(invitation['expires_at']) ?? ''}',
            ),
            trailing: PopupMenuButton<String>(
              enabled: !_offline && !_management.busy,
              onSelected: (action) {
                final id = _phase4BString(invitation['id']);
                if (action == 'resend') _resendInvitation(id);
                if (action == 'revoke') _revokeInvitation(id);
              },
              itemBuilder:
                  (_) => const [
                    PopupMenuItem(
                      value: 'resend',
                      child: Text('Nieuwe link maken'),
                    ),
                    PopupMenuItem(value: 'revoke', child: Text('Intrekken')),
                  ],
            ),
          ),
        ),
        if (_transientShareLink.isNotEmpty)
          OutlinedButton.icon(
            onPressed: _copyTransientLink,
            icon: const Icon(Icons.copy),
            label: const Text('Nieuwe link eenmalig kopiëren en wissen'),
          ),
      ],
    );
  }

  Widget _roles(FlutterFlowTheme theme) =>
      _managementPanel(theme, includeLeave: true);

  Widget _managementPanel(
    FlutterFlowTheme theme, {
    required bool includeLeave,
  }) {
    if (!_isManager && !includeLeave) {
      return _empty(theme, 'Je hebt geen beheerrechten voor medewerkers.');
    }
    if (_managementMembers.isEmpty) {
      return _empty(theme, 'Geen beheerbare medewerkers gevonden.');
    }
    final selected = _selectedManagementMember ?? _managementMembers.first;
    final targetRole = _role(_phase4BString(selected['role']));
    final replacementRoles = _management.allowedReplacementRoles(targetRole);
    if (replacementRoles.isNotEmpty &&
        !replacementRoles.contains(_selectedReplacementRole)) {
      _selectedReplacementRole = replacementRoles.first;
    }
    final membershipId = _phase4BString(selected['membership_id']);
    final activeMembership = selected['membership_status'] == 'active';
    final canManageTarget =
        activeMembership && _management.canManageTarget(targetRole);
    final linkableMemberships =
        _managementMembers
            .where(
              (candidate) =>
                  _phase4BString(candidate['membership_id']).isNotEmpty &&
                  candidate['membership_status'] == 'active' &&
                  candidate['stable_member_id'] != selected['stable_member_id'],
            )
            .toList();
    return _panel(
      theme,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _phase4BString(selected['stable_member_id']),
            decoration: const InputDecoration(labelText: 'Medewerker'),
            items:
                _managementMembers
                    .map(
                      (member) => DropdownMenuItem(
                        value: _phase4BString(member['stable_member_id']),
                        child: Text(_phase4BString(member['display_name'])),
                      ),
                    )
                    .toList(),
            onChanged:
                (value) => setState(() {
                  _memberSelection.choose(value ?? '');
                  _memberSelection.resolve(
                    selectedStableId: FFAppState().selectedCloudStableId,
                    candidates: _managementMembers
                        .map(
                          (member) => Phase4BMemberCandidate(
                            stableId: _phase4BString(member['stable_id']),
                            stableMemberId: _phase4BString(
                              member['stable_member_id'],
                            ),
                          ),
                        )
                        .toList(growable: false),
                  );
                  _selectedManagementMemberId =
                      _memberSelection.selectedStableMemberId;
                  _memberSelectionError = _memberSelection.error;
                }),
          ),
          const SizedBox(height: 12),
          Text(
            _phase4BString(selected['display_name']),
            style: theme.titleLarge,
          ),
          Text(
            'Functie: ${_phase4BString(selected['function_title']).isEmpty ? 'niet ingevuld' : selected['function_title']}',
          ),
          Text(
            membershipId.isEmpty
                ? 'Geen account gekoppeld'
                : 'Rol: ${selected['role']} · status: ${selected['membership_status']}',
          ),
          if (replacementRoles.isNotEmpty && canManageTarget) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<Phase4BRole>(
              initialValue: _selectedReplacementRole,
              decoration: const InputDecoration(labelText: 'Nieuwe rol'),
              items:
                  replacementRoles
                      .map(
                        (role) => DropdownMenuItem(
                          value: role,
                          child: Text(role.name),
                        ),
                      )
                      .toList(),
              onChanged:
                  _offline
                      ? null
                      : (role) {
                        if (role != null) {
                          setState(() => _selectedReplacementRole = role);
                        }
                      },
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed:
                  _offline || _management.busy ? null : _changeSelectedRole,
              child: const Text('Rol wijzigen'),
            ),
            OutlinedButton(
              onPressed: _offline || _management.busy ? null : _suspendSelected,
              child: const Text('Lid schorsen'),
            ),
            OutlinedButton(
              onPressed: _offline || _management.busy ? null : _removeSelected,
              child: const Text('Lid verwijderen'),
            ),
          ],
          if (_isOwner &&
              activeMembership &&
              membershipId.isNotEmpty &&
              targetRole != Phase4BRole.owner)
            OutlinedButton(
              onPressed:
                  _offline || _management.busy ? null : _transferToSelected,
              child: const Text('Eigendom expliciet overdragen'),
            ),
          if (membershipId.isEmpty &&
              _isManager &&
              linkableMemberships.isNotEmpty) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue:
                  linkableMemberships.any(
                        (candidate) =>
                            candidate['membership_id'] == _linkMembershipId,
                      )
                      ? _linkMembershipId
                      : null,
              decoration: const InputDecoration(
                labelText: 'Accountmembership koppelen',
              ),
              items:
                  linkableMemberships
                      .map(
                        (candidate) => DropdownMenuItem(
                          value: _phase4BString(candidate['membership_id']),
                          child: Text(
                            '${candidate['display_name']} (${candidate['role']})',
                          ),
                        ),
                      )
                      .toList(),
              onChanged:
                  _offline
                      ? null
                      : (value) =>
                          setState(() => _linkMembershipId = value ?? ''),
            ),
            FilledButton(
              onPressed:
                  _offline || _management.busy || _linkMembershipId.isEmpty
                      ? null
                      : _linkSelectedMember,
              child: const Text('Account aan medewerker koppelen'),
            ),
          ],
          if (includeLeave && !_isOwner) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed:
                  _offline || _management.busy ? null : _leaveSelectedStable,
              child: const Text('Zelf deze stal verlaten'),
            ),
          ],
          if (_offline)
            Text(
              'Offline read-only: beheeracties zijn niet beschikbaar.',
              style: theme.bodySmall,
            ),
        ],
      ),
    );
  }

  Widget _access(FlutterFlowTheme theme) {
    final status = FFAppState().stableAccessStatus;
    return _empty(
      theme,
      status == 'suspended'
          ? 'Je toegang is geschorst. Lokale autoriteitsmutaties zijn geblokkeerd.'
          : 'Je toegang is verwijderd of kon niet veilig worden gevalideerd.',
    );
  }

  Widget _linkForm(FlutterFlowTheme theme) => _panel(
    theme,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Deze keuze koppelt uitsluitend IDs. Legacydata wordt niet automatisch aan de owner toegewezen.',
          style: theme.bodyMedium,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _localStableId,
          decoration: const InputDecoration(
            labelText: 'Bestaande lokale stal-ID',
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _confirmLocalLink,
          child: const Text('Expliciet bevestigen'),
        ),
      ],
    ),
  );

  Widget _actionCard(
    FlutterFlowTheme theme,
    String title,
    String detail,
    IconData icon,
    VoidCallback onTap,
  ) => Padding(
    padding: const EdgeInsets.all(6),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: _panel(
        theme,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.secondary, size: 30),
            const SizedBox(height: 16),
            Text(title, style: theme.titleMedium),
            const SizedBox(height: 8),
            Text(detail, style: theme.bodyMedium),
          ],
        ),
      ),
    ),
  );

  Widget _panel(FlutterFlowTheme theme, Widget child) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: theme.secondaryBackground,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: theme.alternate),
    ),
    child: child,
  );

  Widget _empty(FlutterFlowTheme theme, String text) => _panel(
    theme,
    Column(
      children: [
        Icon(Icons.info_outline, color: theme.secondary, size: 34),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center, style: theme.bodyLarge),
        const SizedBox(height: 12),
        TextButton(onPressed: _load, child: const Text('Opnieuw proberen')),
      ],
    ),
  );

  Widget _message(FlutterFlowTheme theme, String text, {bool error = false}) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: error ? theme.error.withValues(alpha: 0.10) : theme.accent2,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          style: theme.bodyMedium.copyWith(
            color: error ? theme.error : theme.primaryText,
          ),
        ),
      );
}

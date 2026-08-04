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

import 'package:flutter/material.dart';
import '/app_state.dart';
import 'package:provider/provider.dart';

const _feedingRoundDefinitions = <(String, String, int, int, int)>[
  ('morning', 'Ochtend', 7, 0, 0),
  ('afternoon', 'Middag', 12, 0, 1),
  ('evening', 'Avond', 18, 0, 2),
];

const _feedingCategoryDefinitions = <(String, String, IconData)>[
  ('feed', 'Voer', Icons.grass_outlined),
  ('hay', 'Hooi', Icons.eco_outlined),
  ('supplements', 'Supplementen', Icons.science_outlined),
  ('medication', 'Medicatie', Icons.medication_outlined),
];

const _feedingLegacyStableId = 'local-stable';

DateTime _feedingDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _feedingShiftDay(DateTime value, int days) =>
    DateTime(value.year, value.month, value.day + days);

bool _feedingSameDay(DateTime? first, DateTime second) =>
    first != null &&
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

String _feedingTwo(int value) => value.toString().padLeft(2, '0');

String _feedingDateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${_feedingTwo(value.month)}-${_feedingTwo(value.day)}';

DateTime? _feedingParseDateKey(String value) {
  final parts = value.trim().split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  final parsed = DateTime(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }
  return parsed;
}

String _feedingRoundLabel(String roundId) => _feedingRoundDefinitions
    .firstWhere(
      (entry) => entry.$1 == roundId,
      orElse: () => (roundId, roundId, 0, 0, 99),
    )
    .$2;

DateTime _feedingDefaultTime(String roundId) {
  final definition = _feedingRoundDefinitions.firstWhere(
    (entry) => entry.$1 == roundId,
    orElse: () => (roundId, roundId, 7, 0, 99),
  );
  return DateTime(2000, 1, 1, definition.$3, definition.$4);
}

FeedingItemDataStruct _feedingCopyItem(FeedingItemDataStruct item) =>
    FeedingItemDataStruct(
      id: item.id,
      categoryId: item.categoryId,
      name: item.name,
      quantity: item.quantity,
      quantityMode: item.quantityMode,
      unitId: item.unitId,
      customUnitLabel: item.customUnitLabel,
      instruction: item.instruction,
      linkedProductId: item.linkedProductId,
      sortOrder: item.sortOrder,
    );

String _feedingHorseName(HorseProfileDataStruct horse) {
  if (horse.callName.trim().isNotEmpty) return horse.callName.trim();
  if (horse.officialName.trim().isNotEmpty) return horse.officialName.trim();
  return 'Onbekend paard';
}

DateTime _feedingRecordTimestamp(FeedingExecutionRecordDataStruct record) =>
    record.updatedAt ??
    record.performedAt ??
    record.createdAt ??
    DateTime.fromMillisecondsSinceEpoch(0);

bool _feedingSameLogicalRecord(
  FeedingExecutionRecordDataStruct record, {
  required String stableId,
  required int horseId,
  required DateTime date,
  required String roundId,
}) =>
    record.stableId == stableId &&
    record.horseId == horseId &&
    record.roundId == roundId &&
    _feedingSameDay(record.feedingDate, date);

class _FeedingHorseState {
  const _FeedingHorseState({
    required this.horse,
    required this.hasPlan,
    required this.schedule,
    required this.record,
  });

  final HorseProfileDataStruct horse;
  final bool hasPlan;
  final EffectiveFeedingScheduleDataStruct schedule;
  final FeedingExecutionRecordDataStruct? record;

  bool get hasCurrentFood => schedule.items.isNotEmpty;
  bool get isProcessed => record != null && !record!.isReopened;
  bool get hasSavedSnapshot =>
      record != null && record!.scheduleItems.isNotEmpty;
  bool get isActionable =>
      hasPlan && (hasCurrentFood || (isProcessed && hasSavedSnapshot));
  bool get isDeviation =>
      isActionable && isProcessed && record!.resultStatus == 'deviation';
  List<FeedingItemDataStruct> get displayItems =>
      isProcessed && hasSavedSnapshot ? record!.scheduleItems : schedule.items;
  String get displayScheduleSource =>
      isProcessed && record!.scheduleSource.trim().isNotEmpty
          ? record!.scheduleSource.trim()
          : schedule.sourceType;
}

class _FeedingProgress {
  const _FeedingProgress({
    required this.applicable,
    required this.processed,
    required this.deviations,
    required this.missingPlans,
    required this.emptyRounds,
  });

  factory _FeedingProgress.from(List<_FeedingHorseState> states) {
    final applicable = states.where((state) => state.isActionable).length;
    final processed =
        states.where((state) => state.isActionable && state.isProcessed).length;
    return _FeedingProgress(
      applicable: applicable,
      processed: processed > applicable ? applicable : processed,
      deviations: states.where((state) => state.isDeviation).length,
      missingPlans: states.where((state) => !state.hasPlan).length,
      emptyRounds: states
          .where(
            (state) =>
                state.hasPlan && !state.isActionable && !state.isProcessed,
          )
          .length,
    );
  }

  final int applicable;
  final int processed;
  final int deviations;
  final int missingPlans;
  final int emptyRounds;

  int get open {
    final value = applicable - processed;
    return value < 0 ? 0 : value;
  }

  bool get isComplete => open == 0 && missingPlans == 0;

  double get fraction =>
      applicable == 0 ? 0 : (processed / applicable).clamp(0.0, 1.0).toDouble();
}

class _ExceptionDraft {
  const _ExceptionDraft({
    required this.mode,
    required this.userId,
    required this.note,
  });

  final String mode;
  final String userId;
  final String note;
}

class _DeviationDraft {
  const _DeviationDraft(this.type, this.note);

  final String type;
  final String note;
}

class AvarynDailyFeedingRuntime extends StatefulWidget {
  const AvarynDailyFeedingRuntime({
    super.key,
    this.width,
    this.height,
    this.mode = 'overview',
  });

  final double? width;
  final double? height;
  final String mode;

  @override
  State<AvarynDailyFeedingRuntime> createState() =>
      _AvarynDailyFeedingRuntimeState();
}

class _AvarynDailyFeedingRuntimeState extends State<AvarynDailyFeedingRuntime> {
  late DateTime _selectedDate;
  String _filter = 'open';
  bool _modalOpen = false;
  bool _navigating = false;
  final Set<String> _pendingRecordKeys = <String>{};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedDate = _feedingParseDateKey(FFAppState().selectedFeedingDateKey) ??
        _feedingDay(DateTime.now());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _stableId {
    final value = FFAppState().currentLocalStableId.trim();
    return value.isEmpty ? _feedingLegacyStableId : value;
  }

  String get _currentUserId {
    final value = FFAppState().currentLocalUserId.trim();
    return value.isEmpty ? 'local-current-user' : value;
  }

  bool get _isToday => _feedingSameDay(_selectedDate, DateTime.now());
  bool get _isFuture => _selectedDate.isAfter(_feedingDay(DateTime.now()));
  bool get _canExecute => _isToday;

  List<FeedingRoundConfigDataStruct> get _roundConfigs =>
      _feedingRoundDefinitions.map((definition) {
        final matches = FFAppState()
            .feedingRoundConfigs
            .where(
              (config) =>
                  config.stableId == _stableId &&
                  config.roundId == definition.$1,
            )
            .toList()
          ..sort(
            (first, second) =>
                (second.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                    .compareTo(
              first.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
            ),
          );
        if (matches.isNotEmpty) return matches.first;
        return FeedingRoundConfigDataStruct(
          stableId: _stableId,
          roundId: definition.$1,
          displayLabel: definition.$2,
          plannedTime: _feedingDefaultTime(definition.$1),
          sortOrder: definition.$5,
          defaultResponsibleUserId: '',
          enabled: true,
          schemaVersion: 2,
        );
      }).toList();

  FeedingRoundConfigDataStruct _configFor(String roundId) =>
      _roundConfigs.firstWhere(
        (item) => item.roundId == roundId,
        orElse: () => FeedingRoundConfigDataStruct(
          stableId: _stableId,
          roundId: roundId,
          displayLabel: _feedingRoundLabel(roundId),
          plannedTime: _feedingDefaultTime(roundId),
          enabled: true,
          schemaVersion: 2,
        ),
      );

  ResolvedFeedingResponsibleDataStruct _responsibleFor(
    String roundId, [
    DateTime? date,
  ]) =>
      resolveFeedingResponsibleUserV1(
        FFAppState().feedingRoundConfigs,
        FFAppState().feedingAssignmentExceptions,
        _stableId,
        date ?? _selectedDate,
        roundId,
      ) ??
      ResolvedFeedingResponsibleDataStruct(
        stableId: _stableId,
        date: _feedingDay(date ?? _selectedDate),
        roundId: roundId,
        resolvedUserId: '',
        source: 'unassigned',
        exceptionId: '',
      );

  String _userLabel(String userId) {
    final normalized = userId.trim();
    if (normalized.isEmpty) return 'Nog niemand toegewezen';
    if (normalized == _currentUserId) {
      return 'Huidige lokaal geregistreerde gebruiker';
    }
    return 'Niet-beschikbare gebruiker';
  }

  List<HorseProfileDataStruct> get _activeHorses {
    final horses = FFAppState().horses.where((horse) {
      final horseStable = horse.stableId.trim();
      final scopedStable =
          horseStable.isEmpty ? _feedingLegacyStableId : horseStable;
      return scopedStable == _stableId;
    }).toList();
    horses.sort((first, second) {
      final firstLocation = first.stableLocation.trim();
      final secondLocation = second.stableLocation.trim();
      if (firstLocation.isNotEmpty || secondLocation.isNotEmpty) {
        final locationOrder = firstLocation.compareTo(secondLocation);
        if (locationOrder != 0) return locationOrder;
      }
      return _feedingHorseName(
        first,
      ).toLowerCase().compareTo(_feedingHorseName(second).toLowerCase());
    });
    return horses;
  }

  bool _hasPlan(int horseId) => FFAppState().horseFeedingPlans.any(
        (plan) => plan.stableId == _stableId && plan.horseId == horseId,
      );

  FeedingExecutionRecordDataStruct? _recordFor(
    int horseId,
    DateTime date,
    String roundId,
  ) {
    final matches = FFAppState()
        .feedingExecutionRecords
        .where(
          (record) => _feedingSameLogicalRecord(
            record,
            stableId: _stableId,
            horseId: horseId,
            date: date,
            roundId: roundId,
          ),
        )
        .toList()
      ..sort(
        (first, second) => _feedingRecordTimestamp(
          second,
        ).compareTo(_feedingRecordTimestamp(first)),
      );
    return matches.isEmpty ? null : matches.first;
  }

  List<_FeedingHorseState> _horseStates(String roundId, [DateTime? date]) {
    final targetDate = _feedingDay(date ?? _selectedDate);
    return _activeHorses.map((horse) {
      final resolved = resolveEffectiveFeedingScheduleV1(
            FFAppState().horseFeedingPlans,
            FFAppState().temporaryFeedingSchedules,
            _stableId,
            horse.id,
            targetDate,
            roundId,
          ) ??
          EffectiveFeedingScheduleDataStruct(
            sourceType: 'standard',
            temporaryScheduleId: '',
            stableId: _stableId,
            horseId: horse.id,
            date: targetDate,
            roundId: roundId,
            items: const <FeedingItemDataStruct>[],
          );
      return _FeedingHorseState(
        horse: horse,
        hasPlan: _hasPlan(horse.id),
        schedule: resolved,
        record: _recordFor(horse.id, targetDate, roundId),
      );
    }).toList();
  }

  _FeedingProgress _progressFor(List<_FeedingHorseState> states) =>
      _FeedingProgress.from(states);

  String _timeLabel(FeedingRoundConfigDataStruct config) {
    final time = config.plannedTime ?? _feedingDefaultTime(config.roundId);
    return '${_feedingTwo(time.hour)}:${_feedingTwo(time.minute)}';
  }

  String _dateLabel(DateTime value) {
    const weekdays = <String>[
      'maandag',
      'dinsdag',
      'woensdag',
      'donderdag',
      'vrijdag',
      'zaterdag',
      'zondag',
    ];
    const months = <String>[
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
    ];
    return '${weekdays[value.weekday - 1]} ${value.day} '
        '${months[value.month - 1]} ${value.year}';
  }

  void _setDate(DateTime value) {
    final normalized = _feedingDay(value);
    setState(() => _selectedDate = normalized);
    FFAppState().update(
      () => FFAppState().selectedFeedingDateKey = _feedingDateKey(normalized),
    );
  }

  Future<void> _openRound(String roundId, {DateTime? date}) async {
    if (_navigating) return;
    _navigating = true;
    final targetDate = _feedingDay(date ?? _selectedDate);
    FFAppState().update(() {
      FFAppState().selectedFeedingDateKey = _feedingDateKey(targetDate);
      FFAppState().selectedFeedingRoundId = roundId;
    });
    if (mounted) setState(() {});
    await context.pushNamed('FeedingRoundExecutionPage');
    _navigating = false;
    if (mounted) setState(() {});
  }

  Future<void> _openOverview() async {
    if (_navigating) return;
    _navigating = true;
    final today = _feedingDay(DateTime.now());
    FFAppState().update(
      () => FFAppState().selectedFeedingDateKey = _feedingDateKey(today),
    );
    await context.pushNamed('FeedingOverviewPage');
    _navigating = false;
    if (mounted) setState(() {});
  }

  Future<void> _openSettings() async {
    if (_navigating) return;
    _navigating = true;
    await context.pushNamed('FeedingRoundSettingsPage');
    _navigating = false;
    if (mounted) setState(() {});
  }

  Future<void> _openHorseNutrition(HorseProfileDataStruct horse) async {
    if (_navigating) return;
    final index = FFAppState().horses.indexWhere(
          (candidate) => candidate.id == horse.id,
        );
    if (index < 0) return;
    _navigating = true;
    FFAppState().update(() {
      FFAppState().selectedHorseIndex = index;
      FFAppState().selectedHorse = horse;
    });
    await context.pushNamed('HorseNutritionPage');
    _navigating = false;
    if (mounted) setState(() {});
  }

  Future<void> _editDefaultResponsible(String roundId) async {
    if (_modalOpen) return;
    _modalOpen = true;
    final config = _configFor(roundId);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ResponsiblePickerSheet(
        initialUserId: config.defaultResponsibleUserId,
        currentUserId: _currentUserId,
        allowUseDefault: false,
      ),
    );
    _modalOpen = false;
    if (!mounted || result == null) return;
    _saveRoundConfig(
      config,
      plannedTime: config.plannedTime,
      responsibleUserId: result,
    );
  }

  Future<void> _editRoundTime(String roundId) async {
    if (_modalOpen) return;
    _modalOpen = true;
    final config = _configFor(roundId);
    final result = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _AvarynFeedingTimeWheel(
        initialTime: config.plannedTime ?? _feedingDefaultTime(roundId),
        title: '${_feedingRoundLabel(roundId)} instellen',
      ),
    );
    _modalOpen = false;
    if (!mounted || result == null) return;
    _saveRoundConfig(
      config,
      plannedTime: result,
      responsibleUserId: config.defaultResponsibleUserId,
    );
  }

  void _saveRoundConfig(
    FeedingRoundConfigDataStruct source, {
    required DateTime? plannedTime,
    required String responsibleUserId,
  }) {
    final all = List<FeedingRoundConfigDataStruct>.from(
      FFAppState().feedingRoundConfigs,
    );
    final updated = FeedingRoundConfigDataStruct(
      stableId: _stableId,
      roundId: source.roundId,
      displayLabel: source.displayLabel.trim().isEmpty
          ? _feedingRoundLabel(source.roundId)
          : source.displayLabel.trim(),
      plannedTime: plannedTime ?? _feedingDefaultTime(source.roundId),
      sortOrder: source.sortOrder,
      defaultResponsibleUserId: responsibleUserId.trim(),
      enabled: source.hasEnabled() ? source.enabled : true,
      schemaVersion: 2,
      updatedAt: DateTime.now(),
    );
    all.removeWhere(
      (item) => item.stableId == _stableId && item.roundId == source.roundId,
    );
    all.add(updated);
    FFAppState().update(() => FFAppState().feedingRoundConfigs = all);
  }

  Future<void> _editDateAssignment(String roundId) async {
    if (_modalOpen) return;
    _modalOpen = true;
    final existingMatches = FFAppState()
        .feedingAssignmentExceptions
        .where(
          (item) =>
              item.stableId == _stableId &&
              item.roundId == roundId &&
              _feedingSameDay(item.date, _selectedDate),
        )
        .toList()
      ..sort(
        (first, second) => (second.updatedAt ??
                second.createdAt ??
                DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(
          first.updatedAt ??
              first.createdAt ??
              DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );
    final existing = existingMatches.isEmpty ? null : existingMatches.first;
    final result = await showModalBottomSheet<_ExceptionDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _AssignmentExceptionSheet(
        roundLabel: _feedingRoundLabel(roundId),
        dateLabel: _dateLabel(_selectedDate),
        currentUserId: _currentUserId,
        existing: existing,
      ),
    );
    _modalOpen = false;
    if (!mounted || result == null) return;
    final all = List<FeedingAssignmentExceptionDataStruct>.from(
      FFAppState().feedingAssignmentExceptions,
    );
    all.removeWhere(
      (item) =>
          item.stableId == _stableId &&
          item.roundId == roundId &&
          _feedingSameDay(item.date, _selectedDate),
    );
    if (result.mode != 'default') {
      final now = DateTime.now();
      all.add(
        FeedingAssignmentExceptionDataStruct(
          id: existing?.id.isNotEmpty == true
              ? existing!.id
              : 'feeding-assignment-'
                  '${FFAppState().nextFeedingAssignmentExceptionId}',
          stableId: _stableId,
          date: _feedingDay(_selectedDate),
          roundId: roundId,
          replacementResponsibleUserId:
              result.mode == 'current' ? result.userId : '',
          explicitlyUnassigned: result.mode == 'unassigned',
          note: result.note.trim(),
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
        ),
      );
    }
    FFAppState().update(() {
      FFAppState().feedingAssignmentExceptions = all;
      if (existing == null && result.mode != 'default') {
        FFAppState().nextFeedingAssignmentExceptionId =
            FFAppState().nextFeedingAssignmentExceptionId + 1;
      }
    });
  }

  String _logicalKey(int horseId, String roundId) =>
      feedingExecutionLogicalKeyV1(
        _stableId,
        horseId,
        _selectedDate,
        roundId,
      ) ??
      '';

  Future<void> _saveResult(
    _FeedingHorseState state,
    String roundId, {
    required String status,
    String deviationType = '',
    String deviationNote = '',
  }) async {
    if (!_canExecute || !state.hasPlan || !state.hasCurrentFood) return;
    final key = _logicalKey(state.horse.id, roundId);
    if (_pendingRecordKeys.contains(key)) return;
    _pendingRecordKeys.add(key);
    if (mounted) setState(() {});
    try {
      final all = List<FeedingExecutionRecordDataStruct>.from(
        FFAppState().feedingExecutionRecords,
      );
      final matches = all
          .where(
            (record) => _feedingSameLogicalRecord(
              record,
              stableId: _stableId,
              horseId: state.horse.id,
              date: _selectedDate,
              roundId: roundId,
            ),
          )
          .toList()
        ..sort(
          (first, second) => _feedingRecordTimestamp(
            second,
          ).compareTo(_feedingRecordTimestamp(first)),
        );
      final existing = matches.isEmpty ? null : matches.first;
      if (existing != null && !existing.isReopened) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dit paard is al verwerkt.')),
          );
        }
        return;
      }
      final now = DateTime.now();
      final responsible = _responsibleFor(roundId);
      final record = FeedingExecutionRecordDataStruct(
        id: existing?.id.isNotEmpty == true
            ? existing!.id
            : 'feeding-execution-${FFAppState().nextFeedingExecutionRecordId}',
        stableId: _stableId,
        horseId: state.horse.id,
        feedingDate: _feedingDay(_selectedDate),
        roundId: roundId,
        resultStatus: status,
        performedByUserId: _currentUserId,
        performedAt: now,
        resolvedResponsibleUserId: responsible.resolvedUserId,
        scheduleSource: state.schedule.sourceType,
        temporaryScheduleId: state.schedule.temporaryScheduleId,
        scheduleItems: state.schedule.items.map(_feedingCopyItem).toList(),
        deviationType: deviationType,
        deviationNote: deviationNote.trim(),
        isReopened: false,
        reopenedAt: existing?.reopenedAt,
        reopenedByUserId: existing?.reopenedByUserId ?? '',
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        schemaVersion: 2,
      );
      all.removeWhere(
        (candidate) => _feedingSameLogicalRecord(
          candidate,
          stableId: _stableId,
          horseId: state.horse.id,
          date: _selectedDate,
          roundId: roundId,
        ),
      );
      all.add(record);
      FFAppState().update(() {
        FFAppState().feedingExecutionRecords = all;
        if (existing == null) {
          FFAppState().nextFeedingExecutionRecordId =
              FFAppState().nextFeedingExecutionRecordId + 1;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'completed'
                  ? '${_feedingHorseName(state.horse)} is gevoerd.'
                  : 'Afwijking voor ${_feedingHorseName(state.horse)} opgeslagen.',
            ),
            action: SnackBarAction(
              label: 'Ongedaan maken',
              onPressed: () => _reopenRecord(record, confirm: false),
            ),
          ),
        );
      }
    } finally {
      _pendingRecordKeys.remove(key);
      if (mounted) setState(() {});
    }
  }

  Future<void> _reportDeviation(
    _FeedingHorseState state,
    String roundId,
  ) async {
    if (_modalOpen || !_canExecute) return;
    _modalOpen = true;
    final result = await showModalBottomSheet<_DeviationDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => const _DeviationSheet(),
    );
    _modalOpen = false;
    if (!mounted || result == null) return;
    await _saveResult(
      state,
      roundId,
      status: 'deviation',
      deviationType: result.type,
      deviationNote: result.note,
    );
  }

  Future<void> _reopenRecord(
    FeedingExecutionRecordDataStruct record, {
    bool confirm = true,
  }) async {
    if (confirm) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Resultaat heropenen?'),
          content: const Text(
            'Het paard komt opnieuw bij Openstaand. De opgeslagen historie '
            'en voersnapshot blijven bij dit logische resultaat bewaard.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuleren'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Heropenen'),
            ),
          ],
        ),
      );
      if (accepted != true) return;
    }
    final key = feedingExecutionLogicalKeyV1(
          record.stableId,
          record.horseId,
          record.feedingDate,
          record.roundId,
        ) ??
        '';
    if (_pendingRecordKeys.contains(key)) return;
    _pendingRecordKeys.add(key);
    if (mounted) setState(() {});
    try {
      final all = List<FeedingExecutionRecordDataStruct>.from(
        FFAppState().feedingExecutionRecords,
      );
      final matches = all
          .where(
            (item) => _feedingSameLogicalRecord(
              item,
              stableId: record.stableId,
              horseId: record.horseId,
              date: record.feedingDate ?? _selectedDate,
              roundId: record.roundId,
            ),
          )
          .toList()
        ..sort(
          (first, second) => _feedingRecordTimestamp(
            second,
          ).compareTo(_feedingRecordTimestamp(first)),
        );
      if (matches.isEmpty) return;
      final latest = matches.first;
      final reopened = FeedingExecutionRecordDataStruct(
        id: latest.id,
        stableId: latest.stableId,
        horseId: latest.horseId,
        feedingDate: latest.feedingDate,
        roundId: latest.roundId,
        resultStatus: latest.resultStatus,
        performedByUserId: latest.performedByUserId,
        performedAt: latest.performedAt,
        resolvedResponsibleUserId: latest.resolvedResponsibleUserId,
        scheduleSource: latest.scheduleSource,
        temporaryScheduleId: latest.temporaryScheduleId,
        scheduleItems: latest.scheduleItems.map(_feedingCopyItem).toList(),
        deviationType: latest.deviationType,
        deviationNote: latest.deviationNote,
        isReopened: true,
        reopenedAt: DateTime.now(),
        reopenedByUserId: _currentUserId,
        createdAt: latest.createdAt,
        updatedAt: DateTime.now(),
        schemaVersion: 2,
      );
      all.removeWhere(
        (item) => _feedingSameLogicalRecord(
          item,
          stableId: latest.stableId,
          horseId: latest.horseId,
          date: latest.feedingDate ?? _selectedDate,
          roundId: latest.roundId,
        ),
      );
      all.add(reopened);
      FFAppState().update(() => FFAppState().feedingExecutionRecords = all);
    } finally {
      _pendingRecordKeys.remove(key);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: switch (widget.mode) {
        'today' => _buildTodayCard(context),
        'execution' => _buildExecution(context),
        'settings' => _buildSettings(context),
        _ => _buildOverview(context),
      },
    );
  }

  Widget _pageFrame(BuildContext context, Widget child) {
    final theme = FlutterFlowTheme.of(context);
    return ColoredBox(
      color: theme.primaryBackground,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            constraints.maxWidth >= 700 ? 28 : 18,
            18,
            constraints.maxWidth >= 700 ? 28 : 18,
            48,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageHeader(
    BuildContext context, {
    required String eyebrow,
    required String title,
    required String subtitle,
    VoidCallback? action,
    IconData actionIcon = Icons.settings_outlined,
  }) {
    final theme = FlutterFlowTheme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: () => context.safePop(),
          tooltip: 'Terug',
          icon: const Icon(Icons.arrow_back),
          color: theme.primaryText,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: theme.labelSmall.copyWith(color: theme.secondary),
              ),
              const SizedBox(height: 3),
              Text(
                title,
                style: theme.headlineMedium.copyWith(color: theme.primaryText),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.bodySmall.copyWith(color: theme.secondaryText),
              ),
            ],
          ),
        ),
        if (action != null)
          IconButton(
            onPressed: action,
            tooltip: 'Voerrondes beheren',
            icon: Icon(actionIcon),
            color: theme.secondary,
          ),
      ],
    );
  }

  Widget _buildOverview(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return _pageFrame(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _pageHeader(
            context,
            eyebrow: 'DAGELIJKSE UITVOERING',
            title: 'Voeding',
            subtitle: 'Voerrondes voor ${_dateLabel(_selectedDate)}',
            action: _openSettings,
          ),
          const SizedBox(height: 22),
          _dateNavigator(context),
          const SizedBox(height: 20),
          ..._roundConfigs.map((config) {
            final states = _horseStates(config.roundId);
            final progress = _progressFor(states);
            final responsible = _responsibleFor(config.roundId);
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.secondaryBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.alternate),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${config.displayLabel.isEmpty ? _feedingRoundLabel(config.roundId) : config.displayLabel} '
                            '· ${_timeLabel(config)}',
                            style: theme.titleLarge.copyWith(
                              color: theme.primaryText,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _editDateAssignment(config.roundId),
                          tooltip: 'Verantwoordelijke voor deze datum',
                          icon: const Icon(Icons.person_outline),
                          color: theme.secondary,
                        ),
                      ],
                    ),
                    Text(
                      _userLabel(responsible.resolvedUserId),
                      style: theme.bodyMedium.copyWith(
                        color: theme.primaryText,
                      ),
                    ),
                    if (responsible.source == 'dateException' ||
                        responsible.exceptionId.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          'Aangepast voor deze datum',
                          style: theme.labelSmall.copyWith(
                            color: theme.secondary,
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    LinearProgressIndicator(
                      value: progress.fraction,
                      minHeight: 7,
                      borderRadius: BorderRadius.circular(99),
                      color: theme.secondary,
                      backgroundColor: theme.accent2,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${progress.processed} van ${progress.applicable} paarden verwerkt'
                      ' · ${progress.open} open'
                      '${progress.deviations > 0 ? ' · ${progress.deviations} afwijking${progress.deviations == 1 ? '' : 'en'}' : ''}',
                      style: theme.bodySmall.copyWith(
                        color: theme.secondaryText,
                      ),
                    ),
                    if (progress.missingPlans > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          '${progress.missingPlans} paard${progress.missingPlans == 1 ? '' : 'en'} zonder voerschema',
                          style: theme.bodySmall.copyWith(color: theme.error),
                        ),
                      ),
                    if (progress.emptyRounds > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          '${progress.emptyRounds} paard${progress.emptyRounds == 1 ? '' : 'en'} zonder voeding in deze ronde',
                          style: theme.bodySmall.copyWith(
                            color: theme.secondaryText,
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => _openRound(config.roundId),
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Open voerronde'),
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.secondary,
                        foregroundColor: theme.primary,
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _dateNavigator(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.alternate),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _setDate(_feedingShiftDay(_selectedDate, -1)),
                tooltip: 'Vorige dag',
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  _dateLabel(_selectedDate),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.titleSmall.copyWith(color: theme.primaryText),
                ),
              ),
              IconButton(
                onPressed: () => _setDate(_feedingShiftDay(_selectedDate, 1)),
                tooltip: 'Volgende dag',
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          if (!_isToday)
            TextButton(
              onPressed: () => _setDate(DateTime.now()),
              child: const Text('Vandaag'),
            ),
        ],
      ),
    );
  }

  Widget _buildSettings(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return _pageFrame(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _pageHeader(
            context,
            eyebrow: 'STALINSTELLINGEN',
            title: 'Voerrondes beheren',
            subtitle: 'Tijd en standaard verantwoordelijke per ronde.',
          ),
          const SizedBox(height: 22),
          ..._roundConfigs.map(
            (config) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.secondaryBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.alternate),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      config.displayLabel.isEmpty
                          ? _feedingRoundLabel(config.roundId)
                          : config.displayLabel,
                      style: theme.titleLarge.copyWith(
                        color: theme.primaryText,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _settingsRow(
                      context,
                      icon: Icons.schedule,
                      label: 'Tijd',
                      value: _timeLabel(config),
                      onTap: () => _editRoundTime(config.roundId),
                    ),
                    const Divider(height: 24),
                    _settingsRow(
                      context,
                      icon: Icons.person_outline,
                      label: 'Standaard verantwoordelijk',
                      value: _userLabel(config.defaultResponsibleUserId),
                      onTap: () => _editDefaultResponsible(config.roundId),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.accent2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Er is momenteel één lokaal geregistreerde gebruiker beschikbaar. '
              'AVARYN slaat de gebruikers-ID op; namen zijn alleen weergave.',
              style: theme.bodySmall.copyWith(color: theme.secondaryText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final theme = FlutterFlowTheme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, color: theme.secondary, size: 21),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.labelSmall.copyWith(
                      color: theme.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.bodyMedium.copyWith(color: theme.primaryText),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: theme.secondaryText),
          ],
        ),
      ),
    );
  }

  Widget _buildExecution(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final roundId = FFAppState().selectedFeedingRoundId.trim().isEmpty
        ? 'morning'
        : FFAppState().selectedFeedingRoundId.trim();
    final config = _configFor(roundId);
    final states = _horseStates(roundId);
    final progress = _progressFor(states);
    final responsible = _responsibleFor(roundId);
    final query = _searchController.text.trim().toLowerCase();
    final visibleStates = states.where((state) {
      if (_filter == 'open' && state.isProcessed) return false;
      if (_filter == 'done' && !state.isProcessed) return false;
      if (query.isNotEmpty &&
          !_feedingHorseName(state.horse).toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();

    return _pageFrame(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _pageHeader(
            context,
            eyebrow: _dateLabel(_selectedDate).toUpperCase(),
            title:
                '${config.displayLabel.isEmpty ? _feedingRoundLabel(roundId) : config.displayLabel} '
                '· ${_timeLabel(config)}',
            subtitle: _userLabel(responsible.resolvedUserId),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.secondaryBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.alternate),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${progress.processed} van ${progress.applicable} verwerkt'
                        ' · ${progress.open} open',
                        style: theme.titleSmall.copyWith(
                          color: theme.primaryText,
                        ),
                      ),
                    ),
                    Text(
                      '${progress.deviations} afwijking${progress.deviations == 1 ? '' : 'en'}'
                      '${progress.missingPlans > 0 ? ' · ${progress.missingPlans} aandacht' : ''}',
                      style: theme.bodySmall.copyWith(
                        color:
                            progress.deviations > 0 || progress.missingPlans > 0
                                ? theme.error
                                : theme.secondaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: progress.fraction,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(99),
                  color: theme.secondary,
                  backgroundColor: theme.accent2,
                ),
              ],
            ),
          ),
          if (!_canExecute)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.accent2,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _isFuture
                      ? 'Toekomstige voerronde: bekijken en toewijzen is mogelijk, '
                          'maar paarden kunnen nog niet als gevoerd worden gemarkeerd.'
                      : 'Historische voerronde: opgeslagen resultaten blijven '
                          'zichtbaar. Correcties verlopen via Heropenen.',
                  style: theme.bodySmall.copyWith(color: theme.secondaryText),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _filterChip(context, 'open', 'Openstaand'),
              _filterChip(context, 'done', 'Afgerond'),
              _filterChip(context, 'all', 'Alles'),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Paard zoeken',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                    ),
              filled: true,
              fillColor: theme.secondaryBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.alternate),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.alternate),
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (visibleStates.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.secondaryBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.alternate),
              ),
              child: Text(
                _filter == 'done'
                    ? 'Nog geen paarden afgerond.'
                    : 'Geen paarden in deze weergave.',
                textAlign: TextAlign.center,
                style: theme.bodyMedium.copyWith(color: theme.secondaryText),
              ),
            )
          else
            ...visibleStates.map(
              (state) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _horseExecutionCard(context, state, roundId),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChip(BuildContext context, String value, String label) {
    final theme = FlutterFlowTheme.of(context);
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: theme.accent2,
      backgroundColor: theme.secondaryBackground,
      labelStyle: theme.bodySmall.copyWith(
        color: selected ? theme.primaryText : theme.secondaryText,
      ),
      side: BorderSide(color: selected ? theme.secondary : theme.alternate),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
    );
  }

  Widget _horseExecutionCard(
    BuildContext context,
    _FeedingHorseState state,
    String roundId,
  ) {
    final theme = FlutterFlowTheme.of(context);
    final record = state.record;
    final displayItems = state.displayItems;
    final displaySource = state.displayScheduleSource;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: record?.resultStatus == 'deviation'
              ? theme.error
              : theme.alternate,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: AvarynHorseAvatar(
                  width: 52,
                  height: 52,
                  photoState: state.horse.photoData,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _feedingHorseName(state.horse),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.titleLarge.copyWith(
                        color: theme.primaryText,
                      ),
                    ),
                    if (state.horse.stableLocation.trim().isNotEmpty)
                      Text(
                        state.horse.stableLocation.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.bodySmall.copyWith(
                          color: theme.secondaryText,
                        ),
                      ),
                  ],
                ),
              ),
              if (displaySource == 'temporary')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: theme.accent2,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    'Tijdelijk',
                    style: theme.labelSmall.copyWith(color: theme.secondary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (!state.hasPlan) ...[
            _attentionPanel(
              context,
              icon: Icons.warning_amber,
              title: 'Voerschema ontbreekt',
              body: 'Dit paard wordt niet als succesvol gevoerd meegerekend.',
              color: theme.warning,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _openHorseNutrition(state.horse),
              icon: const Icon(Icons.restaurant_outlined),
              label: const Text('Voerschema openen'),
            ),
          ],
          if (state.hasPlan && displayItems.isEmpty) ...[
            _attentionPanel(
              context,
              icon: Icons.do_not_disturb_alt_outlined,
              title: 'Geen voeding in deze ronde',
              body: displaySource == 'temporary'
                  ? 'Tijdelijk geen voeding'
                  : 'Voor deze ronde staan geen items ingesteld.',
              color: theme.secondary,
            ),
          ],
          if (displayItems.isNotEmpty) ...[
            if (!state.hasPlan) const SizedBox(height: 14),
            Text(
              state.isProcessed
                  ? 'OPGESLAGEN VOERSNAPSHOT'
                  : displaySource == 'temporary'
                      ? 'TIJDELIJK SCHEMA'
                      : 'STANDAARD',
              style: theme.labelSmall.copyWith(color: theme.secondary),
            ),
            const SizedBox(height: 10),
            ..._feedingCategoryDefinitions.map((category) {
              final items = displayItems
                  .where((item) => item.categoryId == category.$1)
                  .toList()
                ..sort(
                  (first, second) =>
                      first.sortOrder.compareTo(second.sortOrder),
                );
              if (items.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(category.$3, size: 17, color: theme.secondary),
                        const SizedBox(width: 7),
                        Text(
                          category.$2,
                          style: theme.labelMedium.copyWith(
                            color: theme.primaryText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    ...items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 7, left: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item.name} — ${_itemQuantity(item)}',
                              style: theme.bodyMedium.copyWith(
                                color: theme.primaryText,
                              ),
                            ),
                            if (item.instruction.trim().isNotEmpty)
                              Text(
                                item.instruction.trim(),
                                style: theme.bodySmall.copyWith(
                                  color: theme.secondaryText,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (category.$1 == 'medication')
                      Padding(
                        padding: const EdgeInsets.only(left: 24, top: 2),
                        child: Text(
                          'AVARYN registreert alleen het ingestelde schema en '
                          'geeft geen medisch advies.',
                          style: theme.bodySmall.copyWith(
                            color: theme.secondaryText,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
          if (record != null) ...[
            const Divider(height: 24),
            _resultPanel(context, record),
            if (!record.isReopened) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _pendingRecordKeys.contains(
                  _logicalKey(state.horse.id, roundId),
                )
                    ? null
                    : () => _reopenRecord(record),
                icon: const Icon(Icons.refresh),
                label: const Text('Heropenen'),
              ),
            ],
          ],
          if ((record == null || record.isReopened) &&
              state.hasPlan &&
              state.hasCurrentFood) ...[
            const Divider(height: 24),
            if (_canExecute)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _reportDeviation(state, roundId),
                      child: const Text('Afwijking melden'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _pendingRecordKeys.contains(
                        _logicalKey(state.horse.id, roundId),
                      )
                          ? null
                          : () => _saveResult(
                                state,
                                roundId,
                                status: 'completed',
                              ),
                      icon: const Icon(Icons.check),
                      label: const Text('Gevoerd'),
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.secondary,
                        foregroundColor: theme.primary,
                      ),
                    ),
                  ),
                ],
              )
            else
              Text(
                _isFuture
                    ? 'Registratie wordt beschikbaar op de geselecteerde dag.'
                    : 'Geen nieuw resultaat toevoegen aan een historische ronde.',
                style: theme.bodySmall.copyWith(color: theme.secondaryText),
              ),
          ],
        ],
      ),
    );
  }

  String _itemQuantity(FeedingItemDataStruct item) {
    if (item.quantityMode == 'unlimited') {
      return 'Onbeperkt / vrije toegang';
    }
    final quantity = item.quantity;
    final quantityText = quantity == quantity.roundToDouble()
        ? quantity.toStringAsFixed(0)
        : quantity
            .toStringAsFixed(2)
            .replaceFirst(RegExp(r'0+$'), '')
            .replaceFirst(RegExp(r'\.$'), '')
            .replaceAll('.', ',');
    final unit = switch (item.unitId) {
      'gram' => 'g',
      'kilogram' => 'kg',
      'milliliter' => 'ml',
      'liter' => 'l',
      'schep' => quantity == 1 ? 'schep' : 'scheppen',
      'maatbeker' => quantity == 1 ? 'maatbeker' : 'maatbekers',
      'tablet' => quantity == 1 ? 'tablet' : 'tabletten',
      'hand' => 'hand',
      'stuk' => quantity == 1 ? 'stuk' : 'stuks',
      'custom' => item.customUnitLabel.trim(),
      _ => item.unitId.trim(),
    };
    return '$quantityText${unit.isEmpty ? '' : ' $unit'}';
  }

  Widget _attentionPanel(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
    required Color color,
  }) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.accent2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.titleSmall.copyWith(color: theme.primaryText),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: theme.bodySmall.copyWith(color: theme.secondaryText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultPanel(
    BuildContext context,
    FeedingExecutionRecordDataStruct record,
  ) {
    final theme = FlutterFlowTheme.of(context);
    final deviation = record.resultStatus == 'deviation';
    final reopened = record.isReopened;
    final performedAt = record.performedAt;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: deviation && !reopened
            ? theme.error.withValues(alpha: 0.10)
            : theme.accent2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reopened
                ? 'Historisch resultaat · heropend'
                : deviation
                    ? 'Afwijking gemeld'
                    : 'Gevoerd',
            style: theme.titleSmall.copyWith(
              color: deviation && !reopened ? theme.error : theme.primaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_userLabel(record.performedByUserId)}'
            '${performedAt == null ? '' : ' · ${_feedingTwo(performedAt.hour)}:${_feedingTwo(performedAt.minute)}'}',
            style: theme.bodySmall.copyWith(color: theme.secondaryText),
          ),
          if (deviation && record.deviationType.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              record.deviationType,
              style: theme.bodyMedium.copyWith(color: theme.primaryText),
            ),
          ],
          if (record.deviationNote.trim().isNotEmpty)
            Text(
              record.deviationNote.trim(),
              style: theme.bodySmall.copyWith(color: theme.secondaryText),
            ),
          if (record.scheduleItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Opgeslagen voersnapshot · ${record.scheduleItems.length} item'
              '${record.scheduleItems.length == 1 ? '' : 's'}',
              style: theme.labelSmall.copyWith(color: theme.secondary),
            ),
            if (reopened) ...[
              const SizedBox(height: 6),
              ...record.scheduleItems.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    '• ${item.name} — ${_itemQuantity(item)}'
                    '${item.instruction.trim().isEmpty ? '' : ' · ${item.instruction.trim()}'}',
                    style: theme.bodySmall.copyWith(color: theme.secondaryText),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildTodayCard(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final today = _feedingDay(DateTime.now());
    final summaries = _roundConfigs.map((config) {
      final states = _horseStates(config.roundId, today);
      return (
        config: config,
        states: states,
        progress: _progressFor(states),
      );
    }).toList();
    final unfinished =
        summaries.where((summary) => !summary.progress.isComplete).toList();
    final nowMinutes = DateTime.now().hour * 60 + DateTime.now().minute;
    final due = unfinished.where((summary) {
      final time = summary.config.plannedTime ??
          _feedingDefaultTime(summary.config.roundId);
      return time.hour * 60 + time.minute <= nowMinutes;
    }).toList();
    final selected = due.isNotEmpty
        ? due.last
        : unfinished.isNotEmpty
            ? unfinished.first
            : summaries.first;
    final noHorses = summaries.every((summary) => summary.states.isEmpty);
    final allComplete = unfinished.isEmpty;
    final responsible = _responsibleFor(selected.config.roundId, today);
    final isMine = responsible.resolvedUserId == _currentUserId;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.restaurant_outlined, color: theme.secondary),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Voeding vandaag',
                  style: theme.titleLarge.copyWith(color: theme.primaryText),
                ),
              ),
              if (isMine && !allComplete && !noHorses)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: theme.accent2,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    'Jouw voerronde',
                    style: theme.labelSmall.copyWith(color: theme.secondary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            noHorses
                ? 'Geen paarden in deze stal'
                : allComplete
                    ? 'Alle voerrondes zijn verwerkt'
                    : '${selected.config.displayLabel.isEmpty ? _feedingRoundLabel(selected.config.roundId) : selected.config.displayLabel} '
                        '· ${_timeLabel(selected.config)}',
            style: theme.titleSmall.copyWith(color: theme.primaryText),
          ),
          const SizedBox(height: 4),
          Text(
            _userLabel(responsible.resolvedUserId),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.bodySmall.copyWith(color: theme.secondaryText),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: selected.progress.fraction,
            minHeight: 7,
            borderRadius: BorderRadius.circular(99),
            color: theme.secondary,
            backgroundColor: theme.accent2,
          ),
          const SizedBox(height: 7),
          Text(
            noHorses
                ? 'Er zijn geen toepasselijke voerrondes.'
                : '${selected.progress.processed} van ${selected.progress.applicable} verwerkt'
                    ' · ${selected.progress.open} open'
                    '${selected.progress.deviations > 0 ? ' · ${selected.progress.deviations} afwijking${selected.progress.deviations == 1 ? '' : 'en'}' : ''}'
                    '${selected.progress.missingPlans > 0 ? ' · ${selected.progress.missingPlans} voerschema ontbreekt' : ''}',
            style: theme.bodySmall.copyWith(color: theme.secondaryText),
          ),
          const SizedBox(height: 13),
          FilledButton(
            onPressed: _navigating
                ? null
                : allComplete || noHorses
                    ? _openOverview
                    : () => _openRound(selected.config.roundId, date: today),
            style: FilledButton.styleFrom(
              backgroundColor: theme.secondary,
              foregroundColor: theme.primary,
              minimumSize: const Size.fromHeight(46),
            ),
            child: Text(allComplete ? 'Bekijk voeding' : 'Open voerronde'),
          ),
          if (!allComplete && !noHorses)
            TextButton(
              onPressed: _navigating ? null : _openOverview,
              child: const Text('Volledig voedingsoverzicht'),
            ),
        ],
      ),
    );
  }
}

class _AvarynFeedingTimeWheel extends StatefulWidget {
  const _AvarynFeedingTimeWheel({
    required this.initialTime,
    required this.title,
  });

  final DateTime initialTime;
  final String title;

  @override
  State<_AvarynFeedingTimeWheel> createState() =>
      _AvarynFeedingTimeWheelState();
}

class _AvarynFeedingTimeWheelState extends State<_AvarynFeedingTimeWheel> {
  late int _hour;
  late int _minute;
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hour;
    _minute = widget.initialTime.minute;
    _hourController = FixedExtentScrollController(initialItem: _hour);
    _minuteController = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  void _close(DateTime? result) {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: theme.secondaryBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                style: theme.titleLarge.copyWith(color: theme.primaryText),
              ),
              const SizedBox(height: 5),
              Text(
                '24-uurs tijd · ${_feedingTwo(_hour)}:${_feedingTwo(_minute)}',
                style: theme.bodySmall.copyWith(color: theme.secondaryText),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 224,
                child: Row(
                  children: [
                    Expanded(
                      child: _wheel(
                        context,
                        label: 'Uur',
                        itemCount: 24,
                        controller: _hourController,
                        selected: _hour,
                        onChanged: (value) => setState(() => _hour = value),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        ':',
                        style: theme.headlineMedium.copyWith(
                          color: theme.secondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _wheel(
                        context,
                        label: 'Minuut',
                        itemCount: 60,
                        controller: _minuteController,
                        selected: _minute,
                        onChanged: (value) => setState(() => _minute = value),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _close(null),
                      child: const Text('Annuleren'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          _close(DateTime(2000, 1, 1, _hour, _minute)),
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.secondary,
                        foregroundColor: theme.primary,
                      ),
                      child: const Text('Bevestigen'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _wheel(
    BuildContext context, {
    required String label,
    required int itemCount,
    required FixedExtentScrollController controller,
    required int selected,
    required ValueChanged<int> onChanged,
  }) {
    final theme = FlutterFlowTheme.of(context);
    return Semantics(
      label: '$label kiezen',
      value: _feedingTwo(selected),
      child: Column(
        children: [
          Text(
            label,
            style: theme.labelSmall.copyWith(color: theme.secondaryText),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: theme.accent2,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: theme.secondary),
                  ),
                ),
                ListWheelScrollView.useDelegate(
                  controller: controller,
                  itemExtent: 44,
                  diameterRatio: 1.65,
                  perspective: 0.0025,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: onChanged,
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: itemCount,
                    builder: (context, index) => InkWell(
                      onTap: () {
                        controller.jumpToItem(index);
                        onChanged(index);
                      },
                      child: Center(
                        child: Text(
                          _feedingTwo(index),
                          style: theme.titleLarge.copyWith(
                            color: index == selected
                                ? theme.primaryText
                                : theme.secondaryText,
                            fontWeight: index == selected
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResponsiblePickerSheet extends StatefulWidget {
  const _ResponsiblePickerSheet({
    required this.initialUserId,
    required this.currentUserId,
    required this.allowUseDefault,
  });

  final String initialUserId;
  final String currentUserId;
  final bool allowUseDefault;

  @override
  State<_ResponsiblePickerSheet> createState() =>
      _ResponsiblePickerSheetState();
}

class _ResponsiblePickerSheetState extends State<_ResponsiblePickerSheet> {
  late String _choice;

  @override
  void initState() {
    super.initState();
    _choice = widget.initialUserId == widget.currentUserId
        ? widget.currentUserId
        : '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
        decoration: BoxDecoration(
          color: theme.secondaryBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Standaard verantwoordelijk',
              style: theme.titleLarge.copyWith(color: theme.primaryText),
            ),
            const SizedBox(height: 12),
            RadioListTile<String>(
              value: widget.currentUserId,
              groupValue: _choice,
              onChanged: (value) => setState(() => _choice = value ?? ''),
              title: const Text('Huidige lokaal geregistreerde gebruiker'),
              subtitle: const Text('Actief'),
            ),
            RadioListTile<String>(
              value: '',
              groupValue: _choice,
              onChanged: (value) => setState(() => _choice = value ?? ''),
              title: const Text('Nog niemand toegewezen'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Annuleren'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_choice),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.secondary,
                      foregroundColor: theme.primary,
                    ),
                    child: const Text('Bevestigen'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignmentExceptionSheet extends StatefulWidget {
  const _AssignmentExceptionSheet({
    required this.roundLabel,
    required this.dateLabel,
    required this.currentUserId,
    required this.existing,
  });

  final String roundLabel;
  final String dateLabel;
  final String currentUserId;
  final FeedingAssignmentExceptionDataStruct? existing;

  @override
  State<_AssignmentExceptionSheet> createState() =>
      _AssignmentExceptionSheetState();
}

class _AssignmentExceptionSheetState extends State<_AssignmentExceptionSheet> {
  late String _mode;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _mode = widget.existing == null
        ? 'default'
        : widget.existing!.explicitlyUnassigned
            ? 'unassigned'
            : 'current';
    _noteController = TextEditingController(text: widget.existing?.note ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          decoration: BoxDecoration(
            color: theme.secondaryBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${widget.roundLabel} · ${widget.dateLabel}',
                  style: theme.titleLarge.copyWith(color: theme.primaryText),
                ),
                const SizedBox(height: 12),
                RadioListTile<String>(
                  value: 'default',
                  groupValue: _mode,
                  onChanged: (value) => setState(() => _mode = value!),
                  title: const Text('Standaard gebruiken'),
                  subtitle: const Text('Verwijdert de datumafwijking'),
                ),
                RadioListTile<String>(
                  value: 'current',
                  groupValue: _mode,
                  onChanged: (value) => setState(() => _mode = value!),
                  title: const Text('Huidige lokaal geregistreerde gebruiker'),
                  subtitle: const Text('Actief'),
                ),
                RadioListTile<String>(
                  value: 'unassigned',
                  groupValue: _mode,
                  onChanged: (value) => setState(() => _mode = value!),
                  title: const Text('Nog niemand toegewezen'),
                  subtitle: const Text('Expliciet voor deze datum'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notitie, optioneel',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Annuleren'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(
                          _ExceptionDraft(
                            mode: _mode,
                            userId: widget.currentUserId,
                            note: _noteController.text,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.secondary,
                          foregroundColor: theme.primary,
                        ),
                        child: const Text('Opslaan'),
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
  }
}

class _DeviationSheet extends StatefulWidget {
  const _DeviationSheet();

  @override
  State<_DeviationSheet> createState() => _DeviationSheetState();
}

class _DeviationSheetState extends State<_DeviationSheet> {
  static const _types = <String>[
    'Voer geweigerd',
    'Product niet beschikbaar',
    'Niet alles opgegeten',
    'Verkeerde hoeveelheid beschikbaar',
    'Anders',
  ];

  String _type = '';
  String? _error;
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    final note = _noteController.text.trim();
    if (_type.isEmpty) {
      setState(() => _error = 'Kies een type afwijking.');
      return;
    }
    if (_type == 'Anders' && note.length < 3) {
      setState(
        () => _error = 'Voeg bij Anders een korte, betekenisvolle notitie toe.',
      );
      return;
    }
    Navigator.of(context).pop(_DeviationDraft(_type, note));
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          decoration: BoxDecoration(
            color: theme.secondaryBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Afwijking melden',
                  style: theme.titleLarge.copyWith(color: theme.primaryText),
                ),
                const SizedBox(height: 12),
                ..._types.map(
                  (type) => RadioListTile<String>(
                    value: type,
                    groupValue: _type,
                    onChanged: (value) => setState(() {
                      _type = value ?? '';
                      _error = null;
                    }),
                    title: Text(type),
                  ),
                ),
                TextField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notitie',
                    hintText: 'Optionele toelichting',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: theme.bodySmall.copyWith(color: theme.error),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Annuleren'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.secondary,
                          foregroundColor: theme.primary,
                        ),
                        child: const Text('Opslaan'),
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
  }
}

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
import 'package:provider/provider.dart';

const _nutritionRounds = <(String, String)>[
  ('morning', 'Ochtend'),
  ('afternoon', 'Middag'),
  ('evening', 'Avond'),
];

const _nutritionCategories = <(String, String, IconData)>[
  ('feed', 'Voer', Icons.grass_outlined),
  ('hay', 'Hooi', Icons.eco_outlined),
  ('supplements', 'Supplementen', Icons.science_outlined),
  ('medication', 'Medicatie', Icons.medication_outlined),
];

const _nutritionUnits = <(String, String)>[
  ('gram', 'Gram'),
  ('kilogram', 'Kilogram'),
  ('milliliter', 'Milliliter'),
  ('liter', 'Liter'),
  ('schep', 'Schep'),
  ('maatbeker', 'Maatbeker'),
  ('tablet', 'Tablet'),
  ('hand', 'Hand'),
  ('stuk', 'Stuk'),
  ('custom', 'Anders'),
];

DateTime _nutritionDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool _nutritionSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _nutritionRoundLabel(String id) => _nutritionRounds
    .firstWhere((entry) => entry.$1 == id, orElse: () => (id, id))
    .$2;

String _nutritionCategoryLabel(String id) => _nutritionCategories
    .firstWhere(
      (entry) => entry.$1 == id,
      orElse: () => (id, id, Icons.circle_outlined),
    )
    .$2;

FeedingItemDataStruct _nutritionCopyItem(FeedingItemDataStruct item) =>
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

FeedingRoundSnapshotDataStruct _nutritionCopyRound(
  FeedingRoundSnapshotDataStruct round,
) =>
    FeedingRoundSnapshotDataStruct(
      roundId: round.roundId,
      items: round.items.map(_nutritionCopyItem).toList(),
    );

String _nutritionDateLabel(DateTime? value) {
  if (value == null) return 'Datum kiezen';
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
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}

String _nutritionRangeLabel(DateTime? start, DateTime? end) {
  if (start == null || end == null) return 'Datumbereik instellen';
  if (_nutritionSameDay(start, end)) return _nutritionDateLabel(start);
  return '${_nutritionDateLabel(start)} – ${_nutritionDateLabel(end)}';
}

String _nutritionMonthLabel(DateTime value) {
  const months = <String>[
    'Januari',
    'Februari',
    'Maart',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Augustus',
    'September',
    'Oktober',
    'November',
    'December',
  ];
  return '${months[value.month - 1]} ${value.year}';
}

List<DateTime> _nutritionVisibleDays(DateTime month) {
  final first = DateTime(month.year, month.month);
  final last = DateTime(month.year, month.month + 1, 0);
  final leading = first.weekday - 1;
  final used = leading + last.day;
  final count = ((used + 6) ~/ 7) * 7;
  final start = first.subtract(Duration(days: leading));
  return List<DateTime>.generate(
    count,
    (index) => start.add(Duration(days: index)),
  );
}

class AvarynHorseNutritionRuntime extends StatefulWidget {
  const AvarynHorseNutritionRuntime({
    super.key,
    this.width,
    this.height,
  });

  final double? width;
  final double? height;

  @override
  State<AvarynHorseNutritionRuntime> createState() =>
      _AvarynHorseNutritionRuntimeState();
}

class _AvarynHorseNutritionRuntimeState
    extends State<AvarynHorseNutritionRuntime> {
  String _section = 'standard';
  bool _modalOpen = false;
  bool _saving = false;

  HorseProfileDataStruct get _horse => FFAppState().selectedHorse;

  String get _stableId {
    final horseStable = _horse.stableId.trim();
    if (horseStable.isNotEmpty) return horseStable;
    final selectedStable = FFAppState().currentLocalStableId.trim();
    return selectedStable.isEmpty ? 'local-stable' : selectedStable;
  }

  String get _horseName {
    if (_horse.callName.trim().isNotEmpty) return _horse.callName.trim();
    if (_horse.officialName.trim().isNotEmpty) {
      return _horse.officialName.trim();
    }
    return 'Onbekend paard';
  }

  HorseFeedingPlanDataStruct? get _plan {
    for (final plan in FFAppState().horseFeedingPlans) {
      if (plan.horseId == _horse.id && plan.stableId == _stableId) return plan;
    }
    return null;
  }

  List<FeedingRoundSnapshotDataStruct> get _standardRounds {
    final stored = _plan?.rounds ?? const <FeedingRoundSnapshotDataStruct>[];
    return _nutritionRounds.map((definition) {
      for (final round in stored) {
        if (round.roundId == definition.$1) return _nutritionCopyRound(round);
      }
      return FeedingRoundSnapshotDataStruct(
        roundId: definition.$1,
        items: const <FeedingItemDataStruct>[],
      );
    }).toList();
  }

  List<TemporaryFeedingScheduleDataStruct> get _temporarySchedules {
    final result = FFAppState()
        .temporaryFeedingSchedules
        .where(
          (item) => item.horseId == _horse.id && item.stableId == _stableId,
        )
        .toList();
    result.sort(_compareTemporary);
    return result;
  }

  int _compareTemporary(
    TemporaryFeedingScheduleDataStruct a,
    TemporaryFeedingScheduleDataStruct b,
  ) {
    final today = _nutritionDay(DateTime.now());
    int rank(TemporaryFeedingScheduleDataStruct item) {
      final start =
          item.startDate == null ? null : _nutritionDay(item.startDate!);
      final end = item.endDate == null ? null : _nutritionDay(item.endDate!);
      if (start != null &&
          end != null &&
          !today.isBefore(start) &&
          !today.isAfter(end)) {
        return 0;
      }
      if (start != null && today.isBefore(start)) return 1;
      return 2;
    }

    final rankOrder = rank(a).compareTo(rank(b));
    if (rankOrder != 0) return rankOrder;
    final aStart = a.startDate ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bStart = b.startDate ?? DateTime.fromMillisecondsSinceEpoch(0);
    return rank(a) == 2 ? bStart.compareTo(aStart) : aStart.compareTo(bStart);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final theme = FlutterFlowTheme.of(context);
    final temporary = _temporarySchedules;
    final active = temporary.where(_isActive).toList();

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ColoredBox(
        color: theme.primaryBackground,
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(theme),
              if (active.isNotEmpty) _activeBanner(theme, active.first),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                child: _sectionSwitch(theme),
              ),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 48),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 960),
                      child: _section == 'standard'
                          ? _standardContent(theme)
                          : _temporaryContent(theme, temporary),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(FlutterFlowTheme theme) => Container(
        color: theme.primary,
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Terug naar paardprofiel',
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back),
                  color: theme.accent1,
                ),
                const SizedBox(width: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AvarynHorseAvatar(
                    width: 54,
                    height: 54,
                    photoState: _horse.photoData,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VOEDING',
                        style: theme.labelSmall.copyWith(
                          color: theme.secondary,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _horseName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.titleLarge.copyWith(
                          color: theme.accent1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'A V A R Y N',
                  style: theme.labelSmall.copyWith(
                    color: theme.accent1,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _sectionSwitch(FlutterFlowTheme theme) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: theme.accent2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.alternate, width: 0.8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _segment(
                    theme,
                    'standard',
                    'Standaard schema',
                    Icons.restaurant_outlined,
                  ),
                ),
                Expanded(
                  child: _segment(
                    theme,
                    'temporary',
                    'Tijdelijke schema’s',
                    Icons.date_range_outlined,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _segment(
    FlutterFlowTheme theme,
    String value,
    String label,
    IconData icon,
  ) {
    final selected = _section == value;
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: () => setState(() => _section = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? theme.secondaryBackground : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: theme.primaryText.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? theme.secondary : theme.secondaryText,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.labelMedium.copyWith(
                  color: selected ? theme.primaryText : theme.secondaryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activeBanner(
    FlutterFlowTheme theme,
    TemporaryFeedingScheduleDataStruct schedule,
  ) =>
      InkWell(
        onTap: () async {
          setState(() => _section = 'temporary');
          await _openTemporaryEditor(schedule);
        },
        child: Container(
          color: theme.info,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Row(
                children: [
                  Icon(Icons.schedule, color: theme.accent1, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tijdelijk schema actief t/m '
                      '${_nutritionDateLabel(schedule.endDate)} · '
                      '${schedule.affectedRoundIds.map(_nutritionRoundLabel).join(', ')}',
                      style: theme.bodyMedium.copyWith(
                        color: theme.accent1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward, color: theme.accent1, size: 20),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _standardContent(FlutterFlowTheme theme) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Standaard schema',
            style: theme.headlineSmall.copyWith(
              color: theme.primaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Het vaste voedingsschema voor $_horseName. '
            'Wijzigingen worden direct lokaal bewaard.',
            style: theme.bodyMedium.copyWith(color: theme.secondaryText),
          ),
          const SizedBox(height: 18),
          ..._standardRounds.map(
            (round) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _standardRoundCard(theme, round),
            ),
          ),
        ],
      );

  Widget _standardRoundCard(
    FlutterFlowTheme theme,
    FeedingRoundSnapshotDataStruct round,
  ) =>
      Container(
        decoration: BoxDecoration(
          color: theme.secondaryBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.alternate, width: 0.8),
        ),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: theme.secondary,
          collapsedIconColor: theme.secondaryText,
          title: Text(
            _nutritionRoundLabel(round.roundId),
            style: theme.titleLarge.copyWith(
              color: theme.primaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            round.items.isEmpty
                ? 'Nog niets ingesteld'
                : '${round.items.length} ${round.items.length == 1 ? 'item' : 'items'}',
            style: theme.bodySmall.copyWith(color: theme.secondaryText),
          ),
          children: _nutritionCategories
              .map(
                (category) => _categorySection(
                  theme,
                  round,
                  category,
                ),
              )
              .toList(),
        ),
      );

  Widget _categorySection(
    FlutterFlowTheme theme,
    FeedingRoundSnapshotDataStruct round,
    (String, String, IconData) category,
  ) {
    final items = round.items
        .where((item) => item.categoryId == category.$1)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(category.$3, size: 18, color: theme.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category.$2,
                  style: theme.titleSmall.copyWith(
                    color: theme.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: '${category.$2} toevoegen',
                onPressed: () =>
                    _openStandardItemEditor(round.roundId, category.$1),
                icon: const Icon(Icons.add_circle_outline),
                color: theme.secondary,
              ),
            ],
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 2, 0, 4),
              child: Text(
                'Nog niets ingesteld',
                style: theme.bodySmall.copyWith(color: theme.secondaryText),
              ),
            )
          else
            ...items.map(
              (item) => _feedingItemRow(
                theme,
                item,
                onTap: () => _openStandardItemEditor(
                  round.roundId,
                  category.$1,
                  existing: item,
                ),
                onDelete: () => _deleteStandardItem(round.roundId, item),
              ),
            ),
        ],
      ),
    );
  }

  Widget _feedingItemRow(
    FlutterFlowTheme theme,
    FeedingItemDataStruct item, {
    required VoidCallback onTap,
    required VoidCallback onDelete,
  }) =>
      Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        decoration: BoxDecoration(
          color: theme.accent2,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name.trim().isEmpty ? 'Naam ontbreekt' : item.name,
                      style: theme.bodyMedium.copyWith(
                        color: theme.primaryText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _itemSummary(item),
                      style: theme.bodySmall.copyWith(
                        color: theme.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Verwijderen',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              color: theme.error,
            ),
          ],
        ),
      );

  String _itemSummary(FeedingItemDataStruct item) {
    final quantity = item.quantityMode == 'unlimited'
        ? 'Onbeperkt / vrije toegang'
        : '${_quantityLabel(item.quantity)} ${_unitLabel(item)}';
    final instruction = item.instruction.trim();
    return instruction.isEmpty ? quantity : '$quantity · $instruction';
  }

  String _quantityLabel(double value) {
    final fixed =
        value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
    return fixed
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '')
        .replaceAll('.', ',');
  }

  String _unitLabel(FeedingItemDataStruct item) {
    if (item.unitId == 'custom') return item.customUnitLabel.trim();
    switch (item.unitId) {
      case 'gram':
        return 'g';
      case 'kilogram':
        return 'kg';
      case 'milliliter':
        return 'ml';
      case 'liter':
        return 'l';
      case 'schep':
        return item.quantity == 1 ? 'schep' : 'scheppen';
      case 'maatbeker':
        return item.quantity == 1 ? 'maatbeker' : 'maatbekers';
      case 'tablet':
        return item.quantity == 1 ? 'tablet' : 'tabletten';
      case 'hand':
        return 'hand';
      case 'stuk':
        return item.quantity == 1 ? 'stuk' : 'stuks';
      default:
        return item.unitId;
    }
  }

  Future<void> _openStandardItemEditor(
    String roundId,
    String categoryId, {
    FeedingItemDataStruct? existing,
  }) async {
    if (_modalOpen || _saving) return;
    setState(() => _modalOpen = true);
    try {
      final result = await _showFeedingItemEditor(
        context,
        roundId: roundId,
        categoryId: categoryId,
        existing: existing,
        proposedId:
            existing?.id ?? 'feed-item-${FFAppState().nextFeedingItemId}',
      );
      if (!mounted || result == null) return;
      setState(() => _saving = true);
      final rounds = _standardRounds;
      final roundIndex = rounds.indexWhere((round) => round.roundId == roundId);
      final items = List<FeedingItemDataStruct>.from(rounds[roundIndex].items);
      final itemIndex = items.indexWhere((item) => item.id == result.id);
      if (itemIndex >= 0) {
        items[itemIndex] = result;
      } else {
        items.add(result);
      }
      rounds[roundIndex] = FeedingRoundSnapshotDataStruct(
        roundId: roundId,
        items: items,
      );
      _persistPlan(rounds, incrementItemId: existing == null);
    } finally {
      if (mounted) {
        setState(() {
          _modalOpen = false;
          _saving = false;
        });
      }
    }
  }

  void _persistPlan(
    List<FeedingRoundSnapshotDataStruct> rounds, {
    bool incrementItemId = false,
  }) {
    final state = FFAppState();
    final next = HorseFeedingPlanDataStruct(
      id: _plan?.id.isNotEmpty == true
          ? _plan!.id
          : 'feeding-plan-$_stableId-${_horse.id}',
      stableId: _stableId,
      horseId: _horse.id,
      rounds: rounds.map(_nutritionCopyRound).toList(),
      schemaVersion: 1,
      updatedAt: DateTime.now(),
    );
    final all = List<HorseFeedingPlanDataStruct>.from(state.horseFeedingPlans);
    final index = all.indexWhere(
      (item) => item.horseId == _horse.id && item.stableId == _stableId,
    );
    if (index >= 0) {
      all[index] = next;
    } else {
      all.add(next);
    }
    state.update(() {
      state.horseFeedingPlans = all;
      if (incrementItemId) {
        state.nextFeedingItemId = state.nextFeedingItemId + 1;
      }
    });
  }

  Future<void> _deleteStandardItem(
    String roundId,
    FeedingItemDataStruct item,
  ) async {
    if (_modalOpen || _saving) return;
    setState(() => _modalOpen = true);
    try {
      final confirmed = await _confirm(
        context,
        title: 'Item verwijderen?',
        message: '${item.name} wordt uit het standaard schema verwijderd.',
        confirmLabel: 'Verwijderen',
      );
      if (!confirmed || !mounted) return;
      final rounds = _standardRounds;
      final roundIndex = rounds.indexWhere((round) => round.roundId == roundId);
      final items = rounds[roundIndex]
          .items
          .where((candidate) => candidate.id != item.id)
          .toList();
      rounds[roundIndex] = FeedingRoundSnapshotDataStruct(
        roundId: roundId,
        items: items,
      );
      _persistPlan(rounds);
    } finally {
      if (mounted) setState(() => _modalOpen = false);
    }
  }

  Widget _temporaryContent(
    FlutterFlowTheme theme,
    List<TemporaryFeedingScheduleDataStruct> schedules,
  ) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tijdelijke schema’s',
                      style: theme.headlineSmall.copyWith(
                        color: theme.primaryText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Maak een zelfstandige kopie voor één of meer voerbeurten.',
                      style:
                          theme.bodyMedium.copyWith(color: theme.secondaryText),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _modalOpen ? null : () => _openTemporaryEditor(null),
                icon: const Icon(Icons.add, size: 19),
                label: const Text('Toevoegen'),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.secondary,
                  foregroundColor: theme.primaryBackground,
                  minimumSize: const Size(0, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (schedules.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.secondaryBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.alternate, width: 0.8),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.date_range_outlined,
                    size: 32,
                    color: theme.secondary,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Nog geen tijdelijke schema’s',
                    style: theme.titleMedium.copyWith(
                      color: theme.primaryText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Het standaard schema blijft van toepassing.',
                    textAlign: TextAlign.center,
                    style:
                        theme.bodyMedium.copyWith(color: theme.secondaryText),
                  ),
                ],
              ),
            )
          else
            ...schedules.map(
              (schedule) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _temporaryCard(theme, schedule),
              ),
            ),
        ],
      );

  Widget _temporaryCard(
    FlutterFlowTheme theme,
    TemporaryFeedingScheduleDataStruct schedule,
  ) {
    final status = _status(schedule);
    final statusColor = status == 'Actief'
        ? theme.success
        : status == 'Aankomend'
            ? theme.secondary
            : theme.secondaryText;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: theme.alternate, width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: theme.accent2,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(Icons.event_note_outlined, color: theme.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () => _openTemporaryEditor(schedule),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        _nutritionRangeLabel(
                          schedule.startDate,
                          schedule.endDate,
                        ),
                        style: theme.titleSmall.copyWith(
                          color: theme.primaryText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          status,
                          style: theme.labelSmall.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    schedule.affectedRoundIds
                        .map(_nutritionRoundLabel)
                        .join(' · '),
                    style:
                        theme.bodyMedium.copyWith(color: theme.secondaryText),
                  ),
                  if (schedule.reason.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      schedule.reason.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          theme.bodySmall.copyWith(color: theme.secondaryText),
                    ),
                  ],
                ],
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Schema-acties',
            color: theme.secondaryBackground,
            onSelected: (value) {
              if (value == 'edit') _openTemporaryEditor(schedule);
              if (value == 'delete') _deleteTemporary(schedule);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Bewerken')),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Verwijderen',
                  style: TextStyle(color: theme.error),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isActive(TemporaryFeedingScheduleDataStruct schedule) {
    if (schedule.startDate == null || schedule.endDate == null) return false;
    final today = _nutritionDay(DateTime.now());
    final start = _nutritionDay(schedule.startDate!);
    final end = _nutritionDay(schedule.endDate!);
    return !today.isBefore(start) && !today.isAfter(end);
  }

  String _status(TemporaryFeedingScheduleDataStruct schedule) {
    if (_isActive(schedule)) return 'Actief';
    if (schedule.startDate != null &&
        _nutritionDay(DateTime.now())
            .isBefore(_nutritionDay(schedule.startDate!))) {
      return 'Aankomend';
    }
    return 'Afgelopen';
  }

  Future<void> _openTemporaryEditor(
    TemporaryFeedingScheduleDataStruct? existing,
  ) async {
    if (_modalOpen || _saving) return;
    setState(() => _modalOpen = true);
    try {
      final result =
          await showModalBottomSheet<TemporaryFeedingScheduleDataStruct>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _TemporaryScheduleEditor(
          stableId: _stableId,
          horseId: _horse.id,
          standardRounds: _standardRounds,
          allSchedules: List<TemporaryFeedingScheduleDataStruct>.from(
            FFAppState().temporaryFeedingSchedules,
          ),
          existing: existing,
        ),
      );
      if (!mounted || result == null) return;
      setState(() => _saving = true);
      final state = FFAppState();
      final all = List<TemporaryFeedingScheduleDataStruct>.from(
        state.temporaryFeedingSchedules,
      );
      final index = all.indexWhere((item) => item.id == result.id);
      if (index >= 0) {
        all[index] = result;
      } else {
        all.add(result);
      }
      state.update(() {
        state.temporaryFeedingSchedules = all;
        if (existing == null) {
          state.nextTemporaryFeedingScheduleId =
              state.nextTemporaryFeedingScheduleId + 1;
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _modalOpen = false;
          _saving = false;
        });
      }
    }
  }

  Future<void> _deleteTemporary(
    TemporaryFeedingScheduleDataStruct schedule,
  ) async {
    if (_modalOpen || _saving) return;
    setState(() => _modalOpen = true);
    try {
      final confirmed = await _confirm(
        context,
        title: 'Tijdelijk schema verwijderen?',
        message: 'Het standaard schema van $_horseName blijft ongewijzigd.',
        confirmLabel: 'Verwijderen',
      );
      if (!confirmed || !mounted) return;
      final remaining = FFAppState()
          .temporaryFeedingSchedules
          .where((item) => item.id != schedule.id)
          .toList();
      FFAppState().update(
        () => FFAppState().temporaryFeedingSchedules = remaining,
      );
    } finally {
      if (mounted) setState(() => _modalOpen = false);
    }
  }
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final theme = FlutterFlowTheme.of(context);
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: theme.secondaryBackground,
          title: Text(title, style: TextStyle(color: theme.primaryText)),
          content: Text(message, style: TextStyle(color: theme.secondaryText)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuleren'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: theme.error,
                foregroundColor: theme.primaryBackground,
              ),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;
}

Future<FeedingItemDataStruct?> _showFeedingItemEditor(
  BuildContext context, {
  required String roundId,
  required String categoryId,
  required String proposedId,
  FeedingItemDataStruct? existing,
}) =>
    showModalBottomSheet<FeedingItemDataStruct>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FeedingItemEditor(
        roundId: roundId,
        categoryId: categoryId,
        proposedId: proposedId,
        existing: existing,
      ),
    );

class _FeedingItemEditor extends StatefulWidget {
  const _FeedingItemEditor({
    required this.roundId,
    required this.categoryId,
    required this.proposedId,
    this.existing,
  });

  final String roundId;
  final String categoryId;
  final String proposedId;
  final FeedingItemDataStruct? existing;

  @override
  State<_FeedingItemEditor> createState() => _FeedingItemEditorState();
}

class _FeedingItemEditorState extends State<_FeedingItemEditor> {
  late final TextEditingController _name;
  late final TextEditingController _quantity;
  late final TextEditingController _customUnit;
  late final TextEditingController _instruction;
  late String _unitId;
  late bool _unlimited;
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final item = widget.existing;
    _name = TextEditingController(text: item?.name ?? '');
    _quantity = TextEditingController(
      text: item == null || item.quantity <= 0
          ? ''
          : item.quantity.toString().replaceAll('.', ','),
    );
    _customUnit = TextEditingController(text: item?.customUnitLabel ?? '');
    _instruction = TextEditingController(text: item?.instruction ?? '');
    _unitId = item?.unitId.isNotEmpty == true ? item!.unitId : 'kilogram';
    _unlimited = item?.quantityMode == 'unlimited';
  }

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _customUnit.dispose();
    _instruction.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Material(
          color: theme.secondaryBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.existing == null
                                  ? 'Voedingsitem toevoegen'
                                  : 'Voedingsitem bewerken',
                              style: theme.headlineSmall.copyWith(
                                color: theme.primaryText,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Sluiten',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                            color: theme.secondaryText,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _editorChip(
                              theme, _nutritionRoundLabel(widget.roundId)),
                          _editorChip(
                            theme,
                            _nutritionCategoryLabel(widget.categoryId),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _field(
                        theme,
                        controller: _name,
                        label: 'Naam *',
                        hint: 'Bijvoorbeeld Sport Mix',
                      ),
                      if (widget.categoryId == 'hay') ...[
                        const SizedBox(height: 12),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Onbeperkt / vrije toegang',
                            style: theme.bodyMedium.copyWith(
                              color: theme.primaryText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          value: _unlimited,
                          activeColor: theme.secondary,
                          onChanged: (value) =>
                              setState(() => _unlimited = value),
                        ),
                      ],
                      if (!_unlimited) ...[
                        const SizedBox(height: 12),
                        _field(
                          theme,
                          controller: _quantity,
                          label: 'Hoeveelheid *',
                          hint: 'Bijvoorbeeld 1,5',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _unitId,
                          dropdownColor: theme.secondaryBackground,
                          decoration: _inputDecoration(theme, 'Eenheid *'),
                          style: theme.bodyMedium
                              .copyWith(color: theme.primaryText),
                          items: _nutritionUnits
                              .map(
                                (unit) => DropdownMenuItem(
                                  value: unit.$1,
                                  child: Text(unit.$2),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _unitId = value ?? ''),
                        ),
                        if (_unitId == 'custom') ...[
                          const SizedBox(height: 12),
                          _field(
                            theme,
                            controller: _customUnit,
                            label: 'Eigen eenheid *',
                            hint: 'Bijvoorbeeld portie',
                          ),
                        ],
                      ],
                      const SizedBox(height: 12),
                      _field(
                        theme,
                        controller: _instruction,
                        label: 'Instructie',
                        hint: 'Optioneel, bijvoorbeeld: Nat maken',
                        maxLines: 3,
                      ),
                      if (widget.categoryId == 'medication') ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.accent2,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 19,
                                color: theme.secondary,
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  'AVARYN registreert alleen het ingestelde '
                                  'schema en geeft geen medisch advies.',
                                  style: theme.bodySmall.copyWith(
                                    color: theme.secondaryText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _error!,
                          style: theme.bodySmall.copyWith(
                            color: theme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(
                  color: theme.secondaryBackground,
                  border: Border(top: BorderSide(color: theme.alternate)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Annuleren'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _submitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.secondary,
                          foregroundColor: theme.primaryBackground,
                        ),
                        child: Text(
                          _submitting ? 'Opslaan…' : 'Opslaan',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _editorChip(FlutterFlowTheme theme, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.accent2,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: theme.labelSmall.copyWith(
            color: theme.secondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  InputDecoration _inputDecoration(FlutterFlowTheme theme, String label) =>
      InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: theme.secondaryText),
        filled: true,
        fillColor: theme.primaryBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.alternate),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.alternate),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.secondary, width: 1.5),
        ),
      );

  Widget _field(
    FlutterFlowTheme theme, {
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) =>
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: theme.bodyMedium.copyWith(color: theme.primaryText),
        decoration: _inputDecoration(theme, label).copyWith(hintText: hint),
      );

  void _submit() {
    if (_submitting) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Vul een naam in.');
      return;
    }
    double quantity = 0;
    if (!_unlimited) {
      quantity =
          double.tryParse(_quantity.text.trim().replaceAll(',', '.')) ?? 0;
      if (quantity <= 0) {
        setState(
          () => _error = 'Vul een hoeveelheid in die groter is dan nul.',
        );
        return;
      }
      if (_unitId.trim().isEmpty) {
        setState(() => _error = 'Kies een eenheid.');
        return;
      }
      if (_unitId == 'custom' && _customUnit.text.trim().isEmpty) {
        setState(() => _error = 'Vul een eigen eenheid in.');
        return;
      }
    }
    if (_unlimited && widget.categoryId != 'hay') {
      setState(
        () => _error =
            'Onbeperkt / vrije toegang kan alleen voor Hooi worden gebruikt.',
      );
      return;
    }
    setState(() => _submitting = true);
    Navigator.of(context).pop(
      FeedingItemDataStruct(
        id: widget.existing?.id ?? widget.proposedId,
        categoryId: widget.categoryId,
        name: name,
        quantity: quantity,
        quantityMode: _unlimited ? 'unlimited' : 'measured',
        unitId: _unlimited ? '' : _unitId,
        customUnitLabel:
            _unlimited || _unitId != 'custom' ? '' : _customUnit.text.trim(),
        instruction: _instruction.text.trim(),
        linkedProductId: widget.existing?.linkedProductId ?? '',
        sortOrder:
            widget.existing?.sortOrder ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

class _TemporaryScheduleEditor extends StatefulWidget {
  const _TemporaryScheduleEditor({
    required this.stableId,
    required this.horseId,
    required this.standardRounds,
    required this.allSchedules,
    this.existing,
  });

  final String stableId;
  final int horseId;
  final List<FeedingRoundSnapshotDataStruct> standardRounds;
  final List<TemporaryFeedingScheduleDataStruct> allSchedules;
  final TemporaryFeedingScheduleDataStruct? existing;

  @override
  State<_TemporaryScheduleEditor> createState() =>
      _TemporaryScheduleEditorState();
}

class _TemporaryScheduleEditorState extends State<_TemporaryScheduleEditor> {
  DateTime? _startDate;
  DateTime? _endDate;
  late DateTime _displayedMonth;
  String _rangeStep = 'start';
  final Set<String> _selectedRounds = <String>{};
  final Map<String, FeedingRoundSnapshotDataStruct> _rounds = {};
  late final TextEditingController _reason;
  late final TextEditingController _note;
  String? _error;
  bool _saving = false;
  bool _emptyConfirmation = false;
  bool _itemEditorOpen = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _startDate = existing?.startDate == null
        ? null
        : _nutritionDay(existing!.startDate!);
    _endDate =
        existing?.endDate == null ? null : _nutritionDay(existing!.endDate!);
    _displayedMonth = DateTime(
      (_startDate ?? DateTime.now()).year,
      (_startDate ?? DateTime.now()).month,
    );
    _selectedRounds.addAll(existing?.affectedRoundIds ?? const <String>[]);
    for (final round in existing?.roundSnapshots ??
        const <FeedingRoundSnapshotDataStruct>[]) {
      _rounds[round.roundId] = _nutritionCopyRound(round);
    }
    _reason = TextEditingController(text: existing?.reason ?? '');
    _note = TextEditingController(text: existing?.note ?? '');
  }

  @override
  void dispose() {
    _reason.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Material(
      color: theme.secondaryBackground,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.94,
        ),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.existing == null
                                ? 'Tijdelijk schema toevoegen'
                                : 'Tijdelijk schema bewerken',
                            style: theme.headlineSmall.copyWith(
                              color: theme.primaryText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Sluiten zonder opslaan',
                          onPressed: _saving
                              ? null
                              : () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                          color: theme.secondaryText,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _dateEndpointButtons(theme),
                    const SizedBox(height: 12),
                    _calendar(theme),
                    const SizedBox(height: 18),
                    Text(
                      'Voerbeurten *',
                      style: theme.titleSmall.copyWith(
                        color: theme.primaryText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _nutritionRounds
                          .map((round) => _roundChoice(theme, round))
                          .toList(),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _reason,
                      style:
                          theme.bodyMedium.copyWith(color: theme.primaryText),
                      decoration: _tempInput(theme, 'Reden', 'Optioneel'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _note,
                      maxLines: 3,
                      style:
                          theme.bodyMedium.copyWith(color: theme.primaryText),
                      decoration:
                          _tempInput(theme, 'Notitie', 'Optionele toelichting'),
                    ),
                    if (_selectedRounds.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      Text(
                        'Tijdelijke inhoud',
                        style: theme.titleLarge.copyWith(
                          color: theme.primaryText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Dit is een zelfstandige kopie. Latere wijzigingen aan '
                        'het standaard schema veranderen deze periode niet.',
                        style: theme.bodySmall
                            .copyWith(color: theme.secondaryText),
                      ),
                      const SizedBox(height: 12),
                      ..._nutritionRounds
                          .where((entry) => _selectedRounds.contains(entry.$1))
                          .map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _temporaryRoundEditor(theme, entry.$1),
                            ),
                          ),
                    ],
                    if (_emptyConfirmation) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: theme.accent3,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: theme.secondary),
                        ),
                        child: Text(
                          'Voor deze ronde staat tijdelijk geen voeding '
                          'ingesteld. Weet je zeker dat dit klopt?',
                          style: theme.bodyMedium.copyWith(
                            color: theme.primaryText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.error.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _error!,
                          style: theme.bodySmall.copyWith(
                            color: theme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              decoration: BoxDecoration(
                color: theme.secondaryBackground,
                border: Border(top: BorderSide(color: theme.alternate)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Annuleren'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.secondary,
                        foregroundColor: theme.primaryBackground,
                      ),
                      child: Text(
                        _emptyConfirmation
                            ? 'Toch opslaan'
                            : _saving
                                ? 'Opslaan…'
                                : 'Schema opslaan',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateEndpointButtons(FlutterFlowTheme theme) => Row(
        children: [
          Expanded(
            child: _dateEndpoint(
              theme,
              'start',
              'Datum van',
              _nutritionDateLabel(_startDate),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _dateEndpoint(
              theme,
              'end',
              'Tot en met',
              _nutritionDateLabel(_endDate),
            ),
          ),
        ],
      );

  Widget _dateEndpoint(
    FlutterFlowTheme theme,
    String value,
    String label,
    String date,
  ) {
    final selected = _rangeStep == value;
    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: () => setState(() => _rangeStep = value),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: selected ? theme.accent2 : theme.primaryBackground,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected ? theme.secondary : theme.alternate,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.labelSmall.copyWith(
                color: selected ? theme.secondary : theme.secondaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              date,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.bodySmall.copyWith(color: theme.primaryText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _calendar(FlutterFlowTheme theme) {
    final days = _nutritionVisibleDays(_displayedMonth);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.primaryBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.alternate),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Vorige maand',
                onPressed: () => setState(
                  () => _displayedMonth = DateTime(
                    _displayedMonth.year,
                    _displayedMonth.month - 1,
                  ),
                ),
                icon: const Icon(Icons.chevron_left),
                color: theme.secondary,
              ),
              Expanded(
                child: Text(
                  _nutritionMonthLabel(_displayedMonth),
                  textAlign: TextAlign.center,
                  style: theme.titleMedium.copyWith(
                    color: theme.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Volgende maand',
                onPressed: () => setState(
                  () => _displayedMonth = DateTime(
                    _displayedMonth.year,
                    _displayedMonth.month + 1,
                  ),
                ),
                icon: const Icon(Icons.chevron_right),
                color: theme.secondary,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: const ['Ma', 'Di', 'Wo', 'Do', 'Vr', 'Za', 'Zo']
                .map(
                  (label) => Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 40,
            ),
            itemBuilder: (context, index) => _dayCell(theme, days[index]),
          ),
        ],
      ),
    );
  }

  Widget _dayCell(FlutterFlowTheme theme, DateTime day) {
    final outside = day.month != _displayedMonth.month;
    final selectedStart =
        _startDate != null && _nutritionSameDay(day, _startDate!);
    final selectedEnd = _endDate != null && _nutritionSameDay(day, _endDate!);
    final inside = _startDate != null &&
        _endDate != null &&
        day.isAfter(_startDate!) &&
        day.isBefore(_endDate!);
    final selected = selectedStart || selectedEnd;
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: () => _selectDay(day),
      child: Container(
        margin: const EdgeInsets.all(2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? theme.secondary
              : inside
                  ? theme.accent3
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          '${day.day}',
          style: theme.bodySmall.copyWith(
            color: selected
                ? theme.primaryBackground
                : outside
                    ? theme.secondaryText.withOpacity(0.55)
                    : theme.primaryText,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _selectDay(DateTime raw) {
    final day = _nutritionDay(raw);
    setState(() {
      _error = null;
      _emptyConfirmation = false;
      if (_rangeStep == 'start') {
        _startDate = day;
        if (_endDate != null && _endDate!.isBefore(day)) _endDate = null;
        _rangeStep = 'end';
      } else {
        if (_startDate == null) {
          _startDate = day;
          _rangeStep = 'end';
        } else if (day.isBefore(_startDate!)) {
          _error = 'Tot en met mag niet vóór Datum van liggen.';
        } else {
          _endDate = day;
        }
      }
      if (day.month != _displayedMonth.month ||
          day.year != _displayedMonth.year) {
        _displayedMonth = DateTime(day.year, day.month);
      }
    });
  }

  Widget _roundChoice(FlutterFlowTheme theme, (String, String) round) {
    final selected = _selectedRounds.contains(round.$1);
    return FilterChip(
      selected: selected,
      label: Text(round.$2),
      avatar: Icon(
        selected ? Icons.check : Icons.add,
        size: 17,
        color: selected ? theme.primaryBackground : theme.secondary,
      ),
      selectedColor: theme.secondary,
      backgroundColor: theme.accent2,
      checkmarkColor: theme.primaryBackground,
      labelStyle: theme.labelMedium.copyWith(
        color: selected ? theme.primaryBackground : theme.primaryText,
        fontWeight: FontWeight.w700,
      ),
      onSelected: (value) => _toggleRound(round.$1, value),
    );
  }

  void _toggleRound(String roundId, bool selected) {
    setState(() {
      _error = null;
      _emptyConfirmation = false;
      if (selected) {
        _selectedRounds.add(roundId);
        if (!_rounds.containsKey(roundId)) {
          final source = widget.standardRounds.firstWhere(
            (round) => round.roundId == roundId,
            orElse: () => FeedingRoundSnapshotDataStruct(
              roundId: roundId,
              items: const <FeedingItemDataStruct>[],
            ),
          );
          _rounds[roundId] = _nutritionCopyRound(source);
        }
      } else {
        _selectedRounds.remove(roundId);
        _rounds.remove(roundId);
      }
    });
  }

  Widget _temporaryRoundEditor(FlutterFlowTheme theme, String roundId) {
    final round = _rounds[roundId] ??
        FeedingRoundSnapshotDataStruct(
          roundId: roundId,
          items: const <FeedingItemDataStruct>[],
        );
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: theme.primaryBackground,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: theme.alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _nutritionRoundLabel(roundId),
            style: theme.titleMedium.copyWith(
              color: theme.primaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (round.items.isEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Tijdelijk geen voeding ingesteld.',
              style: theme.bodySmall.copyWith(color: theme.secondaryText),
            ),
          ],
          ..._nutritionCategories.map((category) {
            final items = round.items
                .where((item) => item.categoryId == category.$1)
                .toList();
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(category.$3, size: 17, color: theme.secondary),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          category.$2,
                          style: theme.labelMedium.copyWith(
                            color: theme.primaryText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '${category.$2} toevoegen',
                        onPressed: _itemEditorOpen
                            ? null
                            : () => _editTemporaryItem(
                                  roundId,
                                  category.$1,
                                  null,
                                ),
                        icon: const Icon(Icons.add),
                        color: theme.secondary,
                      ),
                    ],
                  ),
                  if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 24),
                      child: Text(
                        'Nog niets ingesteld',
                        style: theme.bodySmall
                            .copyWith(color: theme.secondaryText),
                      ),
                    )
                  else
                    ...items.map(
                      (item) => ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.only(left: 20),
                        title: Text(
                          item.name,
                          style: theme.bodyMedium.copyWith(
                            color: theme.primaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: item.instruction.trim().isEmpty
                            ? null
                            : Text(
                                item.instruction,
                                style: TextStyle(color: theme.secondaryText),
                              ),
                        onTap: _itemEditorOpen
                            ? null
                            : () => _editTemporaryItem(
                                  roundId,
                                  category.$1,
                                  item,
                                ),
                        trailing: IconButton(
                          tooltip: 'Verwijderen',
                          onPressed: () =>
                              _removeTemporaryItem(roundId, item.id),
                          icon: const Icon(Icons.delete_outline),
                          color: theme.error,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _editTemporaryItem(
    String roundId,
    String categoryId,
    FeedingItemDataStruct? existing,
  ) async {
    if (_itemEditorOpen || _saving) return;
    setState(() => _itemEditorOpen = true);
    try {
      final result = await _showFeedingItemEditor(
        context,
        roundId: roundId,
        categoryId: categoryId,
        existing: existing,
        proposedId: existing?.id ??
            'feed-item-temp-${DateTime.now().microsecondsSinceEpoch}',
      );
      if (!mounted || result == null) return;
      final round = _rounds[roundId]!;
      final items = List<FeedingItemDataStruct>.from(round.items);
      final index = items.indexWhere((item) => item.id == result.id);
      if (index >= 0) {
        items[index] = result;
      } else {
        items.add(result);
      }
      setState(() {
        _rounds[roundId] = FeedingRoundSnapshotDataStruct(
          roundId: roundId,
          items: items,
        );
        _emptyConfirmation = false;
      });
    } finally {
      if (mounted) setState(() => _itemEditorOpen = false);
    }
  }

  void _removeTemporaryItem(String roundId, String itemId) {
    final round = _rounds[roundId]!;
    setState(() {
      _rounds[roundId] = FeedingRoundSnapshotDataStruct(
        roundId: roundId,
        items: round.items.where((item) => item.id != itemId).toList(),
      );
      _emptyConfirmation = false;
    });
  }

  InputDecoration _tempInput(
    FlutterFlowTheme theme,
    String label,
    String hint,
  ) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: theme.secondaryText),
        filled: true,
        fillColor: theme.primaryBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.alternate),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.alternate),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.secondary, width: 1.5),
        ),
      );

  void _submit() {
    if (_saving) return;
    if (_startDate == null) {
      setState(() => _error = 'Kies Datum van.');
      return;
    }
    if (_endDate == null) {
      setState(() => _error = 'Kies Tot en met.');
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      setState(() => _error = 'Tot en met mag niet vóór Datum van liggen.');
      return;
    }
    if (_selectedRounds.isEmpty) {
      setState(() => _error = 'Kies minimaal één voerbeurt.');
      return;
    }
    final conflict = _findConflict();
    if (conflict != null) {
      setState(() => _error = conflict);
      return;
    }
    final hasEmpty = _selectedRounds.any(
      (roundId) => (_rounds[roundId]?.items ?? const []).isEmpty,
    );
    if (hasEmpty && !_emptyConfirmation) {
      setState(() {
        _emptyConfirmation = true;
        _error = null;
      });
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    final id = widget.existing?.id.isNotEmpty == true
        ? widget.existing!.id
        : 'temporary-feeding-${FFAppState().nextTemporaryFeedingScheduleId}';
    final orderedRounds = _nutritionRounds
        .where((definition) => _selectedRounds.contains(definition.$1))
        .map((definition) => _nutritionCopyRound(_rounds[definition.$1]!))
        .toList();
    Navigator.of(context).pop(
      TemporaryFeedingScheduleDataStruct(
        id: id,
        stableId: widget.stableId,
        horseId: widget.horseId,
        startDate: _nutritionDay(_startDate!),
        endDate: _nutritionDay(_endDate!),
        affectedRoundIds: _nutritionRounds
            .where((entry) => _selectedRounds.contains(entry.$1))
            .map((entry) => entry.$1)
            .toList(),
        roundSnapshots: orderedRounds,
        reason: _reason.text.trim(),
        note: _note.text.trim(),
        schemaVersion: 1,
        createdAt: widget.existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  String? _findConflict() {
    final start = _nutritionDay(_startDate!);
    final end = _nutritionDay(_endDate!);
    for (final schedule in widget.allSchedules) {
      if (schedule.id == widget.existing?.id) continue;
      if (schedule.horseId != widget.horseId ||
          schedule.stableId != widget.stableId ||
          schedule.startDate == null ||
          schedule.endDate == null) {
        continue;
      }
      final otherStart = _nutritionDay(schedule.startDate!);
      final otherEnd = _nutritionDay(schedule.endDate!);
      final overlapsDate =
          !end.isBefore(otherStart) && !start.isAfter(otherEnd);
      if (!overlapsDate) continue;
      final shared =
          _selectedRounds.where(schedule.affectedRoundIds.contains).toList();
      if (shared.isEmpty) continue;
      final overlapStart = start.isAfter(otherStart) ? start : otherStart;
      final overlapEnd = end.isBefore(otherEnd) ? end : otherEnd;
      return 'Dit schema conflicteert met '
          '${_nutritionRangeLabel(schedule.startDate, schedule.endDate)}. '
          'Overlapping: ${_nutritionRangeLabel(overlapStart, overlapEnd)} '
          'voor ${shared.map(_nutritionRoundLabel).join(', ')}.';
    }
    return null;
  }
}

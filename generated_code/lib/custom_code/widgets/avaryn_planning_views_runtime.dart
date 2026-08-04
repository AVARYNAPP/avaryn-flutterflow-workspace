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

class AvarynPlanningViewsRuntime extends StatefulWidget {
  const AvarynPlanningViewsRuntime({
    super.key,
    this.width,
    this.height,
  });

  final double? width;
  final double? height;

  @override
  State<AvarynPlanningViewsRuntime> createState() =>
      _AvarynPlanningViewsRuntimeState();
}

class _AvarynPlanningViewsRuntimeState
    extends State<AvarynPlanningViewsRuntime> {
  String _view = 'list';
  String _filter = 'mine';
  late DateTime _displayedMonth;
  late DateTime _selectedDate;
  bool _openingActivity = false;

  @override
  void initState() {
    super.initState();
    final today = _day(DateTime.now());
    _displayedMonth = DateTime(today.year, today.month);
    _selectedDate = today;
  }

  DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime? _startDate(ActivityDataStruct item) => item.startDate ?? item.date;

  DateTime? _endDate(ActivityDataStruct item) =>
      item.endDate ?? _startDate(item);

  DateTime? _startTime(ActivityDataStruct item) => item.startTime ?? item.time;

  bool _isCompleted(ActivityDataStruct item) =>
      item.isCompleted ||
      item.completionStatus.trim().toLowerCase() == 'completed' ||
      item.completionStatus.trim().toLowerCase() == 'voltooid';

  String _currentUserId() {
    final value = FFAppState().currentLocalUserId.trim();
    return value.isEmpty ? 'local-current-user' : value;
  }

  String _currentStableId(
    List<ActivityDataStruct> activities,
    String currentUserId,
  ) {
    for (final item in activities) {
      if (item.stableId.trim().isNotEmpty &&
          item.assigneeUserIds.contains(currentUserId)) {
        return item.stableId.trim();
      }
    }
    for (final item in activities) {
      if (item.stableId.trim().isNotEmpty) return item.stableId.trim();
    }
    return '';
  }

  List<ActivityDataStruct> _filteredActivities() {
    final source = List<ActivityDataStruct>.from(FFAppState().activities);
    final userId = _currentUserId();
    final stableId = _currentStableId(source, userId);
    final result = source.where((item) {
      final itemStableId = item.stableId.trim();
      final belongsToStable =
          stableId.isEmpty || itemStableId.isEmpty || itemStableId == stableId;
      if (!belongsToStable) return false;
      if (_filter == 'all') return true;
      // Older local prototype records predate explicit assignee IDs. They
      // remain personal records until a real stable roster is connected.
      return item.assigneeUserIds.isEmpty ||
          item.assigneeUserIds.contains(userId);
    }).toList();
    result.sort(_compareActivities);
    return result;
  }

  int _compareActivities(ActivityDataStruct a, ActivityDataStruct b) {
    final ad = _startDate(a);
    final bd = _startDate(b);
    if (ad == null && bd == null) return a.id.compareTo(b.id);
    if (ad == null) return 1;
    if (bd == null) return -1;
    final dateOrder = _day(ad).compareTo(_day(bd));
    if (dateOrder != 0) return dateOrder;
    final at = _startTime(a);
    final bt = _startTime(b);
    if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
    if (at == null && bt == null) return a.id.compareTo(b.id);
    if (at == null) return 1;
    if (bt == null) return -1;
    return (at.hour * 60 + at.minute).compareTo(bt.hour * 60 + bt.minute);
  }

  List<ActivityDataStruct> _activitiesOnDay(
    List<ActivityDataStruct> source,
    DateTime date,
  ) {
    final selected = _day(date);
    final result = source.where((item) {
      final rawStart = _startDate(item);
      if (rawStart == null) return false;
      final start = _day(rawStart);
      final end = _day(_endDate(item) ?? rawStart);
      return !selected.isBefore(start) && !selected.isAfter(end);
    }).toList();
    result.sort(_compareActivities);
    return result;
  }

  List<DateTime> _visibleDays() {
    final first = DateTime(_displayedMonth.year, _displayedMonth.month);
    final last = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0);
    final leading = first.weekday - 1;
    final used = leading + last.day;
    final count = ((used + 6) ~/ 7) * 7;
    final start = first.subtract(Duration(days: leading));
    return List<DateTime>.generate(
      count,
      (index) => start.add(Duration(days: index)),
    );
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String _timeLabel(ActivityDataStruct item) {
    if (item.allDay) return 'Hele dag';
    final value = _startTime(item);
    if (value == null) return 'Geen tijd';
    return '${_two(value.hour)}:${_two(value.minute)}';
  }

  String _activityTitle(ActivityDataStruct item) {
    if (item.customTitle.trim().isNotEmpty) return item.customTitle.trim();
    if (item.title.trim().isNotEmpty) return item.title.trim();
    if (item.activityType.trim().isNotEmpty) return item.activityType.trim();
    return 'Activiteit';
  }

  HorseProfileDataStruct? _horse(ActivityDataStruct item) {
    for (final horse in FFAppState().horses) {
      if (horse.id == item.horseId) return horse;
    }
    return null;
  }

  String _horseName(ActivityDataStruct item) {
    final horse = _horse(item);
    if (horse == null) return 'Onbekend paard';
    if (horse.callName.trim().isNotEmpty) return horse.callName.trim();
    if (horse.officialName.trim().isNotEmpty) return horse.officialName.trim();
    return 'Onbekend paard';
  }

  String _horsePhoto(ActivityDataStruct item) => _horse(item)?.photoData ?? '';

  String _assigneeLabel(ActivityDataStruct item) {
    final ids = item.assigneeUserIds;
    if (ids.isEmpty) return 'Jij';
    final includesCurrent = ids.contains(_currentUserId());
    if (includesCurrent && ids.length == 1) return 'Jij';
    if (includesCurrent) return 'Jij + ${ids.length - 1}';
    if (ids.length == 1) return '1 toegewezen persoon';
    return '${ids.length} toegewezen personen';
  }

  String _locationLabel(ActivityDataStruct item) {
    if (item.locationName.trim().isNotEmpty) return item.locationName.trim();
    return item.locationType.trim();
  }

  String _monthLabel(DateTime value) {
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

  Future<void> _openActivity(ActivityDataStruct item) async {
    if (_openingActivity) return;
    final index = FFAppState().activities.indexWhere(
          (candidate) => candidate.id == item.id,
        );
    if (index < 0) return;
    setState(() => _openingActivity = true);
    FFAppState().update(() {
      FFAppState().selectedActivityIndex = index;
      FFAppState().selectedActivity = item;
    });
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    setState(() => _openingActivity = false);
    await context.pushNamed('ActivityDetailPage');
  }

  void _changeMonth(int delta) {
    final next = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + delta,
    );
    setState(() {
      _displayedMonth = next;
      _selectedDate = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final theme = FlutterFlowTheme.of(context);
    final activities = _filteredActivities();

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                  child: _controls(theme, constraints.maxWidth),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    primary: true,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 48),
                    child: _view == 'list'
                        ? _listView(theme, activities)
                        : _agendaView(theme, activities),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _controls(FlutterFlowTheme theme, double width) {
    final viewSwitch = _segmentedControl(
      theme,
      options: const [
        ('list', 'Lijst', Icons.view_agenda_outlined),
        ('agenda', 'Agenda', Icons.calendar_month_outlined),
      ],
      selected: _view,
      onSelected: (value) => setState(() => _view = value),
    );
    final filter = _segmentedControl(
      theme,
      options: const [
        ('mine', 'Mijn taken', Icons.person_outline),
        ('all', 'Alle taken van de stal', Icons.groups_outlined),
      ],
      selected: _filter,
      onSelected: (value) => setState(() => _filter = value),
    );
    if (width < 560) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          viewSwitch,
          const SizedBox(height: 8),
          filter,
        ],
      );
    }
    return Row(
      children: [
        SizedBox(width: 238, child: viewSwitch),
        const SizedBox(width: 12),
        Expanded(child: filter),
      ],
    );
  }

  Widget _segmentedControl(
    FlutterFlowTheme theme, {
    required List<(String, String, IconData)> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) =>
      Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: theme.secondaryBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.alternate, width: 0.8),
        ),
        child: Row(
          children: options.map((option) {
            final active = option.$1 == selected;
            return Expanded(
              child: Semantics(
                button: true,
                selected: active,
                child: InkWell(
                  onTap: () => onSelected(option.$1),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 42),
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    decoration: BoxDecoration(
                      color: active ? theme.accent2 : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: active
                          ? Border.all(color: theme.secondary, width: 0.8)
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          option.$3,
                          size: 17,
                          color: active ? theme.secondary : theme.secondaryText,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            option.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.labelSmall.copyWith(
                              color: active
                                  ? theme.primaryText
                                  : theme.secondaryText,
                              fontWeight:
                                  active ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );

  Widget _listView(
    FlutterFlowTheme theme,
    List<ActivityDataStruct> activities,
  ) {
    if (activities.isEmpty) {
      return _emptyState(
        theme,
        'Geen activiteiten binnen dit takenfilter.',
      );
    }
    final children = <Widget>[];
    DateTime? previousDate;
    for (final item in activities) {
      final date = _startDate(item);
      if (date != null &&
          (previousDate == null || !_sameDay(previousDate, date))) {
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 10, 2, 2),
            child: Text(
              _dateLabel(date),
              style: theme.titleMedium,
            ),
          ),
        );
        previousDate = date;
      }
      children.add(_activityCard(theme, item, showDate: date == null));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _withSpacing(children, 10),
    );
  }

  Widget _agendaView(
    FlutterFlowTheme theme,
    List<ActivityDataStruct> activities,
  ) {
    final days = _visibleDays();
    final selectedActivities = _activitiesOnDay(activities, _selectedDate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
          decoration: BoxDecoration(
            color: theme.secondaryBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.alternate, width: 0.8),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Vorige maand',
                    onPressed: () => _changeMonth(-1),
                    icon: Icon(
                      Icons.chevron_left,
                      color: theme.secondary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _monthLabel(_displayedMonth),
                      textAlign: TextAlign.center,
                      style: theme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Volgende maand',
                    onPressed: () => _changeMonth(1),
                    icon: Icon(
                      Icons.chevron_right,
                      color: theme.secondary,
                    ),
                  ),
                ],
              ),
              const Row(
                children: [
                  _PlanningWeekday('ma'),
                  _PlanningWeekday('di'),
                  _PlanningWeekday('wo'),
                  _PlanningWeekday('do'),
                  _PlanningWeekday('vr'),
                  _PlanningWeekday('za'),
                  _PlanningWeekday('zo'),
                ],
              ),
              const SizedBox(height: 5),
              GridView.builder(
                shrinkWrap: true,
                primary: false,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: days.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  crossAxisSpacing: 3,
                  mainAxisSpacing: 3,
                  childAspectRatio: 0.9,
                ),
                itemBuilder: (context, index) => _calendarDay(
                  theme,
                  days[index],
                  _activitiesOnDay(activities, days[index]).length,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _dateLabel(_selectedDate),
          style: theme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          '${selectedActivities.length} '
          '${selectedActivities.length == 1 ? 'activiteit' : 'activiteiten'}',
          style: theme.bodySmall.copyWith(color: theme.secondaryText),
        ),
        const SizedBox(height: 10),
        if (selectedActivities.isEmpty)
          _emptyState(
            theme,
            'Geen activiteiten gepland op deze dag.',
          )
        else
          ..._withSpacing(
            selectedActivities
                .map((item) => _activityCard(theme, item))
                .toList(),
            10,
          ),
      ],
    );
  }

  Widget _calendarDay(
    FlutterFlowTheme theme,
    DateTime date,
    int count,
  ) {
    final today = _sameDay(date, DateTime.now());
    final selected = _sameDay(date, _selectedDate);
    final outside = date.month != _displayedMonth.month ||
        date.year != _displayedMonth.year;
    return Semantics(
      button: true,
      selected: selected,
      label: '${_dateLabel(date)}, $count activiteiten',
      child: InkWell(
        onTap: () => setState(() {
          _selectedDate = _day(date);
          if (outside) {
            _displayedMonth = DateTime(date.year, date.month);
          }
        }),
        borderRadius: BorderRadius.circular(9),
        child: Container(
          decoration: BoxDecoration(
            color: selected ? theme.secondary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: today
                  ? theme.secondary
                  : selected
                      ? theme.secondary
                      : Colors.transparent,
              width: today ? 1.2 : 0.8,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${date.day}',
                style: theme.labelMedium.copyWith(
                  color: selected
                      ? theme.primary
                      : outside
                          ? theme.secondaryText
                          : theme.primaryText,
                  fontWeight:
                      selected || today ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              if (count > 0)
                Container(
                  constraints: const BoxConstraints(minWidth: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected ? theme.primary : theme.accent2,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    textAlign: TextAlign.center,
                    style: theme.labelSmall.copyWith(
                      fontSize: 9,
                      height: 1.1,
                      color: selected ? theme.accent1 : theme.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _activityCard(
    FlutterFlowTheme theme,
    ActivityDataStruct item, {
    bool showDate = false,
  }) {
    final location = _locationLabel(item);
    final completed = _isCompleted(item);
    return Semantics(
      button: true,
      label: '${_activityTitle(item)}, ${_horseName(item)}',
      child: InkWell(
        onTap: _openingActivity ? null : () => _openActivity(item),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: theme.secondaryBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.alternate, width: 0.8),
            boxShadow: const [
              BoxShadow(
                blurRadius: 18,
                color: Color(0x1A171518),
                offset: Offset(0, 7),
                spreadRadius: -10,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AvarynHorseAvatar(
                      width: 42,
                      height: 42,
                      photoState: _horsePhoto(item),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _activityTitle(item),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _horseName(item),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.labelMedium.copyWith(
                            color: theme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: theme.secondaryText,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(color: theme.alternate, height: 1),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 7,
                children: [
                  _meta(theme, Icons.schedule, _timeLabel(item)),
                  _meta(theme, Icons.person_outline, _assigneeLabel(item)),
                  if (location.isNotEmpty)
                    _meta(theme, Icons.place_outlined, location),
                  if (showDate && _startDate(item) != null)
                    _meta(
                      theme,
                      Icons.calendar_today_outlined,
                      _dateLabel(_startDate(item)!),
                    ),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: theme.primaryBackground,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: theme.alternate, width: 0.7),
                    ),
                    child: Text(
                      item.activityType.trim().isEmpty
                          ? 'Activiteit'
                          : item.activityType.trim(),
                      style: theme.labelSmall.copyWith(
                        color: theme.secondaryText,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color:
                          completed ? theme.accent2 : theme.primaryBackground,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: completed ? theme.success : theme.alternate,
                        width: 0.7,
                      ),
                    ),
                    child: Text(
                      completed ? 'Voltooid' : 'Open',
                      style: theme.labelSmall.copyWith(
                        color: completed ? theme.success : theme.secondaryText,
                        fontWeight: FontWeight.w600,
                      ),
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

  Widget _meta(
    FlutterFlowTheme theme,
    IconData icon,
    String label,
  ) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: theme.secondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.bodySmall.copyWith(color: theme.secondaryText),
          ),
        ],
      );

  Widget _emptyState(FlutterFlowTheme theme, String message) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        decoration: BoxDecoration(
          color: theme.secondaryBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.alternate, width: 0.8),
        ),
        child: Column(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 28,
              color: theme.secondary,
            ),
            const SizedBox(height: 9),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.bodyMedium.copyWith(color: theme.secondaryText),
            ),
          ],
        ),
      );

  List<Widget> _withSpacing(List<Widget> widgets, double spacing) {
    final result = <Widget>[];
    for (var index = 0; index < widgets.length; index++) {
      if (index > 0) result.add(SizedBox(height: spacing));
      result.add(widgets[index]);
    }
    return result;
  }
}

class _PlanningWeekday extends StatelessWidget {
  const _PlanningWeekday(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: FlutterFlowTheme.of(context).labelSmall.copyWith(
                  color: FlutterFlowTheme.of(context).secondaryText,
                ),
          ),
        ),
      );
}

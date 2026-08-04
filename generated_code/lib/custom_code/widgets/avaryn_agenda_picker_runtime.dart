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

import 'dart:math' as math;

import 'package:flutter/material.dart';

class AvarynAgendaPickerRuntime extends StatefulWidget {
  const AvarynAgendaPickerRuntime({
    super.key,
    this.width,
    this.height,
    this.activityType,
    this.initialMode,
  });

  final double? width;
  final double? height;
  final String? activityType;
  final String? initialMode;

  @override
  State<AvarynAgendaPickerRuntime> createState() =>
      _AvarynAgendaPickerRuntimeState();
}

class _AvarynAgendaPickerRuntimeState extends State<AvarynAgendaPickerRuntime> {
  late String _mode;
  late String _timeTarget;
  late DateTime _displayedMonth;
  late DateTime _timeDraft;
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _startTime;
  DateTime? _endTime;
  bool _editingRangeEnd = false;
  bool _isClosing = false;
  String? _message;

  bool get _isRange => (widget.activityType ?? '').trim() == 'Wedstrijd';
  bool get _isAllDay => FFAppState().activityDraftAllDay;
  bool get _isDirectTime =>
      widget.initialMode == 'startTime' || widget.initialMode == 'endTime';

  @override
  void initState() {
    super.initState();
    final app = FFAppState();
    _mode = (widget.initialMode ?? 'overview').trim();
    if (_mode.isEmpty) _mode = 'overview';
    _startDate = _day(app.activityDraftStartDate);
    _endDate = _day(app.activityDraftEndDate);
    _startTime = app.activityDraftStartTime;
    _endTime = app.activityDraftEndTime;
    final focusDate = _startDate ?? DateTime.now();
    _displayedMonth = DateTime(focusDate.year, focusDate.month);
    _editingRangeEnd = _mode == 'endDate';
    _timeTarget = _mode == 'endTime' ? 'end' : 'start';
    _timeDraft = _initialTime(
      _timeTarget == 'end' ? _endTime : _startTime,
    );
    _hourController = FixedExtentScrollController(
      initialItem: _timeDraft.hour,
    );
    _minuteController = FixedExtentScrollController(
      initialItem: _timeDraft.minute,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusScope.of(context).unfocus();
    });
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  DateTime? _day(DateTime? value) =>
      value == null ? null : DateTime(value.year, value.month, value.day);

  DateTime _initialTime(DateTime? value) {
    if (value != null) return value;
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      (now.minute ~/ 5) * 5,
    );
  }

  bool _sameDay(DateTime? a, DateTime? b) =>
      a != null &&
      b != null &&
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day;

  String _dateLabel(DateTime? value) {
    if (value == null) return 'Datum onbekend';
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

  String _timeLabel(DateTime? value) {
    if (value == null) return 'Geen tijd';
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.hour)}:${two(value.minute)}';
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

  void _selectDate(DateTime selected) {
    final value = _day(selected)!;
    setState(() {
      _message = null;
      _displayedMonth = DateTime(value.year, value.month);
      if (!_isRange) {
        _startDate = value;
        _endDate = value;
        return;
      }
      if (!_editingRangeEnd) {
        _startDate = value;
        _endDate = null;
        _editingRangeEnd = true;
        return;
      }
      if (_startDate == null) {
        _startDate = value;
        _editingRangeEnd = true;
        return;
      }
      if (value.isBefore(_startDate!)) {
        _message = 'Tot en met kan niet voor Datum van liggen.';
        return;
      }
      _endDate = value;
    });
  }

  bool get _datesValid {
    if (_startDate == null) return false;
    if (!_isRange) return true;
    return _endDate != null && !_endDate!.isBefore(_startDate!);
  }

  DateTime _combine(DateTime day, DateTime time) => DateTime(
        day.year,
        day.month,
        day.day,
        time.hour,
        time.minute,
      );

  bool _timesValid({
    DateTime? start,
    DateTime? end,
    DateTime? candidate,
    String? target,
  }) {
    final nextStart = target == 'start' ? candidate : (start ?? _startTime);
    final nextEnd = target == 'end' ? candidate : (end ?? _endTime);
    if (nextStart == null || nextEnd == null) return true;
    final startDay = _startDate ?? DateTime.now();
    final endDay = _isRange ? (_endDate ?? startDay) : startDay;
    return _combine(endDay, nextEnd).isAfter(_combine(startDay, nextStart));
  }

  bool get _ready => _datesValid && _timesValid();

  void _openTime(String target) {
    setState(() {
      _message = null;
      _timeTarget = target;
      _timeDraft = _initialTime(target == 'start' ? _startTime : _endTime);
      _mode = target == 'start' ? 'startTime' : 'endTime';
    });
    _syncTimeWheels();
  }

  void _syncTimeWheels() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_hourController.hasClients) {
        _hourController.jumpToItem(_timeDraft.hour);
      }
      if (_minuteController.hasClients) {
        _minuteController.jumpToItem(_timeDraft.minute);
      }
    });
  }

  void _setTimePart({int? hour, int? minute}) {
    setState(() {
      _message = null;
      _timeDraft = DateTime(
        _timeDraft.year,
        _timeDraft.month,
        _timeDraft.day,
        hour ?? _timeDraft.hour,
        minute ?? _timeDraft.minute,
      );
    });
  }

  void _cancelTime() {
    if (_isClosing) return;
    if (_isDirectTime) {
      _isClosing = true;
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _message = null;
      _mode = 'overview';
    });
  }

  void _confirmTime() {
    if (_isClosing) return;
    if (!_timesValid(candidate: _timeDraft, target: _timeTarget)) {
      setState(() => _message = 'Eindtijd moet na Starttijd liggen.');
      return;
    }
    setState(() {
      _message = null;
      if (_timeTarget == 'start') {
        _startTime = _timeDraft;
      } else {
        _endTime = _timeDraft;
      }
    });
    FFAppState().update(() {
      if (_timeTarget == 'start') {
        FFAppState().activityDraftStartTime = _timeDraft;
      } else {
        FFAppState().activityDraftEndTime = _timeDraft;
      }
    });
    if (_isDirectTime) {
      _isClosing = true;
      Navigator.of(context).maybePop();
    } else {
      setState(() => _mode = 'overview');
    }
  }

  void _commitAgenda() {
    if (!_ready) return;
    FFAppState().update(() {
      FFAppState().activityDraftStartDate = _startDate;
      FFAppState().activityDraftEndDate = _isRange ? _endDate : _startDate;
      if (_isAllDay) {
        FFAppState().activityDraftStartTime = null;
        FFAppState().activityDraftEndTime = null;
      } else {
        FFAppState().activityDraftStartTime = _startTime;
        FFAppState().activityDraftEndTime = _endTime;
      }
    });
    Navigator.of(context).maybePop();
  }

  List<ActivityDataStruct> _plannedActivities() {
    final selected = _startDate;
    if (selected == null) return const <ActivityDataStruct>[];
    final matches = FFAppState().activities.where((item) {
      final rawStart = item.startDate ?? item.date;
      if (rawStart == null) return false;
      final start = _day(rawStart)!;
      final end = _day(item.endDate ?? rawStart)!;
      return !selected.isBefore(start) && !selected.isAfter(end);
    }).toList();
    matches.sort((a, b) {
      final at = a.startTime ?? a.time;
      final bt = b.startTime ?? b.time;
      if (at == null && bt == null) return a.id.compareTo(b.id);
      if (at == null) return 1;
      if (bt == null) return -1;
      return (at.hour * 60 + at.minute).compareTo(bt.hour * 60 + bt.minute);
    });
    return matches;
  }

  String _activityTitle(ActivityDataStruct item) {
    if (item.customTitle.trim().isNotEmpty) return item.customTitle.trim();
    if (item.activityType.trim().isNotEmpty) return item.activityType.trim();
    return item.title.trim().isEmpty ? 'Activiteit' : item.title.trim();
  }

  String _activityTime(ActivityDataStruct item) {
    if (item.allDay) return 'Hele dag';
    return _timeLabel(item.startTime ?? item.time);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final media = MediaQuery.of(context);
    final targetHeight = math.min(
      widget.height ?? media.size.height * 0.88,
      media.size.height - media.padding.top - 8,
    );
    final targetWidth = math.min(widget.width ?? media.size.width, 620.0);
    final isTimeMode = _mode == 'startTime' || _mode == 'endTime';

    return Material(
      color: theme.primaryBackground,
      child: SafeArea(
        top: false,
        child: Center(
          child: SizedBox(
            width: targetWidth,
            height: targetHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(theme, isTimeMode),
                  const SizedBox(height: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      primary: true,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: isTimeMode
                          ? _timePanel(theme)
                          : _calendarPanel(theme),
                    ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _message!,
                      style: theme.bodySmall.copyWith(color: theme.error),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (!isTimeMode) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: _ready ? _commitAgenda : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.secondary,
                          foregroundColor: theme.primary,
                          disabledBackgroundColor: theme.alternate,
                          disabledForegroundColor: theme.secondaryText,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Gereed'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(FlutterFlowTheme theme, bool isTimeMode) {
    final title = switch (_mode) {
      'date' => 'Datum kiezen',
      'endDate' => 'Tot en met kiezen',
      'startTime' => 'Starttijd instellen',
      'endTime' => 'Eindtijd instellen',
      _ => 'Agenda',
    };
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.titleLarge),
              Text(
                'Interne AVARYN-planning',
                style: theme.bodySmall.copyWith(color: theme.secondaryText),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Sluiten',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(Icons.close, color: theme.secondaryText),
        ),
      ],
    );
  }

  Widget _calendarPanel(FlutterFlowTheme theme) {
    final days = _visibleDays();
    final planned = _plannedActivities();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isRange) ...[
          Row(
            children: [
              Expanded(
                child: _endpoint(
                  theme,
                  label: 'Datum van',
                  value: _dateLabel(_startDate),
                  active: !_editingRangeEnd,
                  onTap: () => setState(() {
                    _editingRangeEnd = false;
                    _message = null;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _endpoint(
                  theme,
                  label: 'Tot en met',
                  value: _dateLabel(_endDate),
                  active: _editingRangeEnd,
                  onTap: () => setState(() {
                    _editingRangeEnd = true;
                    _message = null;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _editingRangeEnd ? 'Kies nu Tot en met' : 'Kies nu Datum van',
            style: theme.labelSmall.copyWith(color: theme.secondary),
          ),
          const SizedBox(height: 10),
        ],
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.secondaryBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.alternate, width: 0.8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Vorige maand',
                      onPressed: () => setState(() {
                        _displayedMonth = DateTime(
                          _displayedMonth.year,
                          _displayedMonth.month - 1,
                        );
                      }),
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
                      onPressed: () => setState(() {
                        _displayedMonth = DateTime(
                          _displayedMonth.year,
                          _displayedMonth.month + 1,
                        );
                      }),
                      icon: Icon(
                        Icons.chevron_right,
                        color: theme.secondary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: const [
                    _Weekday('ma'),
                    _Weekday('di'),
                    _Weekday('wo'),
                    _Weekday('do'),
                    _Weekday('vr'),
                    _Weekday('za'),
                    _Weekday('zo'),
                  ],
                ),
                const SizedBox(height: 4),
                GridView.builder(
                  shrinkWrap: true,
                  primary: false,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: days.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                    childAspectRatio: 1.15,
                  ),
                  itemBuilder: (context, index) => _dayCell(theme, days[index]),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (!_isAllDay && _mode == 'overview')
          Row(
            children: [
              Expanded(
                child: _outlineAction(
                  theme,
                  icon: Icons.schedule,
                  label: 'Starttijd ${_timeLabel(_startTime)}',
                  onTap: () => _openTime('start'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _outlineAction(
                  theme,
                  icon: Icons.more_time,
                  label: 'Eindtijd ${_timeLabel(_endTime)}',
                  onTap: () => _openTime('end'),
                ),
              ),
            ],
          ),
        const SizedBox(height: 14),
        Divider(color: theme.alternate, height: 1),
        const SizedBox(height: 14),
        Text('Gepland op geselecteerde dag', style: theme.titleMedium),
        const SizedBox(height: 4),
        Text(
          _dateLabel(_startDate),
          style: theme.bodySmall.copyWith(color: theme.secondaryText),
        ),
        const SizedBox(height: 10),
        if (planned.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(
              'Nog niets gepland op deze dag.',
              textAlign: TextAlign.center,
              style: theme.bodySmall.copyWith(color: theme.secondaryText),
            ),
          )
        else
          ...planned.take(4).map(
                (item) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: theme.secondaryBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: theme.alternate,
                      width: 0.7,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _activityTitle(item),
                          style: theme.labelMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _activityTime(item),
                        style:
                            theme.labelSmall.copyWith(color: theme.secondary),
                      ),
                    ],
                  ),
                ),
              ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _endpoint(
    FlutterFlowTheme theme, {
    required String label,
    required String value,
    required bool active,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          constraints: const BoxConstraints(minHeight: 66),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: active ? theme.accent2 : theme.secondaryBackground,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: active ? theme.secondary : theme.alternate,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.labelSmall.copyWith(color: theme.secondary),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.bodySmall,
              ),
            ],
          ),
        ),
      );

  Widget _dayCell(FlutterFlowTheme theme, DateTime day) {
    final start = _sameDay(day, _startDate);
    final end = _sameDay(day, _endDate);
    final inRange = _startDate != null &&
        _endDate != null &&
        day.isAfter(_startDate!) &&
        day.isBefore(_endDate!);
    final outside =
        day.month != _displayedMonth.month || day.year != _displayedMonth.year;
    final selected = start || end;
    return Semantics(
      button: true,
      selected: selected,
      label: _dateLabel(day),
      child: InkWell(
        onTap: () => _selectDate(day),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? theme.secondary
                : inRange
                    ? theme.accent2
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(selected ? 999 : 5),
          ),
          child: Text(
            '${day.day}',
            style: theme.bodySmall.copyWith(
              color: selected
                  ? theme.primary
                  : outside
                      ? theme.secondaryText
                      : inRange
                          ? theme.secondary
                          : theme.primaryText,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _timePanel(FlutterFlowTheme theme) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
            decoration: BoxDecoration(
              color: theme.secondaryBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.alternate, width: 0.8),
            ),
            child: Column(
              children: [
                Text(
                  _timeTarget == 'start' ? 'Starttijd' : 'Eindtijd',
                  style: theme.labelMedium.copyWith(color: theme.secondary),
                ),
                const SizedBox(height: 4),
                Text(
                  _timeLabel(_timeDraft),
                  style: theme.headlineMedium,
                  semanticsLabel: _timeTarget == 'start'
                      ? 'Geselecteerde starttijd ${_timeLabel(_timeDraft)}'
                      : 'Geselecteerde eindtijd ${_timeLabel(_timeDraft)}',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 186,
                  child: Row(
                    children: [
                      Expanded(
                        child: _timeWheel(
                          theme,
                          label: 'Uur',
                          itemCount: 24,
                          controller: _hourController,
                          selectedValue: _timeDraft.hour,
                          onChanged: (value) => _setTimePart(hour: value),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 35),
                        child: Text(
                          ':',
                          style: theme.headlineMedium.copyWith(
                            color: theme.secondary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _timeWheel(
                          theme,
                          label: 'Minuut',
                          itemCount: 60,
                          controller: _minuteController,
                          selectedValue: _timeDraft.minute,
                          onChanged: (value) => _setTimePart(minute: value),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _cancelTime,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.primaryText,
                    side: BorderSide(color: theme.alternate),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Annuleren'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _confirmTime,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.secondary,
                    foregroundColor: theme.primary,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Bevestigen'),
                ),
              ),
            ],
          ),
        ],
      );

  Widget _timeWheel(
    FlutterFlowTheme theme, {
    required String label,
    required int itemCount,
    required FixedExtentScrollController controller,
    required int selectedValue,
    required ValueChanged<int> onChanged,
  }) =>
      Semantics(
        label: '$label kiezen',
        value: selectedValue.toString().padLeft(2, '0'),
        child: Column(
          children: [
            Text(
              label,
              style: theme.labelSmall.copyWith(color: theme.secondaryText),
            ),
            const SizedBox(height: 5),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  IgnorePointer(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: theme.accent2,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: theme.secondary,
                          width: 1.1,
                        ),
                      ),
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
                      builder: (context, index) {
                        final selected = index == selectedValue;
                        final value = index.toString().padLeft(2, '0');
                        return Semantics(
                          button: true,
                          selected: selected,
                          label: '$label $value',
                          child: InkWell(
                            onTap: () => controller.animateToItem(
                              index,
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            child: Center(
                              child: Text(
                                value,
                                style: selected
                                    ? theme.titleLarge.copyWith(
                                        color: theme.primaryText,
                                        fontWeight: FontWeight.w700,
                                      )
                                    : theme.bodyMedium.copyWith(
                                        color: theme.secondaryText,
                                      ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _outlineAction(
    FlutterFlowTheme theme, {
    IconData? icon,
    required String label,
    required VoidCallback onTap,
  }) =>
      OutlinedButton.icon(
        onPressed: onTap,
        icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18),
        label: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.primaryText,
          side: BorderSide(color: theme.alternate),
          minimumSize: const Size.fromHeight(44),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9),
          ),
        ),
      );
}

class _Weekday extends StatelessWidget {
  const _Weekday(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: FlutterFlowTheme.of(context).labelSmall.copyWith(
                color: FlutterFlowTheme.of(context).secondaryText,
              ),
        ),
      );
}

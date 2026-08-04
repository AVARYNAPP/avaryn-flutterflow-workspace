import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'avaryn_agenda_picker_sheet_model.dart';
export 'avaryn_agenda_picker_sheet_model.dart';

/// Reusable constrained AVARYN calendar, date-range, time and daily-agenda
/// picker.
class AvarynAgendaPickerSheetWidget extends StatefulWidget {
  const AvarynAgendaPickerSheetWidget({
    super.key,
    this.activityType,
    String? initialMode,
  }) : this.initialMode = initialMode ?? 'overview';

  final String? activityType;

  /// Initial agenda mode: overview, date, endDate, startTime or endTime.
  final String initialMode;

  @override
  State<AvarynAgendaPickerSheetWidget> createState() =>
      _AvarynAgendaPickerSheetWidgetState();
}

class _AvarynAgendaPickerSheetWidgetState
    extends State<AvarynAgendaPickerSheetWidget> {
  late AvarynAgendaPickerSheetModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AvarynAgendaPickerSheetModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: custom_widgets.AvarynAgendaPickerRuntime(
        activityType: widget!.activityType,
        initialMode: widget!.initialMode,
      ),
    );
  }
}

import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'avaryn_agenda_picker_sheet_widget.dart'
    show AvarynAgendaPickerSheetWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class AvarynAgendaPickerSheetModel
    extends FlutterFlowModel<AvarynAgendaPickerSheetWidget> {
  ///  Local state fields for this component.

  String? agendaMode = 'overview';

  String? agendaRangeStep = 'start';

  DateTime? agendaDraftStartDate;

  DateTime? agendaDraftEndDate;

  DateTime? agendaDraftStartTime;

  DateTime? agendaDraftEndTime;

  DateTime? agendaDisplayedMonth;

  String? agendaTimeTarget = 'start';

  DateTime? agendaTimeDraft;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}

import '/backend/schema/structs/index.dart';
import '/components/activity_assignee_picker_sheet_widget.dart';
import '/components/activity_conflict_sheet_widget.dart';
import '/components/activity_discard_sheet_v2_widget.dart';
import '/components/activity_horse_picker_sheet_v2_widget.dart';
import '/components/activity_type_change_sheet_widget.dart';
import '/components/avaryn_agenda_picker_sheet_widget.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:ui';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import 'activity_form_page_widget.dart' show ActivityFormPageWidget;
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ActivityFormPageModel extends FlutterFlowModel<ActivityFormPageWidget> {
  ///  Local state fields for this page.

  String? formActivityType = '';

  DateTime? formDate;

  DateTime? formTime;

  String? formDateDay = '';

  String? formDateMonth = '';

  String? formDateYear = '';

  bool? hasChanges = false;

  bool? isSaving = false;

  bool? showTypeError = false;

  bool? showHorseError = false;

  bool? showTitleError = false;

  bool? showDateError = false;

  String? formValidationMessage = '';

  String? formDurationChoice = '';

  bool? agendaOpening = false;

  ///  State fields for stateful widgets in this page.

  // State field(s) for ActivityFormPrimaryScroll widget.
  ScrollController? activityFormPrimaryScrollScrollController;
  // State field(s) for ActivityTypeDropdown widget.
  String? activityTypeDropdownValue;
  FormFieldController<String>? activityTypeDropdownValueController;
  // State field(s) for ActivityTrainingLocationChoice widget.
  String? activityTrainingLocationChoiceValue;
  FormFieldController<String>? activityTrainingLocationChoiceValueController;
  // State field(s) for ActivityTrainingLocationField widget.
  FocusNode? activityTrainingLocationFieldFocusNode;
  TextEditingController? activityTrainingLocationFieldTextController;
  String? Function(BuildContext, String?)?
      activityTrainingLocationFieldTextControllerValidator;
  // State field(s) for ActivityProviderField widget.
  FocusNode? activityProviderFieldFocusNode;
  TextEditingController? activityProviderFieldTextController;
  String? Function(BuildContext, String?)?
      activityProviderFieldTextControllerValidator;
  // State field(s) for ActivityCompetitionLocationField widget.
  FocusNode? activityCompetitionLocationFieldFocusNode;
  TextEditingController? activityCompetitionLocationFieldTextController;
  String? Function(BuildContext, String?)?
      activityCompetitionLocationFieldTextControllerValidator;
  // State field(s) for ActivityCustomTitleField widget.
  FocusNode? activityCustomTitleFieldFocusNode;
  TextEditingController? activityCustomTitleFieldTextController;
  String? Function(BuildContext, String?)?
      activityCustomTitleFieldTextControllerValidator;
  // State field(s) for Toggle widget.
  bool? toggleValue;
  // State field(s) for ActivityDurationDropdown widget.
  String? activityDurationDropdownValue;
  FormFieldController<String>? activityDurationDropdownValueController;
  // State field(s) for ActivityCustomDurationField widget.
  FocusNode? activityCustomDurationFieldFocusNode;
  TextEditingController? activityCustomDurationFieldTextController;
  String? Function(BuildContext, String?)?
      activityCustomDurationFieldTextControllerValidator;
  // State field(s) for ActivityOtherLocationField widget.
  FocusNode? activityOtherLocationFieldFocusNode;
  TextEditingController? activityOtherLocationFieldTextController;
  String? Function(BuildContext, String?)?
      activityOtherLocationFieldTextControllerValidator;
  // State field(s) for ActivityNotesFieldV2 widget.
  FocusNode? activityNotesFieldV2FocusNode;
  TextEditingController? activityNotesFieldV2TextController;
  String? Function(BuildContext, String?)?
      activityNotesFieldV2TextControllerValidator;

  @override
  void initState(BuildContext context) {
    activityFormPrimaryScrollScrollController = ScrollController();
  }

  @override
  void dispose() {
    activityFormPrimaryScrollScrollController?.dispose();
    activityTrainingLocationFieldFocusNode?.dispose();
    activityTrainingLocationFieldTextController?.dispose();

    activityProviderFieldFocusNode?.dispose();
    activityProviderFieldTextController?.dispose();

    activityCompetitionLocationFieldFocusNode?.dispose();
    activityCompetitionLocationFieldTextController?.dispose();

    activityCustomTitleFieldFocusNode?.dispose();
    activityCustomTitleFieldTextController?.dispose();

    activityCustomDurationFieldFocusNode?.dispose();
    activityCustomDurationFieldTextController?.dispose();

    activityOtherLocationFieldFocusNode?.dispose();
    activityOtherLocationFieldTextController?.dispose();

    activityNotesFieldV2FocusNode?.dispose();
    activityNotesFieldV2TextController?.dispose();
  }
}

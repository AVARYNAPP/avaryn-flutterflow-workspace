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
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'activity_form_page_model.dart';
export 'activity_form_page_model.dart';

/// One reusable responsive form for adding and editing a local activity.
class ActivityFormPageWidget extends StatefulWidget {
  const ActivityFormPageWidget({
    super.key,
    this.editMode,
  });

  final bool? editMode;

  static String routeName = 'ActivityFormPage';
  static String routePath = '/planning/activiteit';

  @override
  State<ActivityFormPageWidget> createState() => _ActivityFormPageWidgetState();
}

class _ActivityFormPageWidgetState extends State<ActivityFormPageWidget> {
  late ActivityFormPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ActivityFormPageModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _model.isSaving = false;
      safeSetState(() {});
      _model.formValidationMessage = '';
      safeSetState(() {});
      FFAppState().activitySaveInProgress = false;
      safeSetState(() {});
      if (widget!.editMode!) {
        FFAppState().activityDraftPendingType =
            FFAppState().selectedActivity.activityType;
        safeSetState(() {});
        FFAppState().activityDraftHorseId =
            FFAppState().selectedActivity.horseId;
        safeSetState(() {});
        FFAppState().activityDraftAssigneeUserIds = functions
            .activityEffectiveAssigneeIdsV2(
                FFAppState().selectedActivity, FFAppState().currentLocalUserId)!
            .toList()
            .cast<String>();
        safeSetState(() {});
        FFAppState().activityDraftStartDate = functions
            .activityEffectiveStartDateV2(FFAppState().selectedActivity);
        safeSetState(() {});
        FFAppState().activityDraftEndDate =
            functions.activityEffectiveEndDateV2(FFAppState().selectedActivity);
        safeSetState(() {});
        FFAppState().activityDraftStartTime = functions
            .activityEffectiveStartTimeV2(FFAppState().selectedActivity);
        safeSetState(() {});
        FFAppState().activityDraftEndTime =
            FFAppState().selectedActivity.endTime;
        safeSetState(() {});
        FFAppState().activityDraftAllDay = FFAppState().selectedActivity.allDay;
        safeSetState(() {});
        FFAppState().activityDraftDurationMinutes =
            FFAppState().selectedActivity.durationMinutes;
        safeSetState(() {});
        FFAppState().activityDraftLocationType =
            FFAppState().selectedActivity.locationType;
        safeSetState(() {});
        _model.formDurationChoice =
            functions.activityDurationChoiceForMinutesV2(
                FFAppState().selectedActivity.durationMinutes);
        safeSetState(() {});
        safeSetState(() {
          _model.activityCustomDurationFieldTextController?.text =
              functions.activityDurationCustomTextV2(
                  FFAppState().selectedActivity.durationMinutes)!;
        });
        safeSetState(() {
          _model.activityCustomTitleFieldTextController?.text = functions
              .activityEffectiveCustomTitleV2(FFAppState().selectedActivity)!;
        });
        safeSetState(() {
          _model.activityTrainingLocationFieldTextController?.text =
              FFAppState().selectedActivity.locationName;
        });
        safeSetState(() {
          _model.activityCompetitionLocationFieldTextController?.text =
              FFAppState().selectedActivity.locationName;
        });
        safeSetState(() {
          _model.activityOtherLocationFieldTextController?.text =
              FFAppState().selectedActivity.locationName;
        });
        safeSetState(() {
          _model.activityProviderFieldTextController?.text =
              FFAppState().selectedActivity.serviceProviderName;
        });
        safeSetState(() {
          _model.activityNotesFieldV2TextController?.text =
              FFAppState().selectedActivity.notes;
        });
        _model.hasChanges = false;
        safeSetState(() {});
      } else {
        FFAppState().activityDraftPendingType = '';
        safeSetState(() {});
        FFAppState().activityDraftHorseId = 0;
        safeSetState(() {});
        FFAppState().activityDraftAssigneeUserIds = functions
            .defaultAssigneeIdsV2(FFAppState().currentLocalUserId)!
            .toList()
            .cast<String>();
        safeSetState(() {});
        FFAppState().activityDraftStartDate = null;
        safeSetState(() {});
        FFAppState().activityDraftEndDate = null;
        safeSetState(() {});
        FFAppState().activityDraftStartTime = null;
        safeSetState(() {});
        FFAppState().activityDraftEndTime = null;
        safeSetState(() {});
        FFAppState().activityDraftAllDay = false;
        safeSetState(() {});
        FFAppState().activityDraftDurationMinutes = 0;
        safeSetState(() {});
        FFAppState().activityDraftLocationType = '';
        safeSetState(() {});
        _model.formDurationChoice = '';
        safeSetState(() {});
        safeSetState(() {
          _model.activityCustomDurationFieldTextController?.text = '';
        });
        safeSetState(() {
          _model.activityCustomTitleFieldTextController?.text = '';
        });
        safeSetState(() {
          _model.activityTrainingLocationFieldTextController?.text = '';
        });
        safeSetState(() {
          _model.activityCompetitionLocationFieldTextController?.text = '';
        });
        safeSetState(() {
          _model.activityOtherLocationFieldTextController?.text = '';
        });
        safeSetState(() {
          _model.activityProviderFieldTextController?.text = '';
        });
        safeSetState(() {
          _model.activityNotesFieldV2TextController?.text = '';
        });
        _model.hasChanges = false;
        safeSetState(() {});
      }
    });

    _model.activityTrainingLocationFieldTextController ??=
        TextEditingController();
    _model.activityTrainingLocationFieldFocusNode ??= FocusNode();

    _model.activityProviderFieldTextController ??= TextEditingController();
    _model.activityProviderFieldFocusNode ??= FocusNode();

    _model.activityCompetitionLocationFieldTextController ??=
        TextEditingController();
    _model.activityCompetitionLocationFieldFocusNode ??= FocusNode();

    _model.activityCustomTitleFieldTextController ??= TextEditingController();
    _model.activityCustomTitleFieldFocusNode ??= FocusNode();

    _model.toggleValue = FFAppState().activityDraftAllDay;
    _model.activityCustomDurationFieldTextController ??=
        TextEditingController();
    _model.activityCustomDurationFieldFocusNode ??= FocusNode();

    _model.activityOtherLocationFieldTextController ??= TextEditingController();
    _model.activityOtherLocationFieldFocusNode ??= FocusNode();

    _model.activityNotesFieldV2TextController ??= TextEditingController();
    _model.activityNotesFieldV2FocusNode ??= FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: SafeArea(
          top: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).primary,
                ),
                child: Padding(
                  padding:
                      EdgeInsetsDirectional.fromSTEB(12.0, 16.0, 18.0, 14.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      FlutterFlowIconButton(
                        buttonSize: 40.0,
                        icon: Icon(
                          Icons.arrow_back,
                          color: FlutterFlowTheme.of(context).accent1,
                          size: 23.0,
                        ),
                        onPressed: () async {
                          if (_model.hasChanges!) {
                            await showModalBottomSheet(
                              isScrollControlled: true,
                              context: context,
                              builder: (context) {
                                return GestureDetector(
                                  onTap: () {
                                    FocusScope.of(context).unfocus();
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                  },
                                  child: Padding(
                                    padding: MediaQuery.viewInsetsOf(context),
                                    child: ActivityDiscardSheetV2Widget(),
                                  ),
                                );
                              },
                            ).then((value) => safeSetState(() {}));
                          } else {
                            context.pop();
                          }
                        },
                      ),
                      Expanded(
                        flex: 1,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PLANNING',
                              style: FlutterFlowTheme.of(context)
                                  .labelSmall
                                  .override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .labelSmall
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .labelSmall
                                          .fontStyle,
                                    ),
                                    color:
                                        FlutterFlowTheme.of(context).secondary,
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .labelSmall
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .labelSmall
                                        .fontStyle,
                                  ),
                            ),
                            if (!widget!.editMode!)
                              Text(
                                'Activiteit toevoegen',
                                maxLines: 1,
                                style: FlutterFlowTheme.of(context)
                                    .titleLarge
                                    .override(
                                      font: GoogleFonts.interTight(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .titleLarge
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleLarge
                                            .fontStyle,
                                      ),
                                      color:
                                          FlutterFlowTheme.of(context).accent1,
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .titleLarge
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleLarge
                                          .fontStyle,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (widget!.editMode ?? true)
                              Text(
                                'Activiteit bewerken',
                                maxLines: 1,
                                style: FlutterFlowTheme.of(context)
                                    .titleLarge
                                    .override(
                                      font: GoogleFonts.interTight(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .titleLarge
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleLarge
                                            .fontStyle,
                                      ),
                                      color:
                                          FlutterFlowTheme.of(context).accent1,
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .titleLarge
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleLarge
                                          .fontStyle,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ].divide(SizedBox(height: 2.0)),
                        ),
                      ),
                    ].divide(SizedBox(width: 8.0)),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: SingleChildScrollView(
                  controller: _model.activityFormPrimaryScrollScrollController,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        child: Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              18.0, 22.0, 18.0, 120.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          'Paard',
                                          maxLines: 2,
                                          style: FlutterFlowTheme.of(context)
                                              .labelMedium
                                              .override(
                                                font: GoogleFonts.inter(
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelMedium
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelMedium
                                                          .fontStyle,
                                                ),
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                                letterSpacing: 0.0,
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .labelMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .labelMedium
                                                        .fontStyle,
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        'Verplicht',
                                        style: FlutterFlowTheme.of(context)
                                            .labelSmall
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .labelSmall
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .labelSmall
                                                        .fontStyle,
                                              ),
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondary,
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .labelSmall
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelSmall
                                                      .fontStyle,
                                            ),
                                      ),
                                    ].divide(SizedBox(width: 12.0)),
                                  ),
                                  InkWell(
                                    splashColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    hoverColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    onTap: () async {
                                      _model.formValidationMessage = '';
                                      safeSetState(() {});
                                      _model.hasChanges = true;
                                      safeSetState(() {});
                                      await showModalBottomSheet(
                                        isScrollControlled: true,
                                        context: context,
                                        builder: (context) {
                                          return GestureDetector(
                                            onTap: () {
                                              FocusScope.of(context).unfocus();
                                              FocusManager.instance.primaryFocus
                                                  ?.unfocus();
                                            },
                                            child: Padding(
                                              padding: MediaQuery.viewInsetsOf(
                                                  context),
                                              child:
                                                  ActivityHorsePickerSheetV2Widget(),
                                            ),
                                          );
                                        },
                                      ).then((value) => safeSetState(() {}));
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryBackground,
                                        borderRadius:
                                            BorderRadius.circular(10.0),
                                        border: Border.all(
                                          color: FlutterFlowTheme.of(context)
                                              .alternate,
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            14.0, 13.0, 14.0, 13.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 36.0,
                                              height: 36.0,
                                              decoration: BoxDecoration(
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .accent2,
                                                borderRadius:
                                                    BorderRadius.circular(9.0),
                                              ),
                                              child: Container(
                                                child: custom_widgets
                                                    .AvarynHorseAvatar(
                                                  photoState:
                                                      functions.activityHorsePhoto(
                                                          FFAppState()
                                                              .horses
                                                              .toList(),
                                                          FFAppState()
                                                              .activityDraftHorseId),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 1,
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.start,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  if (FFAppState()
                                                          .activityDraftHorseId ==
                                                      0)
                                                    Text(
                                                      'Selecteer een paard',
                                                      style:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .override(
                                                                font:
                                                                    GoogleFonts
                                                                        .inter(
                                                                  fontWeight: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontWeight,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontStyle,
                                                                ),
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .secondaryText,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontWeight,
                                                                fontStyle: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontStyle,
                                                              ),
                                                    ),
                                                  if (!(FFAppState()
                                                          .activityDraftHorseId ==
                                                      0))
                                                    Text(
                                                      functions.activityHorseName(
                                                          FFAppState()
                                                              .horses
                                                              .toList(),
                                                          FFAppState()
                                                              .activityDraftHorseId)!,
                                                      maxLines: 1,
                                                      style:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .override(
                                                                font:
                                                                    GoogleFonts
                                                                        .inter(
                                                                  fontWeight: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontWeight,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontStyle,
                                                                ),
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .primaryText,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontWeight,
                                                                fontStyle: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontStyle,
                                                              ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                ].divide(SizedBox(height: 2.0)),
                                              ),
                                            ),
                                            Icon(
                                              Icons.keyboard_arrow_down,
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryText,
                                              size: 21.0,
                                            ),
                                          ].divide(SizedBox(width: 11.0)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ].divide(SizedBox(height: 8.0)),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          'Type activiteit',
                                          maxLines: 2,
                                          style: FlutterFlowTheme.of(context)
                                              .labelMedium
                                              .override(
                                                font: GoogleFonts.inter(
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelMedium
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelMedium
                                                          .fontStyle,
                                                ),
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                                letterSpacing: 0.0,
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .labelMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .labelMedium
                                                        .fontStyle,
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        'Verplicht',
                                        style: FlutterFlowTheme.of(context)
                                            .labelSmall
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .labelSmall
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .labelSmall
                                                        .fontStyle,
                                              ),
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondary,
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .labelSmall
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelSmall
                                                      .fontStyle,
                                            ),
                                      ),
                                    ].divide(SizedBox(width: 12.0)),
                                  ),
                                  FlutterFlowDropDown<String>(
                                    controller: _model
                                            .activityTypeDropdownValueController ??=
                                        FormFieldController<String>(
                                      _model.activityTypeDropdownValue ??=
                                          FFAppState().activityDraftPendingType,
                                    ),
                                    options: [
                                      'Training',
                                      'Verzorging',
                                      'Hoefsmid',
                                      'Dierenarts',
                                      'Wedstrijd',
                                      'Overig'
                                    ],
                                    onChanged: (val) async {
                                      safeSetState(() => _model
                                          .activityTypeDropdownValue = val);
                                      _model.formValidationMessage = '';
                                      safeSetState(() {});
                                      if (FFAppState()
                                              .activityDraftPendingType ==
                                          '') {
                                        FFAppState().activityDraftPendingType =
                                            _model.activityTypeDropdownValue!;
                                        safeSetState(() {});
                                        _model.hasChanges = true;
                                        safeSetState(() {});
                                      } else {
                                        await showModalBottomSheet(
                                          isScrollControlled: true,
                                          context: context,
                                          builder: (context) {
                                            return GestureDetector(
                                              onTap: () {
                                                FocusScope.of(context)
                                                    .unfocus();
                                                FocusManager
                                                    .instance.primaryFocus
                                                    ?.unfocus();
                                              },
                                              child: Padding(
                                                padding:
                                                    MediaQuery.viewInsetsOf(
                                                        context),
                                                child:
                                                    ActivityTypeChangeSheetWidget(
                                                  nextType: _model
                                                      .activityTypeDropdownValue,
                                                ),
                                              ),
                                            );
                                          },
                                        ).then((value) => safeSetState(() {}));
                                      }
                                    },
                                    textStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          font: GoogleFonts.inter(
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                          letterSpacing: 0.0,
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                    hintText: 'Selecteer een type',
                                    icon: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                      size: 24.0,
                                    ),
                                    fillColor: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                    elevation: 2.0,
                                    borderColor:
                                        FlutterFlowTheme.of(context).alternate,
                                    borderWidth: 1.0,
                                    borderRadius: 8.0,
                                    margin: EdgeInsetsDirectional.fromSTEB(
                                        12.0, 0.0, 12.0, 0.0),
                                    hidesUnderline: true,
                                    isOverButton: false,
                                    isSearchable: false,
                                    isMultiSelect: false,
                                    labelText: 'Type activiteit',
                                    labelTextStyle: TextStyle(),
                                  ),
                                ].divide(SizedBox(height: 8.0)),
                              ),
                              if (FFAppState().activityDraftPendingType ==
                                  'Training')
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            'Locatiekeuze',
                                            maxLines: 2,
                                            style: FlutterFlowTheme.of(context)
                                                .labelMedium
                                                .override(
                                                  font: GoogleFonts.inter(
                                                    fontWeight:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .labelMedium
                                                            .fontWeight,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .labelMedium
                                                            .fontStyle,
                                                  ),
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primaryText,
                                                  letterSpacing: 0.0,
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelMedium
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelMedium
                                                          .fontStyle,
                                                ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          'Verplicht',
                                          style: FlutterFlowTheme.of(context)
                                              .labelSmall
                                              .override(
                                                font: GoogleFonts.inter(
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelSmall
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelSmall
                                                          .fontStyle,
                                                ),
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondary,
                                                letterSpacing: 0.0,
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .labelSmall
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .labelSmall
                                                        .fontStyle,
                                              ),
                                        ),
                                      ].divide(SizedBox(width: 12.0)),
                                    ),
                                    FlutterFlowDropDown<String>(
                                      controller: _model
                                              .activityTrainingLocationChoiceValueController ??=
                                          FormFieldController<String>(
                                        _model.activityTrainingLocationChoiceValue ??=
                                            FFAppState()
                                                .activityDraftLocationType,
                                      ),
                                      options: ['Op stal', 'Op locatie'],
                                      onChanged: (val) async {
                                        safeSetState(() => _model
                                                .activityTrainingLocationChoiceValue =
                                            val);
                                        FFAppState().activityDraftLocationType =
                                            _model
                                                .activityTrainingLocationChoiceValue!;
                                        safeSetState(() {});
                                        _model.hasChanges = true;
                                        safeSetState(() {});
                                        _model.formValidationMessage = '';
                                        safeSetState(() {});
                                      },
                                      textStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            font: GoogleFonts.inter(
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                            letterSpacing: 0.0,
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                      hintText: 'Op stal of op locatie',
                                      icon: Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryText,
                                        size: 24.0,
                                      ),
                                      fillColor: FlutterFlowTheme.of(context)
                                          .secondaryBackground,
                                      elevation: 2.0,
                                      borderColor: FlutterFlowTheme.of(context)
                                          .alternate,
                                      borderWidth: 1.0,
                                      borderRadius: 8.0,
                                      margin: EdgeInsetsDirectional.fromSTEB(
                                          12.0, 0.0, 12.0, 0.0),
                                      hidesUnderline: true,
                                      isOverButton: false,
                                      isSearchable: false,
                                      isMultiSelect: false,
                                      labelText: 'Locatiekeuze',
                                      labelTextStyle: TextStyle(),
                                    ),
                                    if (FFAppState()
                                            .activityDraftLocationType ==
                                        'Op locatie')
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.max,
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Expanded(
                                                flex: 1,
                                                child: Text(
                                                  'Welke locatie?',
                                                  maxLines: 2,
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .labelMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .primaryText,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontStyle,
                                                      ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Text(
                                                'Verplicht',
                                                style: FlutterFlowTheme.of(
                                                        context)
                                                    .labelSmall
                                                    .override(
                                                      font: GoogleFonts.inter(
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelSmall
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelSmall
                                                                .fontStyle,
                                                      ),
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .secondary,
                                                      letterSpacing: 0.0,
                                                      fontWeight:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .labelSmall
                                                              .fontWeight,
                                                      fontStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .labelSmall
                                                              .fontStyle,
                                                    ),
                                              ),
                                            ].divide(SizedBox(width: 12.0)),
                                          ),
                                          TextFormField(
                                            controller: _model
                                                .activityTrainingLocationFieldTextController,
                                            focusNode: _model
                                                .activityTrainingLocationFieldFocusNode,
                                            onChanged: (_) =>
                                                EasyDebounce.debounce(
                                              '_model.activityTrainingLocationFieldTextController',
                                              Duration(milliseconds: 2000),
                                              () async {
                                                _model.hasChanges = true;
                                                safeSetState(() {});
                                                _model.formValidationMessage =
                                                    '';
                                                safeSetState(() {});
                                              },
                                            ),
                                            obscureText: false,
                                            decoration: InputDecoration(
                                              labelText: 'Welke locatie?',
                                              hintText:
                                                  'Naam of adres van de trainingslocatie',
                                              enabledBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              errorBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              focusedErrorBorder:
                                                  OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              filled: true,
                                            ),
                                            style: TextStyle(),
                                            maxLines: null,
                                            validator: _model
                                                .activityTrainingLocationFieldTextControllerValidator
                                                .asValidator(context),
                                          ),
                                        ].divide(SizedBox(height: 8.0)),
                                      ),
                                  ].divide(SizedBox(height: 8.0)),
                                ),
                              if (functions.activityTypeIsServiceV2(
                                      FFAppState().activityDraftPendingType) ??
                                  true)
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (FFAppState().activityDraftPendingType ==
                                        'Hoefsmid')
                                      Text(
                                        'Naam hoefsmid *',
                                        style: FlutterFlowTheme.of(context)
                                            .labelMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .labelMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .labelMedium
                                                        .fontStyle,
                                              ),
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primaryText,
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontStyle,
                                            ),
                                      ),
                                    if (FFAppState().activityDraftPendingType ==
                                        'Dierenarts')
                                      Text(
                                        'Naam dierenarts *',
                                        style: FlutterFlowTheme.of(context)
                                            .labelMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .labelMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .labelMedium
                                                        .fontStyle,
                                              ),
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primaryText,
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontStyle,
                                            ),
                                      ),
                                    TextFormField(
                                      controller: _model
                                          .activityProviderFieldTextController,
                                      focusNode:
                                          _model.activityProviderFieldFocusNode,
                                      onChanged: (_) => EasyDebounce.debounce(
                                        '_model.activityProviderFieldTextController',
                                        Duration(milliseconds: 2000),
                                        () async {
                                          _model.hasChanges = true;
                                          safeSetState(() {});
                                          _model.formValidationMessage = '';
                                          safeSetState(() {});
                                        },
                                      ),
                                      obscureText: false,
                                      decoration: InputDecoration(
                                        labelText: 'Naam',
                                        hintText: 'Vul de naam in',
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Color(0x00000000),
                                            width: 1.0,
                                          ),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(4.0),
                                            topRight: Radius.circular(4.0),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Color(0x00000000),
                                            width: 1.0,
                                          ),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(4.0),
                                            topRight: Radius.circular(4.0),
                                          ),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Color(0x00000000),
                                            width: 1.0,
                                          ),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(4.0),
                                            topRight: Radius.circular(4.0),
                                          ),
                                        ),
                                        focusedErrorBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Color(0x00000000),
                                            width: 1.0,
                                          ),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(4.0),
                                            topRight: Radius.circular(4.0),
                                          ),
                                        ),
                                        filled: true,
                                      ),
                                      style: TextStyle(),
                                      maxLines: null,
                                      validator: _model
                                          .activityProviderFieldTextControllerValidator
                                          .asValidator(context),
                                    ),
                                  ].divide(SizedBox(height: 8.0)),
                                ),
                              if (FFAppState().activityDraftPendingType ==
                                  'Wedstrijd')
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            'Locatie wedstrijd',
                                            maxLines: 2,
                                            style: FlutterFlowTheme.of(context)
                                                .labelMedium
                                                .override(
                                                  font: GoogleFonts.inter(
                                                    fontWeight:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .labelMedium
                                                            .fontWeight,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .labelMedium
                                                            .fontStyle,
                                                  ),
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primaryText,
                                                  letterSpacing: 0.0,
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelMedium
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelMedium
                                                          .fontStyle,
                                                ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          'Verplicht',
                                          style: FlutterFlowTheme.of(context)
                                              .labelSmall
                                              .override(
                                                font: GoogleFonts.inter(
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelSmall
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelSmall
                                                          .fontStyle,
                                                ),
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondary,
                                                letterSpacing: 0.0,
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .labelSmall
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .labelSmall
                                                        .fontStyle,
                                              ),
                                        ),
                                      ].divide(SizedBox(width: 12.0)),
                                    ),
                                    TextFormField(
                                      controller: _model
                                          .activityCompetitionLocationFieldTextController,
                                      focusNode: _model
                                          .activityCompetitionLocationFieldFocusNode,
                                      onChanged: (_) => EasyDebounce.debounce(
                                        '_model.activityCompetitionLocationFieldTextController',
                                        Duration(milliseconds: 2000),
                                        () async {
                                          _model.hasChanges = true;
                                          safeSetState(() {});
                                          _model.formValidationMessage = '';
                                          safeSetState(() {});
                                        },
                                      ),
                                      obscureText: false,
                                      decoration: InputDecoration(
                                        labelText: 'Locatie wedstrijd',
                                        hintText: 'Wedstrijdterrein of plaats',
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Color(0x00000000),
                                            width: 1.0,
                                          ),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(4.0),
                                            topRight: Radius.circular(4.0),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Color(0x00000000),
                                            width: 1.0,
                                          ),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(4.0),
                                            topRight: Radius.circular(4.0),
                                          ),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Color(0x00000000),
                                            width: 1.0,
                                          ),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(4.0),
                                            topRight: Radius.circular(4.0),
                                          ),
                                        ),
                                        focusedErrorBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Color(0x00000000),
                                            width: 1.0,
                                          ),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(4.0),
                                            topRight: Radius.circular(4.0),
                                          ),
                                        ),
                                        filled: true,
                                      ),
                                      style: TextStyle(),
                                      maxLines: null,
                                      validator: _model
                                          .activityCompetitionLocationFieldTextControllerValidator
                                          .asValidator(context),
                                    ),
                                  ].divide(SizedBox(height: 8.0)),
                                ),
                              if (FFAppState().activityDraftPendingType ==
                                  'Overig')
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            'Titel',
                                            maxLines: 2,
                                            style: FlutterFlowTheme.of(context)
                                                .labelMedium
                                                .override(
                                                  font: GoogleFonts.inter(
                                                    fontWeight:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .labelMedium
                                                            .fontWeight,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .labelMedium
                                                            .fontStyle,
                                                  ),
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primaryText,
                                                  letterSpacing: 0.0,
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelMedium
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelMedium
                                                          .fontStyle,
                                                ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          'Verplicht',
                                          style: FlutterFlowTheme.of(context)
                                              .labelSmall
                                              .override(
                                                font: GoogleFonts.inter(
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelSmall
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelSmall
                                                          .fontStyle,
                                                ),
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondary,
                                                letterSpacing: 0.0,
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .labelSmall
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .labelSmall
                                                        .fontStyle,
                                              ),
                                        ),
                                      ].divide(SizedBox(width: 12.0)),
                                    ),
                                    TextFormField(
                                      controller: _model
                                          .activityCustomTitleFieldTextController,
                                      focusNode: _model
                                          .activityCustomTitleFieldFocusNode,
                                      onChanged: (_) => EasyDebounce.debounce(
                                        '_model.activityCustomTitleFieldTextController',
                                        Duration(milliseconds: 2000),
                                        () async {
                                          _model.hasChanges = true;
                                          safeSetState(() {});
                                          _model.formValidationMessage = '';
                                          safeSetState(() {});
                                        },
                                      ),
                                      obscureText: false,
                                      decoration: InputDecoration(
                                        labelText: 'Titel',
                                        hintText: 'Wat staat er gepland?',
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Color(0x00000000),
                                            width: 1.0,
                                          ),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(4.0),
                                            topRight: Radius.circular(4.0),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Color(0x00000000),
                                            width: 1.0,
                                          ),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(4.0),
                                            topRight: Radius.circular(4.0),
                                          ),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Color(0x00000000),
                                            width: 1.0,
                                          ),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(4.0),
                                            topRight: Radius.circular(4.0),
                                          ),
                                        ),
                                        focusedErrorBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Color(0x00000000),
                                            width: 1.0,
                                          ),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(4.0),
                                            topRight: Radius.circular(4.0),
                                          ),
                                        ),
                                        filled: true,
                                      ),
                                      style: TextStyle(),
                                      maxLines: null,
                                      validator: _model
                                          .activityCustomTitleFieldTextControllerValidator
                                          .asValidator(context),
                                    ),
                                  ].divide(SizedBox(height: 8.0)),
                                ),
                              if (!(FFAppState().activityDraftPendingType ==
                                  ''))
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            'Voor wie',
                                            maxLines: 2,
                                            style: FlutterFlowTheme.of(context)
                                                .labelMedium
                                                .override(
                                                  font: GoogleFonts.inter(
                                                    fontWeight:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .labelMedium
                                                            .fontWeight,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .labelMedium
                                                            .fontStyle,
                                                  ),
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primaryText,
                                                  letterSpacing: 0.0,
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelMedium
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelMedium
                                                          .fontStyle,
                                                ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          'Verplicht',
                                          style: FlutterFlowTheme.of(context)
                                              .labelSmall
                                              .override(
                                                font: GoogleFonts.inter(
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelSmall
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelSmall
                                                          .fontStyle,
                                                ),
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondary,
                                                letterSpacing: 0.0,
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .labelSmall
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .labelSmall
                                                        .fontStyle,
                                              ),
                                        ),
                                      ].divide(SizedBox(width: 12.0)),
                                    ),
                                    InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        await showModalBottomSheet(
                                          isScrollControlled: true,
                                          context: context,
                                          builder: (context) {
                                            return GestureDetector(
                                              onTap: () {
                                                FocusScope.of(context)
                                                    .unfocus();
                                                FocusManager
                                                    .instance.primaryFocus
                                                    ?.unfocus();
                                              },
                                              child: Padding(
                                                padding:
                                                    MediaQuery.viewInsetsOf(
                                                        context),
                                                child:
                                                    ActivityAssigneePickerSheetWidget(),
                                              ),
                                            );
                                          },
                                        ).then((value) => safeSetState(() {}));
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryBackground,
                                          borderRadius:
                                              BorderRadius.circular(10.0),
                                          border: Border.all(
                                            color: FlutterFlowTheme.of(context)
                                                .alternate,
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  14.0, 13.0, 14.0, 13.0),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.max,
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Container(
                                                width: 34.0,
                                                height: 34.0,
                                                decoration: BoxDecoration(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .accent2,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          999.0),
                                                ),
                                                alignment: AlignmentDirectional(
                                                    0.0, 0.0),
                                                child: Icon(
                                                  Icons.person,
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondary,
                                                  size: 18.0,
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Text(
                                                  functions.activityDraftAssigneeLabelV2(
                                                      FFAppState()
                                                          .activityDraftAssigneeUserIds
                                                          .toList(),
                                                      FFAppState()
                                                          .currentLocalUserId)!,
                                                  maxLines: 2,
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .primaryText,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                      ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Icon(
                                                Icons.keyboard_arrow_down,
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryText,
                                                size: 21.0,
                                              ),
                                            ].divide(SizedBox(width: 10.0)),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'Alleen actieve, geregistreerde leden van de huidige stal worden hier later getoond.',
                                      maxLines: 3,
                                      style: FlutterFlowTheme.of(context)
                                          .bodySmall
                                          .override(
                                            font: GoogleFonts.inter(
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodySmall
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodySmall
                                                      .fontStyle,
                                            ),
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryText,
                                            letterSpacing: 0.0,
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .bodySmall
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodySmall
                                                    .fontStyle,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ].divide(SizedBox(height: 8.0)),
                                ),
                              if (functions.activityTypeSupportsAllDayV2(
                                      FFAppState().activityDraftPendingType) ??
                                  true)
                                Container(
                                  decoration: BoxDecoration(
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                    borderRadius: BorderRadius.circular(10.0),
                                    border: Border.all(
                                      color: FlutterFlowTheme.of(context)
                                          .alternate,
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        14.0, 12.0, 14.0, 12.0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Switch(
                                          value: _model.toggleValue!,
                                          onChanged: (newValue) async {
                                            safeSetState(() =>
                                                _model.toggleValue = newValue!);
                                            if (newValue!) {
                                              FFAppState().activityDraftAllDay =
                                                  _model.toggleValue!;
                                              safeSetState(() {});
                                              if (_model.toggleValue!) {
                                                FFAppState()
                                                        .activityDraftStartTime =
                                                    null;
                                                safeSetState(() {});
                                                FFAppState()
                                                        .activityDraftEndTime =
                                                    null;
                                                safeSetState(() {});
                                                _model.hasChanges = true;
                                                safeSetState(() {});
                                                _model.formValidationMessage =
                                                    '';
                                                safeSetState(() {});
                                              }
                                            } else {
                                              FFAppState().activityDraftAllDay =
                                                  _model.toggleValue!;
                                              safeSetState(() {});
                                              if (_model.toggleValue!) {
                                                FFAppState()
                                                        .activityDraftStartTime =
                                                    null;
                                                safeSetState(() {});
                                                FFAppState()
                                                        .activityDraftEndTime =
                                                    null;
                                                safeSetState(() {});
                                                _model.hasChanges = true;
                                                safeSetState(() {});
                                                _model.formValidationMessage =
                                                    '';
                                                safeSetState(() {});
                                              }
                                            }
                                          },
                                          activeColor:
                                              FlutterFlowTheme.of(context)
                                                  .primary,
                                          activeTrackColor:
                                              FlutterFlowTheme.of(context)
                                                  .accent1,
                                          inactiveTrackColor:
                                              FlutterFlowTheme.of(context)
                                                  .primaryBackground,
                                          inactiveThumbColor:
                                              FlutterFlowTheme.of(context)
                                                  .secondaryText,
                                        ),
                                        Container(
                                          width: 8.0,
                                        ),
                                        Text(
                                          'Hele dag',
                                          style: TextStyle(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              if (!(FFAppState().activityDraftPendingType ==
                                  ''))
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (FFAppState().activityDraftPendingType ==
                                        'Wedstrijd')
                                      Text(
                                        'Datum van *',
                                        style: FlutterFlowTheme.of(context)
                                            .labelMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .labelMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .labelMedium
                                                        .fontStyle,
                                              ),
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primaryText,
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontStyle,
                                            ),
                                      ),
                                    if (!(FFAppState()
                                            .activityDraftPendingType ==
                                        'Wedstrijd'))
                                      Text(
                                        'Datum *',
                                        style: FlutterFlowTheme.of(context)
                                            .labelMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .labelMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .labelMedium
                                                        .fontStyle,
                                              ),
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primaryText,
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontStyle,
                                            ),
                                      ),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryBackground,
                                        borderRadius:
                                            BorderRadius.circular(10.0),
                                        border: Border.all(
                                          color: FlutterFlowTheme.of(context)
                                              .alternate,
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.all(10.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            InkWell(
                                              splashColor: Colors.transparent,
                                              focusColor: Colors.transparent,
                                              hoverColor: Colors.transparent,
                                              highlightColor:
                                                  Colors.transparent,
                                              onTap: () async {
                                                if (!_model.agendaOpening!) {
                                                  _model.agendaOpening = true;
                                                  safeSetState(() {});
                                                  await showModalBottomSheet(
                                                    isScrollControlled: true,
                                                    context: context,
                                                    builder: (context) {
                                                      return GestureDetector(
                                                        onTap: () {
                                                          FocusScope.of(context)
                                                              .unfocus();
                                                          FocusManager.instance
                                                              .primaryFocus
                                                              ?.unfocus();
                                                        },
                                                        child: Padding(
                                                          padding: MediaQuery
                                                              .viewInsetsOf(
                                                                  context),
                                                          child:
                                                              AvarynAgendaPickerSheetWidget(
                                                            activityType:
                                                                FFAppState()
                                                                    .activityDraftPendingType,
                                                            initialMode: 'date',
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ).then((value) =>
                                                      safeSetState(() {}));

                                                  _model.agendaOpening = false;
                                                  safeSetState(() {});
                                                }
                                              },
                                              child: Container(
                                                height: 48.0,
                                                child: Padding(
                                                  padding: EdgeInsetsDirectional
                                                      .fromSTEB(
                                                          4.0, 0.0, 4.0, 0.0),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.start,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(
                                                        Icons.calendar_today,
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .secondary,
                                                        size: 18.0,
                                                      ),
                                                      Container(
                                                        width: 76.0,
                                                        child: Text(
                                                          'Datum',
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodySmall
                                                              .override(
                                                                font:
                                                                    GoogleFonts
                                                                        .inter(
                                                                  fontWeight: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodySmall
                                                                      .fontWeight,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodySmall
                                                                      .fontStyle,
                                                                ),
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .secondaryText,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodySmall
                                                                    .fontWeight,
                                                                fontStyle: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodySmall
                                                                    .fontStyle,
                                                              ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        flex: 1,
                                                        child: Text(
                                                          functions
                                                              .formatActivityDateDutch(
                                                                  FFAppState()
                                                                      .activityDraftStartDate)!,
                                                          textAlign:
                                                              TextAlign.end,
                                                          maxLines: 2,
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyMedium
                                                              .override(
                                                                font:
                                                                    GoogleFonts
                                                                        .inter(
                                                                  fontWeight: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontWeight,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontStyle,
                                                                ),
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .primaryText,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontWeight,
                                                                fontStyle: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontStyle,
                                                              ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                      Icon(
                                                        Icons.chevron_right,
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .secondaryText,
                                                        size: 18.0,
                                                      ),
                                                    ].divide(
                                                        SizedBox(width: 9.0)),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (FFAppState()
                                                    .activityDraftPendingType ==
                                                'Wedstrijd')
                                              InkWell(
                                                splashColor: Colors.transparent,
                                                focusColor: Colors.transparent,
                                                hoverColor: Colors.transparent,
                                                highlightColor:
                                                    Colors.transparent,
                                                onTap: () async {
                                                  if (!_model.agendaOpening!) {
                                                    _model.agendaOpening = true;
                                                    safeSetState(() {});
                                                    await showModalBottomSheet(
                                                      isScrollControlled: true,
                                                      context: context,
                                                      builder: (context) {
                                                        return GestureDetector(
                                                          onTap: () {
                                                            FocusScope.of(
                                                                    context)
                                                                .unfocus();
                                                            FocusManager
                                                                .instance
                                                                .primaryFocus
                                                                ?.unfocus();
                                                          },
                                                          child: Padding(
                                                            padding: MediaQuery
                                                                .viewInsetsOf(
                                                                    context),
                                                            child:
                                                                AvarynAgendaPickerSheetWidget(
                                                              activityType:
                                                                  FFAppState()
                                                                      .activityDraftPendingType,
                                                              initialMode:
                                                                  'endDate',
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ).then((value) =>
                                                        safeSetState(() {}));

                                                    _model.agendaOpening =
                                                        false;
                                                    safeSetState(() {});
                                                  }
                                                },
                                                child: Container(
                                                  height: 48.0,
                                                  child: Padding(
                                                    padding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(4.0, 0.0,
                                                                4.0, 0.0),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .start,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .center,
                                                      children: [
                                                        Icon(
                                                          Icons.event,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondary,
                                                          size: 18.0,
                                                        ),
                                                        Container(
                                                          width: 76.0,
                                                          child: Text(
                                                            'Tot en met',
                                                            style: FlutterFlowTheme
                                                                    .of(context)
                                                                .bodySmall
                                                                .override(
                                                                  font:
                                                                      GoogleFonts
                                                                          .inter(
                                                                    fontWeight: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodySmall
                                                                        .fontWeight,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodySmall
                                                                        .fontStyle,
                                                                  ),
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .secondaryText,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodySmall
                                                                      .fontWeight,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodySmall
                                                                      .fontStyle,
                                                                ),
                                                          ),
                                                        ),
                                                        Expanded(
                                                          flex: 1,
                                                          child: Text(
                                                            functions
                                                                .formatActivityDateDutch(
                                                                    FFAppState()
                                                                        .activityDraftEndDate)!,
                                                            textAlign:
                                                                TextAlign.end,
                                                            maxLines: 2,
                                                            style: FlutterFlowTheme
                                                                    .of(context)
                                                                .bodyMedium
                                                                .override(
                                                                  font:
                                                                      GoogleFonts
                                                                          .inter(
                                                                    fontWeight: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .fontWeight,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .fontStyle,
                                                                  ),
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontWeight,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontStyle,
                                                                ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                        Icon(
                                                          Icons.chevron_right,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryText,
                                                          size: 18.0,
                                                        ),
                                                      ].divide(
                                                          SizedBox(width: 9.0)),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            if (!FFAppState()
                                                .activityDraftAllDay)
                                              InkWell(
                                                splashColor: Colors.transparent,
                                                focusColor: Colors.transparent,
                                                hoverColor: Colors.transparent,
                                                highlightColor:
                                                    Colors.transparent,
                                                onTap: () async {
                                                  if (!_model.agendaOpening!) {
                                                    _model.agendaOpening = true;
                                                    safeSetState(() {});
                                                    await showModalBottomSheet(
                                                      isScrollControlled: true,
                                                      context: context,
                                                      builder: (context) {
                                                        return GestureDetector(
                                                          onTap: () {
                                                            FocusScope.of(
                                                                    context)
                                                                .unfocus();
                                                            FocusManager
                                                                .instance
                                                                .primaryFocus
                                                                ?.unfocus();
                                                          },
                                                          child: Padding(
                                                            padding: MediaQuery
                                                                .viewInsetsOf(
                                                                    context),
                                                            child:
                                                                AvarynAgendaPickerSheetWidget(
                                                              activityType:
                                                                  FFAppState()
                                                                      .activityDraftPendingType,
                                                              initialMode:
                                                                  'startTime',
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ).then((value) =>
                                                        safeSetState(() {}));

                                                    _model.agendaOpening =
                                                        false;
                                                    safeSetState(() {});
                                                  }
                                                },
                                                child: Container(
                                                  height: 48.0,
                                                  child: Padding(
                                                    padding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(4.0, 0.0,
                                                                4.0, 0.0),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .start,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .center,
                                                      children: [
                                                        Icon(
                                                          Icons.schedule,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondary,
                                                          size: 18.0,
                                                        ),
                                                        Container(
                                                          width: 76.0,
                                                          child: Text(
                                                            'Starttijd',
                                                            style: FlutterFlowTheme
                                                                    .of(context)
                                                                .bodySmall
                                                                .override(
                                                                  font:
                                                                      GoogleFonts
                                                                          .inter(
                                                                    fontWeight: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodySmall
                                                                        .fontWeight,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodySmall
                                                                        .fontStyle,
                                                                  ),
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .secondaryText,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodySmall
                                                                      .fontWeight,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodySmall
                                                                      .fontStyle,
                                                                ),
                                                          ),
                                                        ),
                                                        Expanded(
                                                          flex: 1,
                                                          child: Text(
                                                            functions
                                                                .formatActivityTimeDutch(
                                                                    FFAppState()
                                                                        .activityDraftStartTime)!,
                                                            textAlign:
                                                                TextAlign.end,
                                                            maxLines: 2,
                                                            style: FlutterFlowTheme
                                                                    .of(context)
                                                                .bodyMedium
                                                                .override(
                                                                  font:
                                                                      GoogleFonts
                                                                          .inter(
                                                                    fontWeight: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .fontWeight,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .fontStyle,
                                                                  ),
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontWeight,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontStyle,
                                                                ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                        Icon(
                                                          Icons.chevron_right,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryText,
                                                          size: 18.0,
                                                        ),
                                                      ].divide(
                                                          SizedBox(width: 9.0)),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            if (functions.activityTypeUsesEndTimeV2(
                                                    FFAppState()
                                                        .activityDraftPendingType,
                                                    FFAppState()
                                                        .activityDraftAllDay) ??
                                                true)
                                              InkWell(
                                                splashColor: Colors.transparent,
                                                focusColor: Colors.transparent,
                                                hoverColor: Colors.transparent,
                                                highlightColor:
                                                    Colors.transparent,
                                                onTap: () async {
                                                  if (!_model.agendaOpening!) {
                                                    _model.agendaOpening = true;
                                                    safeSetState(() {});
                                                    await showModalBottomSheet(
                                                      isScrollControlled: true,
                                                      context: context,
                                                      builder: (context) {
                                                        return GestureDetector(
                                                          onTap: () {
                                                            FocusScope.of(
                                                                    context)
                                                                .unfocus();
                                                            FocusManager
                                                                .instance
                                                                .primaryFocus
                                                                ?.unfocus();
                                                          },
                                                          child: Padding(
                                                            padding: MediaQuery
                                                                .viewInsetsOf(
                                                                    context),
                                                            child:
                                                                AvarynAgendaPickerSheetWidget(
                                                              activityType:
                                                                  FFAppState()
                                                                      .activityDraftPendingType,
                                                              initialMode:
                                                                  'endTime',
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ).then((value) =>
                                                        safeSetState(() {}));

                                                    _model.agendaOpening =
                                                        false;
                                                    safeSetState(() {});
                                                  }
                                                },
                                                child: Container(
                                                  height: 48.0,
                                                  child: Padding(
                                                    padding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(4.0, 0.0,
                                                                4.0, 0.0),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .start,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .center,
                                                      children: [
                                                        Icon(
                                                          Icons.more_time,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondary,
                                                          size: 18.0,
                                                        ),
                                                        Container(
                                                          width: 76.0,
                                                          child: Text(
                                                            'Eindtijd',
                                                            style: FlutterFlowTheme
                                                                    .of(context)
                                                                .bodySmall
                                                                .override(
                                                                  font:
                                                                      GoogleFonts
                                                                          .inter(
                                                                    fontWeight: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodySmall
                                                                        .fontWeight,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodySmall
                                                                        .fontStyle,
                                                                  ),
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .secondaryText,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodySmall
                                                                      .fontWeight,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodySmall
                                                                      .fontStyle,
                                                                ),
                                                          ),
                                                        ),
                                                        Expanded(
                                                          flex: 1,
                                                          child: Text(
                                                            functions
                                                                .formatActivityTimeDutch(
                                                                    FFAppState()
                                                                        .activityDraftEndTime)!,
                                                            textAlign:
                                                                TextAlign.end,
                                                            maxLines: 2,
                                                            style: FlutterFlowTheme
                                                                    .of(context)
                                                                .bodyMedium
                                                                .override(
                                                                  font:
                                                                      GoogleFonts
                                                                          .inter(
                                                                    fontWeight: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .fontWeight,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .fontStyle,
                                                                  ),
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontWeight,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontStyle,
                                                                ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                        Icon(
                                                          Icons.chevron_right,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryText,
                                                          size: 18.0,
                                                        ),
                                                      ].divide(
                                                          SizedBox(width: 9.0)),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            InkWell(
                                              splashColor: Colors.transparent,
                                              focusColor: Colors.transparent,
                                              hoverColor: Colors.transparent,
                                              highlightColor:
                                                  Colors.transparent,
                                              onTap: () async {
                                                if (!_model.agendaOpening!) {
                                                  _model.agendaOpening = true;
                                                  safeSetState(() {});
                                                  await showModalBottomSheet(
                                                    isScrollControlled: true,
                                                    context: context,
                                                    builder: (context) {
                                                      return GestureDetector(
                                                        onTap: () {
                                                          FocusScope.of(context)
                                                              .unfocus();
                                                          FocusManager.instance
                                                              .primaryFocus
                                                              ?.unfocus();
                                                        },
                                                        child: Padding(
                                                          padding: MediaQuery
                                                              .viewInsetsOf(
                                                                  context),
                                                          child:
                                                              AvarynAgendaPickerSheetWidget(
                                                            activityType:
                                                                FFAppState()
                                                                    .activityDraftPendingType,
                                                            initialMode:
                                                                'overview',
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ).then((value) =>
                                                      safeSetState(() {}));

                                                  _model.agendaOpening = false;
                                                  safeSetState(() {});
                                                }
                                              },
                                              child: Container(
                                                height: 44.0,
                                                alignment: AlignmentDirectional(
                                                    0.0, 0.0),
                                                child: Padding(
                                                  padding: EdgeInsetsDirectional
                                                      .fromSTEB(
                                                          4.0, 0.0, 4.0, 0.0),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.end,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        'Open agenda',
                                                        style:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .override(
                                                                  font:
                                                                      GoogleFonts
                                                                          .inter(
                                                                    fontWeight: FlutterFlowTheme.of(
                                                                            context)
                                                                        .labelMedium
                                                                        .fontWeight,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .labelMedium
                                                                        .fontStyle,
                                                                  ),
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .secondary,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight: FlutterFlowTheme.of(
                                                                          context)
                                                                      .labelMedium
                                                                      .fontWeight,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .labelMedium
                                                                      .fontStyle,
                                                                ),
                                                      ),
                                                      Icon(
                                                        Icons.chevron_right,
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .secondary,
                                                        size: 20.0,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ].divide(SizedBox(height: 4.0)),
                                        ),
                                      ),
                                    ),
                                  ].divide(SizedBox(height: 10.0)),
                                ),
                              if (FFAppState().activityDraftPendingType ==
                                  'Verzorging')
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            'Duur',
                                            maxLines: 2,
                                            style: FlutterFlowTheme.of(context)
                                                .labelMedium
                                                .override(
                                                  font: GoogleFonts.inter(
                                                    fontWeight:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .labelMedium
                                                            .fontWeight,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .labelMedium
                                                            .fontStyle,
                                                  ),
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primaryText,
                                                  letterSpacing: 0.0,
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelMedium
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelMedium
                                                          .fontStyle,
                                                ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          'Verplicht',
                                          style: FlutterFlowTheme.of(context)
                                              .labelSmall
                                              .override(
                                                font: GoogleFonts.inter(
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelSmall
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelSmall
                                                          .fontStyle,
                                                ),
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondary,
                                                letterSpacing: 0.0,
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .labelSmall
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .labelSmall
                                                        .fontStyle,
                                              ),
                                        ),
                                      ].divide(SizedBox(width: 12.0)),
                                    ),
                                    FlutterFlowDropDown<String>(
                                      controller: _model
                                              .activityDurationDropdownValueController ??=
                                          FormFieldController<String>(
                                        _model.activityDurationDropdownValue ??=
                                            _model.formDurationChoice,
                                      ),
                                      options: [
                                        '15 minuten',
                                        '30 minuten',
                                        '45 minuten',
                                        '1 uur',
                                        '1,5 uur',
                                        '2 uur',
                                        'Aangepast'
                                      ],
                                      onChanged: (val) async {
                                        safeSetState(() => _model
                                                .activityDurationDropdownValue =
                                            val);
                                        _model.formDurationChoice = _model
                                            .activityDurationDropdownValue;
                                        safeSetState(() {});
                                        if (_model
                                                .activityDurationDropdownValue ==
                                            '15 minuten') {
                                          FFAppState()
                                              .activityDraftDurationMinutes = 15;
                                          safeSetState(() {});
                                          _model.hasChanges = true;
                                          safeSetState(() {});
                                          _model.formValidationMessage = '';
                                          safeSetState(() {});
                                        } else if (_model
                                                .activityDurationDropdownValue ==
                                            '30 minuten') {
                                          FFAppState()
                                              .activityDraftDurationMinutes = 30;
                                          safeSetState(() {});
                                          _model.hasChanges = true;
                                          safeSetState(() {});
                                          _model.formValidationMessage = '';
                                          safeSetState(() {});
                                        } else if (_model
                                                .activityDurationDropdownValue ==
                                            '45 minuten') {
                                          FFAppState()
                                              .activityDraftDurationMinutes = 45;
                                          safeSetState(() {});
                                          _model.hasChanges = true;
                                          safeSetState(() {});
                                          _model.formValidationMessage = '';
                                          safeSetState(() {});
                                        } else if (_model
                                                .activityDurationDropdownValue ==
                                            '1 uur') {
                                          FFAppState()
                                              .activityDraftDurationMinutes = 60;
                                          safeSetState(() {});
                                          _model.hasChanges = true;
                                          safeSetState(() {});
                                          _model.formValidationMessage = '';
                                          safeSetState(() {});
                                        } else if (_model
                                                .activityDurationDropdownValue ==
                                            '1,5 uur') {
                                          FFAppState()
                                              .activityDraftDurationMinutes = 90;
                                          safeSetState(() {});
                                          _model.hasChanges = true;
                                          safeSetState(() {});
                                          _model.formValidationMessage = '';
                                          safeSetState(() {});
                                        } else if (_model
                                                .activityDurationDropdownValue ==
                                            '2 uur') {
                                          FFAppState()
                                                  .activityDraftDurationMinutes =
                                              120;
                                          safeSetState(() {});
                                          _model.hasChanges = true;
                                          safeSetState(() {});
                                          _model.formValidationMessage = '';
                                          safeSetState(() {});
                                        } else if (_model
                                                .activityDurationDropdownValue ==
                                            'Aangepast') {
                                          FFAppState()
                                              .activityDraftDurationMinutes = 0;
                                          safeSetState(() {});
                                          _model.hasChanges = true;
                                          safeSetState(() {});
                                          _model.formValidationMessage = '';
                                          safeSetState(() {});
                                        }
                                      },
                                      textStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            font: GoogleFonts.inter(
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                            letterSpacing: 0.0,
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                      hintText: 'Selecteer een duur',
                                      icon: Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryText,
                                        size: 24.0,
                                      ),
                                      fillColor: FlutterFlowTheme.of(context)
                                          .secondaryBackground,
                                      elevation: 2.0,
                                      borderColor: FlutterFlowTheme.of(context)
                                          .alternate,
                                      borderWidth: 1.0,
                                      borderRadius: 8.0,
                                      margin: EdgeInsetsDirectional.fromSTEB(
                                          12.0, 0.0, 12.0, 0.0),
                                      hidesUnderline: true,
                                      isOverButton: false,
                                      isSearchable: false,
                                      isMultiSelect: false,
                                      labelText: 'Duur',
                                      labelTextStyle: TextStyle(),
                                    ),
                                    if (_model.formDurationChoice ==
                                        'Aangepast')
                                      TextFormField(
                                        controller: _model
                                            .activityCustomDurationFieldTextController,
                                        focusNode: _model
                                            .activityCustomDurationFieldFocusNode,
                                        onChanged: (_) => EasyDebounce.debounce(
                                          '_model.activityCustomDurationFieldTextController',
                                          Duration(milliseconds: 2000),
                                          () async {
                                            FFAppState()
                                                    .activityDraftDurationMinutes =
                                                int.parse(_model
                                                    .activityCustomDurationFieldTextController
                                                    .text);
                                            safeSetState(() {});
                                            _model.hasChanges = true;
                                            safeSetState(() {});
                                            _model.formValidationMessage = '';
                                            safeSetState(() {});
                                          },
                                        ),
                                        obscureText: false,
                                        decoration: InputDecoration(
                                          labelText: 'Aantal minuten',
                                          hintText: 'Bijvoorbeeld 75',
                                          enabledBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: Color(0x00000000),
                                              width: 1.0,
                                            ),
                                            borderRadius:
                                                const BorderRadius.only(
                                              topLeft: Radius.circular(4.0),
                                              topRight: Radius.circular(4.0),
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: Color(0x00000000),
                                              width: 1.0,
                                            ),
                                            borderRadius:
                                                const BorderRadius.only(
                                              topLeft: Radius.circular(4.0),
                                              topRight: Radius.circular(4.0),
                                            ),
                                          ),
                                          errorBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: Color(0x00000000),
                                              width: 1.0,
                                            ),
                                            borderRadius:
                                                const BorderRadius.only(
                                              topLeft: Radius.circular(4.0),
                                              topRight: Radius.circular(4.0),
                                            ),
                                          ),
                                          focusedErrorBorder:
                                              OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: Color(0x00000000),
                                              width: 1.0,
                                            ),
                                            borderRadius:
                                                const BorderRadius.only(
                                              topLeft: Radius.circular(4.0),
                                              topRight: Radius.circular(4.0),
                                            ),
                                          ),
                                          filled: true,
                                        ),
                                        style: TextStyle(),
                                        maxLines: null,
                                        validator: _model
                                            .activityCustomDurationFieldTextControllerValidator
                                            .asValidator(context),
                                      ),
                                  ].divide(SizedBox(height: 8.0)),
                                ),
                              if (FFAppState().activityDraftPendingType ==
                                  'Overig')
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            'Locatie',
                                            maxLines: 2,
                                            style: FlutterFlowTheme.of(context)
                                                .labelMedium
                                                .override(
                                                  font: GoogleFonts.inter(
                                                    fontWeight:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .labelMedium
                                                            .fontWeight,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .labelMedium
                                                            .fontStyle,
                                                  ),
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primaryText,
                                                  letterSpacing: 0.0,
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelMedium
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelMedium
                                                          .fontStyle,
                                                ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          'Optioneel',
                                          style: FlutterFlowTheme.of(context)
                                              .labelSmall
                                              .override(
                                                font: GoogleFonts.inter(
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelSmall
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelSmall
                                                          .fontStyle,
                                                ),
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryText,
                                                letterSpacing: 0.0,
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .labelSmall
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .labelSmall
                                                        .fontStyle,
                                              ),
                                        ),
                                      ].divide(SizedBox(width: 12.0)),
                                    ),
                                    TextFormField(
                                      controller: _model
                                          .activityOtherLocationFieldTextController,
                                      focusNode: _model
                                          .activityOtherLocationFieldFocusNode,
                                      onChanged: (_) => EasyDebounce.debounce(
                                        '_model.activityOtherLocationFieldTextController',
                                        Duration(milliseconds: 2000),
                                        () async {
                                          _model.hasChanges = true;
                                          safeSetState(() {});
                                        },
                                      ),
                                      obscureText: false,
                                      decoration: InputDecoration(
                                        labelText: 'Locatie',
                                        hintText: 'Optioneel',
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Color(0x00000000),
                                            width: 1.0,
                                          ),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(4.0),
                                            topRight: Radius.circular(4.0),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Color(0x00000000),
                                            width: 1.0,
                                          ),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(4.0),
                                            topRight: Radius.circular(4.0),
                                          ),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Color(0x00000000),
                                            width: 1.0,
                                          ),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(4.0),
                                            topRight: Radius.circular(4.0),
                                          ),
                                        ),
                                        focusedErrorBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Color(0x00000000),
                                            width: 1.0,
                                          ),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(4.0),
                                            topRight: Radius.circular(4.0),
                                          ),
                                        ),
                                        filled: true,
                                      ),
                                      style: TextStyle(),
                                      maxLines: null,
                                      validator: _model
                                          .activityOtherLocationFieldTextControllerValidator
                                          .asValidator(context),
                                    ),
                                  ].divide(SizedBox(height: 8.0)),
                                ),
                              if (functions.activityTypeShowsNotesV2(
                                      FFAppState().activityDraftPendingType) ??
                                  true)
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            'Notities',
                                            maxLines: 2,
                                            style: FlutterFlowTheme.of(context)
                                                .labelMedium
                                                .override(
                                                  font: GoogleFonts.inter(
                                                    fontWeight:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .labelMedium
                                                            .fontWeight,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .labelMedium
                                                            .fontStyle,
                                                  ),
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primaryText,
                                                  letterSpacing: 0.0,
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelMedium
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelMedium
                                                          .fontStyle,
                                                ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          'Optioneel',
                                          style: FlutterFlowTheme.of(context)
                                              .labelSmall
                                              .override(
                                                font: GoogleFonts.inter(
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelSmall
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelSmall
                                                          .fontStyle,
                                                ),
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryText,
                                                letterSpacing: 0.0,
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .labelSmall
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .labelSmall
                                                        .fontStyle,
                                              ),
                                        ),
                                      ].divide(SizedBox(width: 12.0)),
                                    ),
                                    TextFormField(
                                      controller: _model
                                          .activityNotesFieldV2TextController,
                                      focusNode:
                                          _model.activityNotesFieldV2FocusNode,
                                      onChanged: (_) => EasyDebounce.debounce(
                                        '_model.activityNotesFieldV2TextController',
                                        Duration(milliseconds: 2000),
                                        () async {
                                          _model.hasChanges = true;
                                          safeSetState(() {});
                                        },
                                      ),
                                      obscureText: false,
                                      decoration: InputDecoration(
                                        labelText: 'Notities',
                                        hintText:
                                            'Optionele voorbereiding of instructie',
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Color(0x00000000),
                                            width: 1.0,
                                          ),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(4.0),
                                            topRight: Radius.circular(4.0),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Color(0x00000000),
                                            width: 1.0,
                                          ),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(4.0),
                                            topRight: Radius.circular(4.0),
                                          ),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Color(0x00000000),
                                            width: 1.0,
                                          ),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(4.0),
                                            topRight: Radius.circular(4.0),
                                          ),
                                        ),
                                        focusedErrorBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Color(0x00000000),
                                            width: 1.0,
                                          ),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(4.0),
                                            topRight: Radius.circular(4.0),
                                          ),
                                        ),
                                        filled: true,
                                      ),
                                      style: TextStyle(),
                                      maxLines: 4,
                                      validator: _model
                                          .activityNotesFieldV2TextControllerValidator
                                          .asValidator(context),
                                    ),
                                  ].divide(SizedBox(height: 8.0)),
                                ),
                            ].divide(SizedBox(height: 22.0)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).secondaryBackground,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 24.0,
                      color: Color(0x24171518),
                      offset: Offset(
                        0.0,
                        -8.0,
                      ),
                      spreadRadius: -12.0,
                    )
                  ],
                  border: Border.all(
                    color: FlutterFlowTheme.of(context).alternate,
                    width: 0.7,
                  ),
                ),
                child: Padding(
                  padding:
                      EdgeInsetsDirectional.fromSTEB(18.0, 10.0, 18.0, 16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!(_model.formValidationMessage == ''))
                        Container(
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context).accent2,
                            borderRadius: BorderRadius.circular(9.0),
                          ),
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                12.0, 9.0, 12.0, 9.0),
                            child: Text(
                              _model.formValidationMessage!,
                              maxLines: 3,
                              style: FlutterFlowTheme.of(context)
                                  .bodySmall
                                  .override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodySmall
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodySmall
                                          .fontStyle,
                                    ),
                                    color: FlutterFlowTheme.of(context).error,
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodySmall
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodySmall
                                        .fontStyle,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      if (!_model.isSaving!)
                        FFButtonWidget(
                          onPressed: () async {
                            _model.formValidationMessage = '';
                            safeSetState(() {});
                            if (!FFAppState().activitySaveInProgress) {
                              if (widget!.editMode!) {
                                if (FFAppState().activityDraftPendingType ==
                                    'Training') {
                                  if (functions.activityFormIsValidBooleanV2(
                                          FFAppState().activityDraftPendingType,
                                          FFAppState().activityDraftHorseId,
                                          FFAppState()
                                              .activityDraftAssigneeUserIds
                                              .toList(),
                                          FFAppState().activityDraftStartDate,
                                          FFAppState().activityDraftEndDate,
                                          FFAppState().activityDraftStartTime,
                                          FFAppState().activityDraftEndTime,
                                          FFAppState().activityDraftAllDay,
                                          FFAppState()
                                              .activityDraftDurationMinutes,
                                          FFAppState()
                                              .activityDraftLocationType,
                                          _model
                                              .activityTrainingLocationFieldTextController
                                              .text,
                                          '',
                                          '') ==
                                      true) {
                                    if (functions.activityHasConflictBooleanV2(
                                            FFAppState().activities.toList(),
                                            ActivityDataStruct(
                                              id: FFAppState()
                                                  .selectedActivity
                                                  .id,
                                              horseId: FFAppState()
                                                  .activityDraftHorseId,
                                              stableId: FFAppState()
                                                  .selectedActivity
                                                  .stableId,
                                              activityType: FFAppState()
                                                  .activityDraftPendingType,
                                              customTitle: '',
                                              assigneeUserIds: FFAppState()
                                                  .activityDraftAssigneeUserIds,
                                              startDate: FFAppState()
                                                  .activityDraftStartDate,
                                              endDate: FFAppState()
                                                  .activityDraftEndDate,
                                              startTime: FFAppState()
                                                  .activityDraftStartTime,
                                              endTime: FFAppState()
                                                  .activityDraftEndTime,
                                              allDay: FFAppState()
                                                  .activityDraftAllDay,
                                              durationMinutes: FFAppState()
                                                  .activityDraftDurationMinutes,
                                              locationType: FFAppState()
                                                  .activityDraftLocationType,
                                              locationName: _model
                                                  .activityTrainingLocationFieldTextController
                                                  .text,
                                              serviceProviderName: '',
                                              notes: _model
                                                  .activityNotesFieldV2TextController
                                                  .text,
                                              completionStatus: FFAppState()
                                                  .selectedActivity
                                                  .completionStatus,
                                              createdAt: FFAppState()
                                                  .selectedActivity
                                                  .createdAt,
                                              updatedAt: getCurrentTimestamp,
                                              title: 'Training',
                                              date: FFAppState()
                                                  .activityDraftStartDate,
                                              time: FFAppState()
                                                  .activityDraftStartTime,
                                              isCompleted: FFAppState()
                                                  .selectedActivity
                                                  .isCompleted,
                                            ),
                                            FFAppState().currentLocalUserId) ==
                                        false) {
                                      FFAppState().activitySaveInProgress =
                                          true;
                                      safeSetState(() {});
                                      _model.isSaving = true;
                                      safeSetState(() {});
                                      FFAppState().updateActivitiesAtIndex(
                                        FFAppState().selectedActivityIndex,
                                        (_) => ActivityDataStruct(
                                          id: FFAppState().selectedActivity.id,
                                          horseId:
                                              FFAppState().activityDraftHorseId,
                                          stableId: FFAppState()
                                              .selectedActivity
                                              .stableId,
                                          activityType: FFAppState()
                                              .activityDraftPendingType,
                                          customTitle: '',
                                          assigneeUserIds: FFAppState()
                                              .activityDraftAssigneeUserIds,
                                          startDate: FFAppState()
                                              .activityDraftStartDate,
                                          endDate:
                                              FFAppState().activityDraftEndDate,
                                          startTime: FFAppState()
                                              .activityDraftStartTime,
                                          endTime:
                                              FFAppState().activityDraftEndTime,
                                          allDay:
                                              FFAppState().activityDraftAllDay,
                                          durationMinutes: FFAppState()
                                              .activityDraftDurationMinutes,
                                          locationType: FFAppState()
                                              .activityDraftLocationType,
                                          locationName: _model
                                              .activityTrainingLocationFieldTextController
                                              .text,
                                          serviceProviderName: '',
                                          notes: _model
                                              .activityNotesFieldV2TextController
                                              .text,
                                          completionStatus: FFAppState()
                                              .selectedActivity
                                              .completionStatus,
                                          createdAt: FFAppState()
                                              .selectedActivity
                                              .createdAt,
                                          updatedAt: getCurrentTimestamp,
                                          title: 'Training',
                                          date: FFAppState()
                                              .activityDraftStartDate,
                                          time: FFAppState()
                                              .activityDraftStartTime,
                                          isCompleted: FFAppState()
                                              .selectedActivity
                                              .isCompleted,
                                        ),
                                      );
                                      safeSetState(() {});
                                      FFAppState().selectedActivity =
                                          ActivityDataStruct(
                                        id: FFAppState().selectedActivity.id,
                                        horseId:
                                            FFAppState().activityDraftHorseId,
                                        stableId: FFAppState()
                                            .selectedActivity
                                            .stableId,
                                        activityType: FFAppState()
                                            .activityDraftPendingType,
                                        customTitle: '',
                                        assigneeUserIds: FFAppState()
                                            .activityDraftAssigneeUserIds,
                                        startDate:
                                            FFAppState().activityDraftStartDate,
                                        endDate:
                                            FFAppState().activityDraftEndDate,
                                        startTime:
                                            FFAppState().activityDraftStartTime,
                                        endTime:
                                            FFAppState().activityDraftEndTime,
                                        allDay:
                                            FFAppState().activityDraftAllDay,
                                        durationMinutes: FFAppState()
                                            .activityDraftDurationMinutes,
                                        locationType: FFAppState()
                                            .activityDraftLocationType,
                                        locationName: _model
                                            .activityTrainingLocationFieldTextController
                                            .text,
                                        serviceProviderName: '',
                                        notes: _model
                                            .activityNotesFieldV2TextController
                                            .text,
                                        completionStatus: FFAppState()
                                            .selectedActivity
                                            .completionStatus,
                                        createdAt: FFAppState()
                                            .selectedActivity
                                            .createdAt,
                                        updatedAt: getCurrentTimestamp,
                                        title: 'Training',
                                        date:
                                            FFAppState().activityDraftStartDate,
                                        time:
                                            FFAppState().activityDraftStartTime,
                                        isCompleted: FFAppState()
                                            .selectedActivity
                                            .isCompleted,
                                      );
                                      safeSetState(() {});
                                      _model.hasChanges = false;
                                      safeSetState(() {});
                                      _model.isSaving = false;
                                      safeSetState(() {});
                                      FFAppState().activitySaveInProgress =
                                          false;
                                      safeSetState(() {});
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Activiteit opgeslagen',
                                            style: TextStyle(),
                                          ),
                                          duration:
                                              Duration(milliseconds: 4000),
                                        ),
                                      );

                                      context.pushNamed(
                                          PlanningPageWidget.routeName);
                                    } else {
                                      await showModalBottomSheet(
                                        isScrollControlled: true,
                                        context: context,
                                        builder: (context) {
                                          return GestureDetector(
                                            onTap: () {
                                              FocusScope.of(context).unfocus();
                                              FocusManager.instance.primaryFocus
                                                  ?.unfocus();
                                            },
                                            child: Padding(
                                              padding: MediaQuery.viewInsetsOf(
                                                  context),
                                              child:
                                                  ActivityConflictSheetWidget(
                                                message: functions
                                                    .activityConflictWarningV2(
                                                        FFAppState()
                                                            .activities
                                                            .toList(),
                                                        ActivityDataStruct(
                                                          id: FFAppState()
                                                              .selectedActivity
                                                              .id,
                                                          horseId: FFAppState()
                                                              .activityDraftHorseId,
                                                          stableId: FFAppState()
                                                              .selectedActivity
                                                              .stableId,
                                                          activityType: FFAppState()
                                                              .activityDraftPendingType,
                                                          customTitle: '',
                                                          assigneeUserIds:
                                                              FFAppState()
                                                                  .activityDraftAssigneeUserIds,
                                                          startDate: FFAppState()
                                                              .activityDraftStartDate,
                                                          endDate: FFAppState()
                                                              .activityDraftEndDate,
                                                          startTime: FFAppState()
                                                              .activityDraftStartTime,
                                                          endTime: FFAppState()
                                                              .activityDraftEndTime,
                                                          allDay: FFAppState()
                                                              .activityDraftAllDay,
                                                          durationMinutes:
                                                              FFAppState()
                                                                  .activityDraftDurationMinutes,
                                                          locationType: FFAppState()
                                                              .activityDraftLocationType,
                                                          locationName: _model
                                                              .activityTrainingLocationFieldTextController
                                                              .text,
                                                          serviceProviderName:
                                                              '',
                                                          notes: _model
                                                              .activityNotesFieldV2TextController
                                                              .text,
                                                          completionStatus:
                                                              FFAppState()
                                                                  .selectedActivity
                                                                  .completionStatus,
                                                          createdAt: FFAppState()
                                                              .selectedActivity
                                                              .createdAt,
                                                          updatedAt:
                                                              getCurrentTimestamp,
                                                          title: 'Training',
                                                          date: FFAppState()
                                                              .activityDraftStartDate,
                                                          time: FFAppState()
                                                              .activityDraftStartTime,
                                                          isCompleted: FFAppState()
                                                              .selectedActivity
                                                              .isCompleted,
                                                        ),
                                                        FFAppState()
                                                            .currentLocalUserId),
                                                editMode: true,
                                                pendingActivity:
                                                    ActivityDataStruct(
                                                  id: FFAppState()
                                                      .selectedActivity
                                                      .id,
                                                  horseId: FFAppState()
                                                      .activityDraftHorseId,
                                                  stableId: FFAppState()
                                                      .selectedActivity
                                                      .stableId,
                                                  activityType: FFAppState()
                                                      .activityDraftPendingType,
                                                  customTitle: '',
                                                  assigneeUserIds: FFAppState()
                                                      .activityDraftAssigneeUserIds,
                                                  startDate: FFAppState()
                                                      .activityDraftStartDate,
                                                  endDate: FFAppState()
                                                      .activityDraftEndDate,
                                                  startTime: FFAppState()
                                                      .activityDraftStartTime,
                                                  endTime: FFAppState()
                                                      .activityDraftEndTime,
                                                  allDay: FFAppState()
                                                      .activityDraftAllDay,
                                                  durationMinutes: FFAppState()
                                                      .activityDraftDurationMinutes,
                                                  locationType: FFAppState()
                                                      .activityDraftLocationType,
                                                  locationName: _model
                                                      .activityTrainingLocationFieldTextController
                                                      .text,
                                                  serviceProviderName: '',
                                                  notes: _model
                                                      .activityNotesFieldV2TextController
                                                      .text,
                                                  completionStatus: FFAppState()
                                                      .selectedActivity
                                                      .completionStatus,
                                                  createdAt: FFAppState()
                                                      .selectedActivity
                                                      .createdAt,
                                                  updatedAt:
                                                      getCurrentTimestamp,
                                                  title: 'Training',
                                                  date: FFAppState()
                                                      .activityDraftStartDate,
                                                  time: FFAppState()
                                                      .activityDraftStartTime,
                                                  isCompleted: FFAppState()
                                                      .selectedActivity
                                                      .isCompleted,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ).then((value) => safeSetState(() {}));
                                    }
                                  } else {
                                    _model.formValidationMessage =
                                        functions.activityFormValidationV2(
                                            FFAppState()
                                                .activityDraftPendingType,
                                            FFAppState().activityDraftHorseId,
                                            FFAppState()
                                                .activityDraftAssigneeUserIds
                                                .toList(),
                                            FFAppState().activityDraftStartDate,
                                            FFAppState().activityDraftEndDate,
                                            FFAppState().activityDraftStartTime,
                                            FFAppState().activityDraftEndTime,
                                            FFAppState().activityDraftAllDay,
                                            FFAppState()
                                                .activityDraftDurationMinutes,
                                            FFAppState()
                                                .activityDraftLocationType,
                                            _model
                                                .activityTrainingLocationFieldTextController
                                                .text,
                                            '',
                                            '');
                                    safeSetState(() {});
                                  }
                                } else if (FFAppState()
                                        .activityDraftPendingType ==
                                    'Verzorging') {
                                  if (functions.activityFormIsValidBooleanV2(
                                          FFAppState().activityDraftPendingType,
                                          FFAppState().activityDraftHorseId,
                                          FFAppState()
                                              .activityDraftAssigneeUserIds
                                              .toList(),
                                          FFAppState().activityDraftStartDate,
                                          FFAppState().activityDraftEndDate,
                                          FFAppState().activityDraftStartTime,
                                          FFAppState().activityDraftEndTime,
                                          FFAppState().activityDraftAllDay,
                                          FFAppState()
                                              .activityDraftDurationMinutes,
                                          FFAppState()
                                              .activityDraftLocationType,
                                          '',
                                          '',
                                          '') ==
                                      true) {
                                    if (functions.activityHasConflictBooleanV2(
                                            FFAppState().activities.toList(),
                                            ActivityDataStruct(
                                              id: FFAppState()
                                                  .selectedActivity
                                                  .id,
                                              horseId: FFAppState()
                                                  .activityDraftHorseId,
                                              stableId: FFAppState()
                                                  .selectedActivity
                                                  .stableId,
                                              activityType: FFAppState()
                                                  .activityDraftPendingType,
                                              customTitle: '',
                                              assigneeUserIds: FFAppState()
                                                  .activityDraftAssigneeUserIds,
                                              startDate: FFAppState()
                                                  .activityDraftStartDate,
                                              endDate: FFAppState()
                                                  .activityDraftEndDate,
                                              startTime: FFAppState()
                                                  .activityDraftStartTime,
                                              endTime: FFAppState()
                                                  .activityDraftEndTime,
                                              allDay: FFAppState()
                                                  .activityDraftAllDay,
                                              durationMinutes: FFAppState()
                                                  .activityDraftDurationMinutes,
                                              locationType: FFAppState()
                                                  .activityDraftLocationType,
                                              locationName: '',
                                              serviceProviderName: '',
                                              notes: '',
                                              completionStatus: FFAppState()
                                                  .selectedActivity
                                                  .completionStatus,
                                              createdAt: FFAppState()
                                                  .selectedActivity
                                                  .createdAt,
                                              updatedAt: getCurrentTimestamp,
                                              title: 'Verzorging',
                                              date: FFAppState()
                                                  .activityDraftStartDate,
                                              time: FFAppState()
                                                  .activityDraftStartTime,
                                              isCompleted: FFAppState()
                                                  .selectedActivity
                                                  .isCompleted,
                                            ),
                                            FFAppState().currentLocalUserId) ==
                                        false) {
                                      FFAppState().activitySaveInProgress =
                                          true;
                                      safeSetState(() {});
                                      _model.isSaving = true;
                                      safeSetState(() {});
                                      FFAppState().updateActivitiesAtIndex(
                                        FFAppState().selectedActivityIndex,
                                        (_) => ActivityDataStruct(
                                          id: FFAppState().selectedActivity.id,
                                          horseId:
                                              FFAppState().activityDraftHorseId,
                                          stableId: FFAppState()
                                              .selectedActivity
                                              .stableId,
                                          activityType: FFAppState()
                                              .activityDraftPendingType,
                                          customTitle: '',
                                          assigneeUserIds: FFAppState()
                                              .activityDraftAssigneeUserIds,
                                          startDate: FFAppState()
                                              .activityDraftStartDate,
                                          endDate:
                                              FFAppState().activityDraftEndDate,
                                          startTime: FFAppState()
                                              .activityDraftStartTime,
                                          endTime:
                                              FFAppState().activityDraftEndTime,
                                          allDay:
                                              FFAppState().activityDraftAllDay,
                                          durationMinutes: FFAppState()
                                              .activityDraftDurationMinutes,
                                          locationType: FFAppState()
                                              .activityDraftLocationType,
                                          locationName: '',
                                          serviceProviderName: '',
                                          notes: '',
                                          completionStatus: FFAppState()
                                              .selectedActivity
                                              .completionStatus,
                                          createdAt: FFAppState()
                                              .selectedActivity
                                              .createdAt,
                                          updatedAt: getCurrentTimestamp,
                                          title: 'Verzorging',
                                          date: FFAppState()
                                              .activityDraftStartDate,
                                          time: FFAppState()
                                              .activityDraftStartTime,
                                          isCompleted: FFAppState()
                                              .selectedActivity
                                              .isCompleted,
                                        ),
                                      );
                                      safeSetState(() {});
                                      FFAppState().selectedActivity =
                                          ActivityDataStruct(
                                        id: FFAppState().selectedActivity.id,
                                        horseId:
                                            FFAppState().activityDraftHorseId,
                                        stableId: FFAppState()
                                            .selectedActivity
                                            .stableId,
                                        activityType: FFAppState()
                                            .activityDraftPendingType,
                                        customTitle: '',
                                        assigneeUserIds: FFAppState()
                                            .activityDraftAssigneeUserIds,
                                        startDate:
                                            FFAppState().activityDraftStartDate,
                                        endDate:
                                            FFAppState().activityDraftEndDate,
                                        startTime:
                                            FFAppState().activityDraftStartTime,
                                        endTime:
                                            FFAppState().activityDraftEndTime,
                                        allDay:
                                            FFAppState().activityDraftAllDay,
                                        durationMinutes: FFAppState()
                                            .activityDraftDurationMinutes,
                                        locationType: FFAppState()
                                            .activityDraftLocationType,
                                        locationName: '',
                                        serviceProviderName: '',
                                        notes: '',
                                        completionStatus: FFAppState()
                                            .selectedActivity
                                            .completionStatus,
                                        createdAt: FFAppState()
                                            .selectedActivity
                                            .createdAt,
                                        updatedAt: getCurrentTimestamp,
                                        title: 'Verzorging',
                                        date:
                                            FFAppState().activityDraftStartDate,
                                        time:
                                            FFAppState().activityDraftStartTime,
                                        isCompleted: FFAppState()
                                            .selectedActivity
                                            .isCompleted,
                                      );
                                      safeSetState(() {});
                                      _model.hasChanges = false;
                                      safeSetState(() {});
                                      _model.isSaving = false;
                                      safeSetState(() {});
                                      FFAppState().activitySaveInProgress =
                                          false;
                                      safeSetState(() {});
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Activiteit opgeslagen',
                                            style: TextStyle(),
                                          ),
                                          duration:
                                              Duration(milliseconds: 4000),
                                        ),
                                      );

                                      context.pushNamed(
                                          PlanningPageWidget.routeName);
                                    } else {
                                      await showModalBottomSheet(
                                        isScrollControlled: true,
                                        context: context,
                                        builder: (context) {
                                          return GestureDetector(
                                            onTap: () {
                                              FocusScope.of(context).unfocus();
                                              FocusManager.instance.primaryFocus
                                                  ?.unfocus();
                                            },
                                            child: Padding(
                                              padding: MediaQuery.viewInsetsOf(
                                                  context),
                                              child:
                                                  ActivityConflictSheetWidget(
                                                message: functions
                                                    .activityConflictWarningV2(
                                                        FFAppState()
                                                            .activities
                                                            .toList(),
                                                        ActivityDataStruct(
                                                          id: FFAppState()
                                                              .selectedActivity
                                                              .id,
                                                          horseId: FFAppState()
                                                              .activityDraftHorseId,
                                                          stableId: FFAppState()
                                                              .selectedActivity
                                                              .stableId,
                                                          activityType: FFAppState()
                                                              .activityDraftPendingType,
                                                          customTitle: '',
                                                          assigneeUserIds:
                                                              FFAppState()
                                                                  .activityDraftAssigneeUserIds,
                                                          startDate: FFAppState()
                                                              .activityDraftStartDate,
                                                          endDate: FFAppState()
                                                              .activityDraftEndDate,
                                                          startTime: FFAppState()
                                                              .activityDraftStartTime,
                                                          endTime: FFAppState()
                                                              .activityDraftEndTime,
                                                          allDay: FFAppState()
                                                              .activityDraftAllDay,
                                                          durationMinutes:
                                                              FFAppState()
                                                                  .activityDraftDurationMinutes,
                                                          locationType: FFAppState()
                                                              .activityDraftLocationType,
                                                          locationName: '',
                                                          serviceProviderName:
                                                              '',
                                                          notes: '',
                                                          completionStatus:
                                                              FFAppState()
                                                                  .selectedActivity
                                                                  .completionStatus,
                                                          createdAt: FFAppState()
                                                              .selectedActivity
                                                              .createdAt,
                                                          updatedAt:
                                                              getCurrentTimestamp,
                                                          title: 'Verzorging',
                                                          date: FFAppState()
                                                              .activityDraftStartDate,
                                                          time: FFAppState()
                                                              .activityDraftStartTime,
                                                          isCompleted: FFAppState()
                                                              .selectedActivity
                                                              .isCompleted,
                                                        ),
                                                        FFAppState()
                                                            .currentLocalUserId),
                                                editMode: true,
                                                pendingActivity:
                                                    ActivityDataStruct(
                                                  id: FFAppState()
                                                      .selectedActivity
                                                      .id,
                                                  horseId: FFAppState()
                                                      .activityDraftHorseId,
                                                  stableId: FFAppState()
                                                      .selectedActivity
                                                      .stableId,
                                                  activityType: FFAppState()
                                                      .activityDraftPendingType,
                                                  customTitle: '',
                                                  assigneeUserIds: FFAppState()
                                                      .activityDraftAssigneeUserIds,
                                                  startDate: FFAppState()
                                                      .activityDraftStartDate,
                                                  endDate: FFAppState()
                                                      .activityDraftEndDate,
                                                  startTime: FFAppState()
                                                      .activityDraftStartTime,
                                                  endTime: FFAppState()
                                                      .activityDraftEndTime,
                                                  allDay: FFAppState()
                                                      .activityDraftAllDay,
                                                  durationMinutes: FFAppState()
                                                      .activityDraftDurationMinutes,
                                                  locationType: FFAppState()
                                                      .activityDraftLocationType,
                                                  locationName: '',
                                                  serviceProviderName: '',
                                                  notes: '',
                                                  completionStatus: FFAppState()
                                                      .selectedActivity
                                                      .completionStatus,
                                                  createdAt: FFAppState()
                                                      .selectedActivity
                                                      .createdAt,
                                                  updatedAt:
                                                      getCurrentTimestamp,
                                                  title: 'Verzorging',
                                                  date: FFAppState()
                                                      .activityDraftStartDate,
                                                  time: FFAppState()
                                                      .activityDraftStartTime,
                                                  isCompleted: FFAppState()
                                                      .selectedActivity
                                                      .isCompleted,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ).then((value) => safeSetState(() {}));
                                    }
                                  } else {
                                    _model.formValidationMessage =
                                        functions.activityFormValidationV2(
                                            FFAppState()
                                                .activityDraftPendingType,
                                            FFAppState().activityDraftHorseId,
                                            FFAppState()
                                                .activityDraftAssigneeUserIds
                                                .toList(),
                                            FFAppState().activityDraftStartDate,
                                            FFAppState().activityDraftEndDate,
                                            FFAppState().activityDraftStartTime,
                                            FFAppState().activityDraftEndTime,
                                            FFAppState().activityDraftAllDay,
                                            FFAppState()
                                                .activityDraftDurationMinutes,
                                            FFAppState()
                                                .activityDraftLocationType,
                                            '',
                                            '',
                                            '');
                                    safeSetState(() {});
                                  }
                                } else if (FFAppState()
                                        .activityDraftPendingType ==
                                    'Hoefsmid') {
                                  if (functions.activityFormIsValidBooleanV2(
                                          FFAppState().activityDraftPendingType,
                                          FFAppState().activityDraftHorseId,
                                          FFAppState()
                                              .activityDraftAssigneeUserIds
                                              .toList(),
                                          FFAppState().activityDraftStartDate,
                                          FFAppState().activityDraftEndDate,
                                          FFAppState().activityDraftStartTime,
                                          FFAppState().activityDraftEndTime,
                                          FFAppState().activityDraftAllDay,
                                          FFAppState()
                                              .activityDraftDurationMinutes,
                                          FFAppState()
                                              .activityDraftLocationType,
                                          '',
                                          _model
                                              .activityProviderFieldTextController
                                              .text,
                                          '') ==
                                      true) {
                                    if (functions.activityHasConflictBooleanV2(
                                            FFAppState().activities.toList(),
                                            ActivityDataStruct(
                                              id: FFAppState()
                                                  .selectedActivity
                                                  .id,
                                              horseId: FFAppState()
                                                  .activityDraftHorseId,
                                              stableId: FFAppState()
                                                  .selectedActivity
                                                  .stableId,
                                              activityType: FFAppState()
                                                  .activityDraftPendingType,
                                              customTitle: '',
                                              assigneeUserIds: FFAppState()
                                                  .activityDraftAssigneeUserIds,
                                              startDate: FFAppState()
                                                  .activityDraftStartDate,
                                              endDate: FFAppState()
                                                  .activityDraftEndDate,
                                              startTime: FFAppState()
                                                  .activityDraftStartTime,
                                              endTime: FFAppState()
                                                  .activityDraftEndTime,
                                              allDay: FFAppState()
                                                  .activityDraftAllDay,
                                              durationMinutes: FFAppState()
                                                  .activityDraftDurationMinutes,
                                              locationType: FFAppState()
                                                  .activityDraftLocationType,
                                              locationName: '',
                                              serviceProviderName: _model
                                                  .activityProviderFieldTextController
                                                  .text,
                                              notes: _model
                                                  .activityNotesFieldV2TextController
                                                  .text,
                                              completionStatus: FFAppState()
                                                  .selectedActivity
                                                  .completionStatus,
                                              createdAt: FFAppState()
                                                  .selectedActivity
                                                  .createdAt,
                                              updatedAt: getCurrentTimestamp,
                                              title: 'Hoefsmid',
                                              date: FFAppState()
                                                  .activityDraftStartDate,
                                              time: FFAppState()
                                                  .activityDraftStartTime,
                                              isCompleted: FFAppState()
                                                  .selectedActivity
                                                  .isCompleted,
                                            ),
                                            FFAppState().currentLocalUserId) ==
                                        false) {
                                      FFAppState().activitySaveInProgress =
                                          true;
                                      safeSetState(() {});
                                      _model.isSaving = true;
                                      safeSetState(() {});
                                      FFAppState().updateActivitiesAtIndex(
                                        FFAppState().selectedActivityIndex,
                                        (_) => ActivityDataStruct(
                                          id: FFAppState().selectedActivity.id,
                                          horseId:
                                              FFAppState().activityDraftHorseId,
                                          stableId: FFAppState()
                                              .selectedActivity
                                              .stableId,
                                          activityType: FFAppState()
                                              .activityDraftPendingType,
                                          customTitle: '',
                                          assigneeUserIds: FFAppState()
                                              .activityDraftAssigneeUserIds,
                                          startDate: FFAppState()
                                              .activityDraftStartDate,
                                          endDate:
                                              FFAppState().activityDraftEndDate,
                                          startTime: FFAppState()
                                              .activityDraftStartTime,
                                          endTime:
                                              FFAppState().activityDraftEndTime,
                                          allDay:
                                              FFAppState().activityDraftAllDay,
                                          durationMinutes: FFAppState()
                                              .activityDraftDurationMinutes,
                                          locationType: FFAppState()
                                              .activityDraftLocationType,
                                          locationName: '',
                                          serviceProviderName: _model
                                              .activityProviderFieldTextController
                                              .text,
                                          notes: _model
                                              .activityNotesFieldV2TextController
                                              .text,
                                          completionStatus: FFAppState()
                                              .selectedActivity
                                              .completionStatus,
                                          createdAt: FFAppState()
                                              .selectedActivity
                                              .createdAt,
                                          updatedAt: getCurrentTimestamp,
                                          title: 'Hoefsmid',
                                          date: FFAppState()
                                              .activityDraftStartDate,
                                          time: FFAppState()
                                              .activityDraftStartTime,
                                          isCompleted: FFAppState()
                                              .selectedActivity
                                              .isCompleted,
                                        ),
                                      );
                                      safeSetState(() {});
                                      FFAppState().selectedActivity =
                                          ActivityDataStruct(
                                        id: FFAppState().selectedActivity.id,
                                        horseId:
                                            FFAppState().activityDraftHorseId,
                                        stableId: FFAppState()
                                            .selectedActivity
                                            .stableId,
                                        activityType: FFAppState()
                                            .activityDraftPendingType,
                                        customTitle: '',
                                        assigneeUserIds: FFAppState()
                                            .activityDraftAssigneeUserIds,
                                        startDate:
                                            FFAppState().activityDraftStartDate,
                                        endDate:
                                            FFAppState().activityDraftEndDate,
                                        startTime:
                                            FFAppState().activityDraftStartTime,
                                        endTime:
                                            FFAppState().activityDraftEndTime,
                                        allDay:
                                            FFAppState().activityDraftAllDay,
                                        durationMinutes: FFAppState()
                                            .activityDraftDurationMinutes,
                                        locationType: FFAppState()
                                            .activityDraftLocationType,
                                        locationName: '',
                                        serviceProviderName: _model
                                            .activityProviderFieldTextController
                                            .text,
                                        notes: _model
                                            .activityNotesFieldV2TextController
                                            .text,
                                        completionStatus: FFAppState()
                                            .selectedActivity
                                            .completionStatus,
                                        createdAt: FFAppState()
                                            .selectedActivity
                                            .createdAt,
                                        updatedAt: getCurrentTimestamp,
                                        title: 'Hoefsmid',
                                        date:
                                            FFAppState().activityDraftStartDate,
                                        time:
                                            FFAppState().activityDraftStartTime,
                                        isCompleted: FFAppState()
                                            .selectedActivity
                                            .isCompleted,
                                      );
                                      safeSetState(() {});
                                      _model.hasChanges = false;
                                      safeSetState(() {});
                                      _model.isSaving = false;
                                      safeSetState(() {});
                                      FFAppState().activitySaveInProgress =
                                          false;
                                      safeSetState(() {});
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Activiteit opgeslagen',
                                            style: TextStyle(),
                                          ),
                                          duration:
                                              Duration(milliseconds: 4000),
                                        ),
                                      );

                                      context.pushNamed(
                                          PlanningPageWidget.routeName);
                                    } else {
                                      await showModalBottomSheet(
                                        isScrollControlled: true,
                                        context: context,
                                        builder: (context) {
                                          return GestureDetector(
                                            onTap: () {
                                              FocusScope.of(context).unfocus();
                                              FocusManager.instance.primaryFocus
                                                  ?.unfocus();
                                            },
                                            child: Padding(
                                              padding: MediaQuery.viewInsetsOf(
                                                  context),
                                              child:
                                                  ActivityConflictSheetWidget(
                                                message: functions
                                                    .activityConflictWarningV2(
                                                        FFAppState()
                                                            .activities
                                                            .toList(),
                                                        ActivityDataStruct(
                                                          id: FFAppState()
                                                              .selectedActivity
                                                              .id,
                                                          horseId: FFAppState()
                                                              .activityDraftHorseId,
                                                          stableId: FFAppState()
                                                              .selectedActivity
                                                              .stableId,
                                                          activityType: FFAppState()
                                                              .activityDraftPendingType,
                                                          customTitle: '',
                                                          assigneeUserIds:
                                                              FFAppState()
                                                                  .activityDraftAssigneeUserIds,
                                                          startDate: FFAppState()
                                                              .activityDraftStartDate,
                                                          endDate: FFAppState()
                                                              .activityDraftEndDate,
                                                          startTime: FFAppState()
                                                              .activityDraftStartTime,
                                                          endTime: FFAppState()
                                                              .activityDraftEndTime,
                                                          allDay: FFAppState()
                                                              .activityDraftAllDay,
                                                          durationMinutes:
                                                              FFAppState()
                                                                  .activityDraftDurationMinutes,
                                                          locationType: FFAppState()
                                                              .activityDraftLocationType,
                                                          locationName: '',
                                                          serviceProviderName:
                                                              _model
                                                                  .activityProviderFieldTextController
                                                                  .text,
                                                          notes: _model
                                                              .activityNotesFieldV2TextController
                                                              .text,
                                                          completionStatus:
                                                              FFAppState()
                                                                  .selectedActivity
                                                                  .completionStatus,
                                                          createdAt: FFAppState()
                                                              .selectedActivity
                                                              .createdAt,
                                                          updatedAt:
                                                              getCurrentTimestamp,
                                                          title: 'Hoefsmid',
                                                          date: FFAppState()
                                                              .activityDraftStartDate,
                                                          time: FFAppState()
                                                              .activityDraftStartTime,
                                                          isCompleted: FFAppState()
                                                              .selectedActivity
                                                              .isCompleted,
                                                        ),
                                                        FFAppState()
                                                            .currentLocalUserId),
                                                editMode: true,
                                                pendingActivity:
                                                    ActivityDataStruct(
                                                  id: FFAppState()
                                                      .selectedActivity
                                                      .id,
                                                  horseId: FFAppState()
                                                      .activityDraftHorseId,
                                                  stableId: FFAppState()
                                                      .selectedActivity
                                                      .stableId,
                                                  activityType: FFAppState()
                                                      .activityDraftPendingType,
                                                  customTitle: '',
                                                  assigneeUserIds: FFAppState()
                                                      .activityDraftAssigneeUserIds,
                                                  startDate: FFAppState()
                                                      .activityDraftStartDate,
                                                  endDate: FFAppState()
                                                      .activityDraftEndDate,
                                                  startTime: FFAppState()
                                                      .activityDraftStartTime,
                                                  endTime: FFAppState()
                                                      .activityDraftEndTime,
                                                  allDay: FFAppState()
                                                      .activityDraftAllDay,
                                                  durationMinutes: FFAppState()
                                                      .activityDraftDurationMinutes,
                                                  locationType: FFAppState()
                                                      .activityDraftLocationType,
                                                  locationName: '',
                                                  serviceProviderName: _model
                                                      .activityProviderFieldTextController
                                                      .text,
                                                  notes: _model
                                                      .activityNotesFieldV2TextController
                                                      .text,
                                                  completionStatus: FFAppState()
                                                      .selectedActivity
                                                      .completionStatus,
                                                  createdAt: FFAppState()
                                                      .selectedActivity
                                                      .createdAt,
                                                  updatedAt:
                                                      getCurrentTimestamp,
                                                  title: 'Hoefsmid',
                                                  date: FFAppState()
                                                      .activityDraftStartDate,
                                                  time: FFAppState()
                                                      .activityDraftStartTime,
                                                  isCompleted: FFAppState()
                                                      .selectedActivity
                                                      .isCompleted,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ).then((value) => safeSetState(() {}));
                                    }
                                  } else {
                                    _model.formValidationMessage =
                                        functions.activityFormValidationV2(
                                            FFAppState()
                                                .activityDraftPendingType,
                                            FFAppState().activityDraftHorseId,
                                            FFAppState()
                                                .activityDraftAssigneeUserIds
                                                .toList(),
                                            FFAppState().activityDraftStartDate,
                                            FFAppState().activityDraftEndDate,
                                            FFAppState().activityDraftStartTime,
                                            FFAppState().activityDraftEndTime,
                                            FFAppState().activityDraftAllDay,
                                            FFAppState()
                                                .activityDraftDurationMinutes,
                                            FFAppState()
                                                .activityDraftLocationType,
                                            '',
                                            _model
                                                .activityProviderFieldTextController
                                                .text,
                                            '');
                                    safeSetState(() {});
                                  }
                                } else if (FFAppState()
                                        .activityDraftPendingType ==
                                    'Dierenarts') {
                                  if (functions.activityFormIsValidBooleanV2(
                                          FFAppState().activityDraftPendingType,
                                          FFAppState().activityDraftHorseId,
                                          FFAppState()
                                              .activityDraftAssigneeUserIds
                                              .toList(),
                                          FFAppState().activityDraftStartDate,
                                          FFAppState().activityDraftEndDate,
                                          FFAppState().activityDraftStartTime,
                                          FFAppState().activityDraftEndTime,
                                          FFAppState().activityDraftAllDay,
                                          FFAppState()
                                              .activityDraftDurationMinutes,
                                          FFAppState()
                                              .activityDraftLocationType,
                                          '',
                                          _model
                                              .activityProviderFieldTextController
                                              .text,
                                          '') ==
                                      true) {
                                    if (functions.activityHasConflictBooleanV2(
                                            FFAppState().activities.toList(),
                                            ActivityDataStruct(
                                              id: FFAppState()
                                                  .selectedActivity
                                                  .id,
                                              horseId: FFAppState()
                                                  .activityDraftHorseId,
                                              stableId: FFAppState()
                                                  .selectedActivity
                                                  .stableId,
                                              activityType: FFAppState()
                                                  .activityDraftPendingType,
                                              customTitle: '',
                                              assigneeUserIds: FFAppState()
                                                  .activityDraftAssigneeUserIds,
                                              startDate: FFAppState()
                                                  .activityDraftStartDate,
                                              endDate: FFAppState()
                                                  .activityDraftEndDate,
                                              startTime: FFAppState()
                                                  .activityDraftStartTime,
                                              endTime: FFAppState()
                                                  .activityDraftEndTime,
                                              allDay: FFAppState()
                                                  .activityDraftAllDay,
                                              durationMinutes: FFAppState()
                                                  .activityDraftDurationMinutes,
                                              locationType: FFAppState()
                                                  .activityDraftLocationType,
                                              locationName: '',
                                              serviceProviderName: _model
                                                  .activityProviderFieldTextController
                                                  .text,
                                              notes: _model
                                                  .activityNotesFieldV2TextController
                                                  .text,
                                              completionStatus: FFAppState()
                                                  .selectedActivity
                                                  .completionStatus,
                                              createdAt: FFAppState()
                                                  .selectedActivity
                                                  .createdAt,
                                              updatedAt: getCurrentTimestamp,
                                              title: 'Dierenarts',
                                              date: FFAppState()
                                                  .activityDraftStartDate,
                                              time: FFAppState()
                                                  .activityDraftStartTime,
                                              isCompleted: FFAppState()
                                                  .selectedActivity
                                                  .isCompleted,
                                            ),
                                            FFAppState().currentLocalUserId) ==
                                        false) {
                                      FFAppState().activitySaveInProgress =
                                          true;
                                      safeSetState(() {});
                                      _model.isSaving = true;
                                      safeSetState(() {});
                                      FFAppState().updateActivitiesAtIndex(
                                        FFAppState().selectedActivityIndex,
                                        (_) => ActivityDataStruct(
                                          id: FFAppState().selectedActivity.id,
                                          horseId:
                                              FFAppState().activityDraftHorseId,
                                          stableId: FFAppState()
                                              .selectedActivity
                                              .stableId,
                                          activityType: FFAppState()
                                              .activityDraftPendingType,
                                          customTitle: '',
                                          assigneeUserIds: FFAppState()
                                              .activityDraftAssigneeUserIds,
                                          startDate: FFAppState()
                                              .activityDraftStartDate,
                                          endDate:
                                              FFAppState().activityDraftEndDate,
                                          startTime: FFAppState()
                                              .activityDraftStartTime,
                                          endTime:
                                              FFAppState().activityDraftEndTime,
                                          allDay:
                                              FFAppState().activityDraftAllDay,
                                          durationMinutes: FFAppState()
                                              .activityDraftDurationMinutes,
                                          locationType: FFAppState()
                                              .activityDraftLocationType,
                                          locationName: '',
                                          serviceProviderName: _model
                                              .activityProviderFieldTextController
                                              .text,
                                          notes: _model
                                              .activityNotesFieldV2TextController
                                              .text,
                                          completionStatus: FFAppState()
                                              .selectedActivity
                                              .completionStatus,
                                          createdAt: FFAppState()
                                              .selectedActivity
                                              .createdAt,
                                          updatedAt: getCurrentTimestamp,
                                          title: 'Dierenarts',
                                          date: FFAppState()
                                              .activityDraftStartDate,
                                          time: FFAppState()
                                              .activityDraftStartTime,
                                          isCompleted: FFAppState()
                                              .selectedActivity
                                              .isCompleted,
                                        ),
                                      );
                                      safeSetState(() {});
                                      FFAppState().selectedActivity =
                                          ActivityDataStruct(
                                        id: FFAppState().selectedActivity.id,
                                        horseId:
                                            FFAppState().activityDraftHorseId,
                                        stableId: FFAppState()
                                            .selectedActivity
                                            .stableId,
                                        activityType: FFAppState()
                                            .activityDraftPendingType,
                                        customTitle: '',
                                        assigneeUserIds: FFAppState()
                                            .activityDraftAssigneeUserIds,
                                        startDate:
                                            FFAppState().activityDraftStartDate,
                                        endDate:
                                            FFAppState().activityDraftEndDate,
                                        startTime:
                                            FFAppState().activityDraftStartTime,
                                        endTime:
                                            FFAppState().activityDraftEndTime,
                                        allDay:
                                            FFAppState().activityDraftAllDay,
                                        durationMinutes: FFAppState()
                                            .activityDraftDurationMinutes,
                                        locationType: FFAppState()
                                            .activityDraftLocationType,
                                        locationName: '',
                                        serviceProviderName: _model
                                            .activityProviderFieldTextController
                                            .text,
                                        notes: _model
                                            .activityNotesFieldV2TextController
                                            .text,
                                        completionStatus: FFAppState()
                                            .selectedActivity
                                            .completionStatus,
                                        createdAt: FFAppState()
                                            .selectedActivity
                                            .createdAt,
                                        updatedAt: getCurrentTimestamp,
                                        title: 'Dierenarts',
                                        date:
                                            FFAppState().activityDraftStartDate,
                                        time:
                                            FFAppState().activityDraftStartTime,
                                        isCompleted: FFAppState()
                                            .selectedActivity
                                            .isCompleted,
                                      );
                                      safeSetState(() {});
                                      _model.hasChanges = false;
                                      safeSetState(() {});
                                      _model.isSaving = false;
                                      safeSetState(() {});
                                      FFAppState().activitySaveInProgress =
                                          false;
                                      safeSetState(() {});
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Activiteit opgeslagen',
                                            style: TextStyle(),
                                          ),
                                          duration:
                                              Duration(milliseconds: 4000),
                                        ),
                                      );

                                      context.pushNamed(
                                          PlanningPageWidget.routeName);
                                    } else {
                                      await showModalBottomSheet(
                                        isScrollControlled: true,
                                        context: context,
                                        builder: (context) {
                                          return GestureDetector(
                                            onTap: () {
                                              FocusScope.of(context).unfocus();
                                              FocusManager.instance.primaryFocus
                                                  ?.unfocus();
                                            },
                                            child: Padding(
                                              padding: MediaQuery.viewInsetsOf(
                                                  context),
                                              child:
                                                  ActivityConflictSheetWidget(
                                                message: functions
                                                    .activityConflictWarningV2(
                                                        FFAppState()
                                                            .activities
                                                            .toList(),
                                                        ActivityDataStruct(
                                                          id: FFAppState()
                                                              .selectedActivity
                                                              .id,
                                                          horseId: FFAppState()
                                                              .activityDraftHorseId,
                                                          stableId: FFAppState()
                                                              .selectedActivity
                                                              .stableId,
                                                          activityType: FFAppState()
                                                              .activityDraftPendingType,
                                                          customTitle: '',
                                                          assigneeUserIds:
                                                              FFAppState()
                                                                  .activityDraftAssigneeUserIds,
                                                          startDate: FFAppState()
                                                              .activityDraftStartDate,
                                                          endDate: FFAppState()
                                                              .activityDraftEndDate,
                                                          startTime: FFAppState()
                                                              .activityDraftStartTime,
                                                          endTime: FFAppState()
                                                              .activityDraftEndTime,
                                                          allDay: FFAppState()
                                                              .activityDraftAllDay,
                                                          durationMinutes:
                                                              FFAppState()
                                                                  .activityDraftDurationMinutes,
                                                          locationType: FFAppState()
                                                              .activityDraftLocationType,
                                                          locationName: '',
                                                          serviceProviderName:
                                                              _model
                                                                  .activityProviderFieldTextController
                                                                  .text,
                                                          notes: _model
                                                              .activityNotesFieldV2TextController
                                                              .text,
                                                          completionStatus:
                                                              FFAppState()
                                                                  .selectedActivity
                                                                  .completionStatus,
                                                          createdAt: FFAppState()
                                                              .selectedActivity
                                                              .createdAt,
                                                          updatedAt:
                                                              getCurrentTimestamp,
                                                          title: 'Dierenarts',
                                                          date: FFAppState()
                                                              .activityDraftStartDate,
                                                          time: FFAppState()
                                                              .activityDraftStartTime,
                                                          isCompleted: FFAppState()
                                                              .selectedActivity
                                                              .isCompleted,
                                                        ),
                                                        FFAppState()
                                                            .currentLocalUserId),
                                                editMode: true,
                                                pendingActivity:
                                                    ActivityDataStruct(
                                                  id: FFAppState()
                                                      .selectedActivity
                                                      .id,
                                                  horseId: FFAppState()
                                                      .activityDraftHorseId,
                                                  stableId: FFAppState()
                                                      .selectedActivity
                                                      .stableId,
                                                  activityType: FFAppState()
                                                      .activityDraftPendingType,
                                                  customTitle: '',
                                                  assigneeUserIds: FFAppState()
                                                      .activityDraftAssigneeUserIds,
                                                  startDate: FFAppState()
                                                      .activityDraftStartDate,
                                                  endDate: FFAppState()
                                                      .activityDraftEndDate,
                                                  startTime: FFAppState()
                                                      .activityDraftStartTime,
                                                  endTime: FFAppState()
                                                      .activityDraftEndTime,
                                                  allDay: FFAppState()
                                                      .activityDraftAllDay,
                                                  durationMinutes: FFAppState()
                                                      .activityDraftDurationMinutes,
                                                  locationType: FFAppState()
                                                      .activityDraftLocationType,
                                                  locationName: '',
                                                  serviceProviderName: _model
                                                      .activityProviderFieldTextController
                                                      .text,
                                                  notes: _model
                                                      .activityNotesFieldV2TextController
                                                      .text,
                                                  completionStatus: FFAppState()
                                                      .selectedActivity
                                                      .completionStatus,
                                                  createdAt: FFAppState()
                                                      .selectedActivity
                                                      .createdAt,
                                                  updatedAt:
                                                      getCurrentTimestamp,
                                                  title: 'Dierenarts',
                                                  date: FFAppState()
                                                      .activityDraftStartDate,
                                                  time: FFAppState()
                                                      .activityDraftStartTime,
                                                  isCompleted: FFAppState()
                                                      .selectedActivity
                                                      .isCompleted,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ).then((value) => safeSetState(() {}));
                                    }
                                  } else {
                                    _model.formValidationMessage =
                                        functions.activityFormValidationV2(
                                            FFAppState()
                                                .activityDraftPendingType,
                                            FFAppState().activityDraftHorseId,
                                            FFAppState()
                                                .activityDraftAssigneeUserIds
                                                .toList(),
                                            FFAppState().activityDraftStartDate,
                                            FFAppState().activityDraftEndDate,
                                            FFAppState().activityDraftStartTime,
                                            FFAppState().activityDraftEndTime,
                                            FFAppState().activityDraftAllDay,
                                            FFAppState()
                                                .activityDraftDurationMinutes,
                                            FFAppState()
                                                .activityDraftLocationType,
                                            '',
                                            _model
                                                .activityProviderFieldTextController
                                                .text,
                                            '');
                                    safeSetState(() {});
                                  }
                                } else if (FFAppState()
                                        .activityDraftPendingType ==
                                    'Wedstrijd') {
                                  if (functions.activityFormIsValidBooleanV2(
                                          FFAppState().activityDraftPendingType,
                                          FFAppState().activityDraftHorseId,
                                          FFAppState()
                                              .activityDraftAssigneeUserIds
                                              .toList(),
                                          FFAppState().activityDraftStartDate,
                                          FFAppState().activityDraftEndDate,
                                          FFAppState().activityDraftStartTime,
                                          FFAppState().activityDraftEndTime,
                                          FFAppState().activityDraftAllDay,
                                          FFAppState()
                                              .activityDraftDurationMinutes,
                                          FFAppState()
                                              .activityDraftLocationType,
                                          _model
                                              .activityCompetitionLocationFieldTextController
                                              .text,
                                          '',
                                          '') ==
                                      true) {
                                    if (functions.activityHasConflictBooleanV2(
                                            FFAppState().activities.toList(),
                                            ActivityDataStruct(
                                              id: FFAppState()
                                                  .selectedActivity
                                                  .id,
                                              horseId: FFAppState()
                                                  .activityDraftHorseId,
                                              stableId: FFAppState()
                                                  .selectedActivity
                                                  .stableId,
                                              activityType: FFAppState()
                                                  .activityDraftPendingType,
                                              customTitle: '',
                                              assigneeUserIds: FFAppState()
                                                  .activityDraftAssigneeUserIds,
                                              startDate: FFAppState()
                                                  .activityDraftStartDate,
                                              endDate: FFAppState()
                                                  .activityDraftEndDate,
                                              startTime: FFAppState()
                                                  .activityDraftStartTime,
                                              endTime: FFAppState()
                                                  .activityDraftEndTime,
                                              allDay: FFAppState()
                                                  .activityDraftAllDay,
                                              durationMinutes: FFAppState()
                                                  .activityDraftDurationMinutes,
                                              locationType: FFAppState()
                                                  .activityDraftLocationType,
                                              locationName: _model
                                                  .activityCompetitionLocationFieldTextController
                                                  .text,
                                              serviceProviderName: '',
                                              notes: _model
                                                  .activityNotesFieldV2TextController
                                                  .text,
                                              completionStatus: FFAppState()
                                                  .selectedActivity
                                                  .completionStatus,
                                              createdAt: FFAppState()
                                                  .selectedActivity
                                                  .createdAt,
                                              updatedAt: getCurrentTimestamp,
                                              title: 'Wedstrijd',
                                              date: FFAppState()
                                                  .activityDraftStartDate,
                                              time: FFAppState()
                                                  .activityDraftStartTime,
                                              isCompleted: FFAppState()
                                                  .selectedActivity
                                                  .isCompleted,
                                            ),
                                            FFAppState().currentLocalUserId) ==
                                        false) {
                                      FFAppState().activitySaveInProgress =
                                          true;
                                      safeSetState(() {});
                                      _model.isSaving = true;
                                      safeSetState(() {});
                                      FFAppState().updateActivitiesAtIndex(
                                        FFAppState().selectedActivityIndex,
                                        (_) => ActivityDataStruct(
                                          id: FFAppState().selectedActivity.id,
                                          horseId:
                                              FFAppState().activityDraftHorseId,
                                          stableId: FFAppState()
                                              .selectedActivity
                                              .stableId,
                                          activityType: FFAppState()
                                              .activityDraftPendingType,
                                          customTitle: '',
                                          assigneeUserIds: FFAppState()
                                              .activityDraftAssigneeUserIds,
                                          startDate: FFAppState()
                                              .activityDraftStartDate,
                                          endDate:
                                              FFAppState().activityDraftEndDate,
                                          startTime: FFAppState()
                                              .activityDraftStartTime,
                                          endTime:
                                              FFAppState().activityDraftEndTime,
                                          allDay:
                                              FFAppState().activityDraftAllDay,
                                          durationMinutes: FFAppState()
                                              .activityDraftDurationMinutes,
                                          locationType: FFAppState()
                                              .activityDraftLocationType,
                                          locationName: _model
                                              .activityCompetitionLocationFieldTextController
                                              .text,
                                          serviceProviderName: '',
                                          notes: _model
                                              .activityNotesFieldV2TextController
                                              .text,
                                          completionStatus: FFAppState()
                                              .selectedActivity
                                              .completionStatus,
                                          createdAt: FFAppState()
                                              .selectedActivity
                                              .createdAt,
                                          updatedAt: getCurrentTimestamp,
                                          title: 'Wedstrijd',
                                          date: FFAppState()
                                              .activityDraftStartDate,
                                          time: FFAppState()
                                              .activityDraftStartTime,
                                          isCompleted: FFAppState()
                                              .selectedActivity
                                              .isCompleted,
                                        ),
                                      );
                                      safeSetState(() {});
                                      FFAppState().selectedActivity =
                                          ActivityDataStruct(
                                        id: FFAppState().selectedActivity.id,
                                        horseId:
                                            FFAppState().activityDraftHorseId,
                                        stableId: FFAppState()
                                            .selectedActivity
                                            .stableId,
                                        activityType: FFAppState()
                                            .activityDraftPendingType,
                                        customTitle: '',
                                        assigneeUserIds: FFAppState()
                                            .activityDraftAssigneeUserIds,
                                        startDate:
                                            FFAppState().activityDraftStartDate,
                                        endDate:
                                            FFAppState().activityDraftEndDate,
                                        startTime:
                                            FFAppState().activityDraftStartTime,
                                        endTime:
                                            FFAppState().activityDraftEndTime,
                                        allDay:
                                            FFAppState().activityDraftAllDay,
                                        durationMinutes: FFAppState()
                                            .activityDraftDurationMinutes,
                                        locationType: FFAppState()
                                            .activityDraftLocationType,
                                        locationName: _model
                                            .activityCompetitionLocationFieldTextController
                                            .text,
                                        serviceProviderName: '',
                                        notes: _model
                                            .activityNotesFieldV2TextController
                                            .text,
                                        completionStatus: FFAppState()
                                            .selectedActivity
                                            .completionStatus,
                                        createdAt: FFAppState()
                                            .selectedActivity
                                            .createdAt,
                                        updatedAt: getCurrentTimestamp,
                                        title: 'Wedstrijd',
                                        date:
                                            FFAppState().activityDraftStartDate,
                                        time:
                                            FFAppState().activityDraftStartTime,
                                        isCompleted: FFAppState()
                                            .selectedActivity
                                            .isCompleted,
                                      );
                                      safeSetState(() {});
                                      _model.hasChanges = false;
                                      safeSetState(() {});
                                      _model.isSaving = false;
                                      safeSetState(() {});
                                      FFAppState().activitySaveInProgress =
                                          false;
                                      safeSetState(() {});
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Activiteit opgeslagen',
                                            style: TextStyle(),
                                          ),
                                          duration:
                                              Duration(milliseconds: 4000),
                                        ),
                                      );

                                      context.pushNamed(
                                          PlanningPageWidget.routeName);
                                    } else {
                                      await showModalBottomSheet(
                                        isScrollControlled: true,
                                        context: context,
                                        builder: (context) {
                                          return GestureDetector(
                                            onTap: () {
                                              FocusScope.of(context).unfocus();
                                              FocusManager.instance.primaryFocus
                                                  ?.unfocus();
                                            },
                                            child: Padding(
                                              padding: MediaQuery.viewInsetsOf(
                                                  context),
                                              child:
                                                  ActivityConflictSheetWidget(
                                                message: functions
                                                    .activityConflictWarningV2(
                                                        FFAppState()
                                                            .activities
                                                            .toList(),
                                                        ActivityDataStruct(
                                                          id: FFAppState()
                                                              .selectedActivity
                                                              .id,
                                                          horseId: FFAppState()
                                                              .activityDraftHorseId,
                                                          stableId: FFAppState()
                                                              .selectedActivity
                                                              .stableId,
                                                          activityType: FFAppState()
                                                              .activityDraftPendingType,
                                                          customTitle: '',
                                                          assigneeUserIds:
                                                              FFAppState()
                                                                  .activityDraftAssigneeUserIds,
                                                          startDate: FFAppState()
                                                              .activityDraftStartDate,
                                                          endDate: FFAppState()
                                                              .activityDraftEndDate,
                                                          startTime: FFAppState()
                                                              .activityDraftStartTime,
                                                          endTime: FFAppState()
                                                              .activityDraftEndTime,
                                                          allDay: FFAppState()
                                                              .activityDraftAllDay,
                                                          durationMinutes:
                                                              FFAppState()
                                                                  .activityDraftDurationMinutes,
                                                          locationType: FFAppState()
                                                              .activityDraftLocationType,
                                                          locationName: _model
                                                              .activityCompetitionLocationFieldTextController
                                                              .text,
                                                          serviceProviderName:
                                                              '',
                                                          notes: _model
                                                              .activityNotesFieldV2TextController
                                                              .text,
                                                          completionStatus:
                                                              FFAppState()
                                                                  .selectedActivity
                                                                  .completionStatus,
                                                          createdAt: FFAppState()
                                                              .selectedActivity
                                                              .createdAt,
                                                          updatedAt:
                                                              getCurrentTimestamp,
                                                          title: 'Wedstrijd',
                                                          date: FFAppState()
                                                              .activityDraftStartDate,
                                                          time: FFAppState()
                                                              .activityDraftStartTime,
                                                          isCompleted: FFAppState()
                                                              .selectedActivity
                                                              .isCompleted,
                                                        ),
                                                        FFAppState()
                                                            .currentLocalUserId),
                                                editMode: true,
                                                pendingActivity:
                                                    ActivityDataStruct(
                                                  id: FFAppState()
                                                      .selectedActivity
                                                      .id,
                                                  horseId: FFAppState()
                                                      .activityDraftHorseId,
                                                  stableId: FFAppState()
                                                      .selectedActivity
                                                      .stableId,
                                                  activityType: FFAppState()
                                                      .activityDraftPendingType,
                                                  customTitle: '',
                                                  assigneeUserIds: FFAppState()
                                                      .activityDraftAssigneeUserIds,
                                                  startDate: FFAppState()
                                                      .activityDraftStartDate,
                                                  endDate: FFAppState()
                                                      .activityDraftEndDate,
                                                  startTime: FFAppState()
                                                      .activityDraftStartTime,
                                                  endTime: FFAppState()
                                                      .activityDraftEndTime,
                                                  allDay: FFAppState()
                                                      .activityDraftAllDay,
                                                  durationMinutes: FFAppState()
                                                      .activityDraftDurationMinutes,
                                                  locationType: FFAppState()
                                                      .activityDraftLocationType,
                                                  locationName: _model
                                                      .activityCompetitionLocationFieldTextController
                                                      .text,
                                                  serviceProviderName: '',
                                                  notes: _model
                                                      .activityNotesFieldV2TextController
                                                      .text,
                                                  completionStatus: FFAppState()
                                                      .selectedActivity
                                                      .completionStatus,
                                                  createdAt: FFAppState()
                                                      .selectedActivity
                                                      .createdAt,
                                                  updatedAt:
                                                      getCurrentTimestamp,
                                                  title: 'Wedstrijd',
                                                  date: FFAppState()
                                                      .activityDraftStartDate,
                                                  time: FFAppState()
                                                      .activityDraftStartTime,
                                                  isCompleted: FFAppState()
                                                      .selectedActivity
                                                      .isCompleted,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ).then((value) => safeSetState(() {}));
                                    }
                                  } else {
                                    _model.formValidationMessage =
                                        functions.activityFormValidationV2(
                                            FFAppState()
                                                .activityDraftPendingType,
                                            FFAppState().activityDraftHorseId,
                                            FFAppState()
                                                .activityDraftAssigneeUserIds
                                                .toList(),
                                            FFAppState().activityDraftStartDate,
                                            FFAppState().activityDraftEndDate,
                                            FFAppState().activityDraftStartTime,
                                            FFAppState().activityDraftEndTime,
                                            FFAppState().activityDraftAllDay,
                                            FFAppState()
                                                .activityDraftDurationMinutes,
                                            FFAppState()
                                                .activityDraftLocationType,
                                            _model
                                                .activityCompetitionLocationFieldTextController
                                                .text,
                                            '',
                                            '');
                                    safeSetState(() {});
                                  }
                                } else if (FFAppState()
                                        .activityDraftPendingType ==
                                    'Overig') {
                                  if (functions.activityFormIsValidBooleanV2(
                                          FFAppState().activityDraftPendingType,
                                          FFAppState().activityDraftHorseId,
                                          FFAppState()
                                              .activityDraftAssigneeUserIds
                                              .toList(),
                                          FFAppState().activityDraftStartDate,
                                          FFAppState().activityDraftEndDate,
                                          FFAppState().activityDraftStartTime,
                                          FFAppState().activityDraftEndTime,
                                          FFAppState().activityDraftAllDay,
                                          FFAppState()
                                              .activityDraftDurationMinutes,
                                          FFAppState()
                                              .activityDraftLocationType,
                                          '',
                                          '',
                                          _model
                                              .activityCustomTitleFieldTextController
                                              .text) ==
                                      true) {
                                    if (functions.activityHasConflictBooleanV2(
                                            FFAppState().activities.toList(),
                                            ActivityDataStruct(
                                              id: FFAppState()
                                                  .selectedActivity
                                                  .id,
                                              horseId: FFAppState()
                                                  .activityDraftHorseId,
                                              stableId: FFAppState()
                                                  .selectedActivity
                                                  .stableId,
                                              activityType: FFAppState()
                                                  .activityDraftPendingType,
                                              customTitle: _model
                                                  .activityCustomTitleFieldTextController
                                                  .text,
                                              assigneeUserIds: FFAppState()
                                                  .activityDraftAssigneeUserIds,
                                              startDate: FFAppState()
                                                  .activityDraftStartDate,
                                              endDate: FFAppState()
                                                  .activityDraftEndDate,
                                              startTime: FFAppState()
                                                  .activityDraftStartTime,
                                              endTime: FFAppState()
                                                  .activityDraftEndTime,
                                              allDay: FFAppState()
                                                  .activityDraftAllDay,
                                              durationMinutes: FFAppState()
                                                  .activityDraftDurationMinutes,
                                              locationType: FFAppState()
                                                  .activityDraftLocationType,
                                              locationName: _model
                                                  .activityOtherLocationFieldTextController
                                                  .text,
                                              serviceProviderName: '',
                                              notes: _model
                                                  .activityNotesFieldV2TextController
                                                  .text,
                                              completionStatus: FFAppState()
                                                  .selectedActivity
                                                  .completionStatus,
                                              createdAt: FFAppState()
                                                  .selectedActivity
                                                  .createdAt,
                                              updatedAt: getCurrentTimestamp,
                                              title: _model
                                                  .activityCustomTitleFieldTextController
                                                  .text,
                                              date: FFAppState()
                                                  .activityDraftStartDate,
                                              time: FFAppState()
                                                  .activityDraftStartTime,
                                              isCompleted: FFAppState()
                                                  .selectedActivity
                                                  .isCompleted,
                                            ),
                                            FFAppState().currentLocalUserId) ==
                                        false) {
                                      FFAppState().activitySaveInProgress =
                                          true;
                                      safeSetState(() {});
                                      _model.isSaving = true;
                                      safeSetState(() {});
                                      FFAppState().updateActivitiesAtIndex(
                                        FFAppState().selectedActivityIndex,
                                        (_) => ActivityDataStruct(
                                          id: FFAppState().selectedActivity.id,
                                          horseId:
                                              FFAppState().activityDraftHorseId,
                                          stableId: FFAppState()
                                              .selectedActivity
                                              .stableId,
                                          activityType: FFAppState()
                                              .activityDraftPendingType,
                                          customTitle: _model
                                              .activityCustomTitleFieldTextController
                                              .text,
                                          assigneeUserIds: FFAppState()
                                              .activityDraftAssigneeUserIds,
                                          startDate: FFAppState()
                                              .activityDraftStartDate,
                                          endDate:
                                              FFAppState().activityDraftEndDate,
                                          startTime: FFAppState()
                                              .activityDraftStartTime,
                                          endTime:
                                              FFAppState().activityDraftEndTime,
                                          allDay:
                                              FFAppState().activityDraftAllDay,
                                          durationMinutes: FFAppState()
                                              .activityDraftDurationMinutes,
                                          locationType: FFAppState()
                                              .activityDraftLocationType,
                                          locationName: _model
                                              .activityOtherLocationFieldTextController
                                              .text,
                                          serviceProviderName: '',
                                          notes: _model
                                              .activityNotesFieldV2TextController
                                              .text,
                                          completionStatus: FFAppState()
                                              .selectedActivity
                                              .completionStatus,
                                          createdAt: FFAppState()
                                              .selectedActivity
                                              .createdAt,
                                          updatedAt: getCurrentTimestamp,
                                          title: _model
                                              .activityCustomTitleFieldTextController
                                              .text,
                                          date: FFAppState()
                                              .activityDraftStartDate,
                                          time: FFAppState()
                                              .activityDraftStartTime,
                                          isCompleted: FFAppState()
                                              .selectedActivity
                                              .isCompleted,
                                        ),
                                      );
                                      safeSetState(() {});
                                      FFAppState().selectedActivity =
                                          ActivityDataStruct(
                                        id: FFAppState().selectedActivity.id,
                                        horseId:
                                            FFAppState().activityDraftHorseId,
                                        stableId: FFAppState()
                                            .selectedActivity
                                            .stableId,
                                        activityType: FFAppState()
                                            .activityDraftPendingType,
                                        customTitle: _model
                                            .activityCustomTitleFieldTextController
                                            .text,
                                        assigneeUserIds: FFAppState()
                                            .activityDraftAssigneeUserIds,
                                        startDate:
                                            FFAppState().activityDraftStartDate,
                                        endDate:
                                            FFAppState().activityDraftEndDate,
                                        startTime:
                                            FFAppState().activityDraftStartTime,
                                        endTime:
                                            FFAppState().activityDraftEndTime,
                                        allDay:
                                            FFAppState().activityDraftAllDay,
                                        durationMinutes: FFAppState()
                                            .activityDraftDurationMinutes,
                                        locationType: FFAppState()
                                            .activityDraftLocationType,
                                        locationName: _model
                                            .activityOtherLocationFieldTextController
                                            .text,
                                        serviceProviderName: '',
                                        notes: _model
                                            .activityNotesFieldV2TextController
                                            .text,
                                        completionStatus: FFAppState()
                                            .selectedActivity
                                            .completionStatus,
                                        createdAt: FFAppState()
                                            .selectedActivity
                                            .createdAt,
                                        updatedAt: getCurrentTimestamp,
                                        title: _model
                                            .activityCustomTitleFieldTextController
                                            .text,
                                        date:
                                            FFAppState().activityDraftStartDate,
                                        time:
                                            FFAppState().activityDraftStartTime,
                                        isCompleted: FFAppState()
                                            .selectedActivity
                                            .isCompleted,
                                      );
                                      safeSetState(() {});
                                      _model.hasChanges = false;
                                      safeSetState(() {});
                                      _model.isSaving = false;
                                      safeSetState(() {});
                                      FFAppState().activitySaveInProgress =
                                          false;
                                      safeSetState(() {});
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Activiteit opgeslagen',
                                            style: TextStyle(),
                                          ),
                                          duration:
                                              Duration(milliseconds: 4000),
                                        ),
                                      );

                                      context.pushNamed(
                                          PlanningPageWidget.routeName);
                                    } else {
                                      await showModalBottomSheet(
                                        isScrollControlled: true,
                                        context: context,
                                        builder: (context) {
                                          return GestureDetector(
                                            onTap: () {
                                              FocusScope.of(context).unfocus();
                                              FocusManager.instance.primaryFocus
                                                  ?.unfocus();
                                            },
                                            child: Padding(
                                              padding: MediaQuery.viewInsetsOf(
                                                  context),
                                              child:
                                                  ActivityConflictSheetWidget(
                                                message: functions
                                                    .activityConflictWarningV2(
                                                        FFAppState()
                                                            .activities
                                                            .toList(),
                                                        ActivityDataStruct(
                                                          id: FFAppState()
                                                              .selectedActivity
                                                              .id,
                                                          horseId: FFAppState()
                                                              .activityDraftHorseId,
                                                          stableId: FFAppState()
                                                              .selectedActivity
                                                              .stableId,
                                                          activityType: FFAppState()
                                                              .activityDraftPendingType,
                                                          customTitle: _model
                                                              .activityCustomTitleFieldTextController
                                                              .text,
                                                          assigneeUserIds:
                                                              FFAppState()
                                                                  .activityDraftAssigneeUserIds,
                                                          startDate: FFAppState()
                                                              .activityDraftStartDate,
                                                          endDate: FFAppState()
                                                              .activityDraftEndDate,
                                                          startTime: FFAppState()
                                                              .activityDraftStartTime,
                                                          endTime: FFAppState()
                                                              .activityDraftEndTime,
                                                          allDay: FFAppState()
                                                              .activityDraftAllDay,
                                                          durationMinutes:
                                                              FFAppState()
                                                                  .activityDraftDurationMinutes,
                                                          locationType: FFAppState()
                                                              .activityDraftLocationType,
                                                          locationName: _model
                                                              .activityOtherLocationFieldTextController
                                                              .text,
                                                          serviceProviderName:
                                                              '',
                                                          notes: _model
                                                              .activityNotesFieldV2TextController
                                                              .text,
                                                          completionStatus:
                                                              FFAppState()
                                                                  .selectedActivity
                                                                  .completionStatus,
                                                          createdAt: FFAppState()
                                                              .selectedActivity
                                                              .createdAt,
                                                          updatedAt:
                                                              getCurrentTimestamp,
                                                          title: _model
                                                              .activityCustomTitleFieldTextController
                                                              .text,
                                                          date: FFAppState()
                                                              .activityDraftStartDate,
                                                          time: FFAppState()
                                                              .activityDraftStartTime,
                                                          isCompleted: FFAppState()
                                                              .selectedActivity
                                                              .isCompleted,
                                                        ),
                                                        FFAppState()
                                                            .currentLocalUserId),
                                                editMode: true,
                                                pendingActivity:
                                                    ActivityDataStruct(
                                                  id: FFAppState()
                                                      .selectedActivity
                                                      .id,
                                                  horseId: FFAppState()
                                                      .activityDraftHorseId,
                                                  stableId: FFAppState()
                                                      .selectedActivity
                                                      .stableId,
                                                  activityType: FFAppState()
                                                      .activityDraftPendingType,
                                                  customTitle: _model
                                                      .activityCustomTitleFieldTextController
                                                      .text,
                                                  assigneeUserIds: FFAppState()
                                                      .activityDraftAssigneeUserIds,
                                                  startDate: FFAppState()
                                                      .activityDraftStartDate,
                                                  endDate: FFAppState()
                                                      .activityDraftEndDate,
                                                  startTime: FFAppState()
                                                      .activityDraftStartTime,
                                                  endTime: FFAppState()
                                                      .activityDraftEndTime,
                                                  allDay: FFAppState()
                                                      .activityDraftAllDay,
                                                  durationMinutes: FFAppState()
                                                      .activityDraftDurationMinutes,
                                                  locationType: FFAppState()
                                                      .activityDraftLocationType,
                                                  locationName: _model
                                                      .activityOtherLocationFieldTextController
                                                      .text,
                                                  serviceProviderName: '',
                                                  notes: _model
                                                      .activityNotesFieldV2TextController
                                                      .text,
                                                  completionStatus: FFAppState()
                                                      .selectedActivity
                                                      .completionStatus,
                                                  createdAt: FFAppState()
                                                      .selectedActivity
                                                      .createdAt,
                                                  updatedAt:
                                                      getCurrentTimestamp,
                                                  title: _model
                                                      .activityCustomTitleFieldTextController
                                                      .text,
                                                  date: FFAppState()
                                                      .activityDraftStartDate,
                                                  time: FFAppState()
                                                      .activityDraftStartTime,
                                                  isCompleted: FFAppState()
                                                      .selectedActivity
                                                      .isCompleted,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ).then((value) => safeSetState(() {}));
                                    }
                                  } else {
                                    _model.formValidationMessage =
                                        functions.activityFormValidationV2(
                                            FFAppState()
                                                .activityDraftPendingType,
                                            FFAppState().activityDraftHorseId,
                                            FFAppState()
                                                .activityDraftAssigneeUserIds
                                                .toList(),
                                            FFAppState().activityDraftStartDate,
                                            FFAppState().activityDraftEndDate,
                                            FFAppState().activityDraftStartTime,
                                            FFAppState().activityDraftEndTime,
                                            FFAppState().activityDraftAllDay,
                                            FFAppState()
                                                .activityDraftDurationMinutes,
                                            FFAppState()
                                                .activityDraftLocationType,
                                            '',
                                            '',
                                            _model
                                                .activityCustomTitleFieldTextController
                                                .text);
                                    safeSetState(() {});
                                  }
                                }
                              } else {
                                if (FFAppState().activityDraftPendingType ==
                                    'Training') {
                                  if (functions.activityFormIsValidBooleanV2(
                                          FFAppState().activityDraftPendingType,
                                          FFAppState().activityDraftHorseId,
                                          FFAppState()
                                              .activityDraftAssigneeUserIds
                                              .toList(),
                                          FFAppState().activityDraftStartDate,
                                          FFAppState().activityDraftEndDate,
                                          FFAppState().activityDraftStartTime,
                                          FFAppState().activityDraftEndTime,
                                          FFAppState().activityDraftAllDay,
                                          FFAppState()
                                              .activityDraftDurationMinutes,
                                          FFAppState()
                                              .activityDraftLocationType,
                                          _model
                                              .activityTrainingLocationFieldTextController
                                              .text,
                                          '',
                                          '') ==
                                      true) {
                                    if (functions.activityHasConflictBooleanV2(
                                            FFAppState().activities.toList(),
                                            ActivityDataStruct(
                                              id: FFAppState().nextActivityId,
                                              horseId: FFAppState()
                                                  .activityDraftHorseId,
                                              stableId: '',
                                              activityType: FFAppState()
                                                  .activityDraftPendingType,
                                              customTitle: '',
                                              assigneeUserIds: FFAppState()
                                                  .activityDraftAssigneeUserIds,
                                              startDate: FFAppState()
                                                  .activityDraftStartDate,
                                              endDate: FFAppState()
                                                  .activityDraftEndDate,
                                              startTime: FFAppState()
                                                  .activityDraftStartTime,
                                              endTime: FFAppState()
                                                  .activityDraftEndTime,
                                              allDay: FFAppState()
                                                  .activityDraftAllDay,
                                              durationMinutes: FFAppState()
                                                  .activityDraftDurationMinutes,
                                              locationType: FFAppState()
                                                  .activityDraftLocationType,
                                              locationName: _model
                                                  .activityTrainingLocationFieldTextController
                                                  .text,
                                              serviceProviderName: '',
                                              notes: _model
                                                  .activityNotesFieldV2TextController
                                                  .text,
                                              completionStatus: 'open',
                                              createdAt: getCurrentTimestamp,
                                              updatedAt: getCurrentTimestamp,
                                              title: 'Training',
                                              date: FFAppState()
                                                  .activityDraftStartDate,
                                              time: FFAppState()
                                                  .activityDraftStartTime,
                                              isCompleted: false,
                                            ),
                                            FFAppState().currentLocalUserId) ==
                                        false) {
                                      FFAppState().activitySaveInProgress =
                                          true;
                                      safeSetState(() {});
                                      _model.isSaving = true;
                                      safeSetState(() {});
                                      FFAppState()
                                          .addToActivities(ActivityDataStruct(
                                        id: FFAppState().nextActivityId,
                                        horseId:
                                            FFAppState().activityDraftHorseId,
                                        stableId: '',
                                        activityType: FFAppState()
                                            .activityDraftPendingType,
                                        customTitle: '',
                                        assigneeUserIds: FFAppState()
                                            .activityDraftAssigneeUserIds,
                                        startDate:
                                            FFAppState().activityDraftStartDate,
                                        endDate:
                                            FFAppState().activityDraftEndDate,
                                        startTime:
                                            FFAppState().activityDraftStartTime,
                                        endTime:
                                            FFAppState().activityDraftEndTime,
                                        allDay:
                                            FFAppState().activityDraftAllDay,
                                        durationMinutes: FFAppState()
                                            .activityDraftDurationMinutes,
                                        locationType: FFAppState()
                                            .activityDraftLocationType,
                                        locationName: _model
                                            .activityTrainingLocationFieldTextController
                                            .text,
                                        serviceProviderName: '',
                                        notes: _model
                                            .activityNotesFieldV2TextController
                                            .text,
                                        completionStatus: 'open',
                                        createdAt: getCurrentTimestamp,
                                        updatedAt: getCurrentTimestamp,
                                        title: 'Training',
                                        date:
                                            FFAppState().activityDraftStartDate,
                                        time:
                                            FFAppState().activityDraftStartTime,
                                        isCompleted: false,
                                      ));
                                      safeSetState(() {});
                                      FFAppState().nextActivityId =
                                          FFAppState().nextActivityId + 1;
                                      safeSetState(() {});
                                      _model.hasChanges = false;
                                      safeSetState(() {});
                                      _model.isSaving = false;
                                      safeSetState(() {});
                                      FFAppState().activitySaveInProgress =
                                          false;
                                      safeSetState(() {});
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Activiteit opgeslagen',
                                            style: TextStyle(),
                                          ),
                                          duration:
                                              Duration(milliseconds: 4000),
                                        ),
                                      );

                                      context.pushNamed(
                                          PlanningPageWidget.routeName);
                                    } else {
                                      await showModalBottomSheet(
                                        isScrollControlled: true,
                                        context: context,
                                        builder: (context) {
                                          return GestureDetector(
                                            onTap: () {
                                              FocusScope.of(context).unfocus();
                                              FocusManager.instance.primaryFocus
                                                  ?.unfocus();
                                            },
                                            child: Padding(
                                              padding: MediaQuery.viewInsetsOf(
                                                  context),
                                              child:
                                                  ActivityConflictSheetWidget(
                                                message: functions
                                                    .activityConflictWarningV2(
                                                        FFAppState()
                                                            .activities
                                                            .toList(),
                                                        ActivityDataStruct(
                                                          id: FFAppState()
                                                              .nextActivityId,
                                                          horseId: FFAppState()
                                                              .activityDraftHorseId,
                                                          stableId: '',
                                                          activityType: FFAppState()
                                                              .activityDraftPendingType,
                                                          customTitle: '',
                                                          assigneeUserIds:
                                                              FFAppState()
                                                                  .activityDraftAssigneeUserIds,
                                                          startDate: FFAppState()
                                                              .activityDraftStartDate,
                                                          endDate: FFAppState()
                                                              .activityDraftEndDate,
                                                          startTime: FFAppState()
                                                              .activityDraftStartTime,
                                                          endTime: FFAppState()
                                                              .activityDraftEndTime,
                                                          allDay: FFAppState()
                                                              .activityDraftAllDay,
                                                          durationMinutes:
                                                              FFAppState()
                                                                  .activityDraftDurationMinutes,
                                                          locationType: FFAppState()
                                                              .activityDraftLocationType,
                                                          locationName: _model
                                                              .activityTrainingLocationFieldTextController
                                                              .text,
                                                          serviceProviderName:
                                                              '',
                                                          notes: _model
                                                              .activityNotesFieldV2TextController
                                                              .text,
                                                          completionStatus:
                                                              'open',
                                                          createdAt:
                                                              getCurrentTimestamp,
                                                          updatedAt:
                                                              getCurrentTimestamp,
                                                          title: 'Training',
                                                          date: FFAppState()
                                                              .activityDraftStartDate,
                                                          time: FFAppState()
                                                              .activityDraftStartTime,
                                                          isCompleted: false,
                                                        ),
                                                        FFAppState()
                                                            .currentLocalUserId),
                                                editMode: false,
                                                pendingActivity:
                                                    ActivityDataStruct(
                                                  id: FFAppState()
                                                      .nextActivityId,
                                                  horseId: FFAppState()
                                                      .activityDraftHorseId,
                                                  stableId: '',
                                                  activityType: FFAppState()
                                                      .activityDraftPendingType,
                                                  customTitle: '',
                                                  assigneeUserIds: FFAppState()
                                                      .activityDraftAssigneeUserIds,
                                                  startDate: FFAppState()
                                                      .activityDraftStartDate,
                                                  endDate: FFAppState()
                                                      .activityDraftEndDate,
                                                  startTime: FFAppState()
                                                      .activityDraftStartTime,
                                                  endTime: FFAppState()
                                                      .activityDraftEndTime,
                                                  allDay: FFAppState()
                                                      .activityDraftAllDay,
                                                  durationMinutes: FFAppState()
                                                      .activityDraftDurationMinutes,
                                                  locationType: FFAppState()
                                                      .activityDraftLocationType,
                                                  locationName: _model
                                                      .activityTrainingLocationFieldTextController
                                                      .text,
                                                  serviceProviderName: '',
                                                  notes: _model
                                                      .activityNotesFieldV2TextController
                                                      .text,
                                                  completionStatus: 'open',
                                                  createdAt:
                                                      getCurrentTimestamp,
                                                  updatedAt:
                                                      getCurrentTimestamp,
                                                  title: 'Training',
                                                  date: FFAppState()
                                                      .activityDraftStartDate,
                                                  time: FFAppState()
                                                      .activityDraftStartTime,
                                                  isCompleted: false,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ).then((value) => safeSetState(() {}));
                                    }
                                  } else {
                                    _model.formValidationMessage =
                                        functions.activityFormValidationV2(
                                            FFAppState()
                                                .activityDraftPendingType,
                                            FFAppState().activityDraftHorseId,
                                            FFAppState()
                                                .activityDraftAssigneeUserIds
                                                .toList(),
                                            FFAppState().activityDraftStartDate,
                                            FFAppState().activityDraftEndDate,
                                            FFAppState().activityDraftStartTime,
                                            FFAppState().activityDraftEndTime,
                                            FFAppState().activityDraftAllDay,
                                            FFAppState()
                                                .activityDraftDurationMinutes,
                                            FFAppState()
                                                .activityDraftLocationType,
                                            _model
                                                .activityTrainingLocationFieldTextController
                                                .text,
                                            '',
                                            '');
                                    safeSetState(() {});
                                  }
                                } else if (FFAppState()
                                        .activityDraftPendingType ==
                                    'Verzorging') {
                                  if (functions.activityFormIsValidBooleanV2(
                                          FFAppState().activityDraftPendingType,
                                          FFAppState().activityDraftHorseId,
                                          FFAppState()
                                              .activityDraftAssigneeUserIds
                                              .toList(),
                                          FFAppState().activityDraftStartDate,
                                          FFAppState().activityDraftEndDate,
                                          FFAppState().activityDraftStartTime,
                                          FFAppState().activityDraftEndTime,
                                          FFAppState().activityDraftAllDay,
                                          FFAppState()
                                              .activityDraftDurationMinutes,
                                          FFAppState()
                                              .activityDraftLocationType,
                                          '',
                                          '',
                                          '') ==
                                      true) {
                                    if (functions.activityHasConflictBooleanV2(
                                            FFAppState().activities.toList(),
                                            ActivityDataStruct(
                                              id: FFAppState().nextActivityId,
                                              horseId: FFAppState()
                                                  .activityDraftHorseId,
                                              stableId: '',
                                              activityType: FFAppState()
                                                  .activityDraftPendingType,
                                              customTitle: '',
                                              assigneeUserIds: FFAppState()
                                                  .activityDraftAssigneeUserIds,
                                              startDate: FFAppState()
                                                  .activityDraftStartDate,
                                              endDate: FFAppState()
                                                  .activityDraftEndDate,
                                              startTime: FFAppState()
                                                  .activityDraftStartTime,
                                              endTime: FFAppState()
                                                  .activityDraftEndTime,
                                              allDay: FFAppState()
                                                  .activityDraftAllDay,
                                              durationMinutes: FFAppState()
                                                  .activityDraftDurationMinutes,
                                              locationType: FFAppState()
                                                  .activityDraftLocationType,
                                              locationName: '',
                                              serviceProviderName: '',
                                              notes: '',
                                              completionStatus: 'open',
                                              createdAt: getCurrentTimestamp,
                                              updatedAt: getCurrentTimestamp,
                                              title: 'Verzorging',
                                              date: FFAppState()
                                                  .activityDraftStartDate,
                                              time: FFAppState()
                                                  .activityDraftStartTime,
                                              isCompleted: false,
                                            ),
                                            FFAppState().currentLocalUserId) ==
                                        false) {
                                      FFAppState().activitySaveInProgress =
                                          true;
                                      safeSetState(() {});
                                      _model.isSaving = true;
                                      safeSetState(() {});
                                      FFAppState()
                                          .addToActivities(ActivityDataStruct(
                                        id: FFAppState().nextActivityId,
                                        horseId:
                                            FFAppState().activityDraftHorseId,
                                        stableId: '',
                                        activityType: FFAppState()
                                            .activityDraftPendingType,
                                        customTitle: '',
                                        assigneeUserIds: FFAppState()
                                            .activityDraftAssigneeUserIds,
                                        startDate:
                                            FFAppState().activityDraftStartDate,
                                        endDate:
                                            FFAppState().activityDraftEndDate,
                                        startTime:
                                            FFAppState().activityDraftStartTime,
                                        endTime:
                                            FFAppState().activityDraftEndTime,
                                        allDay:
                                            FFAppState().activityDraftAllDay,
                                        durationMinutes: FFAppState()
                                            .activityDraftDurationMinutes,
                                        locationType: FFAppState()
                                            .activityDraftLocationType,
                                        locationName: '',
                                        serviceProviderName: '',
                                        notes: '',
                                        completionStatus: 'open',
                                        createdAt: getCurrentTimestamp,
                                        updatedAt: getCurrentTimestamp,
                                        title: 'Verzorging',
                                        date:
                                            FFAppState().activityDraftStartDate,
                                        time:
                                            FFAppState().activityDraftStartTime,
                                        isCompleted: false,
                                      ));
                                      safeSetState(() {});
                                      FFAppState().nextActivityId =
                                          FFAppState().nextActivityId + 1;
                                      safeSetState(() {});
                                      _model.hasChanges = false;
                                      safeSetState(() {});
                                      _model.isSaving = false;
                                      safeSetState(() {});
                                      FFAppState().activitySaveInProgress =
                                          false;
                                      safeSetState(() {});
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Activiteit opgeslagen',
                                            style: TextStyle(),
                                          ),
                                          duration:
                                              Duration(milliseconds: 4000),
                                        ),
                                      );

                                      context.pushNamed(
                                          PlanningPageWidget.routeName);
                                    } else {
                                      await showModalBottomSheet(
                                        isScrollControlled: true,
                                        context: context,
                                        builder: (context) {
                                          return GestureDetector(
                                            onTap: () {
                                              FocusScope.of(context).unfocus();
                                              FocusManager.instance.primaryFocus
                                                  ?.unfocus();
                                            },
                                            child: Padding(
                                              padding: MediaQuery.viewInsetsOf(
                                                  context),
                                              child:
                                                  ActivityConflictSheetWidget(
                                                message: functions
                                                    .activityConflictWarningV2(
                                                        FFAppState()
                                                            .activities
                                                            .toList(),
                                                        ActivityDataStruct(
                                                          id: FFAppState()
                                                              .nextActivityId,
                                                          horseId: FFAppState()
                                                              .activityDraftHorseId,
                                                          stableId: '',
                                                          activityType: FFAppState()
                                                              .activityDraftPendingType,
                                                          customTitle: '',
                                                          assigneeUserIds:
                                                              FFAppState()
                                                                  .activityDraftAssigneeUserIds,
                                                          startDate: FFAppState()
                                                              .activityDraftStartDate,
                                                          endDate: FFAppState()
                                                              .activityDraftEndDate,
                                                          startTime: FFAppState()
                                                              .activityDraftStartTime,
                                                          endTime: FFAppState()
                                                              .activityDraftEndTime,
                                                          allDay: FFAppState()
                                                              .activityDraftAllDay,
                                                          durationMinutes:
                                                              FFAppState()
                                                                  .activityDraftDurationMinutes,
                                                          locationType: FFAppState()
                                                              .activityDraftLocationType,
                                                          locationName: '',
                                                          serviceProviderName:
                                                              '',
                                                          notes: '',
                                                          completionStatus:
                                                              'open',
                                                          createdAt:
                                                              getCurrentTimestamp,
                                                          updatedAt:
                                                              getCurrentTimestamp,
                                                          title: 'Verzorging',
                                                          date: FFAppState()
                                                              .activityDraftStartDate,
                                                          time: FFAppState()
                                                              .activityDraftStartTime,
                                                          isCompleted: false,
                                                        ),
                                                        FFAppState()
                                                            .currentLocalUserId),
                                                editMode: false,
                                                pendingActivity:
                                                    ActivityDataStruct(
                                                  id: FFAppState()
                                                      .nextActivityId,
                                                  horseId: FFAppState()
                                                      .activityDraftHorseId,
                                                  stableId: '',
                                                  activityType: FFAppState()
                                                      .activityDraftPendingType,
                                                  customTitle: '',
                                                  assigneeUserIds: FFAppState()
                                                      .activityDraftAssigneeUserIds,
                                                  startDate: FFAppState()
                                                      .activityDraftStartDate,
                                                  endDate: FFAppState()
                                                      .activityDraftEndDate,
                                                  startTime: FFAppState()
                                                      .activityDraftStartTime,
                                                  endTime: FFAppState()
                                                      .activityDraftEndTime,
                                                  allDay: FFAppState()
                                                      .activityDraftAllDay,
                                                  durationMinutes: FFAppState()
                                                      .activityDraftDurationMinutes,
                                                  locationType: FFAppState()
                                                      .activityDraftLocationType,
                                                  locationName: '',
                                                  serviceProviderName: '',
                                                  notes: '',
                                                  completionStatus: 'open',
                                                  createdAt:
                                                      getCurrentTimestamp,
                                                  updatedAt:
                                                      getCurrentTimestamp,
                                                  title: 'Verzorging',
                                                  date: FFAppState()
                                                      .activityDraftStartDate,
                                                  time: FFAppState()
                                                      .activityDraftStartTime,
                                                  isCompleted: false,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ).then((value) => safeSetState(() {}));
                                    }
                                  } else {
                                    _model.formValidationMessage =
                                        functions.activityFormValidationV2(
                                            FFAppState()
                                                .activityDraftPendingType,
                                            FFAppState().activityDraftHorseId,
                                            FFAppState()
                                                .activityDraftAssigneeUserIds
                                                .toList(),
                                            FFAppState().activityDraftStartDate,
                                            FFAppState().activityDraftEndDate,
                                            FFAppState().activityDraftStartTime,
                                            FFAppState().activityDraftEndTime,
                                            FFAppState().activityDraftAllDay,
                                            FFAppState()
                                                .activityDraftDurationMinutes,
                                            FFAppState()
                                                .activityDraftLocationType,
                                            '',
                                            '',
                                            '');
                                    safeSetState(() {});
                                  }
                                } else if (FFAppState()
                                        .activityDraftPendingType ==
                                    'Hoefsmid') {
                                  if (functions.activityFormIsValidBooleanV2(
                                          FFAppState().activityDraftPendingType,
                                          FFAppState().activityDraftHorseId,
                                          FFAppState()
                                              .activityDraftAssigneeUserIds
                                              .toList(),
                                          FFAppState().activityDraftStartDate,
                                          FFAppState().activityDraftEndDate,
                                          FFAppState().activityDraftStartTime,
                                          FFAppState().activityDraftEndTime,
                                          FFAppState().activityDraftAllDay,
                                          FFAppState()
                                              .activityDraftDurationMinutes,
                                          FFAppState()
                                              .activityDraftLocationType,
                                          '',
                                          _model
                                              .activityProviderFieldTextController
                                              .text,
                                          '') ==
                                      true) {
                                    if (functions.activityHasConflictBooleanV2(
                                            FFAppState().activities.toList(),
                                            ActivityDataStruct(
                                              id: FFAppState().nextActivityId,
                                              horseId: FFAppState()
                                                  .activityDraftHorseId,
                                              stableId: '',
                                              activityType: FFAppState()
                                                  .activityDraftPendingType,
                                              customTitle: '',
                                              assigneeUserIds: FFAppState()
                                                  .activityDraftAssigneeUserIds,
                                              startDate: FFAppState()
                                                  .activityDraftStartDate,
                                              endDate: FFAppState()
                                                  .activityDraftEndDate,
                                              startTime: FFAppState()
                                                  .activityDraftStartTime,
                                              endTime: FFAppState()
                                                  .activityDraftEndTime,
                                              allDay: FFAppState()
                                                  .activityDraftAllDay,
                                              durationMinutes: FFAppState()
                                                  .activityDraftDurationMinutes,
                                              locationType: FFAppState()
                                                  .activityDraftLocationType,
                                              locationName: '',
                                              serviceProviderName: _model
                                                  .activityProviderFieldTextController
                                                  .text,
                                              notes: _model
                                                  .activityNotesFieldV2TextController
                                                  .text,
                                              completionStatus: 'open',
                                              createdAt: getCurrentTimestamp,
                                              updatedAt: getCurrentTimestamp,
                                              title: 'Hoefsmid',
                                              date: FFAppState()
                                                  .activityDraftStartDate,
                                              time: FFAppState()
                                                  .activityDraftStartTime,
                                              isCompleted: false,
                                            ),
                                            FFAppState().currentLocalUserId) ==
                                        false) {
                                      FFAppState().activitySaveInProgress =
                                          true;
                                      safeSetState(() {});
                                      _model.isSaving = true;
                                      safeSetState(() {});
                                      FFAppState()
                                          .addToActivities(ActivityDataStruct(
                                        id: FFAppState().nextActivityId,
                                        horseId:
                                            FFAppState().activityDraftHorseId,
                                        stableId: '',
                                        activityType: FFAppState()
                                            .activityDraftPendingType,
                                        customTitle: '',
                                        assigneeUserIds: FFAppState()
                                            .activityDraftAssigneeUserIds,
                                        startDate:
                                            FFAppState().activityDraftStartDate,
                                        endDate:
                                            FFAppState().activityDraftEndDate,
                                        startTime:
                                            FFAppState().activityDraftStartTime,
                                        endTime:
                                            FFAppState().activityDraftEndTime,
                                        allDay:
                                            FFAppState().activityDraftAllDay,
                                        durationMinutes: FFAppState()
                                            .activityDraftDurationMinutes,
                                        locationType: FFAppState()
                                            .activityDraftLocationType,
                                        locationName: '',
                                        serviceProviderName: _model
                                            .activityProviderFieldTextController
                                            .text,
                                        notes: _model
                                            .activityNotesFieldV2TextController
                                            .text,
                                        completionStatus: 'open',
                                        createdAt: getCurrentTimestamp,
                                        updatedAt: getCurrentTimestamp,
                                        title: 'Hoefsmid',
                                        date:
                                            FFAppState().activityDraftStartDate,
                                        time:
                                            FFAppState().activityDraftStartTime,
                                        isCompleted: false,
                                      ));
                                      safeSetState(() {});
                                      FFAppState().nextActivityId =
                                          FFAppState().nextActivityId + 1;
                                      safeSetState(() {});
                                      _model.hasChanges = false;
                                      safeSetState(() {});
                                      _model.isSaving = false;
                                      safeSetState(() {});
                                      FFAppState().activitySaveInProgress =
                                          false;
                                      safeSetState(() {});
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Activiteit opgeslagen',
                                            style: TextStyle(),
                                          ),
                                          duration:
                                              Duration(milliseconds: 4000),
                                        ),
                                      );

                                      context.pushNamed(
                                          PlanningPageWidget.routeName);
                                    } else {
                                      await showModalBottomSheet(
                                        isScrollControlled: true,
                                        context: context,
                                        builder: (context) {
                                          return GestureDetector(
                                            onTap: () {
                                              FocusScope.of(context).unfocus();
                                              FocusManager.instance.primaryFocus
                                                  ?.unfocus();
                                            },
                                            child: Padding(
                                              padding: MediaQuery.viewInsetsOf(
                                                  context),
                                              child:
                                                  ActivityConflictSheetWidget(
                                                message: functions
                                                    .activityConflictWarningV2(
                                                        FFAppState()
                                                            .activities
                                                            .toList(),
                                                        ActivityDataStruct(
                                                          id: FFAppState()
                                                              .nextActivityId,
                                                          horseId: FFAppState()
                                                              .activityDraftHorseId,
                                                          stableId: '',
                                                          activityType: FFAppState()
                                                              .activityDraftPendingType,
                                                          customTitle: '',
                                                          assigneeUserIds:
                                                              FFAppState()
                                                                  .activityDraftAssigneeUserIds,
                                                          startDate: FFAppState()
                                                              .activityDraftStartDate,
                                                          endDate: FFAppState()
                                                              .activityDraftEndDate,
                                                          startTime: FFAppState()
                                                              .activityDraftStartTime,
                                                          endTime: FFAppState()
                                                              .activityDraftEndTime,
                                                          allDay: FFAppState()
                                                              .activityDraftAllDay,
                                                          durationMinutes:
                                                              FFAppState()
                                                                  .activityDraftDurationMinutes,
                                                          locationType: FFAppState()
                                                              .activityDraftLocationType,
                                                          locationName: '',
                                                          serviceProviderName:
                                                              _model
                                                                  .activityProviderFieldTextController
                                                                  .text,
                                                          notes: _model
                                                              .activityNotesFieldV2TextController
                                                              .text,
                                                          completionStatus:
                                                              'open',
                                                          createdAt:
                                                              getCurrentTimestamp,
                                                          updatedAt:
                                                              getCurrentTimestamp,
                                                          title: 'Hoefsmid',
                                                          date: FFAppState()
                                                              .activityDraftStartDate,
                                                          time: FFAppState()
                                                              .activityDraftStartTime,
                                                          isCompleted: false,
                                                        ),
                                                        FFAppState()
                                                            .currentLocalUserId),
                                                editMode: false,
                                                pendingActivity:
                                                    ActivityDataStruct(
                                                  id: FFAppState()
                                                      .nextActivityId,
                                                  horseId: FFAppState()
                                                      .activityDraftHorseId,
                                                  stableId: '',
                                                  activityType: FFAppState()
                                                      .activityDraftPendingType,
                                                  customTitle: '',
                                                  assigneeUserIds: FFAppState()
                                                      .activityDraftAssigneeUserIds,
                                                  startDate: FFAppState()
                                                      .activityDraftStartDate,
                                                  endDate: FFAppState()
                                                      .activityDraftEndDate,
                                                  startTime: FFAppState()
                                                      .activityDraftStartTime,
                                                  endTime: FFAppState()
                                                      .activityDraftEndTime,
                                                  allDay: FFAppState()
                                                      .activityDraftAllDay,
                                                  durationMinutes: FFAppState()
                                                      .activityDraftDurationMinutes,
                                                  locationType: FFAppState()
                                                      .activityDraftLocationType,
                                                  locationName: '',
                                                  serviceProviderName: _model
                                                      .activityProviderFieldTextController
                                                      .text,
                                                  notes: _model
                                                      .activityNotesFieldV2TextController
                                                      .text,
                                                  completionStatus: 'open',
                                                  createdAt:
                                                      getCurrentTimestamp,
                                                  updatedAt:
                                                      getCurrentTimestamp,
                                                  title: 'Hoefsmid',
                                                  date: FFAppState()
                                                      .activityDraftStartDate,
                                                  time: FFAppState()
                                                      .activityDraftStartTime,
                                                  isCompleted: false,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ).then((value) => safeSetState(() {}));
                                    }
                                  } else {
                                    _model.formValidationMessage =
                                        functions.activityFormValidationV2(
                                            FFAppState()
                                                .activityDraftPendingType,
                                            FFAppState().activityDraftHorseId,
                                            FFAppState()
                                                .activityDraftAssigneeUserIds
                                                .toList(),
                                            FFAppState().activityDraftStartDate,
                                            FFAppState().activityDraftEndDate,
                                            FFAppState().activityDraftStartTime,
                                            FFAppState().activityDraftEndTime,
                                            FFAppState().activityDraftAllDay,
                                            FFAppState()
                                                .activityDraftDurationMinutes,
                                            FFAppState()
                                                .activityDraftLocationType,
                                            '',
                                            _model
                                                .activityProviderFieldTextController
                                                .text,
                                            '');
                                    safeSetState(() {});
                                  }
                                } else if (FFAppState()
                                        .activityDraftPendingType ==
                                    'Dierenarts') {
                                  if (functions.activityFormIsValidBooleanV2(
                                          FFAppState().activityDraftPendingType,
                                          FFAppState().activityDraftHorseId,
                                          FFAppState()
                                              .activityDraftAssigneeUserIds
                                              .toList(),
                                          FFAppState().activityDraftStartDate,
                                          FFAppState().activityDraftEndDate,
                                          FFAppState().activityDraftStartTime,
                                          FFAppState().activityDraftEndTime,
                                          FFAppState().activityDraftAllDay,
                                          FFAppState()
                                              .activityDraftDurationMinutes,
                                          FFAppState()
                                              .activityDraftLocationType,
                                          '',
                                          _model
                                              .activityProviderFieldTextController
                                              .text,
                                          '') ==
                                      true) {
                                    if (functions.activityHasConflictBooleanV2(
                                            FFAppState().activities.toList(),
                                            ActivityDataStruct(
                                              id: FFAppState().nextActivityId,
                                              horseId: FFAppState()
                                                  .activityDraftHorseId,
                                              stableId: '',
                                              activityType: FFAppState()
                                                  .activityDraftPendingType,
                                              customTitle: '',
                                              assigneeUserIds: FFAppState()
                                                  .activityDraftAssigneeUserIds,
                                              startDate: FFAppState()
                                                  .activityDraftStartDate,
                                              endDate: FFAppState()
                                                  .activityDraftEndDate,
                                              startTime: FFAppState()
                                                  .activityDraftStartTime,
                                              endTime: FFAppState()
                                                  .activityDraftEndTime,
                                              allDay: FFAppState()
                                                  .activityDraftAllDay,
                                              durationMinutes: FFAppState()
                                                  .activityDraftDurationMinutes,
                                              locationType: FFAppState()
                                                  .activityDraftLocationType,
                                              locationName: '',
                                              serviceProviderName: _model
                                                  .activityProviderFieldTextController
                                                  .text,
                                              notes: _model
                                                  .activityNotesFieldV2TextController
                                                  .text,
                                              completionStatus: 'open',
                                              createdAt: getCurrentTimestamp,
                                              updatedAt: getCurrentTimestamp,
                                              title: 'Dierenarts',
                                              date: FFAppState()
                                                  .activityDraftStartDate,
                                              time: FFAppState()
                                                  .activityDraftStartTime,
                                              isCompleted: false,
                                            ),
                                            FFAppState().currentLocalUserId) ==
                                        false) {
                                      FFAppState().activitySaveInProgress =
                                          true;
                                      safeSetState(() {});
                                      _model.isSaving = true;
                                      safeSetState(() {});
                                      FFAppState()
                                          .addToActivities(ActivityDataStruct(
                                        id: FFAppState().nextActivityId,
                                        horseId:
                                            FFAppState().activityDraftHorseId,
                                        stableId: '',
                                        activityType: FFAppState()
                                            .activityDraftPendingType,
                                        customTitle: '',
                                        assigneeUserIds: FFAppState()
                                            .activityDraftAssigneeUserIds,
                                        startDate:
                                            FFAppState().activityDraftStartDate,
                                        endDate:
                                            FFAppState().activityDraftEndDate,
                                        startTime:
                                            FFAppState().activityDraftStartTime,
                                        endTime:
                                            FFAppState().activityDraftEndTime,
                                        allDay:
                                            FFAppState().activityDraftAllDay,
                                        durationMinutes: FFAppState()
                                            .activityDraftDurationMinutes,
                                        locationType: FFAppState()
                                            .activityDraftLocationType,
                                        locationName: '',
                                        serviceProviderName: _model
                                            .activityProviderFieldTextController
                                            .text,
                                        notes: _model
                                            .activityNotesFieldV2TextController
                                            .text,
                                        completionStatus: 'open',
                                        createdAt: getCurrentTimestamp,
                                        updatedAt: getCurrentTimestamp,
                                        title: 'Dierenarts',
                                        date:
                                            FFAppState().activityDraftStartDate,
                                        time:
                                            FFAppState().activityDraftStartTime,
                                        isCompleted: false,
                                      ));
                                      safeSetState(() {});
                                      FFAppState().nextActivityId =
                                          FFAppState().nextActivityId + 1;
                                      safeSetState(() {});
                                      _model.hasChanges = false;
                                      safeSetState(() {});
                                      _model.isSaving = false;
                                      safeSetState(() {});
                                      FFAppState().activitySaveInProgress =
                                          false;
                                      safeSetState(() {});
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Activiteit opgeslagen',
                                            style: TextStyle(),
                                          ),
                                          duration:
                                              Duration(milliseconds: 4000),
                                        ),
                                      );

                                      context.pushNamed(
                                          PlanningPageWidget.routeName);
                                    } else {
                                      await showModalBottomSheet(
                                        isScrollControlled: true,
                                        context: context,
                                        builder: (context) {
                                          return GestureDetector(
                                            onTap: () {
                                              FocusScope.of(context).unfocus();
                                              FocusManager.instance.primaryFocus
                                                  ?.unfocus();
                                            },
                                            child: Padding(
                                              padding: MediaQuery.viewInsetsOf(
                                                  context),
                                              child:
                                                  ActivityConflictSheetWidget(
                                                message: functions
                                                    .activityConflictWarningV2(
                                                        FFAppState()
                                                            .activities
                                                            .toList(),
                                                        ActivityDataStruct(
                                                          id: FFAppState()
                                                              .nextActivityId,
                                                          horseId: FFAppState()
                                                              .activityDraftHorseId,
                                                          stableId: '',
                                                          activityType: FFAppState()
                                                              .activityDraftPendingType,
                                                          customTitle: '',
                                                          assigneeUserIds:
                                                              FFAppState()
                                                                  .activityDraftAssigneeUserIds,
                                                          startDate: FFAppState()
                                                              .activityDraftStartDate,
                                                          endDate: FFAppState()
                                                              .activityDraftEndDate,
                                                          startTime: FFAppState()
                                                              .activityDraftStartTime,
                                                          endTime: FFAppState()
                                                              .activityDraftEndTime,
                                                          allDay: FFAppState()
                                                              .activityDraftAllDay,
                                                          durationMinutes:
                                                              FFAppState()
                                                                  .activityDraftDurationMinutes,
                                                          locationType: FFAppState()
                                                              .activityDraftLocationType,
                                                          locationName: '',
                                                          serviceProviderName:
                                                              _model
                                                                  .activityProviderFieldTextController
                                                                  .text,
                                                          notes: _model
                                                              .activityNotesFieldV2TextController
                                                              .text,
                                                          completionStatus:
                                                              'open',
                                                          createdAt:
                                                              getCurrentTimestamp,
                                                          updatedAt:
                                                              getCurrentTimestamp,
                                                          title: 'Dierenarts',
                                                          date: FFAppState()
                                                              .activityDraftStartDate,
                                                          time: FFAppState()
                                                              .activityDraftStartTime,
                                                          isCompleted: false,
                                                        ),
                                                        FFAppState()
                                                            .currentLocalUserId),
                                                editMode: false,
                                                pendingActivity:
                                                    ActivityDataStruct(
                                                  id: FFAppState()
                                                      .nextActivityId,
                                                  horseId: FFAppState()
                                                      .activityDraftHorseId,
                                                  stableId: '',
                                                  activityType: FFAppState()
                                                      .activityDraftPendingType,
                                                  customTitle: '',
                                                  assigneeUserIds: FFAppState()
                                                      .activityDraftAssigneeUserIds,
                                                  startDate: FFAppState()
                                                      .activityDraftStartDate,
                                                  endDate: FFAppState()
                                                      .activityDraftEndDate,
                                                  startTime: FFAppState()
                                                      .activityDraftStartTime,
                                                  endTime: FFAppState()
                                                      .activityDraftEndTime,
                                                  allDay: FFAppState()
                                                      .activityDraftAllDay,
                                                  durationMinutes: FFAppState()
                                                      .activityDraftDurationMinutes,
                                                  locationType: FFAppState()
                                                      .activityDraftLocationType,
                                                  locationName: '',
                                                  serviceProviderName: _model
                                                      .activityProviderFieldTextController
                                                      .text,
                                                  notes: _model
                                                      .activityNotesFieldV2TextController
                                                      .text,
                                                  completionStatus: 'open',
                                                  createdAt:
                                                      getCurrentTimestamp,
                                                  updatedAt:
                                                      getCurrentTimestamp,
                                                  title: 'Dierenarts',
                                                  date: FFAppState()
                                                      .activityDraftStartDate,
                                                  time: FFAppState()
                                                      .activityDraftStartTime,
                                                  isCompleted: false,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ).then((value) => safeSetState(() {}));
                                    }
                                  } else {
                                    _model.formValidationMessage =
                                        functions.activityFormValidationV2(
                                            FFAppState()
                                                .activityDraftPendingType,
                                            FFAppState().activityDraftHorseId,
                                            FFAppState()
                                                .activityDraftAssigneeUserIds
                                                .toList(),
                                            FFAppState().activityDraftStartDate,
                                            FFAppState().activityDraftEndDate,
                                            FFAppState().activityDraftStartTime,
                                            FFAppState().activityDraftEndTime,
                                            FFAppState().activityDraftAllDay,
                                            FFAppState()
                                                .activityDraftDurationMinutes,
                                            FFAppState()
                                                .activityDraftLocationType,
                                            '',
                                            _model
                                                .activityProviderFieldTextController
                                                .text,
                                            '');
                                    safeSetState(() {});
                                  }
                                } else if (FFAppState()
                                        .activityDraftPendingType ==
                                    'Wedstrijd') {
                                  if (functions.activityFormIsValidBooleanV2(
                                          FFAppState().activityDraftPendingType,
                                          FFAppState().activityDraftHorseId,
                                          FFAppState()
                                              .activityDraftAssigneeUserIds
                                              .toList(),
                                          FFAppState().activityDraftStartDate,
                                          FFAppState().activityDraftEndDate,
                                          FFAppState().activityDraftStartTime,
                                          FFAppState().activityDraftEndTime,
                                          FFAppState().activityDraftAllDay,
                                          FFAppState()
                                              .activityDraftDurationMinutes,
                                          FFAppState()
                                              .activityDraftLocationType,
                                          _model
                                              .activityCompetitionLocationFieldTextController
                                              .text,
                                          '',
                                          '') ==
                                      true) {
                                    if (functions.activityHasConflictBooleanV2(
                                            FFAppState().activities.toList(),
                                            ActivityDataStruct(
                                              id: FFAppState().nextActivityId,
                                              horseId: FFAppState()
                                                  .activityDraftHorseId,
                                              stableId: '',
                                              activityType: FFAppState()
                                                  .activityDraftPendingType,
                                              customTitle: '',
                                              assigneeUserIds: FFAppState()
                                                  .activityDraftAssigneeUserIds,
                                              startDate: FFAppState()
                                                  .activityDraftStartDate,
                                              endDate: FFAppState()
                                                  .activityDraftEndDate,
                                              startTime: FFAppState()
                                                  .activityDraftStartTime,
                                              endTime: FFAppState()
                                                  .activityDraftEndTime,
                                              allDay: FFAppState()
                                                  .activityDraftAllDay,
                                              durationMinutes: FFAppState()
                                                  .activityDraftDurationMinutes,
                                              locationType: FFAppState()
                                                  .activityDraftLocationType,
                                              locationName: _model
                                                  .activityCompetitionLocationFieldTextController
                                                  .text,
                                              serviceProviderName: '',
                                              notes: _model
                                                  .activityNotesFieldV2TextController
                                                  .text,
                                              completionStatus: 'open',
                                              createdAt: getCurrentTimestamp,
                                              updatedAt: getCurrentTimestamp,
                                              title: 'Wedstrijd',
                                              date: FFAppState()
                                                  .activityDraftStartDate,
                                              time: FFAppState()
                                                  .activityDraftStartTime,
                                              isCompleted: false,
                                            ),
                                            FFAppState().currentLocalUserId) ==
                                        false) {
                                      FFAppState().activitySaveInProgress =
                                          true;
                                      safeSetState(() {});
                                      _model.isSaving = true;
                                      safeSetState(() {});
                                      FFAppState()
                                          .addToActivities(ActivityDataStruct(
                                        id: FFAppState().nextActivityId,
                                        horseId:
                                            FFAppState().activityDraftHorseId,
                                        stableId: '',
                                        activityType: FFAppState()
                                            .activityDraftPendingType,
                                        customTitle: '',
                                        assigneeUserIds: FFAppState()
                                            .activityDraftAssigneeUserIds,
                                        startDate:
                                            FFAppState().activityDraftStartDate,
                                        endDate:
                                            FFAppState().activityDraftEndDate,
                                        startTime:
                                            FFAppState().activityDraftStartTime,
                                        endTime:
                                            FFAppState().activityDraftEndTime,
                                        allDay:
                                            FFAppState().activityDraftAllDay,
                                        durationMinutes: FFAppState()
                                            .activityDraftDurationMinutes,
                                        locationType: FFAppState()
                                            .activityDraftLocationType,
                                        locationName: _model
                                            .activityCompetitionLocationFieldTextController
                                            .text,
                                        serviceProviderName: '',
                                        notes: _model
                                            .activityNotesFieldV2TextController
                                            .text,
                                        completionStatus: 'open',
                                        createdAt: getCurrentTimestamp,
                                        updatedAt: getCurrentTimestamp,
                                        title: 'Wedstrijd',
                                        date:
                                            FFAppState().activityDraftStartDate,
                                        time:
                                            FFAppState().activityDraftStartTime,
                                        isCompleted: false,
                                      ));
                                      safeSetState(() {});
                                      FFAppState().nextActivityId =
                                          FFAppState().nextActivityId + 1;
                                      safeSetState(() {});
                                      _model.hasChanges = false;
                                      safeSetState(() {});
                                      _model.isSaving = false;
                                      safeSetState(() {});
                                      FFAppState().activitySaveInProgress =
                                          false;
                                      safeSetState(() {});
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Activiteit opgeslagen',
                                            style: TextStyle(),
                                          ),
                                          duration:
                                              Duration(milliseconds: 4000),
                                        ),
                                      );

                                      context.pushNamed(
                                          PlanningPageWidget.routeName);
                                    } else {
                                      await showModalBottomSheet(
                                        isScrollControlled: true,
                                        context: context,
                                        builder: (context) {
                                          return GestureDetector(
                                            onTap: () {
                                              FocusScope.of(context).unfocus();
                                              FocusManager.instance.primaryFocus
                                                  ?.unfocus();
                                            },
                                            child: Padding(
                                              padding: MediaQuery.viewInsetsOf(
                                                  context),
                                              child:
                                                  ActivityConflictSheetWidget(
                                                message: functions
                                                    .activityConflictWarningV2(
                                                        FFAppState()
                                                            .activities
                                                            .toList(),
                                                        ActivityDataStruct(
                                                          id: FFAppState()
                                                              .nextActivityId,
                                                          horseId: FFAppState()
                                                              .activityDraftHorseId,
                                                          stableId: '',
                                                          activityType: FFAppState()
                                                              .activityDraftPendingType,
                                                          customTitle: '',
                                                          assigneeUserIds:
                                                              FFAppState()
                                                                  .activityDraftAssigneeUserIds,
                                                          startDate: FFAppState()
                                                              .activityDraftStartDate,
                                                          endDate: FFAppState()
                                                              .activityDraftEndDate,
                                                          startTime: FFAppState()
                                                              .activityDraftStartTime,
                                                          endTime: FFAppState()
                                                              .activityDraftEndTime,
                                                          allDay: FFAppState()
                                                              .activityDraftAllDay,
                                                          durationMinutes:
                                                              FFAppState()
                                                                  .activityDraftDurationMinutes,
                                                          locationType: FFAppState()
                                                              .activityDraftLocationType,
                                                          locationName: _model
                                                              .activityCompetitionLocationFieldTextController
                                                              .text,
                                                          serviceProviderName:
                                                              '',
                                                          notes: _model
                                                              .activityNotesFieldV2TextController
                                                              .text,
                                                          completionStatus:
                                                              'open',
                                                          createdAt:
                                                              getCurrentTimestamp,
                                                          updatedAt:
                                                              getCurrentTimestamp,
                                                          title: 'Wedstrijd',
                                                          date: FFAppState()
                                                              .activityDraftStartDate,
                                                          time: FFAppState()
                                                              .activityDraftStartTime,
                                                          isCompleted: false,
                                                        ),
                                                        FFAppState()
                                                            .currentLocalUserId),
                                                editMode: false,
                                                pendingActivity:
                                                    ActivityDataStruct(
                                                  id: FFAppState()
                                                      .nextActivityId,
                                                  horseId: FFAppState()
                                                      .activityDraftHorseId,
                                                  stableId: '',
                                                  activityType: FFAppState()
                                                      .activityDraftPendingType,
                                                  customTitle: '',
                                                  assigneeUserIds: FFAppState()
                                                      .activityDraftAssigneeUserIds,
                                                  startDate: FFAppState()
                                                      .activityDraftStartDate,
                                                  endDate: FFAppState()
                                                      .activityDraftEndDate,
                                                  startTime: FFAppState()
                                                      .activityDraftStartTime,
                                                  endTime: FFAppState()
                                                      .activityDraftEndTime,
                                                  allDay: FFAppState()
                                                      .activityDraftAllDay,
                                                  durationMinutes: FFAppState()
                                                      .activityDraftDurationMinutes,
                                                  locationType: FFAppState()
                                                      .activityDraftLocationType,
                                                  locationName: _model
                                                      .activityCompetitionLocationFieldTextController
                                                      .text,
                                                  serviceProviderName: '',
                                                  notes: _model
                                                      .activityNotesFieldV2TextController
                                                      .text,
                                                  completionStatus: 'open',
                                                  createdAt:
                                                      getCurrentTimestamp,
                                                  updatedAt:
                                                      getCurrentTimestamp,
                                                  title: 'Wedstrijd',
                                                  date: FFAppState()
                                                      .activityDraftStartDate,
                                                  time: FFAppState()
                                                      .activityDraftStartTime,
                                                  isCompleted: false,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ).then((value) => safeSetState(() {}));
                                    }
                                  } else {
                                    _model.formValidationMessage =
                                        functions.activityFormValidationV2(
                                            FFAppState()
                                                .activityDraftPendingType,
                                            FFAppState().activityDraftHorseId,
                                            FFAppState()
                                                .activityDraftAssigneeUserIds
                                                .toList(),
                                            FFAppState().activityDraftStartDate,
                                            FFAppState().activityDraftEndDate,
                                            FFAppState().activityDraftStartTime,
                                            FFAppState().activityDraftEndTime,
                                            FFAppState().activityDraftAllDay,
                                            FFAppState()
                                                .activityDraftDurationMinutes,
                                            FFAppState()
                                                .activityDraftLocationType,
                                            _model
                                                .activityCompetitionLocationFieldTextController
                                                .text,
                                            '',
                                            '');
                                    safeSetState(() {});
                                  }
                                } else if (FFAppState()
                                        .activityDraftPendingType ==
                                    'Overig') {
                                  if (functions.activityFormIsValidBooleanV2(
                                          FFAppState().activityDraftPendingType,
                                          FFAppState().activityDraftHorseId,
                                          FFAppState()
                                              .activityDraftAssigneeUserIds
                                              .toList(),
                                          FFAppState().activityDraftStartDate,
                                          FFAppState().activityDraftEndDate,
                                          FFAppState().activityDraftStartTime,
                                          FFAppState().activityDraftEndTime,
                                          FFAppState().activityDraftAllDay,
                                          FFAppState()
                                              .activityDraftDurationMinutes,
                                          FFAppState()
                                              .activityDraftLocationType,
                                          '',
                                          '',
                                          _model
                                              .activityCustomTitleFieldTextController
                                              .text) ==
                                      true) {
                                    if (functions.activityHasConflictBooleanV2(
                                            FFAppState().activities.toList(),
                                            ActivityDataStruct(
                                              id: FFAppState().nextActivityId,
                                              horseId: FFAppState()
                                                  .activityDraftHorseId,
                                              stableId: '',
                                              activityType: FFAppState()
                                                  .activityDraftPendingType,
                                              customTitle: _model
                                                  .activityCustomTitleFieldTextController
                                                  .text,
                                              assigneeUserIds: FFAppState()
                                                  .activityDraftAssigneeUserIds,
                                              startDate: FFAppState()
                                                  .activityDraftStartDate,
                                              endDate: FFAppState()
                                                  .activityDraftEndDate,
                                              startTime: FFAppState()
                                                  .activityDraftStartTime,
                                              endTime: FFAppState()
                                                  .activityDraftEndTime,
                                              allDay: FFAppState()
                                                  .activityDraftAllDay,
                                              durationMinutes: FFAppState()
                                                  .activityDraftDurationMinutes,
                                              locationType: FFAppState()
                                                  .activityDraftLocationType,
                                              locationName: _model
                                                  .activityOtherLocationFieldTextController
                                                  .text,
                                              serviceProviderName: '',
                                              notes: _model
                                                  .activityNotesFieldV2TextController
                                                  .text,
                                              completionStatus: 'open',
                                              createdAt: getCurrentTimestamp,
                                              updatedAt: getCurrentTimestamp,
                                              title: _model
                                                  .activityCustomTitleFieldTextController
                                                  .text,
                                              date: FFAppState()
                                                  .activityDraftStartDate,
                                              time: FFAppState()
                                                  .activityDraftStartTime,
                                              isCompleted: false,
                                            ),
                                            FFAppState().currentLocalUserId) ==
                                        false) {
                                      FFAppState().activitySaveInProgress =
                                          true;
                                      safeSetState(() {});
                                      _model.isSaving = true;
                                      safeSetState(() {});
                                      FFAppState()
                                          .addToActivities(ActivityDataStruct(
                                        id: FFAppState().nextActivityId,
                                        horseId:
                                            FFAppState().activityDraftHorseId,
                                        stableId: '',
                                        activityType: FFAppState()
                                            .activityDraftPendingType,
                                        customTitle: _model
                                            .activityCustomTitleFieldTextController
                                            .text,
                                        assigneeUserIds: FFAppState()
                                            .activityDraftAssigneeUserIds,
                                        startDate:
                                            FFAppState().activityDraftStartDate,
                                        endDate:
                                            FFAppState().activityDraftEndDate,
                                        startTime:
                                            FFAppState().activityDraftStartTime,
                                        endTime:
                                            FFAppState().activityDraftEndTime,
                                        allDay:
                                            FFAppState().activityDraftAllDay,
                                        durationMinutes: FFAppState()
                                            .activityDraftDurationMinutes,
                                        locationType: FFAppState()
                                            .activityDraftLocationType,
                                        locationName: _model
                                            .activityOtherLocationFieldTextController
                                            .text,
                                        serviceProviderName: '',
                                        notes: _model
                                            .activityNotesFieldV2TextController
                                            .text,
                                        completionStatus: 'open',
                                        createdAt: getCurrentTimestamp,
                                        updatedAt: getCurrentTimestamp,
                                        title: _model
                                            .activityCustomTitleFieldTextController
                                            .text,
                                        date:
                                            FFAppState().activityDraftStartDate,
                                        time:
                                            FFAppState().activityDraftStartTime,
                                        isCompleted: false,
                                      ));
                                      safeSetState(() {});
                                      FFAppState().nextActivityId =
                                          FFAppState().nextActivityId + 1;
                                      safeSetState(() {});
                                      _model.hasChanges = false;
                                      safeSetState(() {});
                                      _model.isSaving = false;
                                      safeSetState(() {});
                                      FFAppState().activitySaveInProgress =
                                          false;
                                      safeSetState(() {});
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Activiteit opgeslagen',
                                            style: TextStyle(),
                                          ),
                                          duration:
                                              Duration(milliseconds: 4000),
                                        ),
                                      );

                                      context.pushNamed(
                                          PlanningPageWidget.routeName);
                                    } else {
                                      await showModalBottomSheet(
                                        isScrollControlled: true,
                                        context: context,
                                        builder: (context) {
                                          return GestureDetector(
                                            onTap: () {
                                              FocusScope.of(context).unfocus();
                                              FocusManager.instance.primaryFocus
                                                  ?.unfocus();
                                            },
                                            child: Padding(
                                              padding: MediaQuery.viewInsetsOf(
                                                  context),
                                              child:
                                                  ActivityConflictSheetWidget(
                                                message: functions
                                                    .activityConflictWarningV2(
                                                        FFAppState()
                                                            .activities
                                                            .toList(),
                                                        ActivityDataStruct(
                                                          id: FFAppState()
                                                              .nextActivityId,
                                                          horseId: FFAppState()
                                                              .activityDraftHorseId,
                                                          stableId: '',
                                                          activityType: FFAppState()
                                                              .activityDraftPendingType,
                                                          customTitle: _model
                                                              .activityCustomTitleFieldTextController
                                                              .text,
                                                          assigneeUserIds:
                                                              FFAppState()
                                                                  .activityDraftAssigneeUserIds,
                                                          startDate: FFAppState()
                                                              .activityDraftStartDate,
                                                          endDate: FFAppState()
                                                              .activityDraftEndDate,
                                                          startTime: FFAppState()
                                                              .activityDraftStartTime,
                                                          endTime: FFAppState()
                                                              .activityDraftEndTime,
                                                          allDay: FFAppState()
                                                              .activityDraftAllDay,
                                                          durationMinutes:
                                                              FFAppState()
                                                                  .activityDraftDurationMinutes,
                                                          locationType: FFAppState()
                                                              .activityDraftLocationType,
                                                          locationName: _model
                                                              .activityOtherLocationFieldTextController
                                                              .text,
                                                          serviceProviderName:
                                                              '',
                                                          notes: _model
                                                              .activityNotesFieldV2TextController
                                                              .text,
                                                          completionStatus:
                                                              'open',
                                                          createdAt:
                                                              getCurrentTimestamp,
                                                          updatedAt:
                                                              getCurrentTimestamp,
                                                          title: _model
                                                              .activityCustomTitleFieldTextController
                                                              .text,
                                                          date: FFAppState()
                                                              .activityDraftStartDate,
                                                          time: FFAppState()
                                                              .activityDraftStartTime,
                                                          isCompleted: false,
                                                        ),
                                                        FFAppState()
                                                            .currentLocalUserId),
                                                editMode: false,
                                                pendingActivity:
                                                    ActivityDataStruct(
                                                  id: FFAppState()
                                                      .nextActivityId,
                                                  horseId: FFAppState()
                                                      .activityDraftHorseId,
                                                  stableId: '',
                                                  activityType: FFAppState()
                                                      .activityDraftPendingType,
                                                  customTitle: _model
                                                      .activityCustomTitleFieldTextController
                                                      .text,
                                                  assigneeUserIds: FFAppState()
                                                      .activityDraftAssigneeUserIds,
                                                  startDate: FFAppState()
                                                      .activityDraftStartDate,
                                                  endDate: FFAppState()
                                                      .activityDraftEndDate,
                                                  startTime: FFAppState()
                                                      .activityDraftStartTime,
                                                  endTime: FFAppState()
                                                      .activityDraftEndTime,
                                                  allDay: FFAppState()
                                                      .activityDraftAllDay,
                                                  durationMinutes: FFAppState()
                                                      .activityDraftDurationMinutes,
                                                  locationType: FFAppState()
                                                      .activityDraftLocationType,
                                                  locationName: _model
                                                      .activityOtherLocationFieldTextController
                                                      .text,
                                                  serviceProviderName: '',
                                                  notes: _model
                                                      .activityNotesFieldV2TextController
                                                      .text,
                                                  completionStatus: 'open',
                                                  createdAt:
                                                      getCurrentTimestamp,
                                                  updatedAt:
                                                      getCurrentTimestamp,
                                                  title: _model
                                                      .activityCustomTitleFieldTextController
                                                      .text,
                                                  date: FFAppState()
                                                      .activityDraftStartDate,
                                                  time: FFAppState()
                                                      .activityDraftStartTime,
                                                  isCompleted: false,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ).then((value) => safeSetState(() {}));
                                    }
                                  } else {
                                    _model.formValidationMessage =
                                        functions.activityFormValidationV2(
                                            FFAppState()
                                                .activityDraftPendingType,
                                            FFAppState().activityDraftHorseId,
                                            FFAppState()
                                                .activityDraftAssigneeUserIds
                                                .toList(),
                                            FFAppState().activityDraftStartDate,
                                            FFAppState().activityDraftEndDate,
                                            FFAppState().activityDraftStartTime,
                                            FFAppState().activityDraftEndTime,
                                            FFAppState().activityDraftAllDay,
                                            FFAppState()
                                                .activityDraftDurationMinutes,
                                            FFAppState()
                                                .activityDraftLocationType,
                                            '',
                                            '',
                                            _model
                                                .activityCustomTitleFieldTextController
                                                .text);
                                    safeSetState(() {});
                                  }
                                }
                              }
                            }
                          },
                          text: 'Activiteit opslaan',
                          icon: Icon(
                            Icons.check,
                            size: 20.0,
                          ),
                          options: FFButtonOptions(
                            width: double.infinity,
                            height: 50.0,
                            padding: EdgeInsetsDirectional.fromSTEB(
                                0.0, 0.0, 0.0, 0.0),
                            iconPadding: EdgeInsetsDirectional.fromSTEB(
                                0.0, 0.0, 0.0, 0.0),
                            iconColor: FlutterFlowTheme.of(context).primary,
                            color: FlutterFlowTheme.of(context).secondary,
                            textStyle: TextStyle(
                              color: FlutterFlowTheme.of(context).primary,
                            ),
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                      if (_model.isSaving ?? true)
                        Container(
                          height: 50.0,
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context).accent2,
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          alignment: AlignmentDirectional(0.0, 0.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.sync,
                                color: FlutterFlowTheme.of(context).secondary,
                                size: 19.0,
                              ),
                              Text(
                                'Activiteit opslaan...',
                                style: FlutterFlowTheme.of(context)
                                    .labelMedium
                                    .override(
                                      font: GoogleFonts.inter(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .labelMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .labelMedium
                                            .fontStyle,
                                      ),
                                      color: FlutterFlowTheme.of(context)
                                          .primaryText,
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .labelMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .labelMedium
                                          .fontStyle,
                                    ),
                              ),
                            ].divide(SizedBox(width: 9.0)),
                          ),
                        ),
                    ].divide(SizedBox(height: 8.0)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

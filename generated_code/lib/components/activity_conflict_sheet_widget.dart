import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'activity_conflict_sheet_model.dart';
export 'activity_conflict_sheet_model.dart';

/// Non-blocking double-booking warning with adjust and explicit save choices.
class ActivityConflictSheetWidget extends StatefulWidget {
  const ActivityConflictSheetWidget({
    super.key,
    this.message,
    this.editMode,
    this.pendingActivity,
  });

  final String? message;
  final bool? editMode;
  final ActivityDataStruct? pendingActivity;

  @override
  State<ActivityConflictSheetWidget> createState() =>
      _ActivityConflictSheetWidgetState();
}

class _ActivityConflictSheetWidgetState
    extends State<ActivityConflictSheetWidget> {
  late ActivityConflictSheetModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ActivityConflictSheetModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return Container(
      height: 390.0,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).primaryBackground,
      ),
      child: Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.event_busy,
              color: FlutterFlowTheme.of(context).warning,
              size: 32.0,
            ),
            Text(
              'Mogelijke dubbele planning',
              textAlign: TextAlign.center,
              style: FlutterFlowTheme.of(context).titleLarge.override(
                    font: GoogleFonts.interTight(
                      fontWeight:
                          FlutterFlowTheme.of(context).titleLarge.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).titleLarge.fontStyle,
                    ),
                    color: FlutterFlowTheme.of(context).primaryText,
                    letterSpacing: 0.0,
                    fontWeight:
                        FlutterFlowTheme.of(context).titleLarge.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).titleLarge.fontStyle,
                  ),
            ),
            Container(
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).accent2,
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(
                  color: FlutterFlowTheme.of(context).warning,
                  width: 0.8,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(14.0),
                child: Text(
                  widget!.message!,
                  textAlign: TextAlign.center,
                  maxLines: 6,
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        font: GoogleFonts.inter(
                          fontWeight: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                        ),
                        color: FlutterFlowTheme.of(context).primaryText,
                        letterSpacing: 0.0,
                        fontWeight:
                            FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            FFButtonWidget(
              onPressed: () async {
                context.pop();
              },
              text: 'Planning aanpassen',
              options: FFButtonOptions(
                width: double.infinity,
                height: 46.0,
                padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                iconPadding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                color: Colors.transparent,
                textStyle: TextStyle(
                  color: FlutterFlowTheme.of(context).primary,
                ),
                elevation: 0.0,
                borderSide: BorderSide(
                  color: FlutterFlowTheme.of(context).primary,
                  width: 1.0,
                ),
                borderRadius: BorderRadius.circular(10.0),
              ),
            ),
            FFButtonWidget(
              onPressed: () async {
                if (!FFAppState().activitySaveInProgress) {
                  FFAppState().activitySaveInProgress = true;
                  safeSetState(() {});
                  if (widget!.editMode!) {
                    FFAppState().updateActivitiesAtIndex(
                      FFAppState().selectedActivityIndex,
                      (_) => widget!.pendingActivity!,
                    );
                    safeSetState(() {});
                    FFAppState().selectedActivity = widget!.pendingActivity!;
                    safeSetState(() {});
                    FFAppState().activitySaveInProgress = false;
                    safeSetState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Activiteit opgeslagen met planningsconflict',
                          style: TextStyle(),
                        ),
                        duration: Duration(milliseconds: 4000),
                      ),
                    );

                    context.pushNamed(PlanningPageWidget.routeName);
                  } else {
                    FFAppState().addToActivities(widget!.pendingActivity!);
                    safeSetState(() {});
                    FFAppState().nextActivityId =
                        FFAppState().nextActivityId + 1;
                    safeSetState(() {});
                    FFAppState().activitySaveInProgress = false;
                    safeSetState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Activiteit opgeslagen met planningsconflict',
                          style: TextStyle(),
                        ),
                        duration: Duration(milliseconds: 4000),
                      ),
                    );

                    context.pushNamed(PlanningPageWidget.routeName);
                  }
                }
              },
              text: 'Toch opslaan',
              options: FFButtonOptions(
                width: double.infinity,
                height: 46.0,
                padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                iconPadding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                color: FlutterFlowTheme.of(context).secondary,
                textStyle: TextStyle(
                  color: FlutterFlowTheme.of(context).primary,
                ),
                borderRadius: BorderRadius.circular(10.0),
              ),
            ),
          ].divide(SizedBox(height: 14.0)),
        ),
      ),
    );
  }
}

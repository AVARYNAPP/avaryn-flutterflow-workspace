import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'activity_type_change_sheet_model.dart';
export 'activity_type_change_sheet_model.dart';

/// Confirms a type change before type-specific draft values are cleared.
class ActivityTypeChangeSheetWidget extends StatefulWidget {
  const ActivityTypeChangeSheetWidget({
    super.key,
    this.nextType,
  });

  final String? nextType;

  @override
  State<ActivityTypeChangeSheetWidget> createState() =>
      _ActivityTypeChangeSheetWidgetState();
}

class _ActivityTypeChangeSheetWidgetState
    extends State<ActivityTypeChangeSheetWidget> {
  late ActivityTypeChangeSheetModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ActivityTypeChangeSheetModel());

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
      height: 330.0,
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
              Icons.warning_amber,
              color: FlutterFlowTheme.of(context).warning,
              size: 30.0,
            ),
            Text(
              'Type activiteit wijzigen?',
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
            Text(
              'Type-afhankelijke datum-, tijd-, duur- en locatiekeuzes worden gewist. Paard en toegewezen personen blijven behouden.',
              textAlign: TextAlign.center,
              maxLines: 5,
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    font: GoogleFonts.inter(
                      fontWeight:
                          FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    ),
                    color: FlutterFlowTheme.of(context).secondaryText,
                    letterSpacing: 0.0,
                    fontWeight:
                        FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
            FFButtonWidget(
              onPressed: () async {
                FFAppState().activityDraftPendingType = widget!.nextType!;
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
                context.pop();
              },
              text: 'Wijzigen en velden wissen',
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
            FFButtonWidget(
              onPressed: () async {
                context.pop();
              },
              text: 'Annuleren',
              options: FFButtonOptions(
                width: double.infinity,
                height: 44.0,
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
          ].divide(SizedBox(height: 14.0)),
        ),
      ),
    );
  }
}

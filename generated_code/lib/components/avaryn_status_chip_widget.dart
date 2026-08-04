import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'avaryn_status_chip_model.dart';
export 'avaryn_status_chip_model.dart';

/// Accessible AVARYN status chip with icon and text semantics.
class AvarynStatusChipWidget extends StatefulWidget {
  const AvarynStatusChipWidget({
    super.key,
    this.label,
    this.urgent,
  });

  final String? label;
  final bool? urgent;

  @override
  State<AvarynStatusChipWidget> createState() => _AvarynStatusChipWidgetState();
}

class _AvarynStatusChipWidgetState extends State<AvarynStatusChipWidget> {
  late AvarynStatusChipModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AvarynStatusChipModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: AlignmentDirectional(0.0, 0.0),
      children: [
        if (widget!.urgent ?? true)
          Container(
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).accent3,
              borderRadius: BorderRadius.circular(999.0),
            ),
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(10.0, 6.0, 10.0, 6.0),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: FlutterFlowTheme.of(context).error,
                    size: 14.0,
                  ),
                  Text(
                    widget!.label!,
                    maxLines: 1,
                    style: FlutterFlowTheme.of(context).labelSmall.override(
                          font: GoogleFonts.inter(
                            fontWeight: FlutterFlowTheme.of(context)
                                .labelSmall
                                .fontWeight,
                            fontStyle: FlutterFlowTheme.of(context)
                                .labelSmall
                                .fontStyle,
                          ),
                          color: FlutterFlowTheme.of(context).primaryText,
                          letterSpacing: 0.0,
                          fontWeight: FlutterFlowTheme.of(context)
                              .labelSmall
                              .fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).labelSmall.fontStyle,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ].divide(SizedBox(width: 6.0)),
              ),
            ),
          ),
        if (!widget!.urgent!)
          Container(
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).warning,
              borderRadius: BorderRadius.circular(999.0),
            ),
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(10.0, 6.0, 10.0, 6.0),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: FlutterFlowTheme.of(context).success,
                    size: 14.0,
                  ),
                  Text(
                    widget!.label!,
                    maxLines: 1,
                    style: FlutterFlowTheme.of(context).labelSmall.override(
                          font: GoogleFonts.inter(
                            fontWeight: FlutterFlowTheme.of(context)
                                .labelSmall
                                .fontWeight,
                            fontStyle: FlutterFlowTheme.of(context)
                                .labelSmall
                                .fontStyle,
                          ),
                          color: FlutterFlowTheme.of(context).success,
                          letterSpacing: 0.0,
                          fontWeight: FlutterFlowTheme.of(context)
                              .labelSmall
                              .fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).labelSmall.fontStyle,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ].divide(SizedBox(width: 6.0)),
              ),
            ),
          ),
      ],
    );
  }
}

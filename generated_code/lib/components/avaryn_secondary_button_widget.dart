import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'avaryn_secondary_button_model.dart';
export 'avaryn_secondary_button_model.dart';

/// Restrained AVARYN secondary action for supporting decisions.
class AvarynSecondaryButtonWidget extends StatefulWidget {
  const AvarynSecondaryButtonWidget({
    super.key,
    this.label,
    this.onTapAction,
  });

  final String? label;
  final Future Function()? onTapAction;

  @override
  State<AvarynSecondaryButtonWidget> createState() =>
      _AvarynSecondaryButtonWidgetState();
}

class _AvarynSecondaryButtonWidgetState
    extends State<AvarynSecondaryButtonWidget> {
  late AvarynSecondaryButtonModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AvarynSecondaryButtonModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(16.0, 11.0, 16.0, 11.0),
      child: FFButtonWidget(
        onPressed: () async {
          await widget.onTapAction?.call();
        },
        text: widget!.label!,
        icon: Icon(
          Icons.arrow_forward,
          size: 20.0,
        ),
        options: FFButtonOptions(
          width: double.infinity,
          height: 48.0,
          padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
          iconPadding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
          iconColor: FlutterFlowTheme.of(context).primaryText,
          color: Colors.transparent,
          textStyle: TextStyle(
            color: FlutterFlowTheme.of(context).primaryText,
          ),
          elevation: 0.0,
          borderSide: BorderSide(
            color: FlutterFlowTheme.of(context).alternate,
            width: 1.0,
          ),
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
    );
  }
}

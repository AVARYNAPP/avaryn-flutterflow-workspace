import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'avaryn_primary_button_model.dart';
export 'avaryn_primary_button_model.dart';

/// Obsidian AVARYN primary action with premium pressed and hover states.
class AvarynPrimaryButtonWidget extends StatefulWidget {
  const AvarynPrimaryButtonWidget({
    super.key,
    this.label,
    this.onTapAction,
  });

  final String? label;
  final Future Function()? onTapAction;

  @override
  State<AvarynPrimaryButtonWidget> createState() =>
      _AvarynPrimaryButtonWidgetState();
}

class _AvarynPrimaryButtonWidgetState extends State<AvarynPrimaryButtonWidget> {
  late AvarynPrimaryButtonModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AvarynPrimaryButtonModel());

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
      padding: EdgeInsetsDirectional.fromSTEB(18.0, 12.0, 18.0, 12.0),
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
          height: 50.0,
          padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
          iconPadding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
          iconColor: FlutterFlowTheme.of(context).primaryBackground,
          color: FlutterFlowTheme.of(context).secondary,
          textStyle: TextStyle(
            color: FlutterFlowTheme.of(context).primaryBackground,
          ),
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
    );
  }
}

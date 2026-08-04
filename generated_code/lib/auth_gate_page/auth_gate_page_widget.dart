import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'auth_gate_page_model.dart';
export 'auth_gate_page_model.dart';

/// Deterministic AVARYN startup gate that resolves session, profile,
/// onboarding and local account scope.
class AuthGatePageWidget extends StatefulWidget {
  const AuthGatePageWidget({super.key});

  static String routeName = 'AuthGatePage';
  static String routePath = '/auth/gate';

  @override
  State<AuthGatePageWidget> createState() => _AuthGatePageWidgetState();
}

class _AuthGatePageWidgetState extends State<AuthGatePageWidget> {
  late AuthGatePageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AuthGatePageModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).primaryBackground,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 1,
                  child: Container(
                    child: custom_widgets.AvarynAccountRuntime(
                      mode: 'gate',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import '/backend/schema/structs/index.dart';
import '/components/activity_delete_sheet_v2_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import 'activity_detail_page_widget.dart' show ActivityDetailPageWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ActivityDetailPageModel
    extends FlutterFlowModel<ActivityDetailPageWidget> {
  ///  State fields for stateful widgets in this page.

  // State field(s) for ActivityDetailPageCompactCanvas widget.
  ScrollController? activityDetailPageCompactCanvasScrollController;

  @override
  void initState(BuildContext context) {
    activityDetailPageCompactCanvasScrollController = ScrollController();
  }

  @override
  void dispose() {
    activityDetailPageCompactCanvasScrollController?.dispose();
  }
}

import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/index.dart';
import 'horse_form_page_widget.dart' show HorseFormPageWidget;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class HorseFormPageModel extends FlutterFlowModel<HorseFormPageWidget> {
  ///  Local state fields for this page.

  int? formStep = 0;

  DateTime? formBirthDate;

  String? formSex = '';

  String? formColor = '';

  String? formDiscipline = 'Dressuur';

  String? formCompetitionClass = '';

  String? formPhotoData = '';

  bool? isSaving = false;

  String? formOfficialName = '';

  String? formCallName = '';

  String? formBreed = '';

  String? formPassportNumber = '';

  String? formChipNumber = '';

  String? formOwner = '';

  String? formRider = '';

  String? formStableLocation = '';

  String? formNotes = '';

  String? formBirthDay = '';

  String? formBirthMonth = '';

  String? formBirthYear = '';

  DateTime? formPassportExpiryDate;

  String? formPassportExpiryDay = '';

  String? formPassportExpiryMonth = '';

  String? formPassportExpiryYear = '';

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}

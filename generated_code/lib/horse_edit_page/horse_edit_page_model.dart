import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/index.dart';
import 'horse_edit_page_widget.dart' show HorseEditPageWidget;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class HorseEditPageModel extends FlutterFlowModel<HorseEditPageWidget> {
  ///  Local state fields for this page.

  String? editOfficialName = '';

  String? editCallName = '';

  DateTime? editBirthDate;

  String? editSex = '';

  String? editBreed = '';

  String? editColor = '';

  String? editDiscipline = '';

  String? editCompetitionClass = '';

  String? editPassportNumber = '';

  String? editChipNumber = '';

  String? editOwner = '';

  String? editRider = '';

  String? editStableLocation = '';

  String? editPhotoData = '';

  String? editNotes = '';

  bool? hasChanges = false;

  bool? isSaving = false;

  bool? showNameError = false;

  bool? showSexError = false;

  bool? showDiscardConfirm = false;

  String? editBirthDay = '';

  String? editBirthMonth = '';

  String? editBirthYear = '';

  DateTime? editPassportExpiryDate;

  String? editPassportExpiryDay = '';

  String? editPassportExpiryMonth = '';

  String? editPassportExpiryYear = '';

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}

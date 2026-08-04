import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import '/flutter_flow/custom_functions.dart';
import '/flutter_flow/lat_lng.dart';
import '/flutter_flow/place.dart';
import '/flutter_flow/uploaded_file.dart';
import '/backend/schema/structs/index.dart';
import '/backend/supabase/supabase.dart';
import '/auth/supabase_auth/auth_util.dart';

/// Central, backwards-compatible display title for every activity type.
String? activityDisplayTitleV2(ActivityDataStruct? activity) {
  final type = activity?.activityType.trim() ?? '';
  final custom = activity?.customTitle.trim() ?? '';
  final legacy = activity?.title.trim() ?? '';
  final provider = activity?.serviceProviderName.trim() ?? '';
  switch (type) {
    case 'Training':
      return 'Training';
    case 'Verzorging':
      return 'Verzorging';
    case 'Hoefsmid':
      return provider.isEmpty ? 'Hoefsmid' : 'Hoefsmid · $provider';
    case 'Dierenarts':
      return provider.isEmpty ? 'Dierenarts' : 'Dierenarts · $provider';
    case 'Wedstrijd':
      return 'Wedstrijd';
    case 'Overig':
      return custom.isNotEmpty
          ? custom
          : (legacy.isNotEmpty ? legacy : 'Overige activiteit');
    default:
      return legacy.isNotEmpty
          ? legacy
          : (type.isNotEmpty ? type : 'Activiteit');
  }
}

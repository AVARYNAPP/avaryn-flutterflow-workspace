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

/// Converts practical Dutch care-duration choices to stored minutes.
int? activityDurationMinutesV2(
  String? choice,
  String? customMinutes,
) {
  switch ((choice ?? '').trim()) {
    case '15 minuten':
      return 15;
    case '30 minuten':
      return 30;
    case '45 minuten':
      return 45;
    case '1 uur':
      return 60;
    case '1,5 uur':
      return 90;
    case '2 uur':
      return 120;
    case 'Aangepast':
      return int.tryParse((customMinutes ?? '').trim()) ?? 0;
    default:
      return 0;
  }
}

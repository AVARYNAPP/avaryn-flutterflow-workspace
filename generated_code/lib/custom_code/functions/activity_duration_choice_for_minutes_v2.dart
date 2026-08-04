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

/// Maps stored duration minutes back to the practical care-duration selector.
String? activityDurationChoiceForMinutesV2(int? minutes) {
  switch (minutes ?? 0) {
    case 15:
      return '15 minuten';
    case 30:
      return '30 minuten';
    case 45:
      return '45 minuten';
    case 60:
      return '1 uur';
    case 90:
      return '1,5 uur';
    case 120:
      return '2 uur';
    default:
      return (minutes ?? 0) > 0 ? 'Aangepast' : '';
  }
}

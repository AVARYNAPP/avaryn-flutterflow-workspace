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

/// Formats a single activity date or inclusive competition date range.
String? activityDateRangeLabelV2(ActivityDataStruct? activity) {
  DateTime? start = activity?.startDate ?? activity?.date;
  DateTime? end = activity?.endDate ?? start;
  if (start == null) return 'Datum onbekend';
  const months = <String>[
    'jan',
    'feb',
    'mrt',
    'apr',
    'mei',
    'jun',
    'jul',
    'aug',
    'sep',
    'okt',
    'nov',
    'dec',
  ];
  String day(DateTime value) =>
      '${value.day} ${months[value.month - 1]} ${value.year}';
  if (end == null ||
      (start.year == end.year &&
          start.month == end.month &&
          start.day == end.day)) {
    return day(start);
  }
  return '${day(start)} – ${day(end)}';
}

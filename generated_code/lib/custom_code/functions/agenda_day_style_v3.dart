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

/// Classifies calendar cells for adjacent-month, start, end and
/// inclusive-range styling.
String? agendaDayStyleV3(
  DateTime? date,
  DateTime? month,
  DateTime? startDate,
  DateTime? endDate,
) {
  if (date == null) return 'normal';
  bool same(DateTime? a, DateTime? b) =>
      a != null &&
      b != null &&
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day;
  final start = startDate == null
      ? null
      : DateTime(startDate.year, startDate.month, startDate.day);
  final end = endDate == null
      ? null
      : DateTime(endDate.year, endDate.month, endDate.day);
  final day = DateTime(date.year, date.month, date.day);
  if (same(day, start) && same(day, end)) return 'startEnd';
  if (same(day, start)) return 'start';
  if (same(day, end)) return 'end';
  if (start != null && end != null && day.isAfter(start) && day.isBefore(end)) {
    return 'range';
  }
  if (month != null && (date.year != month.year || date.month != month.month)) {
    return 'outside';
  }
  return 'normal';
}

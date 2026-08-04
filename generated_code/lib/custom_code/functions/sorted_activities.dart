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

/// Sorts activities chronologically, placing untimed entries after timed
/// entries on the same date.
List<ActivityDataStruct>? sortedActivities(
    List<ActivityDataStruct>? activities) {
  final result = List<ActivityDataStruct>.from(
    activities ?? const <ActivityDataStruct>[],
  );
  result.sort((a, b) {
    final aDate = a.date;
    final bDate = b.date;
    if (aDate == null && bDate == null) return a.id.compareTo(b.id);
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    final aDay = DateTime(aDate.year, aDate.month, aDate.day);
    final bDay = DateTime(bDate.year, bDate.month, bDate.day);
    final dateCompare = aDay.compareTo(bDay);
    if (dateCompare != 0) return dateCompare;
    final aTime = a.time;
    final bTime = b.time;
    if (aTime == null && bTime == null) return a.id.compareTo(b.id);
    if (aTime == null) return 1;
    if (bTime == null) return -1;
    final aMinutes = aTime.hour * 60 + aTime.minute;
    final bMinutes = bTime.hour * 60 + bTime.minute;
    final timeCompare = aMinutes.compareTo(bMinutes);
    return timeCompare != 0 ? timeCompare : a.id.compareTo(b.id);
  });
  return result;
}

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

/// Marks the first chronologically sorted activity in each calendar-date
/// group.
bool? activityIsFirstOnDate(
  List<ActivityDataStruct>? activities,
  int? activityId,
) {
  final values = List<ActivityDataStruct>.from(
    activities ?? const <ActivityDataStruct>[],
  );
  values.sort((a, b) {
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
  final index = values.indexWhere((item) => item.id == activityId);
  if (index < 0) return false;
  if (index == 0) return true;
  final current = values[index].date;
  final previous = values[index - 1].date;
  if (current == null) return previous != null;
  if (previous == null) return true;
  return current.year != previous.year ||
      current.month != previous.month ||
      current.day != previous.day;
}

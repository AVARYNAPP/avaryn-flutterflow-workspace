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

/// Returns activities occurring today, including one shared multi-day
/// competition record.
List<ActivityDataStruct>? todayActivitiesV2(
    List<ActivityDataStruct>? activities) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final result = <ActivityDataStruct>[];
  for (final item in activities ?? const <ActivityDataStruct>[]) {
    final rawStart = item.startDate ?? item.date;
    if (rawStart == null) continue;
    final rawEnd = item.endDate ?? rawStart;
    final start = DateTime(rawStart.year, rawStart.month, rawStart.day);
    final end = DateTime(rawEnd.year, rawEnd.month, rawEnd.day);
    if (!today.isBefore(start) && !today.isAfter(end)) result.add(item);
  }
  result.sort((a, b) {
    final at = a.startTime ?? a.time;
    final bt = b.startTime ?? b.time;
    if (at == null && bt == null) return a.id.compareTo(b.id);
    if (at == null) return 1;
    if (bt == null) return -1;
    return (at.hour * 60 + at.minute).compareTo(bt.hour * 60 + bt.minute);
  });
  return result;
}

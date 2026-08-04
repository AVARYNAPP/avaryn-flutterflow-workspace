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

/// Shows a compact non-nested activity summary for the selected agenda day.
String? agendaPlannedSummaryV3(
  List<ActivityDataStruct>? activities,
  DateTime? selectedDate,
) {
  if (selectedDate == null) return '';
  final selected =
      DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
  final matches = <ActivityDataStruct>[];
  for (final item in activities ?? const <ActivityDataStruct>[]) {
    final rawStart = item.startDate ?? item.date;
    if (rawStart == null) continue;
    final rawEnd = item.endDate ?? rawStart;
    final start = DateTime(rawStart.year, rawStart.month, rawStart.day);
    final end = DateTime(rawEnd.year, rawEnd.month, rawEnd.day);
    if (!selected.isBefore(start) && !selected.isAfter(end)) matches.add(item);
  }
  matches.sort((a, b) {
    final at = a.startTime ?? a.time;
    final bt = b.startTime ?? b.time;
    if (at == null && bt == null) return a.id.compareTo(b.id);
    if (at == null) return 1;
    if (bt == null) return -1;
    return (at.hour * 60 + at.minute).compareTo(bt.hour * 60 + bt.minute);
  });
  if (matches.isEmpty) return '';
  String title(ActivityDataStruct item) {
    final custom = item.customTitle.trim();
    if (custom.isNotEmpty) return custom;
    final typed = item.activityType.trim();
    if (typed.isNotEmpty) return typed;
    return item.title.trim().isEmpty ? 'Activiteit' : item.title.trim();
  }

  String clock(ActivityDataStruct item) {
    final value = item.startTime ?? item.time;
    if (value == null || item.allDay) return item.allDay ? 'Hele dag' : '';
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  return matches.take(4).map((item) {
    final time = clock(item);
    return time.isEmpty ? title(item) : '$time - ${title(item)}';
  }).join('\n');
}

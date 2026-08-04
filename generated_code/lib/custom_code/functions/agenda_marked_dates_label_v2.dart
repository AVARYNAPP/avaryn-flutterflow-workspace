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

/// Provides compact visual markers for dates that contain AVARYN activities.
String? agendaMarkedDatesLabelV2(List<ActivityDataStruct>? activities) {
  final dates = <DateTime>[];
  for (final item in activities ?? const <ActivityDataStruct>[]) {
    final value = item.startDate ?? item.date;
    if (value == null) continue;
    final day = DateTime(value.year, value.month, value.day);
    if (!dates.any((existing) => existing == day)) dates.add(day);
  }
  dates.sort();
  if (dates.isEmpty) return 'Nog geen dagen met activiteiten';
  final labels = dates.take(5).map(
        (date) =>
            '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}',
      );
  return ' ${labels.join('    ')}';
}

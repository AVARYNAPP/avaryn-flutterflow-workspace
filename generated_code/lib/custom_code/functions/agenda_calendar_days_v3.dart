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

/// Builds a Monday-first four, five or six row calendar grid including
/// adjacent-month days.
List<DateTime>? agendaCalendarDaysV3(DateTime? month) {
  final source = month ?? DateTime.now();
  final first = DateTime(source.year, source.month, 1);
  final last = DateTime(source.year, source.month + 1, 0);
  final gridStart = first.subtract(Duration(days: first.weekday - 1));
  final gridEnd = last.add(Duration(days: 7 - last.weekday));
  final count = gridEnd.difference(gridStart).inDays + 1;
  return List<DateTime>.generate(
    count,
    (index) => gridStart.add(Duration(days: index)),
  );
}

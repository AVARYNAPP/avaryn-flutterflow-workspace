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

/// Enables confirmation for a complete valid date or range and ordered
/// optional times.
bool? agendaReadyV3(
  String? activityType,
  DateTime? startDate,
  DateTime? endDate,
  DateTime? startTime,
  DateTime? endTime,
) {
  if (startDate == null) return false;
  final type = (activityType ?? '').trim();
  final rangeEnd = type == 'Wedstrijd' ? endDate : startDate;
  if (type == 'Wedstrijd' && rangeEnd == null) return false;
  final startDay = DateTime(startDate.year, startDate.month, startDate.day);
  final endDay = DateTime(
    rangeEnd!.year,
    rangeEnd.month,
    rangeEnd.day,
  );
  if (endDay.isBefore(startDay)) return false;
  if (startTime == null || endTime == null) return true;
  final startMoment = DateTime(
    startDay.year,
    startDay.month,
    startDay.day,
    startTime.hour,
    startTime.minute,
  );
  final endMoment = DateTime(
    endDay.year,
    endDay.month,
    endDay.day,
    endTime.hour,
    endTime.minute,
  );
  return endMoment.isAfter(startMoment);
}

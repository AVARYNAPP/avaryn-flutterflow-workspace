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

/// Validates local start and end moments before a time selection is
/// confirmed.
bool? agendaCandidateTimeIsValidV3(
  String? target,
  String? activityType,
  DateTime? startDate,
  DateTime? endDate,
  DateTime? startTime,
  DateTime? endTime,
  DateTime? candidate,
) {
  if (candidate == null) return false;
  final type = (activityType ?? '').trim();
  final nextStart = target == 'start' ? candidate : startTime;
  final nextEnd = target == 'end' ? candidate : endTime;
  if (nextStart == null || nextEnd == null) return true;
  final startDay = startDate ?? DateTime.now();
  final endDay = type == 'Wedstrijd' ? (endDate ?? startDay) : startDay;
  final startMoment = DateTime(
    startDay.year,
    startDay.month,
    startDay.day,
    nextStart.hour,
    nextStart.minute,
  );
  final endMoment = DateTime(
    endDay.year,
    endDay.month,
    endDay.day,
    nextEnd.hour,
    nextEnd.minute,
  );
  return endMoment.isAfter(startMoment);
}

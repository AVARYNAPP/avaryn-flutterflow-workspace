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

/// Calculates care end time, keeps interval end times and normalizes point
/// appointments.
DateTime? activityEndTimeFromDraftV2(
  String? activityType,
  DateTime? startTime,
  DateTime? endTime,
  bool? allDay,
  int? durationMinutes,
) {
  final type = (activityType ?? '').trim();
  if ((allDay ?? false) && (type == 'Wedstrijd' || type == 'Overig')) {
    return null;
  }
  if (type == 'Verzorging' && startTime != null && (durationMinutes ?? 0) > 0) {
    return startTime.add(Duration(minutes: durationMinutes ?? 0));
  }
  if (type == 'Training' || type == 'Wedstrijd' || type == 'Overig') {
    return endTime;
  }
  return startTime;
}

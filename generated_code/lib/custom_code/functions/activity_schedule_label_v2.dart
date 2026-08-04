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

/// Formats time, duration or all-day state using the typed schedule fields.
String? activityScheduleLabelV2(ActivityDataStruct? activity) {
  String clock(DateTime? value) {
    if (value == null) return '';
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  final allDay = activity?.allDay ?? false;
  if (allDay) return 'Hele dag';
  final start = activity?.startTime ?? activity?.time;
  final end = activity?.endTime;
  final duration = activity?.durationMinutes ?? 0;
  if (start == null) return 'Tijd onbekend';
  if (duration > 0 && (activity?.activityType ?? '') == 'Verzorging') {
    return '${clock(start)} · $duration min';
  }
  if (end != null) return '${clock(start)} – ${clock(end)}';
  return clock(start);
}

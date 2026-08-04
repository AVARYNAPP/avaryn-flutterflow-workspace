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

/// Builds the stable, horse, local-date and round key used to prevent
/// duplicate feeding results.
String? feedingExecutionLogicalKeyV1(
  String? stableId,
  int? horseId,
  DateTime? date,
  String? roundId,
) {
  final rawDate = date ?? DateTime.now();
  final year = rawDate.year.toString().padLeft(4, '0');
  final month = rawDate.month.toString().padLeft(2, '0');
  final day = rawDate.day.toString().padLeft(2, '0');
  return '${(stableId ?? '').trim()}|${horseId ?? 0}|'
      '$year-$month-$day|${(roundId ?? '').trim()}';
}

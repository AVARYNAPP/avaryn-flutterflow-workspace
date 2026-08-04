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

/// Allows an empty optional date but rejects partial, impossible and
/// disallowed future dates.
bool? horseDateSelectionIsValid(
  String? day,
  String? month,
  String? year,
  bool? allowFuture,
) {
  final values = <String?>[day, month, year];
  final emptyCount =
      values.where((value) => value == null || value.isEmpty).length;
  if (emptyCount == 3) return true;
  if (emptyCount != 0) return false;
  const months = <String>[
    'januari',
    'februari',
    'maart',
    'april',
    'mei',
    'juni',
    'juli',
    'augustus',
    'september',
    'oktober',
    'november',
    'december',
  ];
  final dayValue = int.tryParse(day!);
  final monthValue = months.indexOf(month!.toLowerCase()) + 1;
  final yearValue = int.tryParse(year!);
  if (dayValue == null || yearValue == null || monthValue < 1) return false;
  final candidate = DateTime(yearValue, monthValue, dayValue);
  if (candidate.year != yearValue ||
      candidate.month != monthValue ||
      candidate.day != dayValue) {
    return false;
  }
  if (allowFuture != true) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (candidate.isAfter(today)) return false;
  }
  return true;
}

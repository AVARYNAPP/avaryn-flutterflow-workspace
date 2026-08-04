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

/// Composes a validated DateTime from Dutch day, month and year controls.
DateTime? composeHorseDate(
  String? day,
  String? month,
  String? year,
  bool? allowFuture,
) {
  if (day == null ||
      month == null ||
      year == null ||
      day.isEmpty ||
      month.isEmpty ||
      year.isEmpty) {
    return null;
  }
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
  final dayValue = int.tryParse(day);
  final monthValue = months.indexOf(month.toLowerCase()) + 1;
  final yearValue = int.tryParse(year);
  if (dayValue == null || yearValue == null || monthValue < 1) return null;
  final candidate = DateTime(yearValue, monthValue, dayValue);
  if (candidate.year != yearValue ||
      candidate.month != monthValue ||
      candidate.day != dayValue) {
    return null;
  }
  if (allowFuture != true) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (candidate.isAfter(today)) return null;
  }
  return candidate;
}

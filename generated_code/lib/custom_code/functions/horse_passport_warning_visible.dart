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

/// Shows a passport warning from exactly six calendar months before expiry.
bool? horsePassportWarningVisible(DateTime? expiryDate) {
  if (expiryDate == null) return false;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  var thresholdYear = expiryDate.year;
  var thresholdMonth = expiryDate.month - 6;
  while (thresholdMonth <= 0) {
    thresholdMonth += 12;
    thresholdYear--;
  }
  final lastThresholdDay = DateTime(thresholdYear, thresholdMonth + 1, 0).day;
  final thresholdDay =
      expiryDate.day > lastThresholdDay ? lastThresholdDay : expiryDate.day;
  final threshold = DateTime(thresholdYear, thresholdMonth, thresholdDay);
  return !today.isBefore(threshold);
}

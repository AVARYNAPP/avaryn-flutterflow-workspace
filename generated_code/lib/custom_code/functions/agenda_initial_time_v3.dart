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

/// Restores an existing local time or supplies a five-minute aligned local
/// default.
DateTime? agendaInitialTimeV3(DateTime? value) {
  if (value != null) return value;
  final now = DateTime.now();
  final roundedMinute = (now.minute ~/ 5) * 5;
  return DateTime(now.year, now.month, now.day, now.hour, roundedMinute);
}

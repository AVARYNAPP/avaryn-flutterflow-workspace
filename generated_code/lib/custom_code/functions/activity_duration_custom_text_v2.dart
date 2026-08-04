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

/// Returns a custom care duration only when it is not one of the preset
/// choices.
String? activityDurationCustomTextV2(int? minutes) {
  final value = minutes ?? 0;
  return const <int>[15, 30, 45, 60, 90, 120].contains(value) || value <= 0
      ? ''
      : value.toString();
}

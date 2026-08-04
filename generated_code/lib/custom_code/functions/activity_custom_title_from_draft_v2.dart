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

/// Keeps a custom title only for the flexible Overig activity type.
String? activityCustomTitleFromDraftV2(
  String? activityType,
  String? customTitle,
) {
  return (activityType ?? '').trim() == 'Overig'
      ? (customTitle ?? '').trim()
      : '';
}

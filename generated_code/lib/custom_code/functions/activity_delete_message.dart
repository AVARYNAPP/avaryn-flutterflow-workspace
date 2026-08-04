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

/// Builds a calm Dutch deletion confirmation naming the activity.
String? activityDeleteMessage(String? title) {
  final safeTitle = (title ?? '').trim();
  final label = safeTitle.isEmpty ? 'Deze activiteit' : '“$safeTitle”';
  return '$label wordt verwijderd uit Planning en Vandaag. Dit kan niet ongedaan worden gemaakt.';
}

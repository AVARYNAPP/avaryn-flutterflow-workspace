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

/// Preserves stored assignees and migrates previous activities to the current
/// local user on edit.
List<String>? activityEffectiveAssigneeIdsV2(
  ActivityDataStruct? activity,
  String? currentUserId,
) {
  final existing = activity?.assigneeUserIds ?? const <String>[];
  if (existing.isNotEmpty) return List<String>.from(existing);
  final id = (currentUserId ?? '').trim();
  return <String>[id.isEmpty ? 'local-current-user' : id];
}

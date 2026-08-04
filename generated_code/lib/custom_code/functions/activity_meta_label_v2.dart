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

/// Combines applicable location and assignee information for compact cards.
String? activityMetaLabelV2(
  ActivityDataStruct? activity,
  String? currentUserId,
) {
  final location = activity?.locationName.trim() ?? '';
  final locationType = activity?.locationType.trim() ?? '';
  final ids = activity?.assigneeUserIds ?? const <String>[];
  final current = (currentUserId ?? '').trim();
  final activeId = current.isEmpty ? 'local-current-user' : current;
  final hasCurrent = ids.contains(activeId);
  final unavailable = ids.where((id) => id != activeId).length;
  final assignee = ids.isEmpty
      ? 'Nog niet toegewezen'
      : hasCurrent && unavailable == 0
          ? 'Jij'
          : hasCurrent
              ? 'Jij + $unavailable niet meer actief'
              : '$unavailable niet meer actief';
  final place = location.isNotEmpty
      ? location
      : (locationType == 'Op stal' ? 'Op stal' : '');
  return place.isEmpty ? assignee : '$place · $assignee';
}

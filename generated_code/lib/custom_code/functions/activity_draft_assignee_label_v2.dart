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

/// Summarizes the current form assignees without inventing stable members.
String? activityDraftAssigneeLabelV2(
  List<String>? assigneeUserIds,
  String? currentUserId,
) {
  final ids = assigneeUserIds ?? const <String>[];
  if (ids.isEmpty) return 'Selecteer minimaal één persoon';
  final current = (currentUserId ?? '').trim();
  final activeId = current.isEmpty ? 'local-current-user' : current;
  final hasCurrent = ids.contains(activeId);
  final unavailable = ids.where((id) => id != activeId).length;
  if (hasCurrent && unavailable == 0) return 'Jij';
  if (hasCurrent) return 'Jij + $unavailable niet meer actief';
  return unavailable == 1
      ? '1 persoon niet meer actief'
      : '$unavailable personen niet meer actief';
}

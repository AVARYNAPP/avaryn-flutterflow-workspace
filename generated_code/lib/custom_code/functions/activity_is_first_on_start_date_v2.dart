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

/// Marks the first card in each effective local start-date group.
bool? activityIsFirstOnStartDateV2(
  List<ActivityDataStruct>? activities,
  int? activityId,
) {
  final values = List<ActivityDataStruct>.from(
    activities ?? const <ActivityDataStruct>[],
  );
  DateTime? dateOf(ActivityDataStruct item) => item.startDate ?? item.date;
  values.sort((a, b) {
    final ad = dateOf(a);
    final bd = dateOf(b);
    if (ad == null && bd == null) return a.id.compareTo(b.id);
    if (ad == null) return 1;
    if (bd == null) return -1;
    final compare = DateTime(ad.year, ad.month, ad.day)
        .compareTo(DateTime(bd.year, bd.month, bd.day));
    return compare != 0 ? compare : a.id.compareTo(b.id);
  });
  final index = values.indexWhere((item) => item.id == activityId);
  if (index < 0) return false;
  if (index == 0) return true;
  final current = dateOf(values[index]);
  final previous = dateOf(values[index - 1]);
  if (current == null) return previous != null;
  if (previous == null) return true;
  return current.year != previous.year ||
      current.month != previous.month ||
      current.day != previous.day;
}

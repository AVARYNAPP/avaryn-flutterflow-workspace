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

/// Sorts both previous and extended activities by their effective local
/// start.
List<ActivityDataStruct>? sortedActivitiesV2(
    List<ActivityDataStruct>? activities) {
  final result = List<ActivityDataStruct>.from(
    activities ?? const <ActivityDataStruct>[],
  );
  DateTime? dateOf(ActivityDataStruct item) => item.startDate ?? item.date;
  DateTime? timeOf(ActivityDataStruct item) => item.startTime ?? item.time;
  result.sort((a, b) {
    final ad = dateOf(a);
    final bd = dateOf(b);
    if (ad == null && bd == null) return a.id.compareTo(b.id);
    if (ad == null) return 1;
    if (bd == null) return -1;
    final dateCompare = DateTime(ad.year, ad.month, ad.day)
        .compareTo(DateTime(bd.year, bd.month, bd.day));
    if (dateCompare != 0) return dateCompare;
    final at = timeOf(a);
    final bt = timeOf(b);
    if (at == null && bt == null) return a.id.compareTo(b.id);
    if (at == null) return 1;
    if (bt == null) return -1;
    final timeCompare =
        (at.hour * 60 + at.minute).compareTo(bt.hour * 60 + bt.minute);
    return timeCompare != 0 ? timeCompare : a.id.compareTo(b.id);
  });
  return result;
}

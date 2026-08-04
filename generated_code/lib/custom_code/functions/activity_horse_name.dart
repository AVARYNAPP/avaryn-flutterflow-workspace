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

/// Resolves an activity horse dynamically, preferring its call name.
String? activityHorseName(
  List<HorseProfileDataStruct>? horses,
  int? horseId,
) {
  for (final horse in horses ?? const <HorseProfileDataStruct>[]) {
    if (horse.id != horseId) continue;
    final callName = horse.callName.trim();
    if (callName.isNotEmpty) return callName;
    final officialName = horse.officialName.trim();
    return officialName.isNotEmpty ? officialName : 'Onbekend paard';
  }
  return 'Onbekend paard';
}

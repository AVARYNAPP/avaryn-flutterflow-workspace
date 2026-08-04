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

/// Calculates the legacy-compatible title while a typed activity is being
/// saved.
String? activityDraftDisplayTitleV2(
  String? activityType,
  String? customTitle,
  String? serviceProviderName,
) {
  final type = (activityType ?? '').trim();
  final custom = (customTitle ?? '').trim();
  final provider = (serviceProviderName ?? '').trim();
  switch (type) {
    case 'Training':
      return 'Training';
    case 'Verzorging':
      return 'Verzorging';
    case 'Hoefsmid':
      return provider.isEmpty ? 'Hoefsmid' : 'Hoefsmid · $provider';
    case 'Dierenarts':
      return provider.isEmpty ? 'Dierenarts' : 'Dierenarts · $provider';
    case 'Wedstrijd':
      return 'Wedstrijd';
    case 'Overig':
      return custom;
    default:
      return type;
  }
}

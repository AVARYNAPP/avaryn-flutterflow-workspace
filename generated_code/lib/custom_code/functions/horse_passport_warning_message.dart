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

/// Builds a dynamic Dutch passport warning with natural today and expiry
/// wording.
String? horsePassportWarningMessage(
  DateTime? expiryDate,
  String? callName,
  String? officialName,
) {
  if (expiryDate == null) return '';
  final preferredCallName = (callName ?? '').trim();
  final preferredOfficialName = (officialName ?? '').trim();
  final name = preferredCallName.isNotEmpty
      ? preferredCallName
      : (preferredOfficialName.isNotEmpty
          ? preferredOfficialName
          : 'Onbekend paard');
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final expiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
  final days = expiry.difference(today).inDays;
  if (days < -1) return 'Paspoort van $name is ${-days} dagen verlopen.';
  if (days == -1) return 'Paspoort van $name is gisteren verlopen.';
  if (days == 0) return 'Paspoort van $name vervalt vandaag.';
  if (days == 1) return 'Paspoort van $name vervalt morgen.';
  return 'Paspoort van $name vervalt over $days dagen.';
}

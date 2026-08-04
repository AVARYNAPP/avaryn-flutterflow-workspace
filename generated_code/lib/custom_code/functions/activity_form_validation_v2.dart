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

/// Returns one actionable Dutch validation message for the selected activity
/// type.
String? activityFormValidationV2(
  String? activityType,
  int? horseId,
  List<String>? assigneeUserIds,
  DateTime? startDate,
  DateTime? endDate,
  DateTime? startTime,
  DateTime? endTime,
  bool? allDay,
  int? durationMinutes,
  String? locationType,
  String? locationName,
  String? serviceProviderName,
  String? customTitle,
) {
  final type = (activityType ?? '').trim();
  if ((horseId ?? 0) <= 0) return 'Selecteer eerst een paard.';
  if (type.isEmpty) return 'Selecteer een type activiteit.';
  if (assigneeUserIds == null || assigneeUserIds.isEmpty) {
    return 'Selecteer minimaal één persoon bij Voor wie.';
  }
  if (startDate == null) return 'Selecteer een geldige datum.';
  int minutes(DateTime value) => value.hour * 60 + value.minute;
  switch (type) {
    case 'Training':
      if ((locationType ?? '').trim().isEmpty) {
        return 'Kies Op stal of Op locatie.';
      }
      if (locationType == 'Op locatie' && (locationName ?? '').trim().isEmpty) {
        return 'Vul bij Welke locatie? een locatie in.';
      }
      if (startTime == null || endTime == null) {
        return 'Selecteer een starttijd en eindtijd.';
      }
      if (minutes(endTime) <= minutes(startTime)) {
        return 'De eindtijd moet later zijn dan de starttijd.';
      }
      break;
    case 'Verzorging':
      if (startTime == null) return 'Selecteer een starttijd.';
      if ((durationMinutes ?? 0) <= 0) {
        return 'Selecteer een geldige duur.';
      }
      break;
    case 'Hoefsmid':
      if ((serviceProviderName ?? '').trim().isEmpty) {
        return 'Vul de naam van de hoefsmid in.';
      }
      if (startTime == null) return 'Selecteer een tijd.';
      break;
    case 'Dierenarts':
      if ((serviceProviderName ?? '').trim().isEmpty) {
        return 'Vul de naam van de dierenarts in.';
      }
      if (startTime == null) return 'Selecteer een tijd.';
      break;
    case 'Wedstrijd':
      if ((locationName ?? '').trim().isEmpty) {
        return 'Vul de wedstrijdlocatie in.';
      }
      if (endDate == null) return 'Selecteer een einddatum.';
      final startDay = DateTime(startDate.year, startDate.month, startDate.day);
      final endDay = DateTime(endDate.year, endDate.month, endDate.day);
      if (endDay.isBefore(startDay)) {
        return 'De einddatum kan niet voor de startdatum liggen.';
      }
      if (!(allDay ?? false)) {
        if (startTime == null || endTime == null) {
          return 'Selecteer een begin- en eindtijd.';
        }
        final startMoment = DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
          startTime.hour,
          startTime.minute,
        );
        final endMoment = DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
          endTime.hour,
          endTime.minute,
        );
        if (!endMoment.isAfter(startMoment)) {
          return 'Het eindmoment moet later zijn dan het startmoment.';
        }
      }
      break;
    case 'Overig':
      if ((customTitle ?? '').trim().isEmpty) {
        return 'Vul een titel in voor Overig.';
      }
      if (!(allDay ?? false)) {
        if (startTime == null || endTime == null) {
          return 'Selecteer een starttijd en eindtijd.';
        }
        if (minutes(endTime) <= minutes(startTime)) {
          return 'De eindtijd moet later zijn dan de starttijd.';
        }
      }
      break;
  }
  return '';
}

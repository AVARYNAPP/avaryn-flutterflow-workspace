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

/// Boolean form gate used by FlutterFlow conditional actions; mirrors the
/// detailed Dutch validation rules.
bool? activityFormIsValidBooleanV2(
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
  if ((horseId ?? 0) <= 0 ||
      type.isEmpty ||
      assigneeUserIds == null ||
      assigneeUserIds.isEmpty ||
      startDate == null) {
    return false;
  }
  int minutes(DateTime value) => value.hour * 60 + value.minute;
  switch (type) {
    case 'Training':
      if ((locationType ?? '').trim().isEmpty) return false;
      if (locationType == 'Op locatie' && (locationName ?? '').trim().isEmpty)
        return false;
      return startTime != null &&
          endTime != null &&
          minutes(endTime) > minutes(startTime);
    case 'Verzorging':
      return startTime != null && (durationMinutes ?? 0) > 0;
    case 'Hoefsmid':
    case 'Dierenarts':
      return (serviceProviderName ?? '').trim().isNotEmpty && startTime != null;
    case 'Wedstrijd':
      if ((locationName ?? '').trim().isEmpty || endDate == null) return false;
      final startDay = DateTime(startDate.year, startDate.month, startDate.day);
      final endDay = DateTime(endDate.year, endDate.month, endDate.day);
      if (endDay.isBefore(startDay)) return false;
      if (allDay ?? false) return true;
      if (startTime == null || endTime == null) return false;
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
      return endMoment.isAfter(startMoment);
    case 'Overig':
      if ((customTitle ?? '').trim().isEmpty) return false;
      if (allDay ?? false) return true;
      return startTime != null &&
          endTime != null &&
          minutes(endTime) > minutes(startTime);
  }
  return false;
}

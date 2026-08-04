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

/// Detects local double bookings only for shared assignees and excludes the
/// edited record.
String? activityConflictWarningV2(
  List<ActivityDataStruct>? activities,
  ActivityDataStruct? candidate,
  String? currentUserId,
) {
  final draft = candidate;
  if (draft == null) return '';
  final draftPeople = draft.assigneeUserIds;
  if (draftPeople.isEmpty) return '';
  DateTime? startOf(ActivityDataStruct item) {
    final date = item.startDate ?? item.date;
    if (date == null) return null;
    if (item.allDay) return DateTime(date.year, date.month, date.day);
    final time = item.startTime ?? item.time;
    return DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? 0,
      time?.minute ?? 0,
    );
  }

  DateTime? endOf(ActivityDataStruct item) {
    final start = startOf(item);
    if (start == null) return null;
    if (item.allDay) {
      final endDate = item.endDate ?? item.startDate ?? item.date ?? start;
      return DateTime(endDate.year, endDate.month, endDate.day)
          .add(const Duration(days: 1));
    }
    final endDate = item.endDate ?? item.startDate ?? item.date;
    final endTime = item.endTime;
    if (endDate != null && endTime != null) {
      return DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
        endTime.hour,
        endTime.minute,
      );
    }
    if (item.durationMinutes > 0) {
      return start.add(Duration(minutes: item.durationMinutes));
    }
    return start;
  }

  bool completed(ActivityDataStruct item) {
    final status = item.completionStatus.trim().toLowerCase();
    return status == 'completed' || status == 'voltooid' || item.isCompleted;
  }

  String title(ActivityDataStruct item) {
    final type = item.activityType.trim();
    final provider = item.serviceProviderName.trim();
    if (type == 'Hoefsmid' || type == 'Dierenarts') {
      return provider.isEmpty ? type : '$type · $provider';
    }
    if (type == 'Overig') {
      return item.customTitle.trim().isNotEmpty
          ? item.customTitle.trim()
          : item.title.trim();
    }
    return type.isNotEmpty ? type : item.title.trim();
  }

  String clock(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  final draftStart = startOf(draft);
  final draftEnd = endOf(draft);
  if (draftStart == null || draftEnd == null) return '';
  for (final other in activities ?? const <ActivityDataStruct>[]) {
    if (other.id == draft.id || completed(other)) continue;
    final shared = draftPeople.where(other.assigneeUserIds.contains).toList();
    if (shared.isEmpty) continue;
    final otherStart = startOf(other);
    final otherEnd = endOf(other);
    if (otherStart == null || otherEnd == null) continue;
    final draftPoint = draftEnd == draftStart;
    final otherPoint = otherEnd == otherStart;
    final overlaps = draftPoint && otherPoint
        ? draftStart == otherStart
        : draftPoint
            ? !draftStart.isBefore(otherStart) && draftStart.isBefore(otherEnd)
            : otherPoint
                ? !otherStart.isBefore(draftStart) &&
                    otherStart.isBefore(draftEnd)
                : draftStart.isBefore(otherEnd) &&
                    otherStart.isBefore(draftEnd);
    if (!overlaps) continue;
    final current = (currentUserId ?? '').trim();
    final activeId = current.isEmpty ? 'local-current-user' : current;
    final person = shared.first == activeId
        ? 'De huidige gebruiker'
        : 'Een niet meer actieve gebruiker';
    final horse = other.horseId > 0 ? ' met het gekoppelde paard' : '';
    return '$person is op ${otherStart.day}-${otherStart.month} om '
        '${clock(otherStart)} ook ingepland voor ${title(other)}$horse.';
  }
  return '';
}

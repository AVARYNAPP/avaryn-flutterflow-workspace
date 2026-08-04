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

/// Boolean shared-assignee overlap gate used by FlutterFlow conditional
/// actions.
bool? activityHasConflictBooleanV2(
  List<ActivityDataStruct>? activities,
  ActivityDataStruct? candidate,
  String? currentUserId,
) {
  final draft = candidate;
  if (draft == null) return false;
  final current = (currentUserId ?? '').trim();
  final activeId = current.isEmpty ? 'local-current-user' : current;
  final draftPeople = draft.assigneeUserIds.isEmpty
      ? <String>[activeId]
      : draft.assigneeUserIds;
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
    final rawEndDate = item.endDate ?? item.startDate ?? item.date;
    if (rawEndDate == null) return start;
    if (item.allDay) {
      return DateTime(rawEndDate.year, rawEndDate.month, rawEndDate.day)
          .add(const Duration(days: 1));
    }
    final endTime = item.endTime;
    if (endTime != null) {
      return DateTime(
        rawEndDate.year,
        rawEndDate.month,
        rawEndDate.day,
        endTime.hour,
        endTime.minute,
      );
    }
    if (item.durationMinutes > 0) {
      return start.add(Duration(minutes: item.durationMinutes));
    }
    return start;
  }

  bool completed(ActivityDataStruct item) =>
      item.completionStatus == 'completed' || item.isCompleted;
  final draftStart = startOf(draft);
  final draftEnd = endOf(draft);
  if (draftStart == null || draftEnd == null) return false;
  for (final other in activities ?? const <ActivityDataStruct>[]) {
    if (other.id == draft.id || completed(other)) continue;
    final otherPeople = other.assigneeUserIds.isEmpty
        ? <String>[activeId]
        : other.assigneeUserIds;
    if (!draftPeople.any(otherPeople.contains)) continue;
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
    if (overlaps) return true;
  }
  return false;
}

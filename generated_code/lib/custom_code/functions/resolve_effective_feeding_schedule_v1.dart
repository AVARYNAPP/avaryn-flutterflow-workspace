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

/// Resolves one horse, local date and feeding round to a temporary snapshot
/// or standard fallback.
EffectiveFeedingScheduleDataStruct? resolveEffectiveFeedingScheduleV1(
  List<HorseFeedingPlanDataStruct>? plans,
  List<TemporaryFeedingScheduleDataStruct>? temporarySchedules,
  String? stableId,
  int? horseId,
  DateTime? date,
  String? roundId,
) {
  final targetStable = (stableId ?? '').trim();
  final targetHorse = horseId ?? 0;
  final targetRound = (roundId ?? '').trim();
  final rawDate = date ?? DateTime.now();
  final targetDate = DateTime(rawDate.year, rawDate.month, rawDate.day);

  DateTime day(DateTime value) => DateTime(value.year, value.month, value.day);

  final matchingTemporary = (temporarySchedules ??
          const <TemporaryFeedingScheduleDataStruct>[])
      .where((schedule) {
    if (schedule.stableId != targetStable ||
        schedule.horseId != targetHorse ||
        !schedule.affectedRoundIds.contains(targetRound) ||
        schedule.startDate == null ||
        schedule.endDate == null) {
      return false;
    }
    final start = day(schedule.startDate!);
    final end = day(schedule.endDate!);
    return !targetDate.isBefore(start) && !targetDate.isAfter(end);
  }).toList()
    ..sort((a, b) {
      final updatedOrder =
          (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
        a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
      return updatedOrder != 0 ? updatedOrder : a.id.compareTo(b.id);
    });

  if (matchingTemporary.isNotEmpty) {
    final schedule = matchingTemporary.first;
    FeedingRoundSnapshotDataStruct? snapshot;
    for (final candidate in schedule.roundSnapshots) {
      if (candidate.roundId == targetRound) {
        snapshot = candidate;
        break;
      }
    }
    return EffectiveFeedingScheduleDataStruct(
      sourceType: 'temporary',
      temporaryScheduleId: schedule.id,
      stableId: targetStable,
      horseId: targetHorse,
      date: targetDate,
      roundId: targetRound,
      items: List<FeedingItemDataStruct>.from(
        snapshot?.items ?? const <FeedingItemDataStruct>[],
      ),
    );
  }

  HorseFeedingPlanDataStruct? plan;
  for (final candidate in plans ?? const <HorseFeedingPlanDataStruct>[]) {
    if (candidate.stableId == targetStable &&
        candidate.horseId == targetHorse) {
      plan = candidate;
      break;
    }
  }
  FeedingRoundSnapshotDataStruct? standardRound;
  for (final candidate
      in plan?.rounds ?? const <FeedingRoundSnapshotDataStruct>[]) {
    if (candidate.roundId == targetRound) {
      standardRound = candidate;
      break;
    }
  }
  return EffectiveFeedingScheduleDataStruct(
    sourceType: 'standard',
    temporaryScheduleId: '',
    stableId: targetStable,
    horseId: targetHorse,
    date: targetDate,
    roundId: targetRound,
    items: List<FeedingItemDataStruct>.from(
      standardRound?.items ?? const <FeedingItemDataStruct>[],
    ),
  );
}

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

/// Resolves one stable, local date and feeding round to a date exception,
/// default responsible user or unassigned state.
ResolvedFeedingResponsibleDataStruct? resolveFeedingResponsibleUserV1(
  List<FeedingRoundConfigDataStruct>? configs,
  List<FeedingAssignmentExceptionDataStruct>? exceptions,
  String? stableId,
  DateTime? date,
  String? roundId,
) {
  final targetStable = (stableId ?? '').trim();
  final targetRound = (roundId ?? '').trim();
  final rawDate = date ?? DateTime.now();
  final targetDate = DateTime(rawDate.year, rawDate.month, rawDate.day);

  bool sameDay(DateTime? value) =>
      value != null &&
      value.year == targetDate.year &&
      value.month == targetDate.month &&
      value.day == targetDate.day;

  final matchingExceptions =
      (exceptions ?? const <FeedingAssignmentExceptionDataStruct>[])
          .where(
            (item) =>
                item.stableId == targetStable &&
                item.roundId == targetRound &&
                sameDay(item.date),
          )
          .toList()
        ..sort((a, b) {
          final updatedOrder =
              (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
            a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
          );
          return updatedOrder != 0 ? updatedOrder : a.id.compareTo(b.id);
        });

  if (matchingExceptions.isNotEmpty) {
    final exception = matchingExceptions.first;
    final resolved = exception.explicitlyUnassigned
        ? ''
        : exception.replacementResponsibleUserId.trim();
    return ResolvedFeedingResponsibleDataStruct(
      stableId: targetStable,
      date: targetDate,
      roundId: targetRound,
      resolvedUserId: resolved,
      source: resolved.isEmpty ? 'unassigned' : 'dateException',
      exceptionId: exception.id,
    );
  }

  FeedingRoundConfigDataStruct? config;
  for (final candidate in configs ?? const <FeedingRoundConfigDataStruct>[]) {
    if (candidate.stableId == targetStable &&
        candidate.roundId == targetRound &&
        (!candidate.hasEnabled() || candidate.enabled)) {
      config = candidate;
      break;
    }
  }
  final defaultUserId = config?.defaultResponsibleUserId.trim() ?? '';
  return ResolvedFeedingResponsibleDataStruct(
    stableId: targetStable,
    date: targetDate,
    roundId: targetRound,
    resolvedUserId: defaultUserId,
    source: defaultUserId.isEmpty ? 'unassigned' : 'default',
    exceptionId: '',
  );
}

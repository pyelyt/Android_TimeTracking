// lib/features/time_tracking/services/csv_export_service.dart

import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/work_session_repository.dart';
import '../models/pay_period_settings.dart';
import '../models/work_session.dart';
import '../utils/pay_period_utils_extended.dart';
import 'package:flutter/material.dart';


class CsvExportService {
  final WorkSessionRepository repository;
  final PayPeriodSettings settings;

  static final DateFormat _dtFmt = DateFormat('M/d/yyyy HH:mm');
  static final DateFormat _dateFmt = DateFormat('M/d/yyyy');
  static final DateFormat _fileDateFmt = DateFormat('yyyyMMdd');

  CsvExportService({required this.repository, required this.settings});

  /// Build the last 3 pay periods, filter sessions into them,
  /// generate CSV content, write to a temp file, and trigger share sheet.
  Future<void> exportAndShare({required Rect shareOrigin}) async {
    final allSessions = await repository.getAllAsync();

    // Get last 3 pay periods (oldest first)
    final periods = computeLastNPayPeriods(settings, 3);

    final buffer = StringBuffer();

    // Header row
    buffer.writeln(
      'Pay Period Start,Pay Period End,Session Start,Session End,Duration (hrs),Notes',
    );

    for (final period in periods) {
      final periodStart = period['start']!;
      final periodEnd = period['end']!;
      final periodEndFull = DateTime(
        periodEnd.year, periodEnd.month, periodEnd.day + 1);

      // Filter sessions that overlap with this period
      final periodSessions = allSessions
          .where((s) =>
              s.end != null &&
              s.start.toLocal().isBefore(periodEndFull) &&
              s.end!.toLocal().isAfter(periodStart))
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));

      for (final session in periodSessions) {
        // Clip session to period boundaries
        final clippedStart = session.start.toLocal().isBefore(periodStart)
            ? periodStart
            : session.start.toLocal();
        final clippedEnd = session.end!.toLocal().isAfter(periodEndFull)
            ? periodEndFull
            : session.end!.toLocal();
        final clippedHours = clippedEnd.difference(clippedStart).inMinutes / 60.0;
        buffer.writeln(_buildRow(periodStart, periodEnd, session,
            clippedStart: clippedStart,
            clippedEnd: clippedEnd,
            clippedHours: clippedHours));
      }
    }

    // Write to temp file
    final dir = await getTemporaryDirectory();
    final fileName = 'worktime_${_fileDateFmt.format(DateTime.now())}.csv';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(buffer.toString());

    // Share
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'WorkTime Export – Last 3 Pay Periods',
      sharePositionOrigin: shareOrigin,
    );
  }

  String _buildRow(
    DateTime periodStart,
    DateTime periodEnd,
    WorkSession session, {
    DateTime? clippedStart,
    DateTime? clippedEnd,
    double? clippedHours,
  }) {
    final start = clippedStart ?? session.start.toLocal();
    final end = clippedEnd ?? session.end!.toLocal();
    final hours = clippedHours ?? session.hoursDecimal;
    final cols = [
      _csvCell(_dateFmt.format(periodStart)),
      _csvCell(_dateFmt.format(periodEnd)),
      _csvCell(_dtFmt.format(start)),
      _csvCell(_dtFmt.format(end)),
      hours.toStringAsFixed(2),
      _csvCell(session.notes ?? ''),
    ];
    return cols.join(',');
  }

  /// Wraps a value in quotes and escapes internal quotes.
  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }
}

// lib/features/time_tracking/services/csv_export_service.dart

import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/work_session_repository.dart';
import '../models/pay_period_settings.dart';
import '../models/work_session.dart';
import '../utils/pay_period_utils_extended.dart';

class CsvExportService {
  final WorkSessionRepository repository;
  final PayPeriodSettings settings;

  static final DateFormat _dtFmt = DateFormat('yyyy-MM-dd HH:mm');
  static final DateFormat _fileDateFmt = DateFormat('yyyyMMdd');

  CsvExportService({required this.repository, required this.settings});

  /// Build the last 3 pay periods, filter sessions into them,
  /// generate CSV content, write to a temp file, and trigger share sheet.
  Future<void> exportAndShare() async {
    final allSessions = await repository.getAllAsync();

    // Get last 3 pay periods (oldest first)
    final periods = computeLastNPayPeriods(settings, 3);

    final buffer = StringBuffer();

    // Header row
    buffer.writeln(
        'Pay Period Start,Pay Period End,Session Start,Session End,Duration (hrs),Notes');

    for (final period in periods) {
      final periodStart = period['start']!;
      final periodEnd = period['end']!;
      final periodEndFull =
          DateTime(periodEnd.year, periodEnd.month, periodEnd.day, 23, 59, 59);

      // Filter sessions whose start falls within this period
      final periodSessions = allSessions
          .where((s) =>
              s.end != null &&
              !s.start.isBefore(periodStart) &&
              !s.start.isAfter(periodEndFull))
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));

      for (final session in periodSessions) {
        buffer.writeln(_buildRow(periodStart, periodEnd, session));
      }
    }

    // Write to temp file
    final dir = await getTemporaryDirectory();
    final fileName =
        'worktime_${_fileDateFmt.format(DateTime.now())}.csv';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(buffer.toString());

    // Share
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'WorkTime Export – Last 3 Pay Periods',
    );
  }

  String _buildRow(
      DateTime periodStart, DateTime periodEnd, WorkSession session) {
    final cols = [
      _csvCell(_dtFmt.format(periodStart)),
      _csvCell(_dtFmt.format(periodEnd)),
      _csvCell(_dtFmt.format(session.start)),
      _csvCell(_dtFmt.format(session.end!)),
      session.hoursDecimal.toStringAsFixed(2),
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

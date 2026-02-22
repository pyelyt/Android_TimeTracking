// lib/features/time_tracking/utils/pay_period_utils_extended.dart
//
// Extends pay_period_utils.dart with helpers needed by the dashboard
// and CSV export: computing N prior pay periods, and week/month/quarter/year ranges.

import '../models/pay_period_settings.dart';
import 'pay_period_utils.dart';

/// Returns a list of [count] pay period ranges ending with (and including)
/// the current pay period. Index 0 = oldest, last index = current.
List<Map<String, DateTime>> computeLastNPayPeriods(
    PayPeriodSettings settings, int count,
    {DateTime? now}) {
  final List<Map<String, DateTime>> periods = [];

  // Start from the current period and walk backwards.
  DateTime reference = now ?? DateTime.now();

  for (int i = 0; i < count; i++) {
    final range = computePayPeriodRange(settings, now: reference);
    periods.insert(0, range); // prepend so result is oldest-first

    // Step reference back one day before the start of this period
    reference = range['start']!.subtract(const Duration(days: 1));
  }

  return periods;
}

/// A labelled time range used by the dashboard.
class PeriodRange {
  final String label;
  final DateTime start;
  final DateTime end;

  PeriodRange({required this.label, required this.start, required this.end});
}

/// Returns the last [count] complete-or-current weekly ranges (Mon–Sun),
/// most recent last.
List<PeriodRange> lastNWeeks(int count, {DateTime? now}) {
  final today = _today(now);
  // Find the most recent Monday
  final daysFromMonday = (today.weekday - 1) % 7;
  final thisMonday = today.subtract(Duration(days: daysFromMonday));

  final List<PeriodRange> result = [];
  for (int i = count - 1; i >= 0; i--) {
    final start = thisMonday.subtract(Duration(days: 7 * i));
    final end = start.add(const Duration(days: 6));
    result.add(PeriodRange(
      label: _weekLabel(start, end),
      start: start,
      end: end,
    ));
  }
  return result;
}

/// Returns the last [count] complete-or-current calendar months, most recent last.
List<PeriodRange> lastNMonths(int count, {DateTime? now}) {
  final today = _today(now);
  final List<PeriodRange> result = [];

  for (int i = count - 1; i >= 0; i--) {
    int month = today.month - i;
    int year = today.year;
    while (month <= 0) {
      month += 12;
      year--;
    }
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0);
    result.add(PeriodRange(
      label: _monthLabel(start),
      start: start,
      end: end,
    ));
  }
  return result;
}

/// Returns the last [count] complete-or-current calendar quarters, most recent last.
List<PeriodRange> lastNQuarters(int count, {DateTime? now}) {
  final today = _today(now);
  final currentQ = ((today.month - 1) ~/ 3); // 0-based quarter index
  final List<PeriodRange> result = [];

  for (int i = count - 1; i >= 0; i--) {
    int q = currentQ - i;
    int year = today.year;
    while (q < 0) {
      q += 4;
      year--;
    }
    final startMonth = q * 3 + 1;
    final start = DateTime(year, startMonth, 1);
    final end = DateTime(year, startMonth + 3, 0);
    result.add(PeriodRange(
      label: 'Q${q + 1} $year',
      start: start,
      end: end,
    ));
  }
  return result;
}

/// Returns the last [count] complete-or-current calendar years, most recent last.
List<PeriodRange> lastNYears(int count, {DateTime? now}) {
  final today = _today(now);
  final List<PeriodRange> result = [];

  for (int i = count - 1; i >= 0; i--) {
    final year = today.year - i;
    final start = DateTime(year, 1, 1);
    final end = DateTime(year, 12, 31);
    result.add(PeriodRange(
      label: '$year',
      start: start,
      end: end,
    ));
  }
  return result;
}

// --- helpers ---

DateTime _today(DateTime? now) {
  final d = now ?? DateTime.now();
  return DateTime(d.year, d.month, d.day);
}

String _weekLabel(DateTime start, DateTime end) {
  final months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  if (start.month == end.month) {
    return '${months[start.month - 1]} ${start.day}–${end.day}';
  }
  return '${months[start.month - 1]} ${start.day} – ${months[end.month - 1]} ${end.day}';
}

String _monthLabel(DateTime start) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  return '${months[start.month - 1]} ${start.year}';
}

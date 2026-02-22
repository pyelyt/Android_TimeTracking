import '../models/pay_period_settings.dart';

Map<String, DateTime> computePayPeriodRange(PayPeriodSettings settings, {DateTime? now}) {
  final DateTime reference = now ?? DateTime.now();
  final today = DateTime(reference.year, reference.month, reference.day);

  DateTime start;
  DateTime end;

  switch (settings.mode) {
    case PayPeriodMode.weekly:
      final int daysSinceSunday = today.weekday % 7;
      start = today.subtract(Duration(days: daysSinceSunday));
      end = start.add(const Duration(days: 6));
      break;

    case PayPeriodMode.biWeekly:
      final anchor = settings.anchorDate;
      if (anchor == null) {
        final int daysSinceSunday = today.weekday % 7;
        start = today.subtract(Duration(days: daysSinceSunday));
        end = start.add(const Duration(days: 13));
        break;
      }

      DateTime anchorDate = DateTime(anchor.year, anchor.month, anchor.day);

      while (anchorDate.isAfter(today)) {
        anchorDate = anchorDate.subtract(const Duration(days: 14));
      }

      DateTime periodStart = anchorDate;
      while (periodStart.add(const Duration(days: 14)).isBefore(today.add(const Duration(days: 1)))) {
        final next = periodStart.add(const Duration(days: 14));
        if (!next.isAfter(today)) {
          periodStart = next;
        } else {
          break;
        }
      }

      while (periodStart.isAfter(today)) {
        periodStart = periodStart.subtract(const Duration(days: 14));
      }

      start = periodStart;
      end = start.add(const Duration(days: 13));
      break;

    case PayPeriodMode.semiMonthly:
      final middle = settings.middleDay ?? 15;
      final year = today.year;
      final month = today.month;
      final firstOfMonth = DateTime(year, month, 1);
      final lastOfMonth = DateTime(year, month + 1, 0);

      final clampedMiddle = middle.clamp(1, lastOfMonth.day);

      if (today.day <= clampedMiddle) {
        start = firstOfMonth;
        end = DateTime(year, month, clampedMiddle);
      } else {
        start = DateTime(year, month, clampedMiddle + 1);
        end = lastOfMonth;
      }
      break;

    case PayPeriodMode.monthly:
      start = DateTime(today.year, today.month, 1);
      end = DateTime(today.year, today.month + 1, 0);
      break;

    default:
      final int daysSinceSunday = today.weekday % 7;
      start = today.subtract(Duration(days: daysSinceSunday));
      end = start.add(const Duration(days: 6));
  }

  start = DateTime(start.year, start.month, start.day);
  end = DateTime(end.year, end.month, end.day);


  return {"start": start, "end": end};
}
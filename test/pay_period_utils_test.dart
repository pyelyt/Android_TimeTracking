import 'package:flutter_test/flutter_test.dart';
import 'package:worktime_tracker/features/time_tracking/models/pay_period_settings.dart';
import 'package:worktime_tracker/features/time_tracking/utils/pay_period_utils.dart';

void main() {
  test('weekly returns Sunday-Saturday containing today', () {
    final settings = PayPeriodSettings(mode: PayPeriodMode.weekly);
    final now = DateTime(2026, 2, 18); // Wednesday
    final range = computePayPeriodRange(settings, now: now);
    expect(range['start']!.difference(now).inDays <= 0, true);
    expect(range['end']!.difference(now).inDays >= 0, true);
  });

  test('biWeekly with anchor in past contains today', () {
    final anchor = DateTime(2026, 2, 8); // Sunday
    final settings = PayPeriodSettings(mode: PayPeriodMode.biWeekly, anchorDate: anchor);
    final now = DateTime(2026, 2, 18); // falls in 02/08 - 02/21
    final range = computePayPeriodRange(settings, now: now);
    expect(range['start'], DateTime(2026, 2, 8));
    expect(range['end'], DateTime(2026, 2, 21));
  });

  test('biWeekly with anchor in future steps backwards', () {
    final anchor = DateTime(2026, 3, 1); // future relative to now
    final settings = PayPeriodSettings(mode: PayPeriodMode.biWeekly, anchorDate: anchor);
    final now = DateTime(2026, 2, 18);
    final range = computePayPeriodRange(settings, now: now);
    expect(range['start']!.difference(now).inDays <= 0, true);
    expect(range['end']!.difference(now).inDays >= 0, true);
  });

  test('semiMonthly clamps middle day and splits month', () {
    final settings = PayPeriodSettings(mode: PayPeriodMode.semiMonthly, middleDay: 15);
    final now = DateTime(2026, 2, 10);
    final range = computePayPeriodRange(settings, now: now);
    expect(range['start'], DateTime(2026, 2, 1));
    expect(range['end'], DateTime(2026, 2, 15));
  });

  test('monthly returns first to last day', () {
    final settings = PayPeriodSettings(mode: PayPeriodMode.monthly);
    final now = DateTime(2026, 2, 18);
    final range = computePayPeriodRange(settings, now: now);
    expect(range['start'], DateTime(2026, 2, 1));
    expect(range['end'], DateTime(2026, 2, 28));
  });
}

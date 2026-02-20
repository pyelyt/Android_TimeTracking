import 'package:shared_preferences/shared_preferences.dart';
import '../models/pay_period_settings.dart';
import 'package:flutter/foundation.dart';

class SettingsRepository {
  static const _keyMode = 'pay_period_mode';
  static const _keyAnchorDate = 'pay_period_anchor_date';
  static const _keyMiddleDay = 'pay_period_middle_day';

  Future<void> saveSettings(PayPeriodSettings settings) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_keyMode, describeEnum(settings.mode));
    debugPrint(
        'SettingsRepository.saveSettings: mode=${describeEnum(settings.mode)}, anchor=${settings.anchorDate}, middle=${settings.middleDay}');

    if (settings.anchorDate != null) {
      await prefs.setString(
        _keyAnchorDate,
        settings.anchorDate!.toIso8601String(),
      );
    } else {
      await prefs.remove(_keyAnchorDate);
    }

    if (settings.middleDay != null) {
      await prefs.setInt(_keyMiddleDay, settings.middleDay!);
    } else {
      await prefs.remove(_keyMiddleDay);
    }
  }

  Future<PayPeriodSettings?> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final modeString = prefs.getString(_keyMode);
    final anchorString = prefs.getString(_keyAnchorDate);
    final middleDay = prefs.getInt(_keyMiddleDay);
    debugPrint(
        'SettingsRepository.loadSettings: raw modeString=$modeString, anchorString=$anchorString, middleDay=$middleDay');

    if (modeString == null) return null;

    PayPeriodMode mode;

    switch (modeString) {
      case 'weekly':
        mode = PayPeriodMode.weekly;
        break;
      case 'biWeekly':
        mode = PayPeriodMode.biWeekly;
        break;
      case 'semiMonthly':
        mode = PayPeriodMode.semiMonthly;
        break;
      case 'monthly':
        mode = PayPeriodMode.monthly;
        break;
      case 'quarterly':
        mode = PayPeriodMode.quarterly;
        break;
      case 'yearly':
        mode = PayPeriodMode.yearly;
        break;

    // OLD VALUES — prevent crashes
      case 'A':
        mode = PayPeriodMode.weekly;
        break;
      case 'B':
        mode = PayPeriodMode.biWeekly;
        break;
      case 'C':
        mode = PayPeriodMode.semiMonthly;
        break;
      case 'D':
        mode = PayPeriodMode.monthly;
        break;
      case 'E':
        mode = PayPeriodMode.quarterly;
        break;
      case 'F':
        mode = PayPeriodMode.yearly;
        break;

      default:
        mode = PayPeriodMode.weekly;
    }

    final anchorDate =
    anchorString != null ? DateTime.parse(anchorString) : null;

    return PayPeriodSettings(
      mode: mode,
      anchorDate: anchorDate,
      middleDay: middleDay,
    );
  }
}

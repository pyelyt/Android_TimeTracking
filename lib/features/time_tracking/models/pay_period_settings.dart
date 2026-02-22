enum PayPeriodMode {
  weekly,
  biWeekly,
  semiMonthly,
  monthly,
  quarterly,
  yearly,
}

class PayPeriodSettings {
  final PayPeriodMode mode;
  final DateTime? anchorDate;
  final int? middleDay;

  PayPeriodSettings({
    required this.mode,
    this.anchorDate,
    this.middleDay,
  });

  Map<String, dynamic> toMap() {
    return {
      'mode': mode.name,
      'anchorDate': anchorDate?.toIso8601String(),
      'middleDay': middleDay,
    };
  }

  factory PayPeriodSettings.fromMap(Map<String, dynamic> map) {
    int? legacyMiddleDay;
    if (map.containsKey('cutoff2') && map['cutoff2'] != null) {
      legacyMiddleDay = map['cutoff2'];
    }

    return PayPeriodSettings(
      mode: PayPeriodMode.values.firstWhere(
            (m) => m.name == map['mode'],
        orElse: () => PayPeriodMode.weekly,
      ),
      anchorDate: map['anchorDate'] != null
          ? DateTime.parse(map['anchorDate'])
          : null,
      middleDay: map['middleDay'] ?? legacyMiddleDay,
    );
  }
}

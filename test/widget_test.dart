// Basic smoke test: verifies the app builds without crashing.
// The MyApp constructor requires initialSettings; we pass a default weekly setting.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worktime_tracker/main.dart';
import 'package:worktime_tracker/features/time_tracking/models/pay_period_settings.dart';

void main() {
  testWidgets('App smoke test — builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      MyApp(
        initialSettings: PayPeriodSettings(mode: PayPeriodMode.weekly),
      ),
    );
    // Just verify the app renders something at the top level
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

import 'package:flutter/material.dart';

import 'package:worktime_tracker/features/time_tracking/ui/screens/time_tracking_screen.dart';
import 'package:worktime_tracker/features/time_tracking/data/work_session_repository.dart';

import 'package:worktime_tracker/features/time_tracking/data/settings_repository.dart';
import 'package:worktime_tracker/features/time_tracking/models/pay_period_settings.dart';
import 'package:worktime_tracker/features/time_tracking/ui/screens/pay_period_onboarding_screen.dart';
import 'package:worktime_tracker/features/time_tracking/ui/screens/add_session_screen.dart';

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // LOAD CLEAN SETTINGS
  final repo = SettingsRepository();
  final settings = await repo.loadSettings();

  runApp(MyApp(initialSettings: settings));
}


class MyApp extends StatelessWidget {
  final PayPeriodSettings? initialSettings;

  const MyApp({super.key, required this.initialSettings});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WorkTime Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      routes: {
        '/pay-period-setup': (context) => const PayPeriodOnboardingScreen(),
        '/addSession': (context) => AddSessionScreen(),
      },

      home: initialSettings == null
          ? const PayPeriodOnboardingScreen()
          : TimeTrackingScreen(
        repository: WorkSessionRepository(),
      ),
    );

  }
}

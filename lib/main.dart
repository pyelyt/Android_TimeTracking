// lib/main.dart

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'package:worktime_tracker/features/time_tracking/ui/screens/time_tracking_screen.dart';
import 'package:worktime_tracker/features/time_tracking/data/work_session_repository.dart';
import 'package:worktime_tracker/features/time_tracking/data/settings_repository.dart';
import 'package:worktime_tracker/features/time_tracking/models/pay_period_settings.dart';
import 'package:worktime_tracker/features/time_tracking/ui/screens/pay_period_onboarding_screen.dart';
import 'package:worktime_tracker/features/time_tracking/ui/screens/add_session_screen.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

Future<Database> _openDatabase() async {
  final dbPath = await getDatabasesPath();
  final path = p.join(dbPath, 'worktime_tracker.db');

  return openDatabase(
    path,
    version: 1,
    onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE sessions (
          id      INTEGER PRIMARY KEY AUTOINCREMENT,
          start   INTEGER NOT NULL,
          end     INTEGER,
          notes   TEXT
        )
      ''');
      await db.execute(
          'CREATE INDEX idx_sessions_start ON sessions (start)');
    },
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = await _openDatabase();
  final settingsRepo = SettingsRepository();
  final settings = await settingsRepo.loadSettings();

  runApp(MyApp(
    initialSettings: settings,
    repository: WorkSessionRepository(db),
  ));
}

class MyApp extends StatelessWidget {
  final PayPeriodSettings? initialSettings;
  final WorkSessionRepository repository;

  const MyApp({
    super.key,
    required this.initialSettings,
    required this.repository,
  });

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
              repository: repository,
            ),
    );
  }
}

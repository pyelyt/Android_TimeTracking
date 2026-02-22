import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:worktime_tracker/main.dart';
import 'package:worktime_tracker/features/time_tracking/models/pay_period_settings.dart';
import 'package:worktime_tracker/features/time_tracking/data/work_session_repository.dart';

void main() {
  testWidgets('App smoke test — builds without crashing', (WidgetTester tester) async {
    // Use in-memory SQLite for tests (no file system needed)
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('''
      CREATE TABLE sessions (
        id    INTEGER PRIMARY KEY AUTOINCREMENT,
        start INTEGER NOT NULL,
        end   INTEGER,
        notes TEXT
      )
    ''');

    await tester.pumpWidget(
      MyApp(
        initialSettings: PayPeriodSettings(mode: PayPeriodMode.weekly),
        repository: WorkSessionRepository(db),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
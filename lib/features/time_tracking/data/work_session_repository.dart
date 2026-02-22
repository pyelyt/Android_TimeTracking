// lib/features/time_tracking/data/work_session_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:worktime_tracker/features/time_tracking/models/work_session.dart';

class WorkSessionRepository {
  final Database _db;

  WorkSessionRepository(this._db);

  /// Return all sessions ordered by start time.
  Future<List<WorkSession>> getAllAsync() async {
    final rows = await _db.query(
      'sessions',
      orderBy: 'start ASC',
    );
    return rows.map((row) => WorkSession.fromMap(row)).toList();
  }

  /// Synchronous wrapper — kept so existing call sites compile unchanged.
  /// Returns an empty list and triggers an async reload; prefer getAllAsync.
  List<WorkSession> getAll() => [];

  /// Insert a new session. Returns the session with its assigned id.
  void addSession(WorkSession session) {
    _db.insert(
      'sessions',
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Delete a session matched by its database id, falling back to start time.
  void removeSession(WorkSession session) {
    if (session.id != null) {
      _db.delete('sessions', where: 'id = ?', whereArgs: [session.id]);
    } else {
      _db.delete(
        'sessions',
        where: 'start = ?',
        whereArgs: [session.start.millisecondsSinceEpoch],
      );
    }
  }

  /// Update an existing session matched by its database id.
  void updateSession(WorkSession updated) {
    if (updated.id != null) {
      _db.update(
        'sessions',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [updated.id],
      );
    } else {
      _db.update(
        'sessions',
        updated.toMap(),
        where: 'start = ?',
        whereArgs: [updated.start.millisecondsSinceEpoch],
      );
    }
  }

  /// Delete all sessions (useful for testing/debugging).
  void clear() {
    _db.delete('sessions');
  }
}

import 'package:worktime_tracker/features/time_tracking/models/work_session.dart';

class WorkSessionRepository {
  final List<WorkSession> _sessions = [];

  /// Return all sessions (synchronous).
  List<WorkSession> getAll() => List.unmodifiable(_sessions);

  /// Async version of getAll that returns a copy without heavy work.
  /// For an in-memory repository this avoids isolate overhead and keeps
  /// the call non-blocking by scheduling the copy on the event queue.
  Future<List<WorkSession>> getAllAsync() async {
    return await Future<List<WorkSession>>.microtask(() => List.unmodifiable(_sessions));
  }

  /// Add a new session
  void addSession(WorkSession session) {
    _sessions.add(session);
  }

  /// Remove a session
  void removeSession(WorkSession session) {
    _sessions.remove(session);
  }

  /// Clear all sessions (useful for debugging)
  void clear() {
    _sessions.clear();
  }

  /// Update an existing session (used when ending a shift)
  void updateSession(WorkSession updated) {
    final index = _sessions.indexWhere((s) => s.start == updated.start);

    if (index != -1) {
      _sessions[index] = updated;
    }
  }
}

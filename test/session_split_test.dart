import 'package:flutter_test/flutter_test.dart';
import 'package:worktime_tracker/features/time_tracking/models/work_session.dart';

/// Local helper: split a WorkSession into day-constrained segments.
List<_Seg> splitSessionIntoSegments(WorkSession session) {
  final List<_Seg> segments = [];
  if (session.end == null) return segments;
  DateTime currentStart = session.start;
  final DateTime finalEnd = session.end!;
  while (currentStart.isBefore(finalEnd)) {
    final DateTime endOfDay = DateTime(
      currentStart.year,
      currentStart.month,
      currentStart.day + 1,
    );
    final DateTime segmentEnd = finalEnd.isBefore(endOfDay) ? finalEnd : endOfDay;
    segments.add(_Seg(
      date: DateTime(currentStart.year, currentStart.month, currentStart.day),
      start: currentStart,
      end: segmentEnd,
    ));
    currentStart = segmentEnd;
  }
  return segments;
}

class _Seg {
  final DateTime date;
  final DateTime start;
  final DateTime end;
  _Seg({required this.date, required this.start, required this.end});
}

void main() {
  test('split overnight session into two segments', () {
    final start = DateTime(2026, 2, 10, 22, 30);
    final end = DateTime(2026, 2, 11, 1, 15);
    final session = WorkSession(start: start, end: end, notes: 'overnight');

    final segments = splitSessionIntoSegments(session);
    expect(segments.length, 2);
    expect(segments[0].date, DateTime(2026, 2, 10));
    expect(segments[1].date, DateTime(2026, 2, 11));
    expect(segments[0].start, start);
    expect(segments[1].end, end);
  });
}

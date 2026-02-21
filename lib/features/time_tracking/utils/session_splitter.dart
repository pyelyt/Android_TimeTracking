import 'package:worktime_tracker/features/time_tracking/models/work_session.dart';

/// A simple segment type used by the splitter.
class WorkSessionSegment {
  final DateTime date;
  final DateTime start;
  final DateTime end;
  WorkSessionSegment({required this.date, required this.start, required this.end});
}

/// Split a WorkSession into day-constrained segments (midnight boundaries).
List<WorkSessionSegment> splitSessionIntoSegments(WorkSession session) {
  final segments = <WorkSessionSegment>[];
  if (session.end == null) return segments;
  DateTime currentStart = session.start;
  final finalEnd = session.end!;
  while (currentStart.isBefore(finalEnd)) {
    final endOfDay = DateTime(currentStart.year, currentStart.month, currentStart.day + 1);
    final segmentEnd = finalEnd.isBefore(endOfDay) ? finalEnd : endOfDay;
    segments.add(WorkSessionSegment(
      date: DateTime(currentStart.year, currentStart.month, currentStart.day),
      start: currentStart,
      end: segmentEnd,
    ));
    currentStart = segmentEnd;
  }
  return segments;
}

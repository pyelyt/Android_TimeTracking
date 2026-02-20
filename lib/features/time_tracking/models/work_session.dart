class WorkSession {
  final DateTime start;
  DateTime? end;
  final String? notes;

  WorkSession({
    required this.start,
    this.end,
    this.notes,
  });

  double get hoursDecimal {
    if (end == null) return 0;
    final duration = end!.difference(start);
    return duration.inMinutes / 60.0;
  }

  bool get isOpen => end == null;

  /// Create a WorkSession from saved JSON
  factory WorkSession.fromJson(Map<String, dynamic> json) {
    return WorkSession(
      start: DateTime.parse(json['start'] as String),
      end: json['end'] != null ? DateTime.parse(json['end'] as String) : null,
      notes: json['notes'] as String?,
    );
  }

  /// Convert a WorkSession to JSON
  Map<String, dynamic> toJson() {
    return {
      'start': start.toIso8601String(),
      'end': end?.toIso8601String(),
      'notes': notes,
    };
  }
}

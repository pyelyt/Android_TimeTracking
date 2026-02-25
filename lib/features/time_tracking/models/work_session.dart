// lib/features/time_tracking/models/work_session.dart

class WorkSession {
  final int? id; // sqflite row id, null for new unsaved sessions
  final DateTime start;
  DateTime? end;
  final String? notes;

  WorkSession({
    this.id,
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

  /// Create a WorkSession from a sqflite row map.
  factory WorkSession.fromMap(Map<String, dynamic> map) {
    return WorkSession(
      id: map['id'] as int?,
      start: DateTime.fromMillisecondsSinceEpoch(map['start'] as int, isUtc: true).toLocal(),
      end: map['end'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['end'] as int, isUtc: true).toLocal()
          : null,
      notes: map['notes'] as String?,
    );
  }

  /// Convert to a sqflite row map (omit id so sqflite auto-assigns it).
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'start': start.millisecondsSinceEpoch,
      'end': end?.millisecondsSinceEpoch,
      'notes': notes,
    };
  }

  /// Create a WorkSession from JSON (kept for compatibility).
  factory WorkSession.fromJson(Map<String, dynamic> json) {
    return WorkSession(
      start: DateTime.parse(json['start'] as String),
      end: json['end'] != null ? DateTime.parse(json['end'] as String) : null,
      notes: json['notes'] as String?,
    );
  }

  /// Convert to JSON (kept for compatibility).
  Map<String, dynamic> toJson() {
    return {
      'start': start.toIso8601String(),
      'end': end?.toIso8601String(),
      'notes': notes,
    };
  }

  /// Return a copy of this session with updated fields.
  WorkSession copyWith({
    int? id,
    DateTime? start,
    DateTime? end,
    String? notes,
    bool clearEnd = false,
    bool clearNotes = false,
  }) {
    return WorkSession(
      id: id ?? this.id,
      start: start ?? this.start,
      end: clearEnd ? null : (end ?? this.end),
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }
}

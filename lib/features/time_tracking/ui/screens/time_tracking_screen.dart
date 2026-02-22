// lib/features/time_tracking/ui/screens/time_tracking_screen.dart

import 'package:worktime_tracker/features/time_tracking/utils/pay_period_utils.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:worktime_tracker/features/time_tracking/data/work_session_repository.dart';
import 'package:worktime_tracker/features/time_tracking/models/work_session.dart';

import 'package:worktime_tracker/features/time_tracking/data/settings_repository.dart';
import 'package:worktime_tracker/features/time_tracking/models/pay_period_settings.dart';

// Import the routeObserver you added to main.dart
import 'package:worktime_tracker/main.dart' show routeObserver;
import 'package:worktime_tracker/features/time_tracking/ui/screens/dashboard_screen.dart';
import 'package:worktime_tracker/features/time_tracking/services/csv_export_service.dart';

/// Public DTO for a session segment (one calendar-day constrained piece of a WorkSession).
class SessionSegment {
  final DateTime date; // midnight-based date (year, month, day)
  final DateTime start;
  final DateTime end;
  final String? notes;

  SessionSegment({
    required this.date,
    required this.start,
    required this.end,
    this.notes,
  });

  double get hoursDecimal {
    final duration = end.difference(start);
    return duration.inMinutes / 60.0;
  }
}

/// Represents all segments for a single calendar day.
class _DayGroup {
  final DateTime date;
  final List<SessionSegment> segments;

  _DayGroup({
    required this.date,
    required this.segments,
  });

  double get totalHours {
    return segments.fold(0.0, (sum, s) => sum + s.hoursDecimal);
  }
}

/// Split a WorkSession into one or more SessionSegment objects,
/// each constrained to a single calendar day (overnight splitting).
List<SessionSegment> _splitSessionIntoSegments(WorkSession session) {
  final List<SessionSegment> segments = [];

  if (session.end == null) {
    return segments;
  }

  DateTime currentStart = session.start;
  final DateTime finalEnd = session.end!;

  while (currentStart.isBefore(finalEnd)) {
    final DateTime endOfDay = DateTime(
      currentStart.year,
      currentStart.month,
      currentStart.day + 1,
    );

    final DateTime segmentEnd =
    finalEnd.isBefore(endOfDay) ? finalEnd : endOfDay;

    segments.add(
      SessionSegment(
        date: DateTime(currentStart.year, currentStart.month, currentStart.day),
        start: currentStart,
        end: segmentEnd,
        notes: session.notes,
      ),
    );

    currentStart = segmentEnd;
  }

  return segments;
}

/// Group all sessions into day-based groups, with overnight splitting applied.
List<_DayGroup> _buildDayGroups(
    List<WorkSession> sessions, WorkSession? openSession) {
  final sorted = [...sessions]..sort((a, b) => a.start.compareTo(b.start));

  final Map<DateTime, List<SessionSegment>> byDate = {};

  for (final session in sorted) {
    final segments = _splitSessionIntoSegments(session);
    for (final seg in segments) {
      byDate.putIfAbsent(seg.date, () => []).add(seg);
    }
  }

  // Ensure open session day exists even if no closed sessions exist
  if (openSession != null) {
    final d = DateTime(openSession.start.year, openSession.start.month,
        openSession.start.day);
    byDate.putIfAbsent(d, () => []);
  }

  final List<_DayGroup> dayGroups = byDate.entries
      .map(
        (entry) => _DayGroup(
      date: entry.key,
      segments: entry.value
        ..sort((a, b) => a.start.compareTo(b.start)),
    ),
  )
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  return dayGroups;
}

/// Compute the grand total hours across all (closed) sessions.
double _computeGrandTotalHours(List<WorkSession> sessions) {
  double total = 0.0;
  for (final session in sessions) {
    if (session.end != null) {
      total += session.hoursDecimal;
    }
  }
  return total;
}

/// Find the current open session, if any.
WorkSession? _findOpenSession(List<WorkSession> sessions) {
  try {
    return sessions.lastWhere((s) => s.isOpen);
  } catch (_) {
    return null;
  }
}

class TimeTrackingScreen extends StatefulWidget {
  final WorkSessionRepository repository;

  const TimeTrackingScreen({
    super.key,
    required this.repository,
  });

  @override
  State<TimeTrackingScreen> createState() => _TimeTrackingScreenState();
}

class _TimeTrackingScreenState extends State<TimeTrackingScreen> with RouteAware {
  List<WorkSession> _sessions = [];

  PayPeriodSettings? _settings;
  final SettingsRepository _settingsRepo = SettingsRepository();

  Map<String, DateTime>? _currentPayPeriodRange;

  final DateFormat _payPeriodFormatter = DateFormat('MM/dd/yyyy');
  final DateFormat _dayHeaderFormatter = DateFormat('EEEE, MMM d');
  final DateFormat _timeFormatter = DateFormat('h:mm a');

  List<_DayGroup> _cachedDayGroups = [];
  double _cachedGrandTotalHours = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    final s = await _settingsRepo.loadSettings();
    final sessions = await widget.repository.getAllAsync();

    if (!mounted) return;

    final settings = s ?? PayPeriodSettings(mode: PayPeriodMode.weekly);
    final range = computePayPeriodRange(settings);
    final groups = _buildDayGroups(sessions, _findOpenSession(sessions));
    final total = _computeGrandTotalHours(sessions);

    setState(() {
      _settings = settings;
      _currentPayPeriodRange = range;
      _sessions = sessions;
      _cachedDayGroups = groups;
      _cachedGrandTotalHours = total;
    });

    if (kDebugMode) {
      // ignore: avoid_print
      print('TimeTracking: initialized');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final modal = ModalRoute.of(context);
    if (modal != null) {
      routeObserver.subscribe(this, modal);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _reloadSettingsAndSessions();
  }

  Future<void> _reloadSettingsAndSessions() async {
    final s = await _settingsRepo.loadSettings();
    if (!mounted) return;
    setState(() {
      _settings = s ?? PayPeriodSettings(mode: PayPeriodMode.weekly);
      _currentPayPeriodRange = computePayPeriodRange(_settings!);
    });
    await _loadSessions();
  }

  Future<void> _loadSessions() async {
    final sessions = await widget.repository.getAllAsync();
    if (!mounted) return;

    final groups = _buildDayGroups(sessions, _findOpenSession(sessions));
    final total = _computeGrandTotalHours(sessions);

    setState(() {
      _sessions = sessions;
      _cachedDayGroups = groups;
      _cachedGrandTotalHours = total;
    });

    if (kDebugMode) {
      // ignore: avoid_print
      print('TimeTracking: sessions reloaded');
    }
  }

  void _refresh() {
    Future.microtask(_loadSessions);
  }

  void _startSession() {
    final now = DateTime.now();
    final newSession = WorkSession(start: now, notes: null);
    widget.repository.addSession(newSession);
    _refresh();
  }

  void _endSession() {
    final open = _findOpenSession(_sessions);
    if (open == null) return;

    final updated = WorkSession(
      start: open.start,
      end: DateTime.now(),
      notes: open.notes,
    );

    setState(() {
      final mutable = [..._sessions];
      final idx = mutable.indexWhere(
              (s) => identical(s, open) || (s.start == open.start && s.end == open.end));
      if (idx != -1) {
        mutable[idx] = updated;
      } else {
        mutable.add(updated);
      }
      _sessions = mutable;
      _cachedDayGroups = _buildDayGroups(_sessions, _findOpenSession(_sessions));
      _cachedGrandTotalHours = _computeGrandTotalHours(_sessions);
    });

    // Persist: remove original, add updated
    widget.repository.removeSession(open);
    widget.repository.addSession(updated);

    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final grandTotalHours = _cachedGrandTotalHours;
    final openSession = _findOpenSession(_sessions);
    final hasOpen = openSession != null;
    final dayGroups = _cachedDayGroups;

    return Scaffold(
      appBar: AppBar(
        title: const Text('WorkTime Tracker'),
        backgroundColor: const Color(0xFF00796B),
        foregroundColor: Colors.white,
        actions: [
          // Dashboard icon
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Hours Dashboard',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => DashboardScreen(
                  repository: widget.repository,
                  settings: _settings,
                ),
              ));
            },
          ),
          // CSV export icon
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Export CSV',
            onPressed: () async {
              if (_settings == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pay period settings not loaded yet.')),
                );
                return;
              }
              try {
                final exporter = CsvExportService(
                  repository: widget.repository,
                  settings: _settings!,
                );
                await exporter.exportAndShare();
              } catch (e) {
                if (!mounted) return;
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Export failed: $e')),
                );
              }
            },
          ),
          // Settings icon
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final result = await Navigator.of(context).pushNamed('/pay-period-setup');
              if (!mounted) return;
              if (result == true) {
                final s = await _settingsRepo.loadSettings();
                if (!mounted) return;
                setState(() {
                  _settings = s ?? PayPeriodSettings(mode: PayPeriodMode.weekly);
                  _currentPayPeriodRange = computePayPeriodRange(_settings!);
                });
                Future.microtask(_loadSessions);
              }
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(grandTotalHours, hasOpen),
          const Divider(height: 1),
          Expanded(
            child: dayGroups.isEmpty
                ? const Center(child: Text('No sessions yet.'))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: dayGroups.length,
              addRepaintBoundaries: false,
              addAutomaticKeepAlives: false,
              cacheExtent: 200.0,
              itemBuilder: (context, index) {
                final dayGroup = dayGroups[index];
                return _buildDaySection(context, dayGroup, openSession);
              },
            ),
          ),
          const Divider(height: 1),
          _buildSingleStartEndButton(context, openSession),
        ],
      ),
    );
  }

  Widget _buildHeader(double grandTotalHours, bool hasOpen) {
    final totalStr = grandTotalHours.toStringAsFixed(2);

    String periodRange = '';
    if (_settings != null && _currentPayPeriodRange != null) {
      final start = _currentPayPeriodRange!['start'];
      final end = _currentPayPeriodRange!['end'];
      if (start != null && end != null) {
        periodRange =
            '${_payPeriodFormatter.format(start)} – ${_payPeriodFormatter.format(end)}';
      }
    }

    const Color accentTeal = Color(0xFF00796B);
    const Color cardBg = Color(0xFFF5F7F9);

    return Container(
      color: cardBg,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left side: pay period label + date range
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PAY PERIOD',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  periodRange.isNotEmpty ? periodRange : '—',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 8),
                // Session status pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: hasOpen
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFEEEEEE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: hasOpen
                              ? const Color(0xFF43A047)
                              : Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        hasOpen ? 'Shift in progress' : 'No open shift',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: hasOpen
                              ? const Color(0xFF2E7D32)
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Right side: big hours total
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                totalStr,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: accentTeal,
                  height: 1.0,
                ),
              ),
              const Text(
                'hrs this period',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF78909C),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDaySection(
      BuildContext context,
      _DayGroup dayGroup,
      WorkSession? openSession,
      ) {
    final date = dayGroup.date;
    final headerText =
        '${_dayHeaderFormatter.format(date)} (${dayGroup.totalHours.toStringAsFixed(2)} hrs)';

    final isToday = openSession != null &&
        date.year == openSession.start.year &&
        date.month == openSession.start.month &&
        date.day == openSession.start.day;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              headerText,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...dayGroup.segments
              .map((segment) => _buildSessionTile(context, segment)),
          if (isToday) _buildOpenSessionRow(context, openSession),
        ],
      ),
    );
  }

  Widget _buildSessionTile(BuildContext context, SessionSegment segment) {
    return TimeEntryTile(
      key: ValueKey(
          '${segment.date.toIso8601String()}_${segment.start.toIso8601String()}'),
      segment: segment,
      onEdit: (seg) => _showEditSessionSheet(context, seg),
    );
  }

  Future<void> _showEditSessionSheet(
      BuildContext context, SessionSegment segment) async {
    // Match strictly by start time — start is the unique key for a session.
    WorkSession? session;
    try {
      session = _sessions.firstWhere((s) => s.start == segment.start);
    } catch (_) {
      session = null;
    }

    if (session == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to locate session to edit.')),
      );
      return;
    }

    // Capture original session for repository removal later
    final originalSession = session;

    DateTime editedStart = session.start;
    DateTime? editedEnd = session.end;
    final notesController = TextEditingController(text: session.notes ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              Future<void> pickDateTime(bool isStart) async {
                final ctx = context; // capture before any await
                final initial =
                isStart ? editedStart : (editedEnd ?? editedStart);
                final pickedDate = await showDatePicker(
                  context: ctx,
                  initialDate: initial,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (pickedDate == null) return;
                if (!mounted) return;
                final pickedTime = await showTimePicker(
                  // ignore: use_build_context_synchronously
                  context: ctx,
                  initialTime: TimeOfDay.fromDateTime(initial),
                );
                if (pickedTime == null) return;
                final combined = DateTime(
                  pickedDate.year,
                  pickedDate.month,
                  pickedDate.day,
                  pickedTime.hour,
                  pickedTime.minute,
                );
                setModalState(() {
                  if (isStart) {
                    editedStart = combined;
                  } else {
                    editedEnd = combined;
                  }
                });
              }

              String fmt(DateTime dt) => _timeFormatter.format(dt);

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: Text('Edit Session',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium)),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      title: const Text('Start'),
                      subtitle: Text(fmt(editedStart)),
                      trailing: TextButton(
                        onPressed: () => pickDateTime(true),
                        child: const Text('Change'),
                      ),
                    ),
                    ListTile(
                      title: const Text('End'),
                      subtitle: Text(editedEnd != null
                          ? fmt(editedEnd!)
                          : 'In progress'),
                      trailing: TextButton(
                        onPressed: () => pickDateTime(false),
                        child: const Text('Change'),
                      ),
                    ),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(labelText: 'Notes'),
                      maxLines: null,
                      keyboardType: TextInputType.visiblePassword, // suppresses suggestion/clipboard bar on Android
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: const <String>[],
                      enableInteractiveSelection: false,
                      contextMenuBuilder: null,
                    ),
                    const SizedBox(height: 12),
                    // Delete button
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red, size: 18),
                        label: const Text(
                          'Delete Session',
                          style: TextStyle(color: Colors.red),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                        ),
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dialogCtx) => AlertDialog(
                              title: const Text('Delete Session'),
                              content: const Text(
                                  'Are you sure you want to delete this session? This cannot be undone.'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(dialogCtx).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(dialogCtx).pop(true),
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true) return;

                          setState(() {
                            final mutable = [..._sessions];
                            mutable.removeWhere(
                                (s) => s.start == originalSession.start);
                            _sessions = mutable;
                            _cachedDayGroups = _buildDayGroups(
                                _sessions, _findOpenSession(_sessions));
                            _cachedGrandTotalHours =
                                _computeGrandTotalHours(_sessions);
                          });

                          widget.repository.removeSession(originalSession);
                          if (!mounted) return;
                          // ignore: use_build_context_synchronously
                          Navigator.of(context).pop();
                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Session deleted')),
                          );

                          Future.microtask(_loadSessions);
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              // Validate
                              if (editedEnd != null &&
                                  editedEnd!.isBefore(editedStart)) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'End must be after start.')),
                                );
                                return;
                              }

                              final updatedSession = WorkSession(
                                start: editedStart,
                                end: editedEnd,
                                notes: notesController.text.trim().isEmpty
                                    ? null
                                    : notesController.text.trim(),
                              );

                              // Update local state
                              setState(() {
                                final mutable = [..._sessions];
                                final idx = mutable.indexWhere((s) =>
                                    s.start == originalSession.start);
                                if (idx != -1) {
                                  mutable[idx] = updatedSession;
                                } else {
                                  mutable.add(updatedSession);
                                }
                                _sessions = mutable;
                                _cachedDayGroups = _buildDayGroups(
                                    _sessions, _findOpenSession(_sessions));
                                _cachedGrandTotalHours =
                                    _computeGrandTotalHours(_sessions);
                              });

                              // Persist: remove by original start, add updated
                              widget.repository
                                  .removeSession(originalSession);
                              widget.repository.addSession(updatedSession);

                              Navigator.of(context).pop();

                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Session updated')),
                              );

                              Future.microtask(_loadSessions);
                            },
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildOpenSessionRow(BuildContext context, WorkSession openSession) {
    final startStr = _timeFormatter.format(openSession.start);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: ListTile(
          dense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: Color(0xFF43A047),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 18),
          ),
          title: Text('$startStr → In progress'),
          subtitle: const Text('Current session'),
          trailing: Text(
            '-- h',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSingleStartEndButton(
      BuildContext context, WorkSession? openSession) {
    final bool hasOpen = openSession != null;
    final String label = hasOpen ? 'End Shift' : 'Start Shift';
    final IconData icon = hasOpen ? Icons.stop : Icons.play_arrow;
    final Color iconColor = hasOpen ? Colors.red : Colors.green;
    final VoidCallback onPressed = hasOpen ? _endSession : _startSession;

    return Container(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
      alignment: Alignment.center,
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.33,
        height: 48,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade300,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 1,
            padding: EdgeInsets.zero,
          ),
          onPressed: onPressed,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Extracted widget for session rows ---
class TimeEntryTile extends StatelessWidget {
  final SessionSegment segment;
  final ValueChanged<SessionSegment> onEdit;
  static final DateFormat _timeFmt = DateFormat('h:mm a');

  const TimeEntryTile({
    super.key,
    required this.segment,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final startStr = _timeFmt.format(segment.start);
    final endStr = _timeFmt.format(segment.end);
    final hoursStr = segment.hoursDecimal.toStringAsFixed(2);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: ListTile(
          dense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: Color(0xFF1E88E5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 16),
          ),
          title: Text('$startStr → $endStr'),
          subtitle: segment.notes != null && segment.notes!.trim().isNotEmpty
              ? Text(segment.notes!.trim())
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$hoursStr h',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                tooltip: 'Edit session',
                onPressed: () => onEdit(segment),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
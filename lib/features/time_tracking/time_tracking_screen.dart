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

/// Represents a portion of a WorkSession that falls within a single calendar day.
class _SessionSegment {
  final DateTime date; // midnight-based date (year, month, day)
  final DateTime start;
  final DateTime end;
  final String? notes;

  _SessionSegment({
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
  final List<_SessionSegment> segments;

  _DayGroup({
    required this.date,
    required this.segments,
  });

  double get totalHours {
    return segments.fold(0.0, (sum, s) => sum + s.hoursDecimal);
  }
}

/// Split a WorkSession into one or more _SessionSegment objects,
/// each constrained to a single calendar day (overnight splitting).
List<_SessionSegment> _splitSessionIntoSegments(WorkSession session) {
  final List<_SessionSegment> segments = [];

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
      _SessionSegment(
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

  final Map<DateTime, List<_SessionSegment>> byDate = {};

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
  // initialize to an empty list to avoid late initialization issues during rebuilds
  List<WorkSession> _sessions = [];

  PayPeriodSettings? _settings;
  final SettingsRepository _settingsRepo = SettingsRepository();

  // Cached pay period range to avoid recomputing on every build
  Map<String, DateTime>? _currentPayPeriodRange;

  // Cached formatters to avoid allocating on every build
  final DateFormat _payPeriodFormatter = DateFormat('MM/dd/yyyy');
  final DateFormat _dayHeaderFormatter = DateFormat('EEEE, MMM d');
  final DateFormat _timeFormatter = DateFormat('h:mm a');

  // Cached derived values to keep build cheap
  List<_DayGroup> _cachedDayGroups = [];
  double _cachedGrandTotalHours = 0.0;

  @override
  void initState() {
    super.initState();
    // Batch-load settings and sessions after the first frame to minimize startup jank.
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  /// Initialize settings first, then schedule session loading.
  Future<void> _initialize() async {
    final settingsStopwatch = Stopwatch()..start();
    final s = await _settingsRepo.loadSettings();
    settingsStopwatch.stop();

    final sessionsStopwatch = Stopwatch()..start();
    final sessions = await widget.repository.getAllAsync();
    sessionsStopwatch.stop();

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
      print('TimeTracking: loadSettings=${settingsStopwatch.elapsedMilliseconds}ms; '
          'getAllAsync=${sessionsStopwatch.elapsedMilliseconds}ms; '
          'process=${(groups.isEmpty && total == 0.0) ? 0 : 1}ms');
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
    final stopwatch = Stopwatch()..start();

    final repoStopwatch = Stopwatch()..start();
    final sessions = await widget.repository.getAllAsync();
    repoStopwatch.stop();

    if (!mounted) return;

    final processStopwatch = Stopwatch()..start();
    final groups = _buildDayGroups(sessions, _findOpenSession(sessions));
    final total = _computeGrandTotalHours(sessions);
    processStopwatch.stop();

    setState(() {
      _sessions = sessions;
      _cachedDayGroups = groups;
      _cachedGrandTotalHours = total;
    });

    stopwatch.stop();

    if (kDebugMode) {
      // ignore: avoid_print
      print('TimeTracking: loadSessions: total=${stopwatch.elapsedMilliseconds}ms; '
          'repo=${repoStopwatch.elapsedMilliseconds}ms; '
          'process=${processStopwatch.elapsedMilliseconds}ms');
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

    open.end = DateTime.now();
    widget.repository.updateSession(open);
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
        title: const Text('My Time Tracking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final result = await Navigator.of(context).pushNamed('/pay-period-setup');

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
              // Reduce per-item compositing and keep-alive overhead
              addRepaintBoundaries: false,
              addAutomaticKeepAlives: false,
              cacheExtent: 200.0,
              itemBuilder: (context, index) {
                final dayGroup = dayGroups[index];
                return _buildDaySection(
                  context,
                  dayGroup,
                  openSession,
                );
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

    String payPeriodText = '';
    if (_settings != null && _currentPayPeriodRange != null) {
      final startStr = _payPeriodFormatter.format(_currentPayPeriodRange!['start']!);
      final endStr = _payPeriodFormatter.format(_currentPayPeriodRange!['end']!);
      payPeriodText = 'Pay Period: $startStr – $endStr';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_settings != null)
            Text(
              payPeriodText,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (_settings != null) const SizedBox(height: 6),
          Text(
            'THIS PAY PERIOD TOTAL: $totalStr hrs',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Open session: ${hasOpen ? 'Yes' : 'No'}',
            style: Theme.of(context).textTheme.bodyMedium,
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

          // Closed sessions
          ...dayGroup.segments.map((segment) => _buildSessionTile(context, segment)),

          // Always show open session row under today's header
          if (isToday) _buildOpenSessionRow(context, openSession),
        ],
      ),
    );
  }

  // Use the extracted widget with a stable key so Flutter can preserve tiles across parent rebuilds.
  Widget _buildSessionTile(BuildContext context, _SessionSegment segment) {
    return _TimeEntryTile(
      key: ValueKey('${segment.date.toIso8601String()}_${segment.start.toIso8601String()}'),
      segment: segment,
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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

  Widget _buildSingleStartEndButton(BuildContext context, WorkSession? openSession) {
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

// --- New extracted widget for session rows ---
// Placed after the State class to keep the file organized.
class _TimeEntryTile extends StatelessWidget {
  final _SessionSegment segment;

  const _TimeEntryTile({
    required this.segment,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Use a local formatter to avoid depending on the parent's private formatter.
    final timeFmt = DateFormat('h:mm a');
    final startStr = timeFmt.format(segment.start);
    final endStr = timeFmt.format(segment.end);
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          title: Text('$startStr → $endStr'),
          subtitle: segment.notes != null && segment.notes!.trim().isNotEmpty
              ? Text(segment.notes!.trim())
              : null,
          trailing: Text(
            '$hoursStr h',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}


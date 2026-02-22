// lib/features/time_tracking/ui/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/work_session_repository.dart';
import '../../models/pay_period_settings.dart';
import '../../models/work_session.dart';
import '../../utils/pay_period_utils_extended.dart';

class DashboardScreen extends StatefulWidget {
  final WorkSessionRepository repository;
  final PayPeriodSettings? settings;

  const DashboardScreen({
    super.key,
    required this.repository,
    required this.settings,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<WorkSession> _sessions = [];
  bool _loading = true;

  static const Color _accentTeal = Color(0xFF00796B);
  static final DateFormat _dateFmt = DateFormat('MM/dd/yyyy');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sessions = await widget.repository.getAllAsync();
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _loading = false;
    });
  }

  /// Sum hours for all closed sessions whose start falls within [start, end].
  double _hoursInRange(DateTime start, DateTime end) {
    double total = 0;
    final rangeEnd = DateTime(end.year, end.month, end.day, 23, 59, 59);
    for (final s in _sessions) {
      if (s.end == null) continue;
      if (!s.start.isBefore(start) && !s.start.isAfter(rangeEnd)) {
        total += s.hoursDecimal;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hours Dashboard'),
        backgroundColor: _accentTeal,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSection(
                  title: 'WEEKLY',
                  subtitle: 'Last 4 weeks',
                  icon: Icons.view_week_outlined,
                  periods: lastNWeeks(4),
                ),
                const SizedBox(height: 20),
                _buildSection(
                  title: 'MONTHLY',
                  subtitle: 'Last 3 months',
                  icon: Icons.calendar_month_outlined,
                  periods: lastNMonths(3),
                ),
                const SizedBox(height: 20),
                _buildSection(
                  title: 'QUARTERLY',
                  subtitle: 'Last 4 quarters',
                  icon: Icons.bar_chart_outlined,
                  periods: lastNQuarters(4),
                ),
                const SizedBox(height: 20),
                _buildSection(
                  title: 'YEARLY',
                  subtitle: 'Last 3 years',
                  icon: Icons.calendar_today_outlined,
                  periods: lastNYears(3),
                ),
                const SizedBox(height: 16),
              ],
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<PeriodRange> periods,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Icon(icon, size: 16, color: _accentTeal),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: _accentTeal,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Cards — most recent on the right, reversed for display
        ...periods.reversed.map((period) {
          final hours = _hoursInRange(period.start, period.end);
          final isCurrentPeriod = _isCurrentPeriod(period);
          return _buildPeriodCard(period, hours, isCurrentPeriod);
        }),
      ],
    );
  }

  bool _isCurrentPeriod(PeriodRange period) {
    final today = DateTime.now();
    final t = DateTime(today.year, today.month, today.day);
    return !t.isBefore(period.start) && !t.isAfter(period.end);
  }

  Widget _buildPeriodCard(
      PeriodRange period, double hours, bool isCurrent) {
    final hoursStr = hours.toStringAsFixed(2);
    final dateRange =
        '${_dateFmt.format(period.start)} – ${_dateFmt.format(period.end)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCurrent ? const Color(0xFFE0F2F1) : const Color(0xFFF5F7F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrent ? _accentTeal : Colors.grey.shade200,
          width: isCurrent ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Label + date range
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        period.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isCurrent
                              ? _accentTeal
                              : const Color(0xFF1A1A2E),
                        ),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: _accentTeal,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'current',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateRange,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            // Hours
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  hoursStr,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: hours > 0 ? _accentTeal : Colors.grey.shade400,
                    height: 1.0,
                  ),
                ),
                Text(
                  'hrs',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

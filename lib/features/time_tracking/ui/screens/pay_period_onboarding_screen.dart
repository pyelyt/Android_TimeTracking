import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/pay_period_settings.dart';
import '../../data/settings_repository.dart';

class PayPeriodOnboardingScreen extends StatefulWidget {
  const PayPeriodOnboardingScreen({super.key});

  @override
  State<PayPeriodOnboardingScreen> createState() =>
      _PayPeriodOnboardingScreenState();
}

class _PayPeriodOnboardingScreenState
    extends State<PayPeriodOnboardingScreen> {
  // Keep using the A/B/C/D string values to match your existing UI
  String _selectedMode = "A";

  DateTime? _selectedAnchorDate;
  int? _middleDay;

  final SettingsRepository _repo = SettingsRepository();

  bool _loading = true;
  bool _dirty = false;

  bool get _isValid {
    if (_selectedMode == "B") return _selectedAnchorDate != null;
    if (_selectedMode == "C") return _middleDay != null;
    return true;
  }

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
  }

  Future<void> _loadSavedSettings() async {
    final saved = await _repo.loadSettings();

    if (saved != null) {
      // Map enum to your A/B/C/D values
      String modeString;
      switch (saved.mode) {
        case PayPeriodMode.weekly:
          modeString = "A";
          break;
        case PayPeriodMode.biWeekly:
          modeString = "B";
          break;
        case PayPeriodMode.semiMonthly:
          modeString = "C";
          break;
        case PayPeriodMode.monthly:
          modeString = "D";
          break;
        case PayPeriodMode.quarterly:
          modeString = "D"; // fallback to monthly UI option if needed
          break;
        case PayPeriodMode.yearly:
          modeString = "D"; // fallback
          break;
      }

      setState(() {
        _selectedMode = modeString;
        _selectedAnchorDate = saved.anchorDate;
        _middleDay = saved.middleDay;
        _loading = false;
      });
    } else {
      // No saved settings — default to A
      setState(() {
        _selectedMode = "A";
        _selectedAnchorDate = null;
        _middleDay = null;
        _loading = false;
      });
    }
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Pay Period Setup")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Pay Period Setup")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Choose your pay period type:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            RadioGroup<String>(
              groupValue: _selectedMode,
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _selectedMode = v;
                  _markDirty();
                });
              },
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: const Text("A — Weekly (7‑day cycle)"),
                    subtitle: const Text("Sunday → Saturday"),
                    value: "A",
                  ),

                  const SizedBox(height: 12),

                  RadioListTile<String>(
                    title: const Text("B — Bi‑weekly (14‑day cycle)"),
                    subtitle: const Text("Requires selecting an anchor Sunday"),
                    value: "B",
                  ),

                  if (_selectedMode == "B") _buildAnchorPicker(),

                  const SizedBox(height: 12),

                  RadioListTile<String>(
                    title: const Text("C — Semi‑monthly"),
                    subtitle: const Text("Choose middle‑of‑month day"),
                    value: "C",
                  ),

                  if (_selectedMode == "C") _buildMiddleDayPicker(),

                  const SizedBox(height: 12),

                  RadioListTile<String>(
                    title: const Text("D — Monthly"),
                    subtitle: const Text("No additional setup required"),
                    value: "D",
                  ),
                ],
              ),
            ),

            const Spacer(),

            Center(
              child: ElevatedButton(
                onPressed: _isValid ? _save : null,
                child: const Text("Continue"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnchorPicker() {
    final anchorText = _selectedAnchorDate == null
        ? "Choose Sunday"
        : "Selected: ${DateFormat('MMM d, yyyy').format(_selectedAnchorDate!)}";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Select anchor Sunday:"),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () async {
            final now = DateTime.now();
            final initial = _selectedAnchorDate ?? now;
            final picked = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: DateTime(now.year - 5),
              lastDate: DateTime(now.year + 5),
            );

            if (picked == null) return;
            if (!mounted) return;
            if (picked.weekday != DateTime.sunday) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Please select a Sunday.")),
              );
              return;
            }
            setState(() {
              _selectedAnchorDate = DateTime(picked.year, picked.month, picked.day);
              _markDirty();
            });
          },
          child: Text(anchorText),
        ),
      ],
    );
  }

  Widget _buildMiddleDayPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Select middle‑of‑month day:"),
        const SizedBox(height: 8),
        DropdownButton<int>(
          value: _middleDay,
          hint: const Text("Choose day (2–30)"),
          items: List.generate(29, (i) => i + 2)
              .map((d) => DropdownMenuItem(value: d, child: Text("$d")))
              .toList(),
          onChanged: (v) {
            setState(() {
              _middleDay = v;
              _markDirty();
            });
          },
        ),
      ],
    );
  }

  Future<void> _save() async {
    // Build new settings from current UI state
    PayPeriodSettings newSettings;
    if (_selectedMode == "A") {
      newSettings = PayPeriodSettings(mode: PayPeriodMode.weekly);
    } else if (_selectedMode == "B") {
      newSettings = PayPeriodSettings(
        mode: PayPeriodMode.biWeekly,
        anchorDate: _selectedAnchorDate,
      );
    } else if (_selectedMode == "C") {
      newSettings = PayPeriodSettings(
        mode: PayPeriodMode.semiMonthly,
        middleDay: _middleDay,
      );
    } else {
      newSettings = PayPeriodSettings(mode: PayPeriodMode.monthly);
    }

    // Load existing saved settings to compare
    final old = await _repo.loadSettings();

    // Determine if anything actually changed
    bool changed;
    if (old == null) {
      changed = true;
    } else {
      // Compare mode
      if (old.mode != newSettings.mode) {
        changed = true;
      } else {
        // Compare anchorDate presence and value
        final oldAnchor = old.anchorDate;
        final newAnchor = newSettings.anchorDate;
        final anchorDifferent = (oldAnchor == null && newAnchor != null) ||
            (oldAnchor != null && newAnchor == null) ||
            (oldAnchor != null &&
                newAnchor != null &&
                (oldAnchor.year != newAnchor.year ||
                    oldAnchor.month != newAnchor.month ||
                    oldAnchor.day != newAnchor.day));

        // Compare middleDay
        final middleDifferent = old.middleDay != newSettings.middleDay;

        changed = anchorDifferent || middleDifferent;
      }
    }

    if (changed) {
      await _repo.saveSettings(newSettings);

      if (mounted) Navigator.of(context).pop(true);
    } else {
      debugPrint('PayPeriodOnboarding: no changes, not saving');
      if (mounted) Navigator.of(context).pop(false);
    }
  }
}

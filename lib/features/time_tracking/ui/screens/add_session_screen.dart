import 'package:flutter/material.dart';
import '../../models/work_session.dart';

class AddSessionScreen extends StatefulWidget {
  const AddSessionScreen({super.key});

  @override
  State<AddSessionScreen> createState() => _AddSessionScreenState();
}

class _AddSessionScreenState extends State<AddSessionScreen> {
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  final TextEditingController _notesController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Work Session'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Optional notes about this session',
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Start Time',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (picked != null) {
                  setState(() {
                    _startTime = picked;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _startTime == null
                      ? 'Tap to select start time'
                      : _startTime!.format(context),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'End Time',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (picked != null) {
                  setState(() {
                    _endTime = picked;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _endTime == null
                      ? 'Tap to select end time'
                      : _endTime!.format(context),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveSession,
        label: const Text('Save'),
        icon: const Icon(Icons.check),
      ),
    );
  }
  void _saveSession() {
    if (_startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both start and end times')),
      );
      return;
    }

    final now = DateTime.now();

    final start = DateTime(
      now.year,
      now.month,
      now.day,
      _startTime!.hour,
      _startTime!.minute,
    );

    final end = DateTime(
      now.year,
      now.month,
      now.day,
      _endTime!.hour,
      _endTime!.minute,
    );

    final session = WorkSession(
      start: start,
      end: end,
      notes: _notesController.text,
    );

    Navigator.pop(context, session);
  }


}

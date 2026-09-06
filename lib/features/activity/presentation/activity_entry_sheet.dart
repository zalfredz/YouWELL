import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/shared/widgets/ui_helpers.dart';

class ActivityEntrySheet extends StatefulWidget {
  const ActivityEntrySheet({super.key, required this.controller});
  final WellnessController controller;
  @override
  State<ActivityEntrySheet> createState() => _ActivityEntrySheetState();
}

class _ActivityEntrySheetState extends State<ActivityEntrySheet> {
  String type = 'Jalan';
  final km = TextEditingController(text: '1'),
      minutes = TextEditingController(text: '15');
  String? error;
  @override
  void dispose() {
    km.dispose();
    minutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      title('Gerak hari ini'),
      gap(),
      DropdownButtonFormField<String>(
        initialValue: type,
        items: [
          'Jalan',
          'Lari',
          'Workout',
          'Peregangan',
        ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: (s) => type = s!,
      ),
      gap(),
      TextField(
        controller: km,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Jarak (km, isi 0 jika tidak berlaku)',
        ),
      ),
      gap(),
      TextField(
        controller: minutes,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Durasi (menit)'),
      ),
      if (error != null) Text(error!),
      gap(),
      FilledButton(
        onPressed: () {
          final k = double.tryParse(km.text), m = double.tryParse(minutes.text);
          if (k == null ||
              m == null ||
              !k.isFinite ||
              !m.isFinite ||
              k < 0 ||
              k > 200 ||
              m <= 0 ||
              m > 1440) {
            setState(
              () => error = 'Isi jarak 0–200 km dan durasi 1–1440 menit.',
            );
            return;
          }
          widget.controller.logActivity({'type': type, 'km': k, 'minutes': m});
          Navigator.pop(context);
        },
        child: const Text('Simpan aktivitas'),
      ),
    ],
  );
}

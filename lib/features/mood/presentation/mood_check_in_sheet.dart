import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/features/support/domain/crisis_detector.dart';
import 'package:youwell/features/support/presentation/support_card.dart';
import 'package:youwell/shared/widgets/ui_helpers.dart';

class MoodCheckInSheet extends StatefulWidget {
  const MoodCheckInSheet({super.key, required this.controller});
  final WellnessController controller;
  @override
  State<MoodCheckInSheet> createState() => _MoodCheckInSheetState();
}

class _MoodCheckInSheetState extends State<MoodCheckInSheet> {
  int mood = 3;
  final tags = <String>{};
  final note = TextEditingController();
  String city = 'Tidak dibagikan';
  bool help = false;
  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      title('Bagaimana perasaanmu?'),
      gap(8),
      caption('Semua perasaan boleh hadir di sini.'),
      gap(22),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(
          5,
          (i) => ChoiceChip(
            label: Text(
              ['😔 Berat', '😕 Murung', '😐 Biasa', '🙂 Baik', '😊 Senang'][i],
            ),
            selected: mood == i + 1,
            onSelected: (_) => setState(() => mood = i + 1),
          ),
        ),
      ),
      gap(20),
      caption('Yang sedang memengaruhi harimu'),
      Wrap(
        spacing: 8,
        children:
            ['Sekolah', 'Keluarga', 'Teman', 'Lelah', 'Craving', 'Hal baik']
                .map(
                  (t) => FilterChip(
                    label: Text(t),
                    selected: tags.contains(t),
                    onSelected: (v) =>
                        setState(() => v ? tags.add(t) : tags.remove(t)),
                  ),
                )
                .toList(),
      ),
      gap(),
      TextField(
        controller: note,
        maxLength: 300,
        maxLines: 2,
        onChanged: (t) => setState(() => help = crisisSignal(t)),
        decoration: const InputDecoration(
          labelText: 'Catatan singkat (opsional, privat)',
        ),
      ),
      if (help) const SupportCard(),
      gap(),
      DropdownButtonFormField<String>(
        initialValue: city,
        decoration: const InputDecoration(labelText: 'Wilayah (opsional)'),
        items: [
          'Tidak dibagikan',
          'Jakarta',
          'Bandung',
          'Surabaya',
          'Yogyakarta',
          'Medan',
          'Makassar',
        ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
        onChanged: (v) => city = v!,
      ),
      gap(),
      FilledButton(
        onPressed: () {
          widget.controller.checkInMood({
            'mood': mood,
            'tags': tags.toList(),
            'note': note.text.trim(),
            'city': city,
          });
          Navigator.pop(context);
          toast(
            context,
            'Check-in tersimpan. Terima kasih sudah mendengarkan dirimu.',
          );
        },
        child: const Text('Simpan check-in'),
      ),
    ],
  );
}

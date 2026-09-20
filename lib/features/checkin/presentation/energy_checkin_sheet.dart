import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';

class EnergyCheckInSheet extends StatefulWidget {
  const EnergyCheckInSheet({super.key, required this.controller});
  final WellnessController controller;
  @override
  State<EnergyCheckInSheet> createState() => _EnergyCheckInSheetState();
}

class _EnergyCheckInSheetState extends State<EnergyCheckInSheet> {
  String _energy = 'steady';
  final _tags = <String>{};

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: appBorder,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Energi kamu?',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children:
                const [
                      ('low', 'Low'),
                      ('steady', 'Santai'),
                      ('good', 'Good'),
                      ('charged', 'Charged'),
                    ]
                    .map(
                      (item) => ChoiceChip(
                        label: Text(item.$2),
                        selected: _energy == item.$1,
                        onSelected: (_) => setState(() => _energy = item.$1),
                      ),
                    )
                    .toList(),
          ),
          const SizedBox(height: 22),
          const Text(
            'Apa yang paling berpengaruh? (opsional)',
            style: TextStyle(color: appMuted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: ['Tidur', 'Makan', 'Gerak', 'Fokus']
                .map(
                  (tag) => FilterChip(
                    label: Text(tag),
                    selected: _tags.contains(tag),
                    onSelected: (selected) => setState(
                      () => selected ? _tags.add(tag) : _tags.remove(tag),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                widget.controller.checkInEnergy(_energy, tags: _tags.toList());
                Navigator.pop(context);
              },
              child: const Text('Simpan'),
            ),
          ),
        ],
      ),
    ),
  );
}

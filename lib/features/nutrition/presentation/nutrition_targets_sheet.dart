import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/shared/widgets/ui_helpers.dart';

class NutritionTargetsSheet extends StatefulWidget {
  const NutritionTargetsSheet({super.key, required this.controller});
  final WellnessController controller;
  @override
  State<NutritionTargetsSheet> createState() => _NutritionTargetsSheetState();
}

class _NutritionTargetsSheetState extends State<NutritionTargetsSheet> {
  late final fields = {
    for (final key in ['waterGoal', 'kcalGoal', 'proteinGoal'])
      key: TextEditingController(
        text: widget.controller.profile![key].toString(),
      ),
  };
  String? error;
  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      title('Target pribadi'),
      gap(),
      caption('Sesuaikan dengan kebutuhanmu atau arahan profesional.'),
      gap(),
      ...fields.entries.map(
        (e) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: e.value,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: {
                'waterGoal': 'Air (ml)',
                'kcalGoal': 'Energi (kkal)',
                'proteinGoal': 'Protein (g)',
              }[e.key],
            ),
          ),
        ),
      ),
      if (error != null) Text(error!),
      FilledButton(
        onPressed: () {
          if (fields.values.any(
            (c) =>
                int.tryParse(c.text) == null ||
                int.parse(c.text) <= 0 ||
                int.parse(c.text) > 10000,
          )) {
            setState(
              () => error = 'Isi bilangan bulat positif, maksimal 10.000.',
            );
            return;
          }
          widget.controller.updateNutritionTargets({
            for (final e in fields.entries) e.key: int.parse(e.value.text),
          });
          Navigator.pop(context);
        },
        child: const Text('Simpan target'),
      ),
    ],
  );
}

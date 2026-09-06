import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/platform/platform.dart' as platform;
import 'package:youwell/features/nutrition/data/food_catalog.dart';
import 'package:youwell/shared/widgets/ui_helpers.dart';

class MealEntrySheet extends StatefulWidget {
  const MealEntrySheet({super.key, required this.controller});
  final WellnessController controller;
  @override
  State<MealEntrySheet> createState() => _MealEntrySheetState();
}

class _MealEntrySheetState extends State<MealEntrySheet> {
  int food = 0;
  final servings = TextEditingController(text: '1'),
      customName = TextEditingController(),
      kcal = TextEditingController(),
      protein = TextEditingController(),
      carbs = TextEditingController();
  String? photo, error;
  bool busy = false;
  @override
  void dispose() {
    for (final c in [servings, customName, kcal, protein, carbs]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      title('Catat makanan'),
      gap(8),
      caption(
        'Pilih makanan dan konfirmasi porsi. Estimasi katalog dapat berbeda dari resep sebenarnya. Foto belum dianalisis AI.',
      ),
      gap(),
      OutlinedButton.icon(
        onPressed: busy
            ? null
            : () async {
                setState(() => busy = true);
                final value = await platform.pickPhoto();
                if (mounted) {
                  setState(() {
                    photo = value;
                    busy = false;
                  });
                }
              },
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Tambahkan foto privat'),
      ),
      if (photo != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Image.memory(
            base64Decode(photo!.split(',').last),
            height: 100,
          ),
        ),
      gap(),
      DropdownButtonFormField<int>(
        initialValue: food,
        isExpanded: true,
        items: List.generate(
          foodCatalog.length + 1,
          (i) => DropdownMenuItem(
            value: i,
            child: Text(
              i == foodCatalog.length
                  ? 'Input makanan sendiri'
                  : foodCatalog[i]['name'].toString(),
            ),
          ),
        ),
        onChanged: (i) => setState(() => food = i!),
        decoration: const InputDecoration(labelText: 'Makanan'),
      ),
      gap(),
      if (food < foodCatalog.length)
        caption('Porsi referensi: ${foodCatalog[food]['portion']}')
      else ...[
        TextField(
          controller: customName,
          maxLength: 60,
          decoration: const InputDecoration(labelText: 'Nama makanan'),
        ),
        gap(8),
        ...[
          (kcal, 'Energi per porsi (kkal)'),
          (protein, 'Protein per porsi (g)'),
          (carbs, 'Karbo per porsi (g)'),
        ].map(
          (f) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(
              controller: f.$1,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: f.$2),
            ),
          ),
        ),
      ],
      gap(),
      TextField(
        controller: servings,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Jumlah porsi (0.1–10)'),
      ),
      if (error != null)
        Text(error!, style: const TextStyle(color: Colors.red)),
      gap(),
      FilledButton(
        onPressed: () {
          final n = double.tryParse(servings.text);
          final f = food < foodCatalog.length
              ? foodCatalog[food]
              : {
                  'name': customName.text.trim(),
                  'kcal': double.tryParse(kcal.text),
                  'protein': double.tryParse(protein.text),
                  'carbs': double.tryParse(carbs.text),
                };
          if (n == null ||
              !n.isFinite ||
              n <= 0 ||
              n > 10 ||
              f['name'].toString().isEmpty ||
              ['kcal', 'protein', 'carbs'].any(
                (k) =>
                    f[k] is! num ||
                    !(f[k] as num).isFinite ||
                    (f[k] as num) < 0 ||
                    (f[k] as num) > 10000,
              )) {
            setState(
              () => error = 'Periksa nama, porsi, dan angka gizi yang valid.',
            );
            return;
          }
          widget.controller.addMeal({
            'name': f['name'],
            'servings': n,
            'kcal': (f['kcal'] as num) * n,
            'protein': (f['protein'] as num) * n,
            'carbs': (f['carbs'] as num) * n,
            'photo': photo,
          });
          Navigator.pop(context);
        },
        child: const Text('Konfirmasi & simpan'),
      ),
    ],
  );
}

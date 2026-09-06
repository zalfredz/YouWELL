import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/shared/widgets/ui_helpers.dart';

class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({super.key, required this.controller});
  final WellnessController controller;
  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late final alias = TextEditingController(
        text: widget.controller.profile!['alias'],
      ),
      cost = TextEditingController(
        text: widget.controller.profile!['cost'].toString(),
      );
  late String companion = widget.controller.profile!['companion'];
  late int fitness = widget.controller.profile!['fitness'];
  String? error;
  @override
  void dispose() {
    alias.dispose();
    cost.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      title('Profil & ritmemu'),
      gap(),
      TextField(
        controller: alias,
        maxLength: 20,
        decoration: const InputDecoration(labelText: 'Alias'),
      ),
      gap(),
      DropdownButtonFormField<String>(
        initialValue: companion,
        items: ['plant', 'cat', 'cloud']
            .map(
              (c) => DropdownMenuItem(
                value: c,
                child: Text(
                  {
                    'plant': '🌱 Mori',
                    'cat': '🐱 Milo',
                    'cloud': '☁️ Awan',
                  }[c]!,
                ),
              ),
            )
            .toList(),
        onChanged: (c) => companion = c!,
      ),
      gap(),
      DropdownButtonFormField<int>(
        initialValue: fitness,
        items: [1, 2, 3]
            .map(
              (v) => DropdownMenuItem(
                value: v,
                child: Text(
                  ['Baru mulai', 'Kadang bergerak', 'Cukup aktif'][v - 1],
                ),
              ),
            )
            .toList(),
        onChanged: (v) => fitness = v!,
      ),
      gap(),
      TextField(
        controller: cost,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Estimasi biaya per pemakaian rokok/vape (Rp)',
        ),
      ),
      gap(),
      if (error != null) Text(error!),
      FilledButton(
        onPressed: () async {
          final n = double.tryParse(cost.text);
          if (n == null || !n.isFinite || n < 0 || n > 1000000) {
            setState(() => error = 'Isi biaya valid antara 0–1.000.000.');
            return;
          }
          try {
            await widget.controller.setup({
              'alias': alias.text,
              'companion': companion,
              'fitness': fitness,
              'cost': n,
            });
            if (context.mounted) Navigator.pop(context);
          } catch (_) {
            setState(() => error = 'Alias 3–20 karakter, diawali huruf.');
          }
        },
        child: const Text('Simpan profil'),
      ),
    ],
  );
}

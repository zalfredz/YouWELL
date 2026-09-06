import 'package:flutter/material.dart';
import 'package:youwell/core/platform/platform.dart' as platform;
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/features/support/domain/crisis_detector.dart';
import 'package:youwell/features/support/presentation/support_card.dart';
import 'package:youwell/shared/widgets/ui_helpers.dart';

class MicroVentSheet extends StatefulWidget {
  const MicroVentSheet({super.key});
  @override
  State<MicroVentSheet> createState() => _MicroVentSheetState();
}

class _MicroVentSheetState extends State<MicroVentSheet> {
  final text = TextEditingController();
  bool released = false, help = false;
  @override
  void dispose() {
    text.dispose();
    platform.sound('stop');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      title('Boleh dilepaskan.'),
      gap(8),
      caption(
        'Tulisan ini tidak disimpan atau dikirim. Setelah dilepas, teks dihapus dari tampilan.',
      ),
      gap(22),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 700),
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: released
            ? Container(
                key: const ValueKey('released'),
                height: 190,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.spa, size: 56, color: green),
                    gap(),
                    const Text('Sudah dilepas. Ambil satu napas lagi.'),
                  ],
                ),
              )
            : TextField(
                key: const ValueKey('writing'),
                controller: text,
                maxLines: 5,
                maxLength: 1000,
                onChanged: (t) => setState(() => help = crisisSignal(t)),
                decoration: const InputDecoration(
                  hintText: 'Yang lagi memenuhi pikiranku...',
                ),
              ),
      ),
      if (help) const SupportCard(),
      gap(),
      FilledButton.icon(
        onPressed: released
            ? () => setState(() => released = false)
            : () {
                if (text.text.trim().isEmpty) {
                  toast(context, 'Tulis perasaanmu dulu.');
                  return;
                }
                platform.sound('release');
                text.clear();
                setState(() => released = true);
              },
        icon: Icon(
          released ? Icons.edit_outlined : Icons.local_fire_department_outlined,
        ),
        label: Text(released ? 'Tulis lagi' : 'Lepaskan tulisan'),
      ),
    ],
  );
}

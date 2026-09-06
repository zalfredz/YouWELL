import 'dart:async';
import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/shared/widgets/ui_helpers.dart';

class CravingTimerSheet extends StatefulWidget {
  const CravingTimerSheet({super.key, required this.controller});
  final WellnessController controller;
  @override
  State<CravingTimerSheet> createState() => _CravingTimerSheetState();
}

class _CravingTimerSheetState extends State<CravingTimerSheet> {
  int duration = 300, remaining = 300;
  String trigger = 'Stres';
  DateTime? started, deadline;
  Timer? timer;
  bool complete = false, recorded = false, avoid = false;
  void start() {
    started = widget.controller.now;
    deadline = started!.add(Duration(seconds: duration));
    setState(() => remaining = duration);
    timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final n = deadline!.difference(widget.controller.now).inMilliseconds;
      setState(() => remaining = (n / 1000).ceil().clamp(0, duration));
      if (n <= 0) {
        timer?.cancel();
        setState(() => complete = true);
      }
    });
  }

  void record(bool success) {
    if (recorded || started == null) return;
    recorded = true;
    widget.controller.recordCraving({
      'trigger': trigger,
      'seconds': success
          ? duration
          : widget.controller.now
                .difference(started!)
                .inSeconds
                .clamp(0, duration),
      'success': success,
      'avoided': success && avoid,
      'cost': widget.controller.profile?['cost'] ?? 0,
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    if (!recorded && started != null) {
      final success =
          deadline != null && !widget.controller.now.isBefore(deadline!);
      scheduleMicrotask(() => record(success));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      title('Lewati satu gelombang.'),
      gap(8),
      caption('Jeda bukan perlombaan. Kamu bisa berhenti jika tidak nyaman.'),
      gap(20),
      if (started == null) ...[
        DropdownButtonFormField<String>(
          initialValue: trigger,
          decoration: const InputDecoration(labelText: 'Apa pemicunya?'),
          items: [
            'Stres',
            'Setelah makan',
            'Teman',
            'Bosan',
            'Lainnya',
          ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: (t) => trigger = t!,
        ),
        gap(),
        Wrap(
          spacing: 8,
          children: [300, 600]
              .map(
                (n) => ChoiceChip(
                  label: Text('${n ~/ 60} menit'),
                  selected: duration == n,
                  onSelected: (_) => setState(() {
                    duration = n;
                    remaining = n;
                  }),
                ),
              )
              .toList(),
        ),
        gap(),
        FilledButton(onPressed: start, child: const Text('Mulai jeda')),
      ] else ...[
        Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            width: 170 + (remaining % 8 < 4 ? 20 : 0),
            height: 170 + (remaining % 8 < 4 ? 20 : 0),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xffe4ecdd),
            ),
            child: Center(
              child: Text(
                complete
                    ? 'Selesai 🌿'
                    : '${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 36,
                  color: ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        gap(16),
        Center(
          child: Text(
            complete
                ? 'Terima kasih sudah memberi diri jeda.'
                : remaining % 8 < 4
                ? 'Tarik napas perlahan…'
                : 'Hembuskan perlahan…',
          ),
        ),
        gap(),
        if (!complete)
          caption(
            'Atau lihat sekeliling: temukan 5 benda yang bisa kamu lihat. Bernapas senyamanmu, tanpa perlu menahan napas.',
          ),
        if (complete) ...[
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: avoid,
            onChanged: (v) => setState(() => avoid = v!),
            title: const Text(
              'Aku tidak jadi merokok / vape pada kesempatan ini',
            ),
            subtitle: const Text(
              'Konfirmasi untuk mencatat estimasi uang hemat.',
            ),
          ),
          FilledButton(
            onPressed: () {
              record(true);
              Navigator.pop(context);
            },
            child: const Text('Simpan hasil jeda'),
          ),
        ] else
          TextButton(
            onPressed: () {
              record(false);
              Navigator.pop(context);
            },
            child: const Text('Akhiri sesi sekarang'),
          ),
      ],
    ],
  );
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:youwell/core/platform/platform.dart' as platform;
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/shared/widgets/ui_helpers.dart';

class SoundscapeSheet extends StatefulWidget {
  const SoundscapeSheet({super.key});
  @override
  State<SoundscapeSheet> createState() => _SoundscapeSheetState();
}

class _SoundscapeSheetState extends State<SoundscapeSheet> {
  String kind = 'rain';
  int duration = 60, remaining = 60;
  Timer? timer;
  DateTime? deadline;
  bool playing = false;
  @override
  void dispose() {
    timer?.cancel();
    platform.sound('stop');
    super.dispose();
  }

  void stop() {
    timer?.cancel();
    platform.sound('stop');
    setState(() => playing = false);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      title('Suara untuk ruang tenang.'),
      gap(8),
      caption('Audio sintesis lokal. Mulai dengan volume perangkat rendah.'),
      gap(20),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: ['rain', 'ambient', 'breathing']
            .map(
              (s) => ChoiceChip(
                label: Text(
                  {
                    'rain': '🌧 Hujan lembut',
                    'ambient': '♫ Ambient tones',
                    'breathing': '◯ Panduan napas',
                  }[s]!,
                ),
                selected: kind == s,
                onSelected: playing ? null : (_) => setState(() => kind = s),
              ),
            )
            .toList(),
      ),
      gap(),
      Wrap(
        spacing: 8,
        children: [60, 120, 180]
            .map(
              (n) => ChoiceChip(
                label: Text('${n ~/ 60} menit'),
                selected: duration == n,
                onSelected: playing
                    ? null
                    : (_) => setState(() => duration = n),
              ),
            )
            .toList(),
      ),
      gap(24),
      if (playing)
        Center(
          child: Column(
            children: [
              Text(
                '${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w700,
                  color: green,
                ),
              ),
              gap(),
              Text(
                kind == 'breathing'
                    ? (remaining % 8 < 4
                          ? 'Tarik napas perlahan'
                          : 'Hembuskan perlahan')
                    : 'Dengarkan. Tidak perlu melakukan apa-apa.',
              ),
            ],
          ),
        ),
      gap(),
      FilledButton.icon(
        onPressed: playing
            ? stop
            : () {
                platform.sound(kind);
                deadline = DateTime.now().add(Duration(seconds: duration));
                setState(() {
                  playing = true;
                  remaining = duration;
                });
                timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
                  final n =
                      (deadline!.difference(DateTime.now()).inMilliseconds /
                              1000)
                          .ceil()
                          .clamp(0, duration);
                  setState(() => remaining = n);
                  if (n == 0) stop();
                });
              },
        icon: Icon(playing ? Icons.stop : Icons.play_arrow),
        label: Text(playing ? 'Hentikan' : 'Putar soundscape'),
      ),
    ],
  );
}

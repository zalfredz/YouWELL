import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/shared/widgets/game_widgets.dart';

const _habitSwaps = [
  'Minum segelas air',
  'Napas pelan 1 menit',
  'Jalan sebentar',
  'Kunyah permen bebas gula',
  'Kabari teman',
];

/// Delay Craving timer plus Habit Swap log for the smoking/vaping path.
class DelayCravingPanel extends StatefulWidget {
  const DelayCravingPanel({super.key, required this.controller});
  final WellnessController controller;
  @override
  State<DelayCravingPanel> createState() => _DelayCravingPanelState();
}

class _DelayCravingPanelState extends State<DelayCravingPanel> {
  Timer? _timer;
  late int _duration = widget.controller.delayTargetMinutes * 60;
  // Wall-clock based so the countdown stays honest while backgrounded.
  Duration _elapsedBeforePause = Duration.zero;
  DateTime? _runningSince;
  bool _finished = false;
  String? _delayNote;
  ScaffoldMessengerState? _messenger;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.maybeOf(context);
  }

  bool get _running => _timer != null;

  /// Today's open Delay Craving quest, if any, so its XP is visible here.
  Map<String, dynamic>? get _quest => widget.controller.quests
      .where(
        (task) =>
            task['activityKind'] == 'delay' && task['status'] != 'completed',
      )
      .firstOrNull;

  Duration get _elapsed =>
      _elapsedBeforePause +
      (_runningSince == null
          ? Duration.zero
          : clock.now().difference(_runningSince!));

  int get _remaining => _finished
      ? 0
      : (_duration - _elapsed.inSeconds).clamp(0, _duration).toInt();

  /// A delay stopped before the end is still progress: "ditunda X menit".
  String? _logStoppedDelay() {
    final minutes = _elapsed.inMinutes;
    if (_finished || minutes < 1) return null;
    widget.controller.recordHabitDelay(
      minutes: minutes,
      plannedMinutes: _duration ~/ 60,
      completed: false,
    );
    return 'Tercatat: kamu sudah menunda $minutes menit.';
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (!_finished && _elapsed.inMinutes >= 1) {
      // Defer so listeners are not notified while this tree is unmounting.
      final messenger = _messenger;
      final stopped = _logStoppedDelay;
      scheduleMicrotask(() {
        final note = stopped();
        if (note != null) {
          messenger?.showSnackBar(SnackBar(content: Text(note)));
        }
      });
    }
    super.dispose();
  }

  void _restart() {
    _timer?.cancel();
    final note = _logStoppedDelay();
    setState(() {
      _timer = null;
      _duration = widget.controller.delayTargetMinutes * 60;
      _elapsedBeforePause = Duration.zero;
      _runningSince = null;
      _finished = false;
      _delayNote = note;
    });
  }

  void _toggle() {
    if (_running) {
      _timer?.cancel();
      setState(() {
        _timer = null;
        _elapsedBeforePause = _elapsed;
        _runningSince = null;
      });
      return;
    }
    _runningSince = clock.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remaining > 0) {
        setState(() {});
        return;
      }
      timer.cancel();
      widget.controller.recordHabitDelay(
        minutes: _duration ~/ 60,
        plannedMinutes: _duration ~/ 60,
      );
      setState(() {
        _timer = null;
        _runningSince = null;
        _finished = true;
      });
    });
    setState(() => _delayNote = null);
  }

  void _logSwap(String swap) {
    final wait = widget.controller.habitSwapCooldownMinutes;
    final saved = widget.controller.recordHabitSwap(swap);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            saved
                ? 'Habit Swap dicatat: $swap'
                : 'Habit Swap barusan sudah tercatat. Catat lagi saat '
                      'keinginan berikutnya muncul (sekitar $wait menit lagi).',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (_remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remaining % 60).toString().padLeft(2, '0');
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 42),
      children: [
        Text(
          widget.controller.reductionLabel,
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          'Saat muncul keinginan, mulai Delay Craving '
          '${_duration ~/ 60} menit. Sesi yang selesai otomatis dicatat.',
          style: TextStyle(color: context.colors.muted),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: context.colors.border, width: 2),
          ),
          child: Column(
            children: [
              Text(
                'Tunda rokok / vape',
                style: TextStyle(
                  color: context.colors.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              RingProgress(
                value: _duration == 0 ? 0 : 1 - _remaining / _duration,
                size: 200,
                stroke: 14,
                track: context.colors.border,
                color: _finished
                    ? context.colors.success
                    : context.colors.reduction,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$minutes:$seconds',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.5,
                      ),
                    ),
                    if (_quest != null) XpPill((_quest!['xp'] as num).toInt()),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _remaining == 0 ? null : _toggle,
                      icon: Icon(
                        _running
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      label: Text(_running ? 'Jeda' : 'Mulai'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.outlined(
                    tooltip: 'Ulangi timer',
                    onPressed: _restart,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          '${widget.controller.delayedToday} jeda selesai hari ini',
          style: TextStyle(
            color: context.colors.accent,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (_finished) ...[
          const SizedBox(height: 8),
          const Text('Jeda selesai dan sudah dicatat.'),
        ],
        if (_delayNote != null) ...[
          const SizedBox(height: 8),
          Text(_delayNote!),
        ],
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Habit Swap',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Pilih aktivitas pengganti yang kamu lakukan sekarang.',
                style: TextStyle(color: context.colors.muted, height: 1.5),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final swap in _habitSwaps)
                    ActionChip(
                      backgroundColor: context.colors.raised,
                      side: BorderSide(color: context.colors.border),
                      label: Text(swap),
                      onPressed: () => _logSwap(swap),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${widget.controller.habitSwapsToday} habit swap hari ini',
                style: TextStyle(
                  color: context.colors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

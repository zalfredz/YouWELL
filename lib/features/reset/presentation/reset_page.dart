import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';

class ResetPage extends StatefulWidget {
  const ResetPage({
    super.key,
    required this.controller,
    this.initialMode = 'reset',
  });
  final WellnessController controller;
  final String initialMode;
  @override
  State<ResetPage> createState() => _ResetPageState();
}

const _habitSwaps = [
  'Minum segelas air',
  'Napas pelan 1 menit',
  'Jalan sebentar',
  'Kunyah permen bebas gula',
  'Kabari teman',
];

class _ResetPageState extends State<ResetPage> {
  Timer? _timer;
  int _duration = 5 * 60;
  String _mode = 'focus';
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

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _duration = _mode == 'delay'
        ? widget.controller.delayTargetMinutes * 60
        : 60;
  }

  bool get _running => _timer != null;

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
    if (_mode != 'delay' || _finished || minutes < 1) return null;
    widget.controller.recordHabitDelay(
      minutes: minutes,
      plannedMinutes: _duration ~/ 60,
      completed: false,
    );
    return 'Tercatat: kamu sudah menunda $minutes menit.';
  }

  void _showStretch() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Stretch ringan',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const Text(
              '1. Putar bahu perlahan 5 kali.\n2. Miringkan kepala ke kanan dan kiri.\n3. Berdiri dan regangkan punggung senyamanmu.',
              style: TextStyle(height: 1.6),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.pop(sheetContext),
              child: const Text('Selesai'),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _timer?.cancel();
    if (_mode == 'delay' && !_finished && _elapsed.inMinutes >= 1) {
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

  void _select(String mode, int seconds) {
    _timer?.cancel();
    final note = _logStoppedDelay();
    setState(() {
      _timer = null;
      _mode = mode;
      _duration = seconds;
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
      if (_mode == 'focus') {
        widget.controller.recordFocusSession({
          'minutes': _duration ~/ 60,
          'mode': 'quick',
        });
      } else if (_mode == 'delay') {
        widget.controller.recordHabitDelay(
          minutes: _duration ~/ 60,
          plannedMinutes: _duration ~/ 60,
        );
      }
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
    final reductionSupport =
        widget.initialMode == 'delay' && widget.controller.reduction;
    final minutes = (_remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remaining % 60).toString().padLeft(2, '0');
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 42),
      children: [
        Text(
          reductionSupport ? widget.controller.reductionLabel : 'Ambil jeda',
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          reductionSupport
              ? 'Saat muncul keinginan, mulai Delay Craving '
                    '${widget.controller.delayTargetMinutes} menit. '
                    'Sesi yang selesai otomatis dicatat.'
              : 'Pilihan cepat saat kamu butuh jeda.',
          style: TextStyle(color: context.colors.muted),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [context.colors.selected, context.colors.surface],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: context.colors.border),
          ),
          child: Column(
            children: [
              Text(
                _mode == 'delay'
                    ? 'Tunda rokok / vape'
                    : _mode == 'reset'
                    ? 'Jeda singkat'
                    : 'Fokus singkat',
                style: TextStyle(
                  color: context.colors.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '$minutes:$seconds',
                style: const TextStyle(
                  fontSize: 58,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2,
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
                      label: Text(_running ? 'Tahan' : 'Mulai'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.outlined(
                    onPressed: () => _select(_mode, _duration),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _ModeButton(
                label: 'Fokus 5m',
                icon: Icons.bolt_rounded,
                selected: _mode == 'focus' && _duration == 300,
                onTap: () => _select('focus', 300),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ModeButton(
                label: 'Reset 60s',
                icon: Icons.self_improvement_rounded,
                selected: _mode == 'reset',
                onTap: () => _select('reset', 60),
              ),
            ),
          ],
        ),
        if (widget.controller.reduction) ...[
          const SizedBox(height: 10),
          _ModeButton(
            label:
                'Delay Craving ${widget.controller.delayTargetMinutes} menit',
            icon: Icons.air_rounded,
            selected: _mode == 'delay',
            onTap: () =>
                _select('delay', widget.controller.delayTargetMinutes * 60),
          ),
          const SizedBox(height: 18),
          Text(
            '${widget.controller.delayedToday} jeda selesai hari ini',
            style: TextStyle(
              color: context.colors.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (_mode == 'delay' && _finished) ...[
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
        const SizedBox(height: 26),
        const Text(
          'Aksi cepat',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        _ActionCard(
          icon: Icons.water_drop_outlined,
          title: 'Minum air',
          detail:
              '${widget.controller.water.toInt()} / ${widget.controller.profile?['waterGoal'] ?? 2000} ml',
          action: '+250 ml',
          onTap: widget.controller.addWater,
          progress:
              (widget.controller.water /
                      ((widget.controller.profile?['waterGoal'] as num?) ??
                          2000))
                  .clamp(0, 1)
                  .toDouble(),
        ),
        _ActionCard(
          icon: Icons.accessibility_new_rounded,
          title: 'Stretch ringan',
          detail: 'Leher, bahu, dan punggung',
          action: 'Lihat gerakan',
          onTap: _showStretch,
        ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: selected ? context.colors.selected : context.colors.raised,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? context.colors.accent : context.colors.muted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.action,
    this.onTap,
    this.progress,
  });
  final IconData icon;
  final String title, detail, action;
  final VoidCallback? onTap;
  final double? progress;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: context.colors.border),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Icon(icon, color: context.colors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    detail,
                    style: TextStyle(color: context.colors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onTap, child: Text(action)),
          ],
        ),
        if (progress != null) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            borderRadius: BorderRadius.circular(99),
            backgroundColor: context.colors.raised,
            color: context.colors.cyan,
          ),
        ],
      ],
    ),
  );
}

import 'dart:async';

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

class _ResetPageState extends State<ResetPage> {
  Timer? _timer;
  int _duration = 5 * 60;
  int _remaining = 5 * 60;
  String _mode = 'focus';

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _duration = _mode == 'delay' ? 300 : 60;
    _remaining = _duration;
  }

  bool get _running => _timer != null;

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
    super.dispose();
  }

  void _select(String mode, int seconds) {
    _timer?.cancel();
    setState(() {
      _timer = null;
      _mode = mode;
      _duration = seconds;
      _remaining = seconds;
    });
  }

  void _toggle() {
    if (_running) {
      _timer?.cancel();
      setState(() => _timer = null);
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remaining > 1) {
        setState(() => _remaining--);
        return;
      }
      timer.cancel();
      if (_mode == 'focus') {
        widget.controller.recordFocusSession({
          'minutes': _duration ~/ 60,
          'mode': 'quick',
        });
      } else if (_mode == 'delay') {
        widget.controller.recordHabitDelay(minutes: _duration ~/ 60);
      }
      setState(() {
        _timer = null;
        _remaining = 0;
      });
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (_remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remaining % 60).toString().padLeft(2, '0');
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 42),
      children: [
        const Text(
          'Ambil jeda',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        const Text(
          'Pilihan cepat saat kamu butuh jeda.',
          style: TextStyle(color: appMuted),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xff19352d), appSurface],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xff315043)),
          ),
          child: Column(
            children: [
              Text(
                _mode == 'delay'
                    ? 'Tunda kebiasaan'
                    : _mode == 'reset'
                    ? 'Jeda singkat'
                    : 'Quick focus',
                style: const TextStyle(
                  color: appAccent,
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
                      label: Text(_running ? 'Pause' : 'Mulai'),
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
            label: 'Tunda rokok / vape 5m',
            icon: Icons.air_rounded,
            selected: _mode == 'delay',
            onTap: () => _select('delay', 300),
          ),
        ],
        const SizedBox(height: 26),
        const Text(
          'Quick actions',
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
        const SizedBox(height: 18),
        const Text(
          'Untuk sesi Pomodoro, soundscape, dan fokus panjang, gunakan workspace web YouWell.',
          style: TextStyle(color: appMuted, height: 1.5),
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
    color: selected ? const Color(0xff203a32) : appRaised,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: selected ? appAccent : appMuted),
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
      color: appSurface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: appBorder),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Icon(icon, color: appAccent),
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
                    style: const TextStyle(color: appMuted, fontSize: 12),
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
            backgroundColor: appRaised,
            color: appAccentCyan,
          ),
        ],
      ],
    ),
  );
}

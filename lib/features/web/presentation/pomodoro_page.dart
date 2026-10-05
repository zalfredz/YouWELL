import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/platform/platform.dart' as platform;

class WebPomodoroPage extends StatefulWidget {
  const WebPomodoroPage({super.key, required this.controller});
  final WellnessController controller;

  @override
  State<WebPomodoroPage> createState() => _WebPomodoroPageState();
}

class _Preset {
  const _Preset(this.focus, this.breakMinutes);
  final int focus, breakMinutes;
  String get label => '$focus / $breakMinutes';
}

enum _SessionMode { focus, breakTime }

class _WebPomodoroPageState extends State<WebPomodoroPage> {
  static const _presets = [
    _Preset(45, 15),
    _Preset(25, 5),
    _Preset(15, 5),
    _Preset(10, 5),
  ];

  final _target = TextEditingController();
  Timer? _timer;
  var _preset = _presets[1];
  var _mode = _SessionMode.focus;
  var _remaining = 25 * 60;
  var _notice = 'Pilih durasi dan mulai saat kamu siap.';

  int get _duration =>
      (_mode == _SessionMode.focus ? _preset.focus : _preset.breakMinutes) * 60;
  bool get _running => _timer != null;

  @override
  void dispose() {
    _timer?.cancel();
    _target.dispose();
    super.dispose();
  }

  void _selectPreset(_Preset preset) {
    _timer?.cancel();
    setState(() {
      _timer = null;
      _preset = preset;
      _remaining = _duration;
      _notice = 'Ritme ${preset.label} dipilih.';
    });
  }

  void _setMode(_SessionMode mode) {
    _timer?.cancel();
    setState(() {
      _timer = null;
      _mode = mode;
      _remaining = _duration;
      _notice = mode == _SessionMode.focus
          ? 'Mode fokus siap.'
          : 'Waktunya memberi pikiran jeda.';
    });
  }

  void _toggleTimer() {
    if (_running) {
      _timer?.cancel();
      setState(() {
        _timer = null;
        _notice = 'Timer dijeda. Kamu tetap memegang kendali.';
      });
      return;
    }
    setState(
      () => _notice = _mode == _SessionMode.focus
          ? 'Focus mode aktif. Satu hal pada satu waktu.'
          : 'Break aktif. Tarik napas dan jauhkan mata dari layar.',
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remaining > 1) {
        setState(() => _remaining--);
        return;
      }
      _timer?.cancel();
      _timer = null;
      platform.sound('ding');
      if (_mode == _SessionMode.focus) {
        widget.controller.recordFocusSession({
          'minutes': _preset.focus,
          'target': _target.text.trim(),
          'preset': _preset.label,
          'completed': true,
        });
      }
      setState(() {
        _remaining = 0;
        _notice = _mode == _SessionMode.focus
            ? 'Focus selesai. Ding! Kamu boleh mulai break ${_preset.breakMinutes} menit.'
            : 'Break selesai. Ding! Siap kembali fokus?';
      });
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _timer = null;
      _remaining = _duration;
      _notice = 'Timer di-reset.';
    });
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.colors.canvas,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pomodoro Focus',
            style: TextStyle(
              color: context.colors.text,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -.8,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Ruang tenang untuk menyelesaikan satu hal dengan utuh.',
            style: TextStyle(color: context.colors.muted),
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, box) {
              final timerStage = _TimerStage(
                preset: _preset,
                mode: _mode,
                remaining: _remaining,
                duration: _duration,
                running: _running,
                target: _target,
                notice: _notice,
                presets: _presets,
                onPreset: _selectPreset,
                onMode: _setMode,
                onToggle: _toggleTimer,
                onReset: _resetTimer,
              );
              final insights = _FocusInsights(controller: widget.controller);
              return box.maxWidth < 980
                  ? Column(
                      children: [
                        timerStage,
                        const SizedBox(height: 18),
                        insights,
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: timerStage),
                        const SizedBox(width: 20),
                        Expanded(flex: 3, child: insights),
                      ],
                    );
            },
          ),
        ],
      ),
    ),
  );
}

class _TimerStage extends StatelessWidget {
  const _TimerStage({
    required this.preset,
    required this.mode,
    required this.remaining,
    required this.duration,
    required this.running,
    required this.target,
    required this.notice,
    required this.presets,
    required this.onPreset,
    required this.onMode,
    required this.onToggle,
    required this.onReset,
  });

  final _Preset preset;
  final _SessionMode mode;
  final int remaining, duration;
  final bool running;
  final TextEditingController target;
  final String notice;
  final List<_Preset> presets;
  final ValueChanged<_Preset> onPreset;
  final ValueChanged<_SessionMode> onMode;
  final VoidCallback onToggle, onReset;

  @override
  Widget build(BuildContext context) {
    final minutes = (remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (remaining % 60).toString().padLeft(2, '0');
    final progress = duration == 0 ? 0.0 : 1 - remaining / duration;
    return Container(
      height: 690,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.colors.selected,
            context.colors.surface,
            context.colors.raised,
          ],
        ),
        border: Border.all(color: context.colors.border),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 9,
            runSpacing: 9,
            children: [
              _ModeChip(
                label: 'Focus',
                selected: mode == _SessionMode.focus,
                onTap: () => onMode(_SessionMode.focus),
              ),
              _ModeChip(
                label: 'Short break',
                selected: mode == _SessionMode.breakTime,
                onTap: () => onMode(_SessionMode.breakTime),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: presets
                .map(
                  (item) => ChoiceChip(
                    label: Text('${item.label} min'),
                    selected: identical(item, preset),
                    onSelected: (_) => onPreset(item),
                    showCheckmark: false,
                    selectedColor: context.colors.selected,
                    backgroundColor: context.colors.raised,
                    side: BorderSide(color: context.colors.border),
                    labelStyle: TextStyle(color: context.colors.text),
                  ),
                )
                .toList(),
          ),
          const Spacer(),
          _FlipClock(minutes: minutes, seconds: seconds),
          const SizedBox(height: 22),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 7,
              color: context.colors.accent,
              backgroundColor: context.colors.border,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(color: context.colors.muted, fontSize: 11),
              ),
              const Spacer(),
              Text(
                '${preset.label} rhythm',
                style: TextStyle(color: context.colors.muted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onToggle,
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.accent,
                  foregroundColor: context.colors.canvas,
                  minimumSize: const Size(138, 48),
                ),
                icon: Icon(
                  running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
                label: Text(running ? 'Pause' : 'Start focus'),
              ),
              OutlinedButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Reset'),
              ),
            ],
          ),
          const Spacer(),
          TextField(
            controller: target,
            style: TextStyle(color: context.colors.text),
            decoration: InputDecoration(
              hintText: 'Apa target fokusmu sesi ini?',
              prefixIcon: Icon(Icons.flag_outlined, color: context.colors.cyan),
              filled: true,
              fillColor: context.colors.raised.withValues(alpha: .67),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 13),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Align(
              key: ValueKey(notice),
              alignment: Alignment.centerLeft,
              child: Text(
                notice,
                style: TextStyle(color: context.colors.muted, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
    showCheckmark: false,
    selectedColor: context.colors.text,
    backgroundColor: Colors.transparent,
    side: BorderSide(color: context.colors.border),
    labelStyle: TextStyle(
      color: selected ? context.colors.canvas : context.colors.text,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _FlipClock extends StatelessWidget {
  const _FlipClock({required this.minutes, required this.seconds});
  final String minutes, seconds;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _FlipTile(value: minutes),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            ':',
            style: TextStyle(
              color: context.colors.text,
              fontSize: 68,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
        _FlipTile(value: seconds),
      ],
    ),
  );
}

class _FlipTile extends StatelessWidget {
  const _FlipTile({required this.value});
  final String value;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 280),
    transitionBuilder: (child, animation) => RotationTransition(
      turns: Tween(begin: -.035, end: 0.0).animate(animation),
      alignment: Alignment.bottomCenter,
      child: FadeTransition(opacity: animation, child: child),
    ),
    child: Container(
      key: ValueKey(value),
      width: 190,
      height: 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Column(
              children: [
                Expanded(child: ColoredBox(color: context.colors.raised)),
                Expanded(child: ColoredBox(color: context.colors.surface)),
              ],
            ),
          ),
          Divider(color: context.colors.border, thickness: 2),
          Text(
            value,
            style: TextStyle(
              color: context.colors.text,
              fontSize: 92,
              height: 1,
              fontWeight: FontWeight.w700,
              letterSpacing: -5,
            ),
          ),
        ],
      ),
    ),
  );
}

class _FocusInsights extends StatelessWidget {
  const _FocusInsights({required this.controller});
  final WellnessController controller;

  @override
  Widget build(BuildContext context) {
    final today = controller.focusSessions
        .where((session) => session['day'] == controller.today)
        .toList();
    final minutes = today.fold<int>(
      0,
      (sum, session) => sum + ((session['minutes'] ?? 0) as num).toInt(),
    );
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today’s focus',
            style: TextStyle(
              color: context.colors.text,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              Expanded(
                child: _InsightValue(
                  label: 'Focus time',
                  value: '$minutes min',
                  icon: Icons.timer_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InsightValue(
                  label: 'Sessions',
                  value: '${today.length}',
                  icon: Icons.bolt_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Recent sessions',
            style: TextStyle(
              color: context.colors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          if (today.isEmpty)
            Text(
              'Selesaikan timer pertamamu hari ini.',
              style: TextStyle(color: context.colors.muted, fontSize: 12),
            )
          else
            ...today.reversed
                .take(3)
                .map(
                  (session) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: context.colors.accent,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            session['target']?.toString().isNotEmpty == true
                                ? session['target'].toString()
                                : '${session['minutes']} minute focus',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.colors.text,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _InsightValue extends StatelessWidget {
  const _InsightValue({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: context.colors.raised,
      border: Border.all(color: context.colors.border),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: context.colors.cyan, size: 18),
        const SizedBox(height: 10),
        Text(
          value,
          style: TextStyle(
            color: context.colors.text,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: context.colors.muted, fontSize: 10),
        ),
      ],
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: context.colors.surface,
      border: Border.all(color: context.colors.border),
      borderRadius: BorderRadius.circular(14),
    ),
    child: child,
  );
}

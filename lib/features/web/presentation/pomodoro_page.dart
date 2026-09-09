import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/platform/platform.dart' as platform;

const _bg = Color(0xff0d0e11);
const _panel = Color(0xff16181d);
const _raised = Color(0xff1c1f25);
const _line = Color(0xff2a2d34);
const _text = Color(0xfff1f3f5);
const _muted = Color(0xff9298a3);
const _green = Color(0xff78e3b1);
const _cyan = Color(0xff77d7e5);

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

enum _ReleaseStyle { tear, burn, crush, trash }

class _WebPomodoroPageState extends State<WebPomodoroPage> {
  static const _presets = [
    _Preset(45, 15),
    _Preset(25, 5),
    _Preset(15, 5),
    _Preset(10, 5),
  ];

  final _target = TextEditingController();
  final _vent = TextEditingController();
  Timer? _timer;
  var _preset = _presets[1];
  var _mode = _SessionMode.focus;
  var _remaining = 25 * 60;
  var _notice = 'Pilih durasi dan mulai saat kamu siap.';
  var _releaseStyle = _ReleaseStyle.tear;
  var _releasing = false;

  int get _duration =>
      (_mode == _SessionMode.focus ? _preset.focus : _preset.breakMinutes) * 60;
  bool get _running => _timer != null;

  @override
  void dispose() {
    _timer?.cancel();
    _target.dispose();
    _vent.dispose();
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
    setState(() => _notice = _mode == _SessionMode.focus
        ? 'Focus mode aktif. Satu hal pada satu waktu.'
        : 'Break aktif. Tarik napas dan jauhkan mata dari layar.');
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

  Future<void> _releaseVent() async {
    if (_vent.text.trim().isEmpty || _releasing) return;
    setState(() => _releasing = true);
    await Future<void>.delayed(const Duration(milliseconds: 850));
    if (!mounted) return;
    setState(() {
      _vent.clear();
      _releasing = false;
      _notice = 'Catatan dilepas. Tidak ada yang disimpan.';
    });
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: _bg,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 56),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pomodoro Focus',
                style: TextStyle(
                  color: _text,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.8,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Ruang tenang untuk menyelesaikan satu hal dengan utuh.',
                style: TextStyle(color: _muted),
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
                  final insights = Column(
                    children: [
                      _FocusInsights(controller: widget.controller),
                      const SizedBox(height: 18),
                      _MicroVent(
                        controller: _vent,
                        style: _releaseStyle,
                        releasing: _releasing,
                        onStyle: (style) =>
                            setState(() => _releaseStyle = style),
                        onRelease: _releaseVent,
                      ),
                    ],
                  );
                  return box.maxWidth < 980
                      ? Column(children: [
                          timerStage,
                          const SizedBox(height: 18),
                          insights,
                        ])
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff182522), Color(0xff12171a), Color(0xff18151e)],
        ),
        border: Border.all(color: const Color(0xff30403b)),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: Color(0x44000000), blurRadius: 28, offset: Offset(0, 14)),
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
                    selectedColor: const Color(0xff2c4d41),
                    backgroundColor: const Color(0xff20252a),
                    side: const BorderSide(color: _line),
                    labelStyle: const TextStyle(color: _text),
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
              color: _green,
              backgroundColor: const Color(0xff364047),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('${(progress * 100).round()}%',
                  style: const TextStyle(color: _muted, fontSize: 11)),
              const Spacer(),
              Text('${preset.label} rhythm',
                  style: const TextStyle(color: _muted, fontSize: 11)),
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
                  backgroundColor: _green,
                  foregroundColor: const Color(0xff102019),
                  minimumSize: const Size(138, 48),
                ),
                icon: Icon(
                    running ? Icons.pause_rounded : Icons.play_arrow_rounded),
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
            style: const TextStyle(color: _text),
            decoration: const InputDecoration(
              hintText: 'Apa target fokusmu sesi ini?',
              prefixIcon: Icon(Icons.flag_outlined, color: _cyan),
              filled: true,
              fillColor: Color(0xaa15191d),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 13),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Align(
              key: ValueKey(notice),
              alignment: Alignment.centerLeft,
              child: Text(notice,
                  style: const TextStyle(color: _muted, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: _text,
        backgroundColor: Colors.transparent,
        side: const BorderSide(color: Color(0x99ffffff)),
        labelStyle: TextStyle(
          color: selected ? _bg : _text,
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Text(':',
                  style: TextStyle(
                      color: _text, fontSize: 68, fontWeight: FontWeight.w300)),
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
            color: const Color(0xff24272d),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xff3a3e47)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 18,
                  offset: Offset(0, 10)),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Column(children: const [
                  Expanded(child: ColoredBox(color: Color(0xff292c33))),
                  Expanded(child: ColoredBox(color: Color(0xff202329))),
                ]),
              ),
              const Divider(color: Color(0xff111318), thickness: 2),
              Text(
                value,
                style: const TextStyle(
                  color: _text,
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
          const Text('Today’s focus',
              style: TextStyle(
                  color: _text, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 17),
          Row(children: [
            Expanded(
                child: _InsightValue(
                    label: 'Focus time',
                    value: '$minutes min',
                    icon: Icons.timer_outlined)),
            const SizedBox(width: 10),
            Expanded(
                child: _InsightValue(
                    label: 'Sessions',
                    value: '${today.length}',
                    icon: Icons.bolt_rounded)),
          ]),
          const SizedBox(height: 16),
          const Text('Recent sessions',
              style: TextStyle(
                  color: _muted, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 9),
          if (today.isEmpty)
            const Text('Selesaikan timer pertamamu hari ini.',
                style: TextStyle(color: _muted, fontSize: 12))
          else
            ...today.reversed.take(3).map(
                  (session) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      const Icon(Icons.check_circle_rounded,
                          color: _green, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          session['target']?.toString().isNotEmpty == true
                              ? session['target'].toString()
                              : '${session['minutes']} minute focus',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _text, fontSize: 12),
                        ),
                      ),
                    ]),
                  ),
                ),
        ],
      ),
    );
  }
}

class _InsightValue extends StatelessWidget {
  const _InsightValue(
      {required this.label, required this.value, required this.icon});
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: _raised,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: _cyan, size: 18),
          const SizedBox(height: 10),
          Text(value,
              style: const TextStyle(
                  color: _text, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: _muted, fontSize: 10)),
        ]),
      );
}

class _MicroVent extends StatelessWidget {
  const _MicroVent({
    required this.controller,
    required this.style,
    required this.releasing,
    required this.onStyle,
    required this.onRelease,
  });
  final TextEditingController controller;
  final _ReleaseStyle style;
  final bool releasing;
  final ValueChanged<_ReleaseStyle> onStyle;
  final VoidCallback onRelease;

  @override
  Widget build(BuildContext context) => _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Micro-Vent',
                style: TextStyle(
                    color: _text, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            const Text('Tulis, lepaskan, lalu kembali. Catatan tidak disimpan.',
                style: TextStyle(color: _muted, fontSize: 12)),
            const SizedBox(height: 13),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _ReleaseStyle.values.map((item) {
                final label = switch (item) {
                  _ReleaseStyle.tear => 'Robek',
                  _ReleaseStyle.burn => 'Bakar',
                  _ReleaseStyle.crush => 'Remas',
                  _ReleaseStyle.trash => 'Buang',
                };
                return ChoiceChip(
                  label: Text(label),
                  selected: style == item,
                  onSelected: (_) => onStyle(item),
                  showCheckmark: false,
                  selectedColor: const Color(0xff2c4d41),
                  backgroundColor: _raised,
                  side: const BorderSide(color: _line),
                  labelStyle: const TextStyle(color: _text, fontSize: 11),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeInBack,
              transform: Matrix4.identity()
                ..translateByDouble(
                  releasing
                      ? style == _ReleaseStyle.trash
                          ? 70.0
                          : 0.0
                      : 0.0,
                  releasing ? 30.0 : 0.0,
                  0,
                  1,
                )
                ..rotateZ(releasing
                    ? style == _ReleaseStyle.crush
                        ? .18
                        : style == _ReleaseStyle.tear
                            ? -.08
                            : 0
                    : 0)
                ..scaleByDouble(
                  releasing ? .18 : 1.0,
                  releasing ? .18 : 1.0,
                  1,
                  1,
                ),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 650),
                opacity: releasing ? 0 : 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: style == _ReleaseStyle.burn && releasing
                        ? const Color(0xff4a2418)
                        : const Color(0xffefe9dc),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: controller,
                    maxLines: 5,
                    style: const TextStyle(color: Color(0xff24231f)),
                    decoration: const InputDecoration(
                      hintText: 'Apa yang mau kamu lepaskan?',
                      hintStyle: TextStyle(color: Color(0xff77736a)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(14),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 13),
            FilledButton.icon(
              onPressed: releasing ? null : onRelease,
              icon: Icon(switch (style) {
                _ReleaseStyle.tear => Icons.content_cut_rounded,
                _ReleaseStyle.burn => Icons.local_fire_department_rounded,
                _ReleaseStyle.crush => Icons.compress_rounded,
                _ReleaseStyle.trash => Icons.delete_outline_rounded,
              }),
              label: Text(releasing ? 'Melepaskan…' : 'Lepaskan catatan'),
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
          color: _panel,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      );
}

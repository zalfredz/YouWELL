import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';

/// Hibernasi (Istirahat from 5 Nov 2026): a countdown of calm breathing and
/// keeping still. The quest finishes only when the countdown ends; stopping
/// early gives nothing and can be started again. Time is measured from the
/// start, so a locked screen or a paused web tab still counts.
class HibernationPage extends StatefulWidget {
  const HibernationPage({
    super.key,
    required this.controller,
    required this.questId,
  });
  final WellnessController controller;
  final String questId;

  @override
  State<HibernationPage> createState() => _HibernationPageState();
}

/// One breath: 4 seconds in, 6 seconds out.
const _inhale = 4, _breath = 10;

class _HibernationPageState extends State<HibernationPage> {
  DateTime? _startedAt;
  Timer? _ticker;
  bool _finished = false;

  WellnessController get _c => widget.controller;

  Map<String, dynamic>? get _quest =>
      _c.quests.where((task) => task['id'] == widget.questId).firstOrNull;

  Duration get _target =>
      Duration(minutes: (_quest?['durationMinutes'] as num?)?.toInt() ?? 1);

  Duration get _elapsed {
    final start = _startedAt;
    if (start == null) return Duration.zero;
    final passed = _c.now.difference(start);
    return passed > _target ? _target : passed;
  }

  @override
  void initState() {
    super.initState();
    _finished = _quest?['status'] == 'completed';
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() => _startedAt = _c.now);
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  void _stop() {
    _ticker?.cancel();
    setState(() => _startedAt = null);
  }

  void _tick() {
    if (!mounted || _startedAt == null) return;
    if (_elapsed >= _target) {
      _ticker?.cancel();
      _c.completeCard(widget.questId);
      if (_c.haptics) HapticFeedback.mediumImpact();
      setState(() {
        _finished = true;
        _startedAt = null;
      });
    } else {
      setState(() {});
    }
  }

  static String _clock(Duration value) =>
      '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final quest = _quest;
    final running = _startedAt != null;
    final elapsed = _elapsed;
    final left = _target - elapsed;
    final inhaling = elapsed.inSeconds % _breath < _inhale;
    final calm = _c.reduceMotion;
    final String guide;
    if (_finished) {
      guide = 'Hibernasi selesai. Misinya tercentang.';
    } else if (!running) {
      guide =
          'Duduk nyaman. Tarik napas 4 hitungan, hembuskan 6 hitungan, lalu '
          'berdiam sejenak sampai waktunya habis.';
    } else {
      guide = inhaling ? 'Tarik napas…' : 'Hembuskan pelan…';
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Hibernasi')),
      body: SafeArea(
        child: quest == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Misi ini sudah tidak ada di kartu hari ini.',
                    style: TextStyle(color: c.muted),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                children: [
                  Text(
                    quest['title'].toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Center(
                    child: SizedBox.square(
                      dimension: 240,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CircularProgressIndicator(
                              value: _finished
                                  ? 1
                                  : elapsed.inMilliseconds /
                                        _target.inMilliseconds,
                              strokeWidth: 10,
                              color: _finished ? c.success : c.energy,
                              backgroundColor: c.raised,
                            ),
                          ),
                          // The breathing circle grows on the in-breath.
                          AnimatedScale(
                            scale: running && !calm
                                ? (inhaling ? 1 : .72)
                                : .86,
                            duration: calm
                                ? Duration.zero
                                : Duration(
                                    seconds: inhaling
                                        ? _inhale
                                        : _breath - _inhale,
                                  ),
                            curve: Curves.easeInOut,
                            child: Container(
                              width: 170,
                              height: 170,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (_finished ? c.success : c.energy)
                                    .withValues(alpha: .14),
                              ),
                            ),
                          ),
                          Semantics(
                            liveRegion: true,
                            label: _finished
                                ? 'Selesai'
                                : 'Sisa ${_clock(left)}',
                            excludeSemantics: true,
                            child: _finished
                                ? Icon(
                                    Icons.check_rounded,
                                    size: 72,
                                    color: c.success,
                                  )
                                : Text(
                                    _clock(left),
                                    style: TextStyle(
                                      color: c.text,
                                      fontSize: 48,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    guide,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: c.text,
                      fontSize: running ? 20 : 16,
                      fontWeight: running ? FontWeight.w800 : FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 52,
                    child: _finished
                        ? FilledButton(
                            onPressed: () => Navigator.maybePop(context),
                            child: const Text('Kembali'),
                          )
                        : running
                        ? OutlinedButton(
                            onPressed: _stop,
                            child: const Text('Berhenti'),
                          )
                        : FilledButton.icon(
                            onPressed: _start,
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Mulai'),
                          ),
                  ),
                  if (running) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Misi tercentang saat hitung mundur selesai. Berhenti '
                      'jika pusing.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.muted, fontSize: 13),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

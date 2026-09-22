import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';

/// Foreground-only activity log. Coordinates never enter the local snapshot.
class WorkoutPage extends StatefulWidget {
  const WorkoutPage({super.key, required this.controller});
  final WellnessController controller;

  @override
  State<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> with WidgetsBindingObserver {
  final Stopwatch _watch = Stopwatch();
  Timer? _ticker;
  StreamSubscription<Position>? _positions;
  Position? _lastPosition;
  String _kind = 'walk';
  String? _message;
  double _meters = 0;
  bool _starting = false;
  bool _gpsEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _watch.isRunning) _pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _positions?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    if (_watch.isRunning || _starting) return;
    setState(() {
      _starting = true;
      _message = null;
    });
    var enabled = false;
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        enabled =
            permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse;
      }
    } catch (_) {
      enabled = false;
    }
    if (!mounted) return;
    _gpsEnabled = enabled;
    _lastPosition = null;
    if (enabled) {
      _positions =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
            ),
          ).listen(
            (position) {
              if (!mounted || !_watch.isRunning) return;
              final last = _lastPosition;
              _lastPosition = position;
              if (last == null || position.accuracy > 60) return;
              final delta = Geolocator.distanceBetween(
                last.latitude,
                last.longitude,
                position.latitude,
                position.longitude,
              );
              if (delta > 0 && delta < 150) setState(() => _meters += delta);
            },
            onError: (_) {
              if (mounted) {
                setState(() {
                  _gpsEnabled = false;
                  _message = 'GPS terputus. Timer tetap berjalan.';
                });
              }
            },
          );
    }
    _watch.start();
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    setState(() {
      _starting = false;
      if (!enabled) {
        _message =
            'Lokasi tidak aktif. Waktu tetap tercatat, jarak tidak dihitung.';
      }
    });
  }

  void _pause() {
    _watch.stop();
    _positions?.cancel();
    _positions = null;
    _lastPosition = null;
    setState(() {});
  }

  void _finish() {
    _pause();
    if (_watch.elapsed.inSeconds < 1) return;
    widget.controller.recordWorkout(
      kind: _kind,
      seconds: _watch.elapsed.inSeconds,
      meters: _meters.round(),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = _watch.elapsed;
    final clock =
        '${elapsed.inMinutes.toString().padLeft(2, '0')}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
    return PopScope(
      canPop: !_watch.isRunning,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _watch.isRunning) _pause();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Jalan & Lari')),
        body: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const Text(
              'Gerak sesuai ritmemu',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tracking hanya aktif saat sesi ini berjalan.',
              style: TextStyle(color: appMuted),
            ),
            const SizedBox(height: 24),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'walk',
                  icon: Icon(Icons.directions_walk),
                  label: Text('Jalan'),
                ),
                ButtonSegment(
                  value: 'run',
                  icon: Icon(Icons.directions_run),
                  label: Text('Lari'),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: _watch.elapsed.inSeconds > 0
                  ? null
                  : (value) => setState(() => _kind = value.first),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: appSurface,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: appBorder),
              ),
              child: Column(
                children: [
                  Icon(
                    _kind == 'walk'
                        ? Icons.directions_walk_rounded
                        : Icons.directions_run_rounded,
                    size: 68,
                    color: appAccent,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    clock,
                    style: const TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text('waktu aktif', style: TextStyle(color: appMuted)),
                  const SizedBox(height: 22),
                  Text(
                    '${(_meters / 1000).toStringAsFixed(2)} km',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: appAccent,
                    ),
                  ),
                  Text(
                    _gpsEnabled
                        ? 'jarak GPS perkiraan'
                        : 'jarak belum tersedia',
                    style: const TextStyle(color: appMuted),
                  ),
                ],
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 14),
              Text(_message!, style: const TextStyle(color: appAccentAmber)),
            ],
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _starting
                  ? null
                  : _watch.isRunning
                  ? _pause
                  : _start,
              icon: Icon(
                _watch.isRunning
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
              ),
              label: Text(
                _starting
                    ? 'Menyiapkan...'
                    : _watch.isRunning
                    ? 'Pause'
                    : elapsed.inSeconds > 0
                    ? 'Lanjutkan'
                    : 'Mulai',
              ),
            ),
            if (elapsed.inSeconds > 0) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _finish,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Selesai & simpan'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/features/companion/domain/companion_rewards.dart';

/// Listens once for rewards from every mobile route, including activity pages.
/// The queue is transient; earned rewards themselves are persisted by the controller.
class MobileRewardHost extends StatefulWidget {
  const MobileRewardHost({
    super.key,
    required this.controller,
    required this.child,
    required this.target,
  });
  final WellnessController controller;
  final Widget child;
  final GlobalKey target;
  @override
  State<MobileRewardHost> createState() => _MobileRewardHostState();
}

class _MobileRewardHostState extends State<MobileRewardHost> {
  OverlayEntry? _entry;
  Timer? _timer;
  bool _scheduled = false;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_schedule);
  }

  void _schedule() {
    if (_entry != null || _scheduled || !mounted) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _showNext();
    });
  }

  void _showNext() {
    if (_entry != null || !mounted) return;
    final moment = widget.controller.takeRewardMoment();
    if (moment == null) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    final box = widget.target.currentContext?.findRenderObject();
    final overlayBox = overlay.context.findRenderObject();
    Offset? destination;
    if (box is RenderBox &&
        box.attached &&
        overlayBox is RenderBox &&
        ModalRoute.of(context)?.isCurrent == true) {
      destination = box.localToGlobal(
        box.size.center(Offset.zero),
        ancestor: overlayBox,
      );
    }
    if (widget.controller.haptics && moment.xp > 0) {
      unawaited(HapticFeedback.lightImpact().catchError((_) {}));
    }
    final reduce =
        widget.controller.reduceMotion ||
        MediaQuery.disableAnimationsOf(context);
    _entry = OverlayEntry(
      builder: (_) => InheritedTheme.captureAll(
        context,
        _RewardOverlay(
          moment: moment,
          destination: destination,
          reduceMotion: reduce,
          onClose: _close,
        ),
      ),
    );
    overlay.insert(_entry!);
    _timer = Timer(
      Duration(seconds: moment.dayComplete || moment.evolved ? 5 : 3),
      _close,
    );
  }

  void _close() {
    _timer?.cancel();
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
    if (mounted) {
      _schedule();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_schedule);
    _timer?.cancel();
    _entry?.remove();
    _entry?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _RewardOverlay extends StatelessWidget {
  const _RewardOverlay({
    required this.moment,
    required this.destination,
    required this.reduceMotion,
    required this.onClose,
  });
  final RewardMoment moment;
  final Offset? destination;
  final bool reduceMotion;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final target = destination ?? Offset(size.width / 2, 160);
    final title = moment.dayComplete
        ? 'Hari penuh! ✨'
        : moment.evolved
        ? 'Temanmu tumbuh! 🌱'
        : moment.ladder ??
              (moment.xp > 0 ? 'Langkah kecil, berarti.' : 'Pencapaian baru!');
    final details = [
      if (moment.dayComplete) 'Semua quest selesai · bonus 20 XP',
      if (moment.evolved) 'Tahap pertumbuhan baru terbuka',
      ...moment.unlocks.map((name) => '$name terbuka'),
      ...moment.badges,
    ];
    return Stack(
      children: [
        if (!reduceMotion && moment.xp > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1600),
                curve: Curves.easeInOut,
                builder: (context, value, _) => Stack(
                  children: [
                    Positioned(
                      left: target.dx - 56,
                      top: target.dy + 90 * (1 - value),
                      child: Opacity(
                        opacity: (1 - value).clamp(0, 1),
                        child: Text(
                          '+${moment.xp} XP ✨',
                          style: TextStyle(
                            color: context.colors.accent,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
          left: 16,
          right: 16,
          child: Semantics(
            liveRegion: true,
            child: Material(
              color: context.colors.surface,
              elevation: 8,
              shadowColor: Colors.black38,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(
                  color: context.colors.accent.withValues(alpha: .5),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      moment.ladder != null
                          ? Icons.stairs_rounded
                          : Icons.auto_awesome_rounded,
                      color: context.colors.accent,
                      size: 30,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (moment.xp > 0)
                            Text(
                              '+${moment.xp} XP',
                              style: TextStyle(
                                color: context.colors.accent,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          if (details.isNotEmpty)
                            Text(
                              details.join(' · '),
                              style: TextStyle(
                                color: context.colors.muted,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tutup perayaan',
                      onPressed: onClose,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

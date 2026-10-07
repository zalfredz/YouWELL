import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/features/companion/domain/companion_rewards.dart';

/// Mobile-only living companion. Animation respects OS and in-app preferences.
class MobileCompanion extends StatefulWidget {
  const MobileCompanion({
    super.key,
    required this.controller,
    this.size = 286,
    this.onTap,
  });
  final WellnessController controller;
  final double size;
  final VoidCallback? onTap;
  @override
  State<MobileCompanion> createState() => _MobileCompanionState();
}

class _MobileCompanionState extends State<MobileCompanion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  int _seenReward = 0;
  bool _happy = false;
  bool _moving = false;
  Timer? _reactionTimer;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _configure();
  }

  @override
  void didUpdateWidget(MobileCompanion oldWidget) {
    super.didUpdateWidget(oldWidget);
    _configure();
    if (_seenReward != widget.controller.rewardSerial) {
      _seenReward = widget.controller.rewardSerial;
      _react();
    }
  }

  void _configure() {
    final move =
        !widget.controller.reduceMotion &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (move == _moving) return;
    _moving = move;
    if (move) {
      _motion.repeat(reverse: true);
    } else {
      _motion.stop();
    }
  }

  void _react() {
    if (!mounted) return;
    _reactionTimer?.cancel();
    setState(() => _happy = true);
    _reactionTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _happy = false);
    });
  }

  @override
  void dispose() {
    _reactionTimer?.cancel();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final kind = controller.profile?['companion']?.toString() ?? 'plant';
    final stage = companionStage(controller.level);
    return Semantics(
      button: true,
      label:
          '${companionStageName(kind, stage)}, tahap $stage dari 5. Sentuh untuk menyapa.',
      child: GestureDetector(
        onTap: () {
          _react();
          widget.onTap?.call();
        },
        child: AnimatedBuilder(
          animation: _motion,
          builder: (context, _) => Transform.translate(
            offset: Offset(
              0,
              _moving
                  ? -6 * math.sin(_motion.value * math.pi) - (_happy ? 7 : 0)
                  : 0,
            ),
            child: AnimatedScale(
              scale: _happy && _moving ? 1.06 : 1,
              duration: Duration(milliseconds: _moving ? 250 : 0),
              child: SizedBox.square(
                dimension: widget.size,
                child: AnimatedSwitcher(
                  duration: Duration(milliseconds: _moving ? 650 : 0),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  ),
                  child: CustomPaint(
                    key: ValueKey('$kind-$stage'),
                    size: Size.square(widget.size),
                    painter: _PetPainter(
                      kind,
                      stage,
                      controller.companionAccessory,
                      controller.companionBackground,
                      _happy,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Still drawing of the companion with any stage or reward, for previews.
class CompanionPreview extends StatelessWidget {
  const CompanionPreview({
    super.key,
    required this.kind,
    required this.stage,
    this.accessory = 'none',
    this.background = 'natural',
    this.size = 84,
  });
  final String kind, accessory, background;
  final int stage;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: _PetPainter(kind, stage, accessory, background, false),
    ),
  );
}

class _PetPainter extends CustomPainter {
  _PetPainter(
    this.kind,
    this.stage,
    this.accessory,
    this.background,
    this.happy,
  );
  final String kind, accessory, background;
  final int stage;
  final bool happy;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 300);
    final paint = Paint();
    final backdrop = switch (background) {
      'dusk' => const Color(0xffd4c7f1),
      'sunrise' => const Color(0xffffdcb2),
      _ => const Color(0xffe2ecd7),
    };
    canvas.drawCircle(const Offset(150, 150), 126, paint..color = backdrop);
    if (kind == 'plant') {
      // Five distinct silhouettes: seed, sprout, leaves, flower, small tree.
      if (stage == 1) {
        canvas.drawOval(
          const Rect.fromLTWH(129, 146, 42, 34),
          paint..color = const Color(0xff72976a),
        );
      } else {
        canvas.drawLine(
          const Offset(150, 210),
          Offset(150, stage >= 4 ? 60 : 108),
          paint
            ..color = const Color(0xff42745b)
            ..strokeWidth = stage == 5 ? 10 : 6,
        );
        for (var i = 0; i < stage - 1; i++) {
          final y = 132.0 - i * 24;
          canvas.save();
          canvas.translate(150, y);
          canvas.rotate(-.55);
          canvas.drawOval(
            const Rect.fromLTWH(-67, -22, 66, 33),
            paint..color = const Color(0xff42745b),
          );
          canvas.restore();
          canvas.save();
          canvas.translate(150, y - 12);
          canvas.rotate(.55);
          canvas.drawOval(
            const Rect.fromLTWH(0, -22, 60, 33),
            paint..color = const Color(0xff72976a),
          );
          canvas.restore();
        }
        if (stage >= 4) {
          final flower = Offset(stage == 5 ? 188 : 150, 65);
          for (var i = 0; i < 5; i++) {
            final angle = i * 2 * math.pi / 5;
            canvas.drawCircle(
              flower + Offset(math.cos(angle) * 15, math.sin(angle) * 15),
              13,
              paint..color = const Color(0xffee99b4),
            );
          }
          canvas.drawCircle(flower, 11, paint..color = const Color(0xffffd36d));
        }
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(98, 196, 104, 77),
          const Radius.circular(26),
        ),
        paint..color = const Color(0xfff1b992),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(90, 187, 120, 23),
          const Radius.circular(10),
        ),
        paint..color = const Color(0xffd99c77),
      );
    } else {
      final scale = .75 + stage * .05;
      canvas.save();
      canvas.translate(150, 156);
      canvas.scale(scale);
      canvas.translate(-150, -156);
      paint.color = kind == 'cat'
          ? const Color(0xfff1b992)
          : const Color(0xfffff4dd);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(77, 115, 146, 121),
          const Radius.circular(55),
        ),
        paint,
      );
      if (kind == 'cat') {
        canvas.drawPath(
          Path()
            ..moveTo(81, 155)
            ..lineTo(84, 80)
            ..lineTo(127, 120)
            ..moveTo(175, 120)
            ..lineTo(219, 80)
            ..lineTo(220, 156),
          paint,
        );
        if (stage >= 3) {
          canvas.drawArc(
            const Rect.fromLTWH(211, 175, 37, 61),
            -1.4,
            3.7,
            false,
            Paint()
              ..color = const Color(0xffd99c77)
              ..strokeWidth = 12
              ..style = PaintingStyle.stroke,
          );
        }
      } else {
        canvas.drawCircle(const Offset(126, 110), 43, paint);
        canvas.drawCircle(const Offset(174, 116), 37, paint);
        if (stage >= 4) {
          for (var i = 0; i < 3; i++) {
            canvas.drawArc(
              Rect.fromCircle(
                center: const Offset(150, 95),
                radius: 54.0 + i * 9,
              ),
              math.pi,
              math.pi,
              false,
              Paint()
                ..color = [
                  const Color(0xffee99b4),
                  const Color(0xffffd36d),
                  const Color(0xff72976a),
                ][i]
                ..strokeWidth = 6
                ..style = PaintingStyle.stroke,
            );
          }
        }
      }
      canvas.restore();
      for (var i = 0; i < stage - 1; i++) {
        canvas.drawCircle(
          Offset(48.0 + i * 65, 65 + (i.isEven ? 0 : 12)),
          4,
          paint..color = const Color(0xff72976a),
        );
      }
    }
    final faceY = kind == 'plant' ? 231.0 : 177.0;
    paint.color = const Color(0xff203d34);
    for (final x in [133.0, 169.0]) {
      if (happy) {
        canvas.drawArc(
          Rect.fromCenter(center: Offset(x, faceY), width: 13, height: 10),
          math.pi,
          math.pi,
          false,
          Paint()
            ..color = paint.color
            ..strokeWidth = 3
            ..style = PaintingStyle.stroke,
        );
      } else {
        canvas.drawCircle(Offset(x, faceY), 4.5, paint);
      }
    }
    canvas.drawArc(
      Rect.fromCenter(center: Offset(151, faceY + 9), width: 24, height: 18),
      0,
      math.pi,
      false,
      Paint()
        ..color = paint.color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
    if (accessory == 'ribbon') {
      canvas.drawPath(
        Path()
          ..moveTo(150, 210)
          ..lineTo(131, 200)
          ..lineTo(131, 220)
          ..close()
          ..moveTo(150, 210)
          ..lineTo(169, 200)
          ..lineTo(169, 220)
          ..close(),
        paint..color = const Color(0xff8970d5),
      );
    }
    if (accessory == 'crown') {
      canvas.drawPath(
        Path()
          ..moveTo(120, 83)
          ..lineTo(116, 53)
          ..lineTo(137, 66)
          ..lineTo(150, 44)
          ..lineTo(164, 66)
          ..lineTo(185, 53)
          ..lineTo(181, 83)
          ..close(),
        paint..color = const Color(0xffe5b94f),
      );
    }
    if (accessory == 'stars' || happy) {
      for (final center in [
        const Offset(65, 103),
        const Offset(235, 132),
        const Offset(214, 48),
      ]) {
        canvas.drawPath(
          Path()
            ..moveTo(center.dx, center.dy - 10)
            ..lineTo(center.dx + 3, center.dy - 3)
            ..lineTo(center.dx + 10, center.dy)
            ..lineTo(center.dx + 3, center.dy + 3)
            ..lineTo(center.dx, center.dy + 10)
            ..lineTo(center.dx - 3, center.dy + 3)
            ..lineTo(center.dx - 10, center.dy)
            ..lineTo(center.dx - 3, center.dy - 3)
            ..close(),
          paint..color = const Color(0xffe5b94f),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PetPainter old) =>
      kind != old.kind ||
      stage != old.stage ||
      accessory != old.accessory ||
      background != old.background ||
      happy != old.happy;
}

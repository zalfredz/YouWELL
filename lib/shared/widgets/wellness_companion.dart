import 'package:flutter/material.dart';
import 'package:youwell/core/theme/app_colors.dart';

class WellnessCompanion extends StatelessWidget {
  const WellnessCompanion({
    super.key,
    required this.kind,
    required this.level,
    this.frozen = false,
  });
  final String kind;
  final int level;
  final bool frozen;
  @override
  Widget build(BuildContext context) => Semantics(
    label:
        'Companion $kind level $level${frozen ? ' sedang beristirahat' : ''}',
    child: SizedBox(
      width: 200,
      height: 185,
      child: CustomPaint(painter: _CompanionPainter(kind, level, frozen)),
    ),
  );
}

class _CompanionPainter extends CustomPainter {
  _CompanionPainter(this.kind, this.level, this.frozen);
  final String kind;
  final int level;
  final bool frozen;
  @override
  void paint(Canvas c, Size s) {
    final p = Paint();
    c.drawCircle(const Offset(100, 88), 80, p..color = const Color(0xffe2ecd7));
    if (kind == 'plant') {
      c.drawLine(
        const Offset(100, 120),
        Offset(100, level > 1 ? 35 : 58),
        p
          ..color = green
          ..strokeWidth = 5,
      );
      c.save();
      c.translate(100, 73);
      c.rotate(-.65);
      c.drawOval(const Rect.fromLTWH(-51, -22, 52, 28), p..color = green);
      c.restore();
      c.save();
      c.translate(100, 60);
      c.rotate(.65);
      c.drawOval(
        const Rect.fromLTWH(0, -22, 48, 28),
        p..color = const Color(0xff72976a),
      );
      c.restore();
      if (level > 1) {
        c.drawOval(const Rect.fromLTWH(93, 20, 14, 36), p..color = green);
      }
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(69, 113, 62, 54),
          const Radius.circular(19),
        ),
        p..color = peach,
      );
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(63, 107, 74, 14),
          const Radius.circular(6),
        ),
        p..color = const Color(0xffd99c77),
      );
    } else {
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(51, 69, 98, 77),
          const Radius.circular(40),
        ),
        p..color = kind == 'cat' ? peach : Colors.white,
      );
      if (kind == 'cat') {
        final ears = Path()
          ..moveTo(54, 90)
          ..lineTo(55, 49)
          ..lineTo(82, 72)
          ..moveTo(123, 72)
          ..lineTo(148, 49)
          ..lineTo(147, 95);
        c.drawPath(ears, p);
      } else {
        c.drawCircle(const Offset(83, 69), 30, p);
        c.drawCircle(const Offset(115, 75), 27, p);
      }
    }
    final y = kind == 'plant' ? 137.0 : 109.0;
    c.drawCircle(Offset(89, y), 3, p..color = ink);
    c.drawCircle(Offset(112, y), 3, p);
    c.drawArc(
      Rect.fromCenter(center: Offset(100, y + 5), width: 12, height: 10),
      0,
      3.14,
      false,
      p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    p.style = PaintingStyle.fill;
    if (frozen) {
      c.drawCircle(
        const Offset(141, 129),
        12,
        p..color = Colors.lightBlue.shade100,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CompanionPainter old) =>
      old.kind != kind || old.level != level || old.frozen != frozen;
}

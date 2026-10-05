import 'package:flutter/material.dart';
import 'package:youwell/core/theme/app_colors.dart';

// Mori keeps its natural plant colors in both light and dark themes.
const _moriLeaf = Color(0xff42745b);
const _moriLightLeaf = Color(0xff72976a);
const _moriPot = Color(0xfff1b992);
const _moriPotRim = Color(0xffd99c77);
const _moriFace = Color(0xff203d34);
const _moriBackdrop = Color(0xffe2ecd7);

class WellnessCompanion extends StatelessWidget {
  const WellnessCompanion({
    super.key,
    required this.kind,
    required this.level,
    this.frozen = false,
    this.size = 200,
  });
  final String kind;
  final int level;
  final bool frozen;
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label:
        'Companion $kind level $level${frozen ? ' sedang beristirahat' : ''}',
    child: SizedBox(
      width: size,
      height: size * .925,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 200,
          height: 185,
          child: CustomPaint(painter: _CompanionPainter(kind, level, frozen)),
        ),
      ),
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
    c.drawCircle(
      const Offset(100, 88),
      80,
      p..color = kind == 'plant' ? _moriBackdrop : brandLavender,
    );
    if (kind == 'plant') {
      c.drawLine(
        const Offset(100, 120),
        Offset(100, level > 1 ? 35 : 58),
        p
          ..color = _moriLeaf
          ..strokeWidth = 5,
      );
      c.save();
      c.translate(100, 73);
      c.rotate(-.65);
      c.drawOval(const Rect.fromLTWH(-51, -22, 52, 28), p..color = _moriLeaf);
      c.restore();
      c.save();
      c.translate(100, 60);
      c.rotate(.65);
      c.drawOval(
        const Rect.fromLTWH(0, -22, 48, 28),
        p..color = _moriLightLeaf,
      );
      c.restore();
      if (level > 1) {
        c.drawOval(const Rect.fromLTWH(93, 20, 14, 36), p..color = _moriLeaf);
      }
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(69, 113, 62, 54),
          const Radius.circular(19),
        ),
        p..color = _moriPot,
      );
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(63, 107, 74, 14),
          const Radius.circular(6),
        ),
        p..color = _moriPotRim,
      );
    } else {
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(51, 69, 98, 77),
          const Radius.circular(40),
        ),
        p..color = kind == 'cat' ? brandOrange : brandCream,
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
    c.drawCircle(
      Offset(89, y),
      3,
      p..color = kind == 'plant' ? _moriFace : brandBlue,
    );
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
      c.drawCircle(const Offset(141, 129), 12, p..color = brandLavender);
    }
  }

  @override
  bool shouldRepaint(covariant _CompanionPainter old) =>
      old.kind != kind || old.level != level || old.frozen != frozen;
}

import 'package:flutter/material.dart';

class VibeMapPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = const Color(0xffcddbbb)
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    Offset o(double x, double y) => Offset(x * s.width, y * s.height);
    c.drawLine(o(.10, .10), o(.29, .61), p);
    c.drawLine(o(.32, .67), o(.62, .82), p);
    c.drawOval(
      Rect.fromCenter(
        center: o(.48, .28),
        width: s.width * .16,
        height: s.height * .36,
      ),
      p,
    );
    c.drawLine(o(.68, .23), o(.70, .52), p);
    c.drawLine(o(.70, .35), o(.80, .28), p);
    c.drawLine(o(.83, .52), o(.94, .65), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

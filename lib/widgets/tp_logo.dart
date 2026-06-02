import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Logo TrackParty — pin de localisation blanc + bullseye orange + étoile 4 branches.
class TpLogo extends StatelessWidget {
  final double size;
  const TpLogo({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 0.72,
      height: size,
      child: CustomPaint(painter: _PinPainter()),
    );
  }
}

class _PinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w  = s.width;
    final h  = s.height;
    final r  = w / 2;
    final cx = w / 2;
    final cy = r;

    // Ombre
    canvas.drawPath(
      _pinPath(w, h).shift(const Offset(0, 5)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Corps blanc du pin
    canvas.drawPath(_pinPath(w, h), Paint()..color = Colors.white);

    // Bullseye
    canvas.drawCircle(Offset(cx, cy), r * 0.62, Paint()..color = kAccent);
    canvas.drawCircle(Offset(cx, cy), r * 0.38, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(cx, cy), r * 0.16, Paint()..color = kAccent);

    // Étoile 4 branches (top-right)
    _drawStar(canvas, Offset(cx + r * 0.70, cy - r * 0.58), r * 0.17);
  }

  Path _pinPath(double w, double h) {
    final r  = w / 2;
    final cy = r;
    return Path()
      ..moveTo(w / 2, h)
      ..cubicTo(w * 0.08, h * 0.74, 0, cy + r * 0.52, 0, cy)
      ..arcTo(Rect.fromCircle(center: Offset(w / 2, cy), radius: r), pi, -pi, false)
      ..cubicTo(w, cy + r * 0.52, w * 0.92, h * 0.74, w / 2, h)
      ..close();
  }

  void _drawStar(Canvas canvas, Offset center, double outerR) {
    final innerR = outerR * 0.32;
    const arms  = 4;
    final path  = Path();
    for (int i = 0; i < arms * 2; i++) {
      final angle = (i * pi / arms) - pi / 2;
      final dist  = i.isEven ? outerR : innerR;
      final pt = Offset(center.dx + cos(angle) * dist, center.dy + sin(angle) * dist);
      if (i == 0) { path.moveTo(pt.dx, pt.dy); } else { path.lineTo(pt.dx, pt.dy); }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = kAccent);
  }

  @override
  bool shouldRepaint(_) => false;
}

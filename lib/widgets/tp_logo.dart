import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';

/// Marque officielle TrackParty : « Le Ticket Tombola (Vestiaire) ».
///
/// Ticket corail incliné à -6° avec encoches d'angle et encoches latérales,
/// pointillé de souche interne (masqué sous 34px) et lettrage `tp` bondissant.
class TpLogo extends StatelessWidget {
  final double size;
  final Color color;
  final Color letterColor;
  final Color? shadowColor;
  final bool showShadow;
  final bool? showDashedBorder;
  final double tiltDegrees;

  const TpLogo({
    super.key,
    this.size = 120,
    this.color = kPrimary,
    this.letterColor = Colors.white,
    this.shadowColor,
    this.showShadow = true,
    this.showDashedBorder,
    this.tiltDegrees = -6.0,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _TicketTombolaPainter(
            fillColor: color,
            letterColor: letterColor,
            shadowColor: shadowColor ?? const Color(0x4D05080D),
            showShadow: showShadow,
            showDashedBorder: showDashedBorder ?? size >= 34,
            tiltRadians: tiltDegrees * math.pi / 180,
          ),
        ),
      ),
    );
  }
}

/// Lockup horizontal TrackParty : badge Ticket Tombola + typographie TRACK PARTY.
class TpWordmark extends StatelessWidget {
  final double iconSize;
  final double fontSize;
  final Color? textColor;
  final Color accentColor;
  final bool compact;

  const TpWordmark({
    super.key,
    this.iconSize = 36,
    this.fontSize = 20,
    this.textColor,
    this.accentColor = kPrimary,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = textColor ?? (isDark ? kInkDark : kInkLight);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        TpLogo(size: iconSize),
        SizedBox(width: compact ? 4 : 6),
        RichText(
          text: TextSpan(
            style: GoogleFonts.notoSansDisplay(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
              height: 1.0,
            ),
            children: [
              TextSpan(text: 'TRACK', style: TextStyle(color: ink)),
              TextSpan(text: 'PARTY', style: TextStyle(color: accentColor)),
            ],
          ),
        ),
      ],
    );
  }
}

class _TicketTombolaPainter extends CustomPainter {
  final Color fillColor;
  final Color letterColor;
  final Color shadowColor;
  final bool showShadow;
  final bool showDashedBorder;
  final double tiltRadians;

  const _TicketTombolaPainter({
    required this.fillColor,
    required this.letterColor,
    required this.shadowColor,
    required this.showShadow,
    required this.showDashedBorder,
    required this.tiltRadians,
  });

  static final Path _ticketPath = _buildTicketPath();
  static final Path _tPath = _buildTPath();
  static final Path _pPath = _buildPPath();
  static final Path _innerFramePath = Path()
    ..addRRect(
      RRect.fromLTRBR(23, 32, 97, 88, const Radius.circular(4)),
    );

  static Path _buildTicketPath() {
    return Path()
      ..moveTo(25, 24)
      ..lineTo(95, 24)
      ..arcToPoint(const Offset(106, 35),
          radius: const Radius.circular(11), clockwise: false)
      ..lineTo(106, 53)
      ..arcToPoint(const Offset(106, 67),
          radius: const Radius.circular(7), clockwise: false)
      ..lineTo(106, 85)
      ..arcToPoint(const Offset(95, 96),
          radius: const Radius.circular(11), clockwise: false)
      ..lineTo(25, 96)
      ..arcToPoint(const Offset(14, 85),
          radius: const Radius.circular(11), clockwise: false)
      ..lineTo(14, 67)
      ..arcToPoint(const Offset(14, 53),
          radius: const Radius.circular(7), clockwise: false)
      ..lineTo(14, 35)
      ..arcToPoint(const Offset(25, 24),
          radius: const Radius.circular(11), clockwise: false)
      ..close();
  }

  static Path _buildTPath() {
    return Path()
      ..moveTo(34, 32)
      ..cubicTo(34, 29.8, 35.8, 28, 38, 28)
      ..lineTo(43, 28)
      ..cubicTo(45.2, 28, 47, 29.8, 47, 32)
      ..lineTo(47, 40.5)
      ..lineTo(52, 40.5)
      ..cubicTo(54.2, 40.5, 55.8, 42.1, 55.8, 44.3)
      ..lineTo(55.8, 48.7)
      ..cubicTo(55.8, 50.9, 54.2, 52.5, 52, 52.5)
      ..lineTo(47, 52.5)
      ..lineTo(47, 63.5)
      ..cubicTo(47, 67.5, 48.8, 69.2, 52.3, 69.2)
      ..lineTo(53.2, 69.2)
      ..cubicTo(55.1, 69.2, 56.5, 70.6, 56.5, 72.5)
      ..lineTo(56.5, 77)
      ..cubicTo(56.5, 79.1, 54.9, 80.5, 52.2, 80.5)
      ..lineTo(48.8, 80.5)
      ..cubicTo(38.8, 80.5, 34, 74.8, 34, 64.2)
      ..lineTo(34, 32)
      ..close();
  }

  static Path _buildPPath() {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..moveTo(59.5, 43.5)
      ..cubicTo(59.5, 41.4, 61.1, 39.8, 63.2, 39.8)
      ..lineTo(68.3, 39.8)
      ..cubicTo(70.3, 39.8, 71.8, 41.2, 71.9, 43)
      ..cubicTo(74.6, 40.6, 78.2, 39.4, 82.4, 39.4)
      ..cubicTo(93, 39.4, 100.2, 48.2, 100.2, 60)
      ..cubicTo(100.2, 71.8, 93, 80.6, 82.4, 80.6)
      ..cubicTo(78.4, 80.6, 75, 79.4, 72.3, 77.2)
      ..lineTo(72.3, 87.8)
      ..cubicTo(72.3, 89.9, 70.7, 91.5, 68.6, 91.5)
      ..lineTo(63.2, 91.5)
      ..cubicTo(61.1, 91.5, 59.5, 89.9, 59.5, 87.8)
      ..lineTo(59.5, 43.5)
      ..close()
      ..moveTo(71.8, 60)
      ..cubicTo(71.8, 66.2, 75.3, 70.4, 80.4, 70.4)
      ..cubicTo(85.5, 70.4, 89, 66.2, 89, 60)
      ..cubicTo(89, 53.8, 85.5, 49.6, 80.4, 49.6)
      ..cubicTo(75.3, 49.6, 71.8, 53.8, 71.8, 60)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 120.0;
    canvas.save();
    canvas.scale(s, s);
    canvas.translate(60, 60);
    canvas.rotate(tiltRadians);
    canvas.translate(-60, -60);

    // Ombre autocollant nette (détourage physique du ticket)
    if (showShadow) {
      canvas.save();
      canvas.translate(4, 5);
      canvas.drawPath(_ticketPath, Paint()..color = shadowColor);
      canvas.restore();
    }

    // Fond du ticket
    canvas.drawPath(_ticketPath, Paint()..color = fillColor);

    // Filet pointillé de billet (lisible dès 34px)
    if (showDashedBorder) {
      final dashPaint = Paint()
        ..color = letterColor.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.butt;
      for (final ui.PathMetric metric in _innerFramePath.computeMetrics()) {
        double dist = 0;
        const dash = 4.0;
        const gap = 3.5;
        while (dist < metric.length) {
          final end = math.min(dist + dash, metric.length);
          canvas.drawPath(metric.extractPath(dist, end), dashPaint);
          dist += dash + gap;
        }
      }
    }

    // Lettrage 'tp' centré et légèrement désaxé façon sticker
    const letterScale = 0.82;
    const ox = 60.0 - 67.1 * letterScale;
    const oy = 60.0 - 59.8 * letterScale;
    final letterPaint = Paint()..color = letterColor;

    canvas.save();
    canvas.translate(ox, oy);
    canvas.scale(letterScale, letterScale);

    canvas.save();
    canvas.translate(44, 56);
    canvas.rotate(-4 * math.pi / 180);
    canvas.translate(-44, -56);
    canvas.drawPath(_tPath, letterPaint);
    canvas.restore();

    canvas.save();
    canvas.translate(79, 60);
    canvas.rotate(3 * math.pi / 180);
    canvas.translate(-79, -60);
    canvas.translate(0, -1.2);
    canvas.drawPath(_pPath, letterPaint);
    canvas.restore();

    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TicketTombolaPainter old) =>
      old.fillColor != fillColor ||
      old.letterColor != letterColor ||
      old.shadowColor != shadowColor ||
      old.showShadow != showShadow ||
      old.showDashedBorder != showDashedBorder ||
      old.tiltRadians != tiltRadians;
}

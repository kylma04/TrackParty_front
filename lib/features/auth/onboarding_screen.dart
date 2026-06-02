import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;

  void _next() {
    if (_page < 2) {
      _ctrl.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tpBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Skip ──────────────────────────────────────────────────────
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, Sp.lg, 0),
                child: Semantics(
                  button: true,
                  label: 'Passer l\'onboarding',
                  child: GestureDetector(
                    onTap: () => context.go('/login'),
                    child: Text('Passer',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.tpInkSub)),
                  ),
                ),
              ),
            ),

            // ── Illustrations ─────────────────────────────────────────────
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: 8),
                child: PageView.builder(
                  controller: _ctrl,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemCount: 3,
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: [
                      const _MapIllustration(),
                      const _GiftIllustration(),
                      const _CrownIllustration(),
                    ][i],
                  ),
                ),
              ),
            ),

            // ── Texte + dots + bouton ─────────────────────────────────────
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.lg, Sp.xl, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ['Découvre les events\nautour de toi', 'Apporte ta\ncontribution', 'Construis ta\nréputation'][_page],
                      style: TextStyle(
                        fontSize: 30, fontWeight: FontWeight.w900,
                        letterSpacing: -1.0, height: 1.1, color: context.tpInk,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      [
                        'Une carte interactive avec tous les rendez-vous festifs en Côte d\'Ivoire.',
                        'Bouteille, plat, sono… Chaque promoteur indique ce qu\'il attend de toi.',
                        'Organise, participe, gagne en confiance. Deviens un Promoteur reconnu.',
                      ][_page],
                      style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500,
                        height: 1.45, color: context.tpInkSub,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: List.generate(3, (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: Sp.sm),
                        width: i == _page ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          gradient: i == _page ? trackpartyGradient : null,
                          color: i == _page ? null : const Color(0xFFD9D8E5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      )),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 50),
                      child: TpButton(
                        label: _page == 2 ? 'Commencer' : 'Suivant',
                        fullWidth: true,
                        onPressed: _next,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Background "Photo" fidèle au JSX — radial gradients empilés
// tone dusk   : #1B1A2E · #4F46E5 · #EC4899
// tone sunset : #EC4899 · #F97316 · #F59E0B
// tone party  : #7C3AED · #EC4899 · #F97316
// ═══════════════════════════════════════════════════════════

class _PhotoBg extends StatelessWidget {
  final Color a;
  final Color b;
  final Color c;
  final Widget child;

  const _PhotoBg({required this.a, required this.b, required this.c, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Base linear gradient (135°, a → c)
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [a, c],
            ),
          ),
        ),
        // Radial a — haut-gauche (20% 10%)
        Positioned.fill(child: _RadialLayer(color: a, cx: 0.20, cy: 0.10, rx: 1.2, ry: 0.9, opacity: 0.85)),
        // Radial b — haut-droit (90% 20%)
        Positioned.fill(child: _RadialLayer(color: b, cx: 0.90, cy: 0.20, rx: 1.2, ry: 0.9, opacity: 0.75)),
        // Radial c — bas-centre (50% 110%)
        Positioned.fill(child: _RadialLayer(color: c, cx: 0.50, cy: 1.10, rx: 1.2, ry: 1.0, opacity: 0.70)),
        // Texture croisée légère
        Positioned.fill(
          child: CustomPaint(painter: _TexturePainter()),
        ),
        // Lumière haute (glow blanc depuis le haut)
        Positioned(
          top: 0, left: 0, right: 0,
          height: 120,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white.withValues(alpha: 0.18), Colors.transparent],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _RadialLayer extends StatelessWidget {
  final Color color;
  final double cx, cy, rx, ry, opacity;
  const _RadialLayer({required this.color, required this.cx, required this.cy,
    required this.rx, required this.ry, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, box) {
      final w = box.maxWidth, h = box.maxHeight;
      return CustomPaint(
        painter: _RadialPainter(
          center: Offset(cx * w, cy * h),
          radiusX: rx * w / 2,
          radiusY: ry * h / 2,
          color: color.withValues(alpha: opacity),
        ),
      );
    });
  }
}

class _RadialPainter extends CustomPainter {
  final Offset center;
  final double radiusX, radiusY;
  final Color color;
  const _RadialPainter({required this.center, required this.radiusX,
    required this.radiusY, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, Colors.transparent],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCenter(center: center, width: radiusX * 2, height: radiusY * 2));
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radiusX * 2, height: radiusY * 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

class _TexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const step = 4.0;
    for (double i = 0; i < size.width + size.height; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(0, i), p);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ═══════════════════════════════════════════════════════════
// SLIDE 1 — Carte avec marqueurs + emojis
// ═══════════════════════════════════════════════════════════

class _MapIllustration extends StatelessWidget {
  const _MapIllustration();

  // couleur → emoji (mêmes catégories que la carte de l'app)
  static const _pins = [
    _PinData(x: 80,  y: 110, color: Color(0xFFEC4899), emoji: '🎉', big: true),
    _PinData(x: 200, y: 90,  color: Color(0xFFF97316), emoji: '🍽', big: false),
    _PinData(x: 130, y: 220, color: Color(0xFF06B6D4), emoji: '⚽', big: false),
    _PinData(x: 240, y: 240, color: Color(0xFF84CC16), emoji: '🎨', big: false),
    _PinData(x: 60,  y: 290, color: Color(0xFF7C3AED), emoji: '🎵', big: false),
  ];

  @override
  Widget build(BuildContext context) {
    // tone="dusk" : a=#1B1A2E · b=#4F46E5 · c=#EC4899
    return _PhotoBg(
      a: const Color(0xFF1B1A2E),
      b: const Color(0xFF4F46E5),
      c: const Color(0xFFEC4899),
      child: CustomPaint(
        painter: _MapPainter(pins: _pins),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _PinData {
  final double x, y;
  final Color color;
  final String emoji;
  final bool big;
  const _PinData({required this.x, required this.y, required this.color,
    required this.emoji, required this.big});
}

class _MapPainter extends CustomPainter {
  final List<_PinData> pins;
  const _MapPainter({required this.pins});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 320;
    final sy = size.height / 380;

    // ── Routes ──────────────────────────────────────────────────────────
    final road = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    void quad(double x1, double y1, double cx, double cy, double x2, double y2) {
      canvas.drawPath(
        Path()..moveTo(x1 * sx, y1 * sy)..quadraticBezierTo(cx * sx, cy * sy, x2 * sx, y2 * sy),
        road,
      );
    }

    quad(0, 60, 160, 80, 320, 50);
    quad(0, 150, 200, 130, 320, 170);
    quad(0, 240, 120, 280, 320, 230);
    quad(80, 0, 60, 200, 100, 380);
    quad(220, 0, 260, 200, 200, 380);

    // ── Marqueurs avec emoji ─────────────────────────────────────────────
    for (final p in pins) {
      final pw = (p.big ? 44.0 : 32.0) * sx;
      final ph = (p.big ? 56.0 : 42.0) * sy;
      final cx = p.x * sx;
      final top = p.y * sy - ph;
      final bounds = Rect.fromLTWH(cx - pw / 2, top, pw, ph);

      // Ombre
      canvas.drawPath(
        _pinPath(bounds).shift(Offset(0, 3 * sy)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.30)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      // Corps coloré
      canvas.drawPath(_pinPath(bounds), Paint()..color = p.color);
      // Anneau blanc
      final headR = pw / 2;
      canvas.drawCircle(Offset(cx, top + headR), headR, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(cx, top + headR), headR - 2 * sx, Paint()..color = p.color);

      // Emoji centré dans la tête
      final fontSize = (p.big ? 20.0 : 14.0) * sx;
      final pb = ui.ParagraphBuilder(ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: fontSize,
        maxLines: 1,
      ))..addText(p.emoji);
      final para = pb.build()..layout(ui.ParagraphConstraints(width: pw));
      canvas.drawParagraph(para, Offset(cx - pw / 2, top + headR - para.height / 2));
    }

    // ── You-are-here (point indigo + halo) ──────────────────────────────
    final youX = 160.0 * sx;
    final youY = 320.0 * sy;
    canvas.drawCircle(Offset(youX, youY), 10 * sx, Paint()..color = kPrimary.withValues(alpha: 0.30));
    canvas.drawCircle(Offset(youX, youY), 11 * sx, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(youX, youY), 8  * sx, Paint()..color = kPrimary);
  }

  Path _pinPath(Rect r) {
    final cx = r.left + r.width / 2;
    final cy = r.top + r.width / 2;
    final rad = r.width / 2;
    return Path()
      ..moveTo(cx, r.bottom)
      ..cubicTo(r.left, cy + rad * 0.65, r.left, cy + rad * 0.1, r.left, cy)
      ..arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: rad), pi, -pi, false)
      ..cubicTo(r.right, cy + rad * 0.1, r.right, cy + rad * 0.65, cx, r.bottom)
      ..close();
  }

  @override
  bool shouldRepaint(_) => false;
}

// ═══════════════════════════════════════════════════════════
// SLIDE 2 — Bouteille + Plat + Enceinte (emoji réels)
// ═══════════════════════════════════════════════════════════

class _GiftIllustration extends StatelessWidget {
  const _GiftIllustration();

  @override
  Widget build(BuildContext context) {
    // tone="sunset" : a=#EC4899 · b=#F97316 · c=#F59E0B
    return _PhotoBg(
      a: const Color(0xFFEC4899),
      b: const Color(0xFFF97316),
      c: const Color(0xFFF59E0B),
      child: Stack(
        children: [
          // ── Sparkles ────────────────────────────────────────────────
          ...[
            (50.0, 80.0, 12.0), (270.0, 120.0, 16.0),
            (80.0, 290.0, 10.0), (240.0, 60.0, 14.0),
          ].map((s) => Positioned(
            left: s.$1, top: s.$2,
            child: CustomPaint(
              painter: _StarPainter(radius: s.$3, color: Colors.white.withValues(alpha: 0.9)),
              size: Size(s.$3 * 2, s.$3 * 2),
            ),
          )),

          // ── Trois items centrés ─────────────────────────────────────
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Bouteille d'alcool
                _EmojiCard(
                  emoji: '🍾',
                  emojiSize: 60,
                  width: 72,
                  height: 160,
                  bgColor: const Color(0xFF1B1A2E),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                    bottom: Radius.circular(14),
                  ),
                ),
                const SizedBox(width: 14),
                // Plat de nourriture
                _EmojiCard(
                  emoji: '🍛',
                  emojiSize: 56,
                  width: 110,
                  height: 110,
                  bgColor: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(55),
                  outerBorder: const Border.fromBorderSide(
                    BorderSide(color: Colors.white, width: 4),
                  ),
                ),
                const SizedBox(width: 14),
                // Enceinte sonore
                _EmojiCard(
                  emoji: '🔊',
                  emojiSize: 40,
                  width: 66,
                  height: 130,
                  bgColor: const Color(0xFF1B1A2E),
                  borderRadius: BorderRadius.circular(14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmojiCard extends StatelessWidget {
  final String emoji;
  final double emojiSize;
  final double width, height;
  final Color bgColor;
  final BorderRadiusGeometry borderRadius;
  final BoxBorder? outerBorder;

  const _EmojiCard({
    required this.emoji,
    required this.emojiSize,
    required this.width,
    required this.height,
    required this.bgColor,
    required this.borderRadius,
    this.outerBorder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: borderRadius,
        border: outerBorder,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: TextStyle(fontSize: emojiSize)),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// SLIDE 3 — Couronne + avatars empilés
// ═══════════════════════════════════════════════════════════

class _CrownIllustration extends StatelessWidget {
  const _CrownIllustration();

  static const _avatars = [
    ('AK', Color(0xFF4F46E5)),
    ('BD', Color(0xFFEC4899)),
    ('CE', Color(0xFFF97316)),
    ('DF', Color(0xFF06B6D4)),
    ('+5', Color(0xFF1B1A2E)),
  ];

  // Largeur totale des avatars superposés
  // 5 avatars × 48px, overlap 12px entre chacun → 48 + 4 × 36 = 192px
  static const _avatarW = 48.0;
  static const _overlap = 12.0;
  // 5 avatars : 48 + 4 × 36 = 192
  static const _totalW = _avatarW + 4 * (_avatarW - _overlap);

  @override
  Widget build(BuildContext context) {
    // tone="party" : a=#7C3AED · b=#EC4899 · c=#F97316
    return _PhotoBg(
      a: const Color(0xFF7C3AED),
      b: const Color(0xFFEC4899),
      c: const Color(0xFFF97316),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Couronne ──────────────────────────────────────────────
            CustomPaint(
              painter: _CrownPainter(),
              size: const Size(180, 120),
            ),
            const SizedBox(height: 24),

            // ── Avatars superposés, centrés ───────────────────────────
            SizedBox(
              width: _totalW,
              height: _avatarW + 6, // +6 pour la bordure blanche
              child: Stack(
                children: List.generate(_avatars.length, (i) {
                  final (label, color) = _avatars[i];
                  return Positioned(
                    left: i * (_avatarW - _overlap),
                    top: 0,
                    child: Container(
                      width: _avatarW,
                      height: _avatarW,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CrownPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 180;
    final sy = size.height / 120;

    // Corps de la couronne (orange)
    final body = Path()
      ..moveTo(20 * sx, 90 * sy)
      ..lineTo(10 * sx, 30 * sy)
      ..lineTo(50 * sx, 60 * sy)
      ..lineTo(90 * sx, 15 * sy)
      ..lineTo(130 * sx, 60 * sy)
      ..lineTo(170 * sx, 30 * sy)
      ..lineTo(160 * sx, 90 * sy)
      ..close();

    canvas.drawPath(body, Paint()..color = kAccent);
    canvas.drawPath(body, Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * sx);

    // Bande de base (violet)
    final base = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(20 * sx, 90 * sy, 140 * sx, 14 * sy),
        Radius.circular(4 * sx),
      ));
    canvas.drawPath(base, Paint()..color = kSecondary);
    canvas.drawPath(base, Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * sx);

    // Cercles aux pointes (rose)
    void tip(double x, double y, double r) {
      canvas.drawCircle(Offset(x * sx, y * sy), r * sx, Paint()..color = kTertiary);
      canvas.drawCircle(Offset(x * sx, y * sy), r * sx, Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * sx);
    }

    tip(10, 30, 8);
    tip(90, 15, 10);
    tip(170, 30, 8);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Étoile 4 branches ─────────────────────────────────────────────────────────

class _StarPainter extends CustomPainter {
  final double radius;
  final Color color;
  const _StarPainter({required this.radius, required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2, cy = s.height / 2;
    final inner = radius * 0.30;
    const arms = 4;
    final path = Path();
    for (int i = 0; i < arms * 2; i++) {
      final angle = (i * pi / arms) - pi / 2;
      final r = i.isEven ? radius : inner;
      final pt = Offset(cx + cos(angle) * r, cy + sin(angle) * r);
      if (i == 0) { path.moveTo(pt.dx, pt.dy); } else { path.lineTo(pt.dx, pt.dy); }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_) => false;
}

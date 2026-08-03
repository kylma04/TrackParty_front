import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_button.dart';

// ═══════════════════════════════════════════════════════════
// Contenu des slides — copy reprise du site (Hero/Manifeste/
// HowToUse) et de speech.md, condensée pour l'onboarding mobile.
// ═══════════════════════════════════════════════════════════

class _Satellite {
  final IconData icon;
  final Color color;
  final Alignment alignment;
  const _Satellite(this.icon, this.color, this.alignment);
}

class _SlideData {
  final String kicker;
  final String title;
  final String description;
  final IconData icon;
  final Color accent;
  final Color toneA, toneB, toneC;
  final List<_Satellite> satellites;
  const _SlideData({
    required this.kicker,
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    required this.toneA,
    required this.toneB,
    required this.toneC,
    required this.satellites,
  });
}

// Positions communes des 3 satellites autour du badge central —
// constellation cohérente d'une slide à l'autre.
const _satTopLeft = Alignment(-0.88, -0.52);
const _satTopRight = Alignment(0.86, -0.4);
const _satBottom = Alignment(-0.55, 0.8);

final _slides = <_SlideData>[
  _SlideData(
    kicker: 'BIENVENUE',
    title: 'Ce que tu cherches\nexiste déjà.',
    description: 'Soirées, concerts, ateliers, sport, clubs de lecture… Trouve les événements et les gens qui te ressemblent, partout en Côte d\'Ivoire.',
    icon: PhosphorIcons.compass(PhosphorIconsStyle.fill),
    accent: kPrimary,
    toneA: kInkLight, toneB: kPrimary, toneC: kTertiary,
    satellites: [
      _Satellite(PhosphorIcons.mapPin(PhosphorIconsStyle.fill), kTertiary, _satTopLeft),
      _Satellite(PhosphorIcons.musicNotes(PhosphorIconsStyle.fill), kAccent, _satTopRight),
      _Satellite(PhosphorIcons.usersThree(PhosphorIconsStyle.fill), kInfo, _satBottom),
    ],
  ),
  _SlideData(
    kicker: 'CARTE EN DIRECT',
    title: 'Découvre ce qui se\npasse près de toi',
    description: 'Une carte interactive en temps réel, filtrée par centre d\'intérêt — soirée, sport, atelier, lecture, art…',
    icon: PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
    accent: kInfo,
    toneA: kInkLight, toneB: kInfo, toneC: kPrimary,
    satellites: [
      _Satellite(PhosphorIcons.confetti(PhosphorIconsStyle.fill), kTertiary, _satTopLeft),
      _Satellite(PhosphorIcons.paintBrush(PhosphorIconsStyle.fill), kCategoryArt, _satTopRight),
      _Satellite(PhosphorIcons.barbell(PhosphorIconsStyle.fill), kAccent, _satBottom),
    ],
  ),
  _SlideData(
    kicker: 'BILLETTERIE',
    title: 'Réserve en\nquelques secondes',
    description: 'Paye en mobile money, récupère ton billet QR direct dans l\'app. Plus besoin de faire la queue.',
    icon: PhosphorIcons.ticket(PhosphorIconsStyle.fill),
    accent: kAccent,
    toneA: kTertiary, toneB: kAccent, toneC: kWarning,
    satellites: [
      _Satellite(PhosphorIcons.qrCode(PhosphorIconsStyle.fill), kPrimary, _satTopLeft),
      _Satellite(PhosphorIcons.deviceMobile(PhosphorIconsStyle.fill), kSecondary, _satTopRight),
      _Satellite(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), kSuccess, _satBottom),
    ],
  ),
  _SlideData(
    kicker: 'CONTRIBUTION EN NATURE',
    title: 'Apporte ta\ncontribution',
    description: 'Bouteille, plat, sono… Sur certains événements, ta contribution remplace l\'achat du billet. Chaque organisateur précise ce qu\'il attend de toi.',
    icon: PhosphorIcons.gift(PhosphorIconsStyle.fill),
    accent: kWarning,
    toneA: kSecondary, toneB: kWarning, toneC: kTertiary,
    satellites: [
      _Satellite(PhosphorIcons.wine(PhosphorIconsStyle.fill), kTertiary, _satTopLeft),
      _Satellite(PhosphorIcons.forkKnife(PhosphorIconsStyle.fill), kAccent, _satTopRight),
      _Satellite(PhosphorIcons.speakerHigh(PhosphorIconsStyle.fill), kInfo, _satBottom),
    ],
  ),
  _SlideData(
    kicker: 'COMMUNAUTÉ',
    title: 'Fais connaissance\navant d\'arriver',
    description: 'Échange avec les autres participants et l\'organisateur, avant, pendant et après l\'événement.',
    icon: PhosphorIcons.chatCircleDots(PhosphorIconsStyle.fill),
    accent: kSecondary,
    toneA: kSecondary, toneB: kPrimary, toneC: kInfo,
    satellites: [
      _Satellite(PhosphorIcons.heart(PhosphorIconsStyle.fill), kTertiary, _satTopLeft),
      _Satellite(PhosphorIcons.usersThree(PhosphorIconsStyle.fill), kAccent, _satTopRight),
      _Satellite(PhosphorIcons.bell(PhosphorIconsStyle.fill), kWarning, _satBottom),
    ],
  ),
  _SlideData(
    kicker: 'DEVIENS ORGANISATEUR',
    title: 'Organise et bâtis\nta réputation',
    description: 'Publie tes événements, vends tes billets, anime ta communauté — et deviens un organisateur reconnu à chaque édition.',
    icon: PhosphorIcons.crown(PhosphorIconsStyle.fill),
    accent: kTertiary,
    toneA: kSecondary, toneB: kTertiary, toneC: kAccent,
    satellites: [
      _Satellite(PhosphorIcons.star(PhosphorIconsStyle.fill), kWarning, _satTopLeft),
      _Satellite(PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill), kSuccess, _satTopRight),
      _Satellite(PhosphorIcons.rocketLaunch(PhosphorIconsStyle.fill), kInfo, _satBottom),
    ],
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  final _ctrl = PageController();
  late final AnimationController _float =
      AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
  int _page = 0;

  void _next() {
    if (_page < _slides.length - 1) {
      _ctrl.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _slides.length - 1;
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
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: context.tpCard,
                        borderRadius: BorderRadius.circular(Radii.pill),
                        border: Border.all(color: context.tpHair),
                      ),
                      child: Text('Passer',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: context.tpInkSub)),
                    ),
                  ),
                ),
              ),
            ),

            // ── Illustrations ─────────────────────────────────────────────
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: PageView.builder(
                    controller: _ctrl,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemCount: _slides.length,
                    itemBuilder: (_, i) => AnimatedBuilder(
                      animation: _float,
                      builder: (_, _) => _OnboardingVisual(
                        data: _slides[i],
                        bob: sin(_float.value * 2 * pi),
                      ),
                    ),
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
                      _slides[_page].kicker,
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w900,
                        letterSpacing: 1.6, color: _slides[_page].accent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _slides[_page].title,
                      style: TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w900,
                        letterSpacing: -1.0, height: 1.1, color: context.tpInk,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _slides[_page].description,
                      style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500,
                        height: 1.42, color: context.tpInkSub,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: List.generate(_slides.length, (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: Sp.sm),
                        width: i == _page ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          gradient: i == _page ? trackpartyGradient : null,
                          color: i == _page ? null : kHairLight,
                          borderRadius: BorderRadius.circular(Radii.xs),
                        ),
                      )),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 50),
                      child: TpButton(
                        label: isLast ? 'Commencer' : 'Suivant',
                        icon: isLast
                            ? PhosphorIcons.rocketLaunch(PhosphorIconsStyle.fill)
                            : PhosphorIcons.arrowRight(PhosphorIconsStyle.bold),
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
// Background "Photo" — radial gradients empilés + texture légère.
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
// Visuel de slide — badge central + constellation d'icônes
// satellites, sur fond dégradé, avec un très léger flottement.
// ═══════════════════════════════════════════════════════════

class _OnboardingVisual extends StatelessWidget {
  final _SlideData data;
  final double bob; // -1..1

  const _OnboardingVisual({required this.data, required this.bob});

  @override
  Widget build(BuildContext context) {
    return _PhotoBg(
      a: data.toneA, b: data.toneB, c: data.toneC,
      child: Center(
        child: SizedBox(
          width: 280,
          height: 280,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Halo derrière le badge
              _RadialLayer(color: Colors.white, cx: 0.5, cy: 0.46, rx: 1.0, ry: 0.85, opacity: 0.22),

              // Anneau en pointillés, lente rotation
              Transform.rotate(
                angle: bob * pi / 40,
                child: CustomPaint(painter: _OrbitPainter(), size: const Size(272, 272)),
              ),

              // Icônes satellites (constellation autour du badge)
              for (final s in data.satellites)
                Align(
                  alignment: s.alignment,
                  child: Transform.translate(
                    offset: Offset(0, bob * 5),
                    child: _SatelliteChip(icon: s.icon, color: s.color),
                  ),
                ),

              // Badge principal
              Transform.translate(
                offset: Offset(0, -bob * 7),
                child: _MainBadge(icon: data.icon, color: data.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MainBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _MainBadge({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 152,
      height: 152,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 3),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.24), blurRadius: 32, offset: const Offset(0, 18)),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 64, color: color),
    );
  }
}

class _SatelliteChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _SatelliteChip({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 14, offset: const Offset(0, 8)),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 20, color: Colors.white),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    const dashCount = 48;
    for (int i = 0; i < dashCount; i++) {
      if (i.isOdd) continue;
      final a1 = (i / dashCount) * 2 * pi;
      final a2 = ((i + 0.55) / dashCount) * 2 * pi;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), a1, a2 - a1, false, paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

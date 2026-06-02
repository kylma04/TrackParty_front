import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_provider.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../widgets/tp_logo.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  bool _animDone = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _scale = Tween(begin: 0.75, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutQuart));
    _fade = Tween(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
    _ctrl.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _animDone = true);
        _tryNavigate();
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _tryNavigate() {
    if (!mounted || !_animDone) return;
    final authValue = ref.read(authNotifierProvider);
    if (authValue.isLoading) return; // wait for auth to resolve (listener will retry)

    if (authValue.valueOrNull is AuthAuthenticated) {
      context.go('/feed');
    } else {
      context.go('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for auth resolution to navigate once animation is done
    ref.listen(authNotifierProvider, (_, next) {
      if (!next.isLoading) _tryNavigate();
    });

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: trackpartyGradient),
        child: Stack(
          children: [
            Positioned(
              top: -80, right: -60,
              child: Container(
                width: 260, height: 260,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [Color(0x2EFFFFFF), Colors.transparent]),
                ),
              ),
            ),
            Positioned(
              bottom: 80, left: -100,
              child: Container(
                width: 280, height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [kAccent.withValues(alpha: 0.32), Colors.transparent],
                  ),
                ),
              ),
            ),
            const Positioned(top: 200, left: 40, child: _Dot(size: 8, color: Colors.white, opacity: 0.7)),
            const Positioned(top: 320, right: 60, child: _Dot(size: 6, color: Colors.white, opacity: 0.5)),
            const Positioned(bottom: 280, right: 80, child: _Dot(size: 10, color: kAccent, opacity: 0.7)),
            Positioned.fill(
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const TpLogo(size: 120),
                      const SizedBox(height: 24),
                      RichText(
                        text: const TextSpan(children: [
                          TextSpan(
                            text: 'Track',
                            style: TextStyle(
                              color: Colors.white, fontSize: 52,
                              fontWeight: FontWeight.w900, letterSpacing: -1.5, height: 1.0,
                            ),
                          ),
                          TextSpan(
                            text: 'Party',
                            style: TextStyle(
                              color: kAccent, fontSize: 52,
                              fontWeight: FontWeight.w900, letterSpacing: -1.5, height: 1.0,
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'La carte des bons plans 🇨🇮',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 80, left: 0, right: 0,
              child: FadeTransition(
                opacity: _fade,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) => Container(
                    width: 8, height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: i == 0 ? 1.0 : 0.4),
                    ),
                  )),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;
  const _Dot({required this.size, required this.color, required this.opacity});

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: opacity,
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      );
}

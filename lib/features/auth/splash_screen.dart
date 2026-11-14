import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_provider.dart';
import '../../theme/colors.dart';
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
    if (ModalRoute.of(context)?.isCurrent != true) return;
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
      backgroundColor: kBgDark,
      body: Stack(
        children: [
          Positioned.fill(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const TpLogo(size: 112),
                    const SizedBox(height: 24),
                    RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: 'Track',
                            style: TextStyle(
                              color: kInkDark,
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.4,
                              height: 1.0,
                            ),
                          ),
                          TextSpan(
                            text: 'Party',
                            style: TextStyle(
                              color: kPrimary,
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.4,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'La carte des bons plans',
                      style: TextStyle(
                        color: kInkSubDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 72,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fade,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  3,
                  (i) => Container(
                    width: i == 0 ? 22 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: i == 0 ? kPrimary : kInkMuteDark.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

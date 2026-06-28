import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../features/event/boost_popup.dart';
import '../../theme/gradients.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_button.dart';
import '../../widgets/tp_tab_bar.dart';
import '../providers/auth_provider.dart';

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  final GoRouterState state;

  const MainShell({super.key, required this.child, required this.state});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  static const _routes = ['/feed', '/map', '/messages', '/me'];

  int get _activeIndex {
    final loc = widget.state.uri.path;
    final i = _routes.indexOf(loc);
    return i < 0 ? 0 : i;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Popup d'événement boosté à l'ouverture de l'app (cap 2/jour géré en interne).
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkBoostPopup());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Retour de l'arrière-plan = nouvelle « ouverture ».
    if (state == AppLifecycleState.resumed) _checkBoostPopup();
  }

  void _checkBoostPopup() {
    if (!mounted) return;
    final auth = ref.read(authNotifierProvider).valueOrNull;
    if (auth is! AuthAuthenticated) return;
    BoostPopupController.maybeShow(context, ref);
  }

  void _onCreateTap(BuildContext context) {
    final auth = ref.read(authNotifierProvider).valueOrNull;
    final user = auth is AuthAuthenticated ? auth.user : null;
    // Vérification d'identité requise AVANT d'entrer dans la création.
    if (user?.identityVerificationStatus == 'approved') {
      context.push('/event/new');
    } else {
      _showVerificationRequired(context);
    }
  }

  void _showVerificationRequired(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: dialogCtx.tpCard,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.cardLg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  gradient: trackpartyGradient,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  PhosphorIcons.identificationCard(PhosphorIconsStyle.fill),
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Vérification requise',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: dialogCtx.tpInk,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tu dois faire vérifier ton identité avant de pouvoir créer un événement.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                  color: dialogCtx.tpInkSub,
                ),
              ),
              const SizedBox(height: 22),
              TpButton(
                label: 'Faire vérifier mon identité',
                icon: PhosphorIcons.arrowRight(),
                fullWidth: true,
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  context.push('/identity-verification');
                },
              ),
              const SizedBox(height: 6),
              TpButton(
                label: 'Plus tard',
                variant: TpButtonVariant.ghost,
                fullWidth: true,
                onPressed: () => Navigator.pop(dialogCtx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: TpTabBar(
        activeIndex: _activeIndex,
        onTap: (i) => context.go(_routes[i]),
        onCreateTap: () => _onCreateTap(context),
      ),
    );
  }
}

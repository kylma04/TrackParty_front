import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/providers/auth_provider.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_button.dart';

class BlockedScreen extends ConsumerWidget {
  const BlockedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider).valueOrNull;
    final message = auth is AuthBlocked
        ? auth.message
        : 'Ton compte a été suspendu suite à des signalements.';

    return PopScope(
      // L'utilisateur est confiné ici tant qu'il est bloqué.
      canPop: false,
      child: Scaffold(
        backgroundColor: context.tpBg,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(Sp.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: kError.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      PhosphorIcons.prohibit(PhosphorIconsStyle.fill),
                      color: kError,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: Sp.lg),
                  Text(
                    'Compte suspendu',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: context.tpInk,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                      color: context.tpInkSub,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: context.tpCardAlt,
                      borderRadius: BorderRadius.circular(Radii.md),
                    ),
                    child: Text(
                      'Si vous pensez que cette décision est une erreur ou un '
                      'malentendu, veuillez contacter le service client.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                        color: context.tpInkMute,
                      ),
                    ),
                  ),
                  const SizedBox(height: Sp.xl),
                  TpButton(
                    label: 'Se déconnecter',
                    icon: PhosphorIcons.signOut(),
                    variant: TpButtonVariant.outline,
                    fullWidth: true,
                    onPressed: () =>
                        ref.read(authNotifierProvider.notifier).logout(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

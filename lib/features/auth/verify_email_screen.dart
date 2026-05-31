import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/services/auth_service.dart';
import '../../theme/gradients.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_button.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  final String? email;
  const VerifyEmailScreen({super.key, this.email});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _resending  = false;
  bool _resentOk   = false;
  bool _checking   = false;
  String? _checkError;

  Future<void> _resend() async {
    setState(() { _resending = true; _resentOk = false; });
    try {
      await ref.read(authServiceProvider).resendVerification();
      if (mounted) setState(() { _resending = false; _resentOk = true; });
    } catch (_) {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _checkVerification() async {
    setState(() { _checking = true; _checkError = null; });
    try {
      final user = await ref.read(authServiceProvider).getMe();
      if (!mounted) return;
      if (user.isVerified) {
        // Update auth state so the router redirect kicks in
        await ref.read(authNotifierProvider.notifier).refreshUser();
        if (mounted) context.go('/feed');
      } else {
        setState(() {
          _checking = false;
          _checkError = 'Email pas encore vérifié. Vérifie ta boîte mail.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _checking = false;
          _checkError = 'Impossible de vérifier. Réessaie.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.email ?? ref.watch(
      authNotifierProvider.select((v) =>
          v.valueOrNull is AuthAuthenticated
              ? (v.value as AuthAuthenticated).user.email
              : null),
    );

    return Scaffold(
      backgroundColor: context.tpBg,
      appBar: AppBar(backgroundColor: context.tpBg),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Sp.md),
        child: Column(
          children: [
            const SizedBox(height: Sp.xl),
            Container(
              width: 110, height: 110,
              decoration: BoxDecoration(gradient: coralGradient, borderRadius: BorderRadius.circular(32)),
              alignment: Alignment.center,
              child: const Text('💌', style: TextStyle(fontSize: 52)),
            ),
            const SizedBox(height: Sp.lg),
            Text(
              'Vérifie ton email',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900,
                  letterSpacing: -0.8, color: context.tpInk),
            ),
            const SizedBox(height: Sp.sm),
            Text(
              email != null
                  ? 'On a envoyé un lien de vérification à\n$email'
                  : 'On t\'a envoyé un lien de vérification.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  color: context.tpInkSub, height: 1.5),
            ),
            const SizedBox(height: 8),
            Text(
              'Clique sur le lien dans l\'email, puis reviens ici.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: context.tpInkMute, height: 1.4),
            ),
            const SizedBox(height: Sp.xl),

            TpButton(
              label: 'J\'ai vérifié mon email',
              fullWidth: true,
              state: _checking ? TpButtonState.loading : TpButtonState.idle,
              onPressed: _checking ? null : _checkVerification,
            ),

            if (_checkError != null) ...[
              const SizedBox(height: 10),
              Text(_checkError!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red.shade600)),
            ],

            const SizedBox(height: Sp.md),

            if (_resentOk)
              Text(
                'Email renvoyé ✓',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.green.shade600),
              )
            else
              TpButton(
                label: 'Renvoyer l\'email',
                fullWidth: true,
                variant: TpButtonVariant.ghost,
                state: _resending ? TpButtonState.loading : TpButtonState.idle,
                onPressed: _resending ? null : _resend,
              ),
          ],
        ),
      ),
    );
  }
}

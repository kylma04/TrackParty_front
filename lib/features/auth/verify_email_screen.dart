import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/services/auth_service.dart';
import '../../theme/gradients.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/otp_countdown.dart';
import '../../widgets/tp_button.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  final String? email;
  final String? password;
  const VerifyEmailScreen({super.key, this.email, this.password});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _codeCtrl = TextEditingController();
  bool _verifying  = false;
  bool _resending  = false;
  bool _resentOk   = false;
  bool _codeExpired = false;
  int  _timerKey   = 0; // incrémenté au renvoi pour relancer le countdown
  String? _error;

  String? get _resolvedEmail =>
      widget.email ??
      (ref.read(authNotifierProvider).valueOrNull is AuthAuthenticated
          ? (ref.read(authNotifierProvider).value as AuthAuthenticated).user.email
          : null);

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final email = _resolvedEmail;
    final code = _codeCtrl.text.trim();
    if (email == null) { setState(() => _error = 'Adresse email introuvable.'); return; }
    if (code.length != 6) { setState(() => _error = 'Saisis le code à 6 chiffres.'); return; }

    setState(() { _verifying = true; _error = null; });
    try {
      // Un seul appel réseau : le backend vérifie ET retourne les tokens JWT
      final authResponse = await ref.read(authServiceProvider).verifyEmailCode(email, code);
      if (!mounted) return;
      // Applique les tokens → navigation immédiate déclenchée par le router
      await ref.read(authNotifierProvider.notifier).loginWithResponse(authResponse);
    } catch (e) {
      if (mounted) setState(() { _verifying = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  Future<void> _resend() async {
    final email = _resolvedEmail;
    if (email == null) return;
    setState(() { _resending = true; _resentOk = false; _error = null; });
    try {
      await ref.read(authServiceProvider).resendVerification(email);
      if (mounted) {
        setState(() {
          _resending = false;
          _resentOk = true;
          _codeExpired = false;
          _timerKey++;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.email ??
        ref.watch(authNotifierProvider.select((v) =>
            v.valueOrNull is AuthAuthenticated
                ? (v.value as AuthAuthenticated).user.email
                : null));

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
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.8, color: context.tpInk),
            ),
            const SizedBox(height: Sp.sm),
            Text(
              email != null
                  ? 'On a envoyé un code à 6 chiffres à\n$email'
                  : 'On t\'a envoyé un code à 6 chiffres.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.tpInkSub, height: 1.5),
            ),
            const SizedBox(height: Sp.lg),

            // ── Countdown ────────────────────────────────────────────────────
            OtpCountdown(
              key: ValueKey(_timerKey),
              duration: const Duration(minutes: 15),
              onExpired: () => setState(() { _codeExpired = true; _error = null; }),
            ),

            const SizedBox(height: Sp.lg),

            // ── Saisie du code ───────────────────────────────────────────────
            Opacity(
              opacity: _codeExpired ? 0.4 : 1.0,
              child: TextField(
                controller: _codeCtrl,
                enabled: !_codeExpired,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 16, color: context.tpInk),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '______',
                  hintStyle: TextStyle(fontSize: 28, letterSpacing: 12, color: context.tpHair, fontWeight: FontWeight.w900),
                  filled: true,
                  fillColor: context.tpCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                ),
                onChanged: (_) { if (_error != null) setState(() => _error = null); },
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red.shade600)),
            ],

            const SizedBox(height: Sp.lg),

            if (!_codeExpired)
              TpButton(
                label: 'Vérifier',
                fullWidth: true,
                state: _verifying ? TpButtonState.loading : TpButtonState.idle,
                onPressed: _verifying ? null : _verify,
              ),

            const SizedBox(height: Sp.md),

            if (_resentOk)
              Text('Code renvoyé ✓',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.green.shade600))
            else
              TpButton(
                label: _codeExpired ? 'Obtenir un nouveau code' : 'Renvoyer le code',
                fullWidth: true,
                variant: _codeExpired ? TpButtonVariant.gradient : TpButtonVariant.ghost,
                state: _resending ? TpButtonState.loading : TpButtonState.idle,
                onPressed: _resending ? null : _resend,
              ),
          ],
        ),
      ),
    );
  }
}

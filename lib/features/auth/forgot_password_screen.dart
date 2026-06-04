import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/api/api_exception.dart';
import '../../core/services/auth_service.dart';
import '../../theme/gradients.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_button.dart';
import '../../widgets/tp_field.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  int _step = 0; // 0=email, 1=code, 2=nouveau mot de passe

  final _emailCtrl    = TextEditingController();
  final _codeCtrl     = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ── Étape 1 : envoi du code — fire & forget ───────────────────────────────────
  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Saisis un email valide.');
      return;
    }
    // Naviguer immédiatement sans attendre l'API
    setState(() { _step = 1; _error = null; });
    // Lancer l'envoi en arrière-plan
    unawaited(
      ref.read(authServiceProvider).requestPasswordReset(email).catchError((e) {
        // L'utilisateur voit déjà l'étape 2 avec un bouton "Renvoyer le code"
        if (mounted) setState(() => _error = 'Problème d\'envoi. Appuie sur "Renvoyer le code".');
      }),
    );
  }

  // ── Étape 2 : validation du code — navigation immédiate ──────────────────────
  void _verifyCode() {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Le code fait 6 chiffres.');
      return;
    }
    // Avancer immédiatement — le code sera validé à l'étape 3 avec le backend
    setState(() { _step = 2; _error = null; });
  }

  // ── Étape 3 : réinitialisation ────────────────────────────────────────────────
  Future<void> _resetPassword() async {
    final password = _passwordCtrl.text;
    final confirm  = _confirmCtrl.text;
    if (password.length < 8) {
      setState(() => _error = 'Le mot de passe doit faire au moins 8 caractères.');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Les mots de passe ne correspondent pas.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authServiceProvider).confirmPasswordResetCode(
        email: _emailCtrl.text.trim(),
        code: _codeCtrl.text.trim(),
        newPassword: password,
      );
      if (mounted) context.go('/login');
    } on ApiException catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.message; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tpBg,
      appBar: AppBar(
        backgroundColor: context.tpBg,
        leading: _step > 0
            ? IconButton(
                icon: Icon(PhosphorIcons.arrowLeft(), color: context.tpInk),
                onPressed: () => setState(() { _step--; _error = null; }),
              )
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Sp.md),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: switch (_step) {
            0 => _EmailStep(
                key: const ValueKey(0),
                ctrl: _emailCtrl,
                error: _error,
                onSubmit: _sendCode,
              ),
            1 => _CodeStep(
                key: const ValueKey(1),
                email: _emailCtrl.text.trim(),
                ctrl: _codeCtrl,
                error: _error,
                onSubmit: _verifyCode,
                onResend: _sendCode,
              ),
            _ => _PasswordStep(
                key: const ValueKey(2),
                passwordCtrl: _passwordCtrl,
                confirmCtrl: _confirmCtrl,
                obscure: _obscure,
                loading: _loading,
                error: _error,
                onToggleObscure: () => setState(() => _obscure = !_obscure),
                onSubmit: _resetPassword,
              ),
          },
        ),
      ),
    );
  }
}

// ── Étape 1 : email ───────────────────────────────────────────────────────────

class _EmailStep extends StatelessWidget {
  final TextEditingController ctrl;
  final String? error;
  final VoidCallback onSubmit;
  const _EmailStep({super.key, required this.ctrl, required this.error, required this.onSubmit});

  @override
  Widget build(BuildContext context) => Column(children: [
        const SizedBox(height: Sp.xl),
        Container(
          width: 96, height: 96,
          decoration: BoxDecoration(gradient: coralGradient, borderRadius: BorderRadius.circular(28)),
          alignment: Alignment.center,
          child: Icon(PhosphorIcons.lockKey(), color: Colors.white, size: 48),
        ),
        const SizedBox(height: Sp.lg),
        Text('Mot de passe oublié ?',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.8, color: context.tpInk)),
        const SizedBox(height: Sp.sm),
        Text('On t\'envoie un code de réinitialisation.',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.tpInkSub)),
        const SizedBox(height: Sp.xl),
        TpField(label: 'Email', prefixIcon: PhosphorIcons.envelope(), keyboardType: TextInputType.emailAddress, controller: ctrl),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(error!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red.shade600)),
        ],
        const SizedBox(height: Sp.lg),
        TpButton(label: 'Envoyer le code', fullWidth: true, onPressed: onSubmit),
      ]);
}

// ── Étape 2 : code OTP ────────────────────────────────────────────────────────

class _CodeStep extends StatelessWidget {
  final String email;
  final TextEditingController ctrl;
  final String? error;
  final VoidCallback onSubmit;
  final VoidCallback onResend;
  const _CodeStep({super.key, required this.email, required this.ctrl, required this.error, required this.onSubmit, required this.onResend});

  @override
  Widget build(BuildContext context) => Column(children: [
        const SizedBox(height: Sp.xl),
        Container(
          width: 96, height: 96,
          decoration: BoxDecoration(gradient: coralGradient, borderRadius: BorderRadius.circular(28)),
          alignment: Alignment.center,
          child: const Text('🔑', style: TextStyle(fontSize: 48)),
        ),
        const SizedBox(height: Sp.lg),
        Text('Saisis ton code',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.8, color: context.tpInk)),
        const SizedBox(height: Sp.sm),
        Text('Code envoyé à $email',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.tpInkSub, height: 1.5)),
        const SizedBox(height: Sp.xl),
        TextField(
          controller: ctrl,
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
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(error!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red.shade600)),
        ],
        const SizedBox(height: Sp.lg),
        TpButton(label: 'Continuer', fullWidth: true, onPressed: onSubmit),
        const SizedBox(height: Sp.sm),
        TpButton(label: 'Renvoyer le code', fullWidth: true, variant: TpButtonVariant.ghost, onPressed: onResend),
      ]);
}

// ── Étape 3 : nouveau mot de passe ───────────────────────────────────────────

class _PasswordStep extends StatelessWidget {
  final TextEditingController passwordCtrl;
  final TextEditingController confirmCtrl;
  final bool obscure, loading;
  final String? error;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  const _PasswordStep({super.key, required this.passwordCtrl, required this.confirmCtrl, required this.obscure, required this.loading, required this.error, required this.onToggleObscure, required this.onSubmit});

  @override
  Widget build(BuildContext context) => Column(children: [
        const SizedBox(height: Sp.xl),
        Container(
          width: 96, height: 96,
          decoration: BoxDecoration(gradient: coralGradient, borderRadius: BorderRadius.circular(28)),
          alignment: Alignment.center,
          child: Icon(PhosphorIcons.lockKeyOpen(), color: Colors.white, size: 48),
        ),
        const SizedBox(height: Sp.lg),
        Text('Nouveau mot de passe',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.8, color: context.tpInk)),
        const SizedBox(height: Sp.sm),
        Text('Choisis un mot de passe solide.',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.tpInkSub)),
        const SizedBox(height: Sp.xl),
        TpField(
          label: 'Nouveau mot de passe',
          prefixIcon: PhosphorIcons.lock(),
          controller: passwordCtrl,
          obscureText: obscure,
          suffixIcon: GestureDetector(
            onTap: onToggleObscure,
            child: Icon(obscure ? PhosphorIcons.eye() : PhosphorIcons.eyeSlash(), size: 20),
          ),
        ),
        const SizedBox(height: 12),
        TpField(
          label: 'Confirmer le mot de passe',
          prefixIcon: PhosphorIcons.lock(),
          controller: confirmCtrl,
          obscureText: obscure,
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(error!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red.shade600)),
        ],
        const SizedBox(height: Sp.lg),
        TpButton(
          label: 'Réinitialiser le mot de passe',
          fullWidth: true,
          state: loading ? TpButtonState.loading : TpButtonState.idle,
          onPressed: loading ? null : onSubmit,
        ),
      ]);
}

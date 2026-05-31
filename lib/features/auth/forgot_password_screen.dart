import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/services/auth_service.dart';
import '../../theme/gradients.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_button.dart';
import '../../widgets/tp_field.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saisis un email valide.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).requestPasswordReset(email);
      if (mounted) setState(() { _loading = false; _sent = true; });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tpBg,
      appBar: AppBar(backgroundColor: context.tpBg),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Sp.md),
        child: _sent ? _SuccessView(email: _emailCtrl.text.trim()) : _FormView(
          emailCtrl: _emailCtrl,
          loading: _loading,
          onSubmit: _submit,
        ),
      ),
    );
  }
}

class _FormView extends StatelessWidget {
  final TextEditingController emailCtrl;
  final bool loading;
  final VoidCallback onSubmit;
  const _FormView({required this.emailCtrl, required this.loading, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: Sp.xl),
        Container(
          width: 96, height: 96,
          decoration: BoxDecoration(gradient: coralGradient, borderRadius: BorderRadius.circular(28)),
          alignment: Alignment.center,
          child: Icon(PhosphorIcons.lockKey(), color: Colors.white, size: 48),
        ),
        const SizedBox(height: Sp.lg),
        Text(
          'Mot de passe oublié ?',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.8, color: context.tpInk),
        ),
        const SizedBox(height: Sp.sm),
        Text(
          'On t\'envoie un lien de réinitialisation.',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.tpInkSub),
        ),
        const SizedBox(height: Sp.xl),
        TpField(label: 'Email', prefixIcon: PhosphorIcons.envelope(), keyboardType: TextInputType.emailAddress, controller: emailCtrl),
        const SizedBox(height: Sp.lg),
        TpButton(
          label: 'Envoyer le lien',
          fullWidth: true,
          state: loading ? TpButtonState.loading : TpButtonState.idle,
          onPressed: loading ? null : onSubmit,
        ),
      ],
    );
  }
}

class _SuccessView extends StatelessWidget {
  final String email;
  const _SuccessView({required this.email});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: Sp.xl),
        Container(
          width: 96, height: 96,
          decoration: BoxDecoration(gradient: coralGradient, borderRadius: BorderRadius.circular(28)),
          alignment: Alignment.center,
          child: const Text('💌', style: TextStyle(fontSize: 48)),
        ),
        const SizedBox(height: Sp.lg),
        Text(
          'Email envoyé !',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.8, color: context.tpInk),
        ),
        const SizedBox(height: Sp.sm),
        Text(
          'Si un compte existe pour $email,\nun lien de réinitialisation a été envoyé.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.tpInkSub, height: 1.5),
        ),
        const SizedBox(height: Sp.xl),
        TpButton(
          label: 'Retour à la connexion',
          fullWidth: true,
          onPressed: () => context.go('/login'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/providers/auth_provider.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_button.dart';
import '../../widgets/tp_field.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  String? _emailError;
  String? _nameError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _emailError = null; _nameError = null; });
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authNotifierProvider.notifier).register(
          email: _emailCtrl.text.trim(),
          displayName: _nameCtrl.text.trim(),
          password: _passCtrl.text,
        );
    // If successful, router navigates to /feed.
    // VerifyEmail screen is shown from /feed if is_verified is false (future task).
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authNotifierProvider, (_, next) {
      if (next.hasError) {
        final err = next.error;
        if (err is ApiException) {
          final emailErr = err.fieldError('email');
          final nameErr = err.fieldError('display_name');
          if (emailErr != null || nameErr != null) {
            setState(() { _emailError = emailErr; _nameError = nameErr; });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(err.message), backgroundColor: Colors.red.shade700),
            );
          }
        }
      }
    });

    final isLoading = ref.watch(authNotifierProvider).isLoading;

    return Scaffold(
      backgroundColor: context.tpBg,
      appBar: AppBar(backgroundColor: context.tpBg),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: Sp.md),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rejoins la fête ✨',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -1.0, color: context.tpInk),
              ),
              const SizedBox(height: Sp.xl),
              TpField(
                label: 'Nom d\'affichage',
                prefixIcon: PhosphorIcons.user(),
                controller: _nameCtrl,
                errorText: _nameError,
                validator: (v) {
                  if (v == null || v.trim().length < 2) return 'Au moins 2 caractères';
                  return null;
                },
              ),
              const SizedBox(height: Sp.md),
              TpField(
                label: 'Email',
                prefixIcon: PhosphorIcons.envelope(),
                keyboardType: TextInputType.emailAddress,
                controller: _emailCtrl,
                errorText: _emailError,
                validator: (v) => v == null || !v.contains('@') ? 'Email invalide' : null,
              ),
              const SizedBox(height: Sp.md),
              TpField(
                label: 'Mot de passe',
                prefixIcon: PhosphorIcons.lock(),
                obscureText: _obscure,
                controller: _passCtrl,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? PhosphorIcons.eye() : PhosphorIcons.eyeSlash(),
                    color: context.tpInkMute, size: 20,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
                validator: (v) => v == null || v.length < 8 ? 'Au moins 8 caractères' : null,
              ),
              const SizedBox(height: Sp.xl),
              TpButton(
                label: 'Créer mon compte',
                fullWidth: true,
                state: isLoading ? TpButtonState.loading : TpButtonState.idle,
                onPressed: isLoading ? null : _submit,
              ),
              const SizedBox(height: Sp.lg),
              Center(
                child: Semantics(
                  button: true,
                  label: 'Se connecter',
                  child: GestureDetector(
                    onTap: () => context.pop(),
                    child: Text.rich(TextSpan(
                      text: 'Déjà inscrit ? ',
                      style: TextStyle(fontSize: 14, color: context.tpInkSub, fontWeight: FontWeight.w600),
                      children: const [
                        TextSpan(text: 'Se connecter', style: TextStyle(color: kPrimary, fontWeight: FontWeight.w800)),
                      ],
                    )),
                  ),
                ),
              ),
              const SizedBox(height: Sp.xl),
            ],
          ),
        ),
      ),
    );
  }
}

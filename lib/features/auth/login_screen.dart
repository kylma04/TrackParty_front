import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/api/api_exception.dart';
import '../../core/config/env.dart';
import '../../core/providers/auth_provider.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_button.dart';
import '../../widgets/tp_field.dart';
import '../../widgets/tp_logo.dart';


class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authNotifierProvider.notifier).login(
          _emailCtrl.text.trim(),
          _passCtrl.text,
        );
  }

  Future<void> _googleLogin() async {
    if (!Env.googleConfigured) {
      _showError(
        'Google Sign-In non configuré.\n'
        'Ajoute ton GOOGLE_WEB_CLIENT_ID dans dart_defines + google-services.json.\n'
        'Voir OBLIGATOIRE.md → étape 3.',
      );
      return;
    }
    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: Env.googleWebClientId,
      );
      final account = await googleSignIn.signIn();
      if (account == null || !mounted) return;
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        _showError('Impossible d\'obtenir le token Google. Réessaie.');
        return;
      }
      await ref.read(authNotifierProvider.notifier).googleLogin(idToken);
    } on Exception catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('canceled') || e.toString().contains('cancelled')
          ? 'Connexion Google annulée.'
          : 'Connexion Google échouée — vérifie la configuration.';
      _showError(msg);
    }
  }

  Future<void> _appleLogin() async {
    // Apple Sign-In sur Android nécessite un serveur de redirection OAuth.
    // En développement local, seul iOS est supporté.
    if (Platform.isAndroid) {
      _showInfo(
        'Apple Sign-In n\'est disponible que sur iOS.\n'
        'Sur Android, utilise Google, email ou un autre provider.',
      );
      return;
    }
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final idToken = credential.identityToken;
      if (idToken == null || !mounted) return;

      final displayName = [credential.givenName, credential.familyName]
          .where((s) => s != null && s.isNotEmpty)
          .join(' ');

      await ref.read(authNotifierProvider.notifier).appleLogin(
            idToken,
            displayName: displayName.isNotEmpty ? displayName : null,
          );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code != AuthorizationErrorCode.canceled && mounted) {
        _showError('Apple Sign-In échoué : ${e.message}');
      }
    } on Exception catch (_) {
      if (mounted) _showError('Apple Sign-In non disponible sur cet appareil.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: kError,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: kInfo,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authNotifierProvider, (_, next) {
      if (next.hasError) {
        final err = next.error;
        final msg = err is ApiException ? err.message : 'Une erreur est survenue.';
        _showError(msg);
      }
    });

    final isLoading = ref.watch(authNotifierProvider).isLoading;
    final isAndroid = Platform.isAndroid;

    return Scaffold(
      backgroundColor: context.tpBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: Sp.md),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 48),
                const TpLogo(size: 96),
                const SizedBox(height: Sp.lg),
                Text(
                  'Bon retour 👋',
                  style: TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w900,
                      letterSpacing: -0.8, color: context.tpInk),
                ),
                const SizedBox(height: 6),
                Text(
                  'Connecte-toi pour rejoindre la fête',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.tpInkSub),
                ),
                const SizedBox(height: Sp.xl),
                TpField(
                  label: 'Email',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  controller: _emailCtrl,
                  validator: (v) => v == null || !v.contains('@') ? 'Email invalide' : null,
                ),
                const SizedBox(height: Sp.md),
                TpField(
                  label: 'Mot de passe',
                  prefixIcon: Icons.lock_outline,
                  obscureText: _obscure,
                  controller: _passCtrl,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: context.tpInkMute, size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                    tooltip: _obscure ? 'Afficher' : 'Masquer',
                  ),
                  validator: (v) => v == null || v.length < 6 ? 'Mot de passe trop court' : null,
                ),
                const SizedBox(height: Sp.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: Semantics(
                    button: true,
                    label: 'Mot de passe oublié',
                    child: GestureDetector(
                      onTap: () => context.push('/forgot'),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Text('Mot de passe oublié ?',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kPrimary)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Sp.lg),
                TpButton(
                  label: 'Se connecter',
                  fullWidth: true,
                  state: isLoading ? TpButtonState.loading : TpButtonState.idle,
                  onPressed: isLoading ? null : _submit,
                ),
                const SizedBox(height: Sp.lg),
                Row(children: [
                  Expanded(child: Divider(color: context.tpHair)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Sp.sm),
                    child: Text('OU CONTINUER AVEC',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.tpInkMute)),
                  ),
                  Expanded(child: Divider(color: context.tpHair)),
                ]),
                const SizedBox(height: Sp.lg),
                if (isAndroid)
                  _SocialBtn(
                    label: 'Continuer avec Google',
                    svgAsset: 'assets/icons/google_logo.svg',
                    onTap: isLoading ? null : _googleLogin,
                    badge: Env.googleConfigured ? null : '⚙️',
                    badgeTooltip: Env.googleConfigured ? null : 'Non configuré — voir OBLIGATOIRE.md',
                  )
                else ...[
                  _SocialBtn(
                    label: 'Continuer avec Apple',
                    svgAsset: 'assets/icons/apple_logo.svg',
                    svgThemed: true,
                    onTap: isLoading ? null : _appleLogin,
                  ),
                  const SizedBox(height: Sp.sm),
                  _SocialBtn(
                    label: 'Continuer avec Google',
                    svgAsset: 'assets/icons/google_logo.svg',
                    onTap: isLoading ? null : _googleLogin,
                    badge: Env.googleConfigured ? null : '⚙️',
                    badgeTooltip: Env.googleConfigured ? null : 'Non configuré — voir OBLIGATOIRE.md',
                  ),
                ],
                const SizedBox(height: Sp.xl),
                Semantics(
                  button: true,
                  label: 'Créer un compte',
                  child: GestureDetector(
                    onTap: () => context.push('/signup'),
                    child: RichText(
                      text: TextSpan(
                        text: 'Pas encore inscrit ? ',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.tpInkSub),
                        children: const [
                          TextSpan(
                            text: 'Créer un compte',
                            style: TextStyle(color: kPrimary, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Sp.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialBtn extends StatelessWidget {
  final String label;
  final String svgAsset;
  // true = apply tpInk color filter (monochrome logos like Apple)
  final bool svgThemed;
  final VoidCallback? onTap;
  final String? badge;
  final String? badgeTooltip;

  const _SocialBtn({
    required this.label,
    required this.svgAsset,
    required this.onTap,
    this.svgThemed = false,
    this.badge,
    this.badgeTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;

    final icon = SvgPicture.asset(
      svgAsset,
      width: 22,
      height: 22,
      colorFilter: svgThemed
          ? ColorFilter.mode(context.tpInk, BlendMode.srcIn)
          : null,
    );

    Widget btn = Opacity(
      opacity: isDisabled ? 0.45 : 1.0,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: context.tpCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.tpHair, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.tpInk)),
            if (badge != null) ...[
              const SizedBox(width: 4),
              Text(badge!, style: const TextStyle(fontSize: 12)),
            ],
          ],
        ),
      ),
    );

    if (badgeTooltip != null) {
      btn = Tooltip(message: badgeTooltip!, child: btn);
    }

    return Semantics(
      button: true,
      enabled: !isDisabled,
      label: isDisabled
          ? '$label — ${badgeTooltip ?? 'indisponible'}'
          : label,
      child: GestureDetector(
        onTap: isDisabled ? null : onTap,
        child: btn,
      ),
    );
  }
}

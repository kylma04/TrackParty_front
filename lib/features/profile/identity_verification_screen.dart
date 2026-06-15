import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/cloudinary_service.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_button.dart';

class IdentityVerificationScreen extends ConsumerStatefulWidget {
  const IdentityVerificationScreen({super.key});

  @override
  ConsumerState<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends ConsumerState<IdentityVerificationScreen> {
  String _documentType = 'cni';
  String? _frontUrl;
  String? _backUrl;
  String? _selfieUrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Récupère le statut à jour à l'ouverture (l'admin a pu valider/refuser entre-temps).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authNotifierProvider.notifier).refreshUser();
    });
  }

  Future<void> _pick(void Function(String) assign) async {
    final source = await _chooseSource();
    if (source == null || !mounted) return;
    final url = await ref
        .read(cloudinaryServiceProvider)
        .pickAndUpload(source: source, folder: 'identity_verifications');
    if (url != null && mounted) setState(() => assign(url));
  }

  /// Laisse choisir entre l'appareil photo et la galerie.
  Future<ImageSource?> _chooseSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: ctx.tpCard,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Radii.sheet),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: ctx.tpHair,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 10),
              _sourceTile(
                ctx,
                PhosphorIcons.camera(),
                'Prendre une photo',
                ImageSource.camera,
              ),
              _sourceTile(
                ctx,
                PhosphorIcons.image(),
                'Choisir dans la galerie',
                ImageSource.gallery,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sourceTile(
    BuildContext ctx,
    IconData icon,
    String label,
    ImageSource source,
  ) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: kPrimary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Icon(icon, color: kPrimary, size: 22),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: ctx.tpInk,
        ),
      ),
      onTap: () => Navigator.pop(ctx, source),
    );
  }

  Future<void> _submit() async {
    if (_frontUrl == null || _selfieUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ajoute au moins le recto de la pièce et un selfie.'),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await ref
          .read(authServiceProvider)
          .submitIdentityVerification(
            documentType: _documentType,
            frontImageUrl: _frontUrl!,
            backImageUrl: _backUrl,
            selfieImageUrl: _selfieUrl!,
          );

      await ref.read(authNotifierProvider.notifier).refreshUser();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vérification envoyée.')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider).valueOrNull;
    final user = auth is AuthAuthenticated ? auth.user : null;
    final status = user?.identityVerificationStatus;
    final canSubmit = status == null || status == 'rejected';

    return Scaffold(
      backgroundColor: context.tpBg,
      appBar: AppBar(
        backgroundColor: context.tpBg,
        elevation: 0,
        title: const Text('Vérification d\'identité'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Sp.md, Sp.sm, Sp.md, 40),
        children: [
          _StatusHero(status: status),
          const SizedBox(height: 14),
          _privacyNote(context),

          if (canSubmit) ...[
            const SizedBox(height: Sp.lg),
            _sectionLabel(context, 'TYPE DE DOCUMENT'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: context.tpCard,
                borderRadius: BorderRadius.circular(Radii.lg),
                border: Border.all(color: context.tpHair, width: 1.2),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _documentType,
                  isExpanded: true,
                  icon: Icon(
                    PhosphorIcons.caretDown(),
                    color: context.tpInkMute,
                    size: 18,
                  ),
                  dropdownColor: context.tpCard,
                  borderRadius: BorderRadius.circular(Radii.md),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.tpInk,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'cni',
                      child: Text('🪪  Carte d\'identité'),
                    ),
                    DropdownMenuItem(
                      value: 'passport',
                      child: Text('🛂  Passeport'),
                    ),
                    DropdownMenuItem(
                      value: 'driver_license',
                      child: Text('🚗  Permis de conduire'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _documentType = v);
                  },
                ),
              ),
            ),

            const SizedBox(height: Sp.lg),
            _sectionLabel(context, 'TES DOCUMENTS'),
            const SizedBox(height: 10),
            _CaptureTile(
              label: 'Recto de la pièce',
              hint: 'Appuie pour photographier',
              icon: PhosphorIcons.identificationCard(),
              imageUrl: _frontUrl,
              onTap: _loading ? null : () => _pick((u) => _frontUrl = u),
            ),
            const SizedBox(height: 10),
            _CaptureTile(
              label: 'Verso de la pièce',
              hint: 'Appuie pour photographier',
              icon: PhosphorIcons.identificationCard(),
              imageUrl: _backUrl,
              optional: true,
              onTap: _loading ? null : () => _pick((u) => _backUrl = u),
            ),
            const SizedBox(height: 10),
            _CaptureTile(
              label: 'Selfie',
              hint: 'Ton visage bien visible',
              icon: PhosphorIcons.userFocus(),
              imageUrl: _selfieUrl,
              onTap: _loading ? null : () => _pick((u) => _selfieUrl = u),
            ),

            const SizedBox(height: Sp.lg),
            TpButton(
              label: 'Soumettre la vérification',
              icon: PhosphorIcons.paperPlaneTilt(),
              fullWidth: true,
              state: _loading
                  ? TpButtonState.loading
                  : (_frontUrl != null && _selfieUrl != null
                        ? TpButtonState.idle
                        : TpButtonState.disabled),
              onPressed: _submit,
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Text(
    text,
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w900,
      color: context.tpInkSub,
      letterSpacing: 0.4,
    ),
  );

  Widget _privacyNote(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(PhosphorIcons.lockKey(), size: 15, color: context.tpInkMute),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          'Tes documents sont confidentiels et utilisés uniquement pour vérifier ton identité.',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            height: 1.35,
            color: context.tpInkMute,
          ),
        ),
      ),
    ],
  );
}

// ── Hero de statut ────────────────────────────────────────────────────────────
({Color color, IconData icon, String title, String message}) _statusMeta(
  String? status,
) {
  switch (status) {
    case 'approved':
      return (
        color: kSuccess,
        icon: PhosphorIcons.sealCheck(PhosphorIconsStyle.fill),
        title: 'Identité vérifiée',
        message: 'Ton compte affiche désormais le badge vérifié.',
      );
    case 'pending':
      return (
        color: kWarning,
        icon: PhosphorIcons.clockCountdown(),
        title: 'En attente de validation',
        message:
            'On examine tes documents, ça ne prend généralement pas longtemps.',
      );
    case 'rejected':
      return (
        color: kError,
        icon: PhosphorIcons.xCircle(PhosphorIconsStyle.fill),
        title: 'Vérification refusée',
        message:
            'Tes documents n\'ont pas pu être validés. Reprends des photos nettes, bien éclairées et cadrées.',
      );
    case 'manual_review':
      return (
        color: kInfo,
        icon: PhosphorIcons.eye(PhosphorIconsStyle.fill),
        title: 'Examen manuel en cours',
        message: 'Un membre de l\'équipe vérifie tes documents manuellement.',
      );
    default:
      return (
        color: kPrimary,
        icon: PhosphorIcons.identificationCard(PhosphorIconsStyle.fill),
        title: 'Vérifie ton identité',
        message:
            'Confirme qui tu es pour inspirer confiance et débloquer plus de fonctionnalités.',
      );
  }
}

class _StatusHero extends StatelessWidget {
  final String? status;
  const _StatusHero({required this.status});

  @override
  Widget build(BuildContext context) {
    final m = _statusMeta(status);
    final isApproved = status == 'approved';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        gradient: isApproved ? trackpartyGradient : null,
        color: isApproved
            ? null
            : m.color.withValues(alpha: context.isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(Radii.card),
        boxShadow: isApproved ? Shadows.brand : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isApproved
                  ? Colors.white.withValues(alpha: 0.22)
                  : m.color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Icon(
              m.icon,
              color: isApproved ? Colors.white : m.color,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.title,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    color: isApproved ? Colors.white : context.tpInk,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  m.message,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: isApproved
                        ? Colors.white.withValues(alpha: 0.92)
                        : context.tpInkSub,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Carte de capture d'un document ────────────────────────────────────────────
class _CaptureTile extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final String? imageUrl;
  final bool optional;
  final VoidCallback? onTap;

  const _CaptureTile({
    required this.label,
    required this.hint,
    required this.icon,
    required this.imageUrl,
    this.optional = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final done = imageUrl != null;

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.tpCard,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(
              color: done ? kSuccess.withValues(alpha: 0.45) : context.tpHair,
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D1B1A2E),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.md),
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: done
                      ? Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _iconBox(context),
                          loadingBuilder: (_, child, p) =>
                              p == null ? child : _iconBox(context),
                        )
                      : _iconBox(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: context.tpInk,
                            ),
                          ),
                        ),
                        if (optional) ...[
                          const SizedBox(width: 6),
                          Text(
                            'optionnel',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: context.tpInkMute,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      done ? 'Photo ajoutée' : hint,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: done ? kSuccess : context.tpInkSub,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                done
                    ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)
                    : PhosphorIcons.camera(),
                color: done ? kSuccess : context.tpInkMute,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconBox(BuildContext context) => Container(
    color: kPrimary.withValues(alpha: 0.10),
    alignment: Alignment.center,
    child: Icon(icon, color: kPrimary, size: 24),
  );
}

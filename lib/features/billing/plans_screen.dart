import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/services/billing_service.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';

class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  String _fmtMoney(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(plansProvider);

    return Scaffold(
      backgroundColor: context.tpBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _appBar(context),
            Expanded(
              child: plansAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Sp.lg),
                    child: Text(
                      'Impossible de charger les offres.',
                      style: TextStyle(color: context.tpInkSub),
                    ),
                  ),
                ),
                data: (p) => _content(context, p),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _appBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, 12),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Retour',
            child: GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.tpCard,
                  borderRadius: BorderRadius.circular(Radii.md),
                  boxShadow: Shadows.sm,
                ),
                child: Icon(PhosphorIcons.caretLeft(),
                    color: context.tpInk, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text('Offres & tarifs',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: context.tpInk)),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, PlansCatalog p) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(Sp.md, 4, Sp.md, Sp.lg),
      children: [
        Text(
          'Tu organises ?\nPasse à la vitesse sup.',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: context.tpInk,
            height: 1.15,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Publie gratuitement tes premiers événements. Le plan Pro débloque '
          'l\'illimité, les analytics et la mise en avant.',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: context.tpInkSub,
            height: 1.5,
          ),
        ),
        const SizedBox(height: Sp.lg),

        _freeCard(context, p),
        const SizedBox(height: Sp.md),
        _proCard(context, p),

        const SizedBox(height: Sp.md),
        Text(
          'Sur les billets payants, TrackParty prélève une commission de '
          '${p.commissionPct.toString().replaceAll('.', ',')}% (frais de paiement inclus). '
          'Le plan Pro n\'affecte pas cette commission.',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: context.tpInkMute,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _freeCard(BuildContext context, PlansCatalog p) {
    final isCurrent = !p.isPro;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: context.tpInkMute.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('GRATUIT',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: kPrimary)),
              const Spacer(),
              if (isCurrent) _currentChip(context),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('0',
                  style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      color: context.tpInk,
                      letterSpacing: -1)),
              const SizedBox(width: 6),
              Text('FCFA',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.tpInkMute)),
            ],
          ),
          const SizedBox(height: 16),
          _feat(context, 'Jusqu\'à ${p.freeMaxEvents} événements actifs'),
          _feat(context, 'Billetterie & QR code d\'entrée'),
          _feat(context, 'Catégories de billets & participants'),
          _feat(context, 'Chat de communauté & notifications'),
          _feat(context, 'Événements illimités', enabled: false),
          _feat(context, 'Analytics avancées', enabled: false),
          _feat(context, 'Jours de boost offerts', enabled: false),
        ],
      ),
    );
  }

  Widget _proCard(BuildContext context, PlansCatalog p) {
    final isCurrent = p.isPro;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        gradient: trackpartyGradient,
        borderRadius: BorderRadius.circular(Radii.lg + 2),
        boxShadow: const [
          BoxShadow(color: Color(0x334F46E5), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.tpCard,
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('PRO',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        color: Color(0xFFEC4899))),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: trackpartyGradient,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text('★ POPULAIRE',
                      style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5)),
                ),
                const Spacer(),
                if (isCurrent) _currentChip(context),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(_fmtMoney(p.proPrice),
                    style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: context.tpInk,
                        letterSpacing: -1)),
                const SizedBox(width: 6),
                Text('FCFA/mois',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.tpInkMute)),
              ],
            ),
            const SizedBox(height: 16),
            _feat(context, 'Événements illimités', strong: true),
            _feat(context, '${p.proWeeklyBoostDays} jours de boost offerts / semaine',
                strong: true),
            _feat(context, 'Tableau de bord web & analytics complètes'),
            _feat(context, 'Badge Pro sur ton profil'),
            _feat(context, 'Co-organisateurs illimités'),
            const SizedBox(height: 18),
            if (!isCurrent)
              GestureDetector(
                onTap: () => _showSoonSheet(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    gradient: trackpartyGradient,
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  alignment: Alignment.center,
                  child: const Text('Passer au Pro',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: context.tpCardAlt,
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                alignment: Alignment.center,
                child: Text(
                  p.periodEnd != null
                      ? 'Actif jusqu\'au ${p.periodEnd!.day}/${p.periodEnd!.month}/${p.periodEnd!.year}'
                      : 'Plan actif',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: context.tpInk),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _currentChip(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: kSuccess.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text('Plan actuel',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w900, color: kSuccess)),
      );

  Widget _feat(BuildContext context, String text,
      {bool enabled = true, bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            enabled ? Icons.check_rounded : Icons.close_rounded,
            size: 18,
            color: enabled ? const Color(0xFF34D399) : context.tpInkMute,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                color: enabled
                    ? (strong ? context.tpInk : context.tpInkSub)
                    : context.tpInkMute,
                decoration:
                    enabled ? null : TextDecoration.lineThrough,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSoonSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, Sp.lg),
        decoration: BoxDecoration(
          color: ctx.tpCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: trackpartyGradient,
                shape: BoxShape.circle,
              ),
              child: Icon(PhosphorIcons.crown(PhosphorIconsStyle.fill),
                  color: Colors.white, size: 26),
            ),
            const SizedBox(height: 16),
            Text('Paiement bientôt disponible',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: ctx.tpInk)),
            const SizedBox(height: 8),
            Text(
              'L\'abonnement Pro arrive très bientôt avec le paiement mobile. '
              'On te préviendra dès son ouverture.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ctx.tpInkSub,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: TextButton.styleFrom(
                  backgroundColor: kPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                ),
                child: const Text('Compris',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

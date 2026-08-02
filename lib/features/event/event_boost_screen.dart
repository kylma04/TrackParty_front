import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/api/api_exception.dart';
import '../../core/providers/event_provider.dart';
import '../../core/services/event_service.dart';
import '../../theme/colors.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_toast.dart';
import '../payment/payment_sheet.dart';

const _goldRose = LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFEC4899)]);

class EventBoostScreen extends ConsumerStatefulWidget {
  final String eventId;
  final String eventTitle;

  const EventBoostScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  @override
  ConsumerState<EventBoostScreen> createState() => _EventBoostScreenState();
}

class _EventBoostScreenState extends ConsumerState<EventBoostScreen> {
  bool _submitting = false;
  bool _useProDay = false;

  String _fmtMoney(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return '${buf.toString()} FCFA';
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }

  Future<void> _submit({required bool proFree}) async {
    setState(() => _submitting = true);
    try {
      final boost = await ref.read(eventServiceProvider).createBoost(
            widget.eventId,
            mode: proFree ? 'pro_free' : null,
          );
      ref.invalidate(eventBoostProvider(widget.eventId));
      if (!mounted) return;

      final status = boost['status'] as String?;
      final amount = (boost['amount'] as num?)?.toInt() ?? 0;
      final boostId = boost['id'] as String?;

      // Jour Pro offert, ou boost déjà activé (pré-lancement auto-approuvé),
      // ou gratuit : rien à payer.
      if (proFree || status == 'active' || amount <= 0 || boostId == null) {
        _showPendingSheet(proFree: proFree);
        return;
      }

      // Boost payant en attente de paiement → feuille de paiement Jeko.
      final paid = await showPaymentSheet(
        context, ref,
        purpose: 'boost',
        objectId: boostId,
        amount: amount,
        title: 'Booster l\'événement',
      );
      if (!mounted) return;
      ref.invalidate(eventBoostProvider(widget.eventId));
      if (paid) TpToast.success(context, 'Boost activé 🚀');
    } on ApiException catch (e) {
      if (mounted) TpToast.error(context, e.message);
    } catch (_) {
      if (mounted) TpToast.error(context, 'Une erreur est survenue.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showPendingSheet({required bool proFree}) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
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
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                gradient: _goldRose,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.rocket_launch_rounded,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              proFree ? 'Boost Pro demandé 🚀' : 'Demande enregistrée',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: ctx.tpInk,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              proFree
                  ? 'Ton jour de boost offert est en cours d\'activation. '
                      'Ton événement sera bientôt mis en avant.'
                  : 'Ta demande de boost a bien été enregistrée. Elle sera '
                      'activée dès la confirmation du paiement.',
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
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.pop();
                },
                style: TextButton.styleFrom(
                  backgroundColor: kPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                ),
                child: const Text(
                  'Compris',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final boostAsync = ref.watch(eventBoostProvider(widget.eventId));

    return Scaffold(
      backgroundColor: context.tpBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _appBar(context),
            Expanded(
              child: boostAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Sp.lg),
                    child: Text(
                      'Impossible de charger les infos de boost.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.tpInkSub),
                    ),
                  ),
                ),
                data: (data) => _content(context, data),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Booster',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: context.tpInk)),
                Text(widget.eventTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: context.tpInkSub)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, Map<String, dynamic> data) {
    final active = data['active_boost'] as Map<String, dynamic>?;
    if (active != null) return _activeView(context, active);

    final quote = (data['quote'] as Map<String, dynamic>?) ?? const {};
    final proDays = (data['pro_boost_days_left'] as num?)?.toInt() ?? 0;
    final amount = (quote['amount'] as num?)?.toInt() ?? 0;
    final days = (quote['days'] as num?)?.toInt() ?? 7;
    final mode = quote['pricing_mode'] as String? ?? 'per_day';

    return ListView(
      padding: const EdgeInsets.fromLTRB(Sp.md, 4, Sp.md, Sp.lg),
      children: [
        _hero(context),
        const SizedBox(height: Sp.md),
        _benefits(context),
        const SizedBox(height: Sp.md),
        if (proDays > 0) _proDayCard(context, proDays),
        if (proDays > 0) const SizedBox(height: Sp.sm),
        _priceCard(context, amount: amount, days: days, mode: mode),
        const SizedBox(height: Sp.lg),
        _cta(context, amount: amount),
      ],
    );
  }

  Widget _hero(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: _goldRose,
        borderRadius: BorderRadius.circular(Radii.lg),
        boxShadow: const [
          BoxShadow(color: Color(0x33EC4899), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 32),
          const SizedBox(height: 12),
          const Text(
            'Mets ton événement\nen première ligne',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Un boost place ton événement tout en haut du fil et le distingue '
            'sur la carte avec le label « Sponsorisé ».',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _benefits(BuildContext context) {
    const items = [
      ('Placement prioritaire', 'En tête du fil et de la recherche'),
      ('Label « Sponsorisé »', 'Une vignette dorée qui attire l\'œil'),
      ('Plus de participants', 'Plus de visibilité = plus d\'inscrits'),
    ];
    return Column(
      children: [
        for (final (title, sub) in items)
          Padding(
            padding: const EdgeInsets.only(bottom: Sp.sm),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(Radii.tag),
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Color(0xFFF59E0B), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: context.tpInk)),
                      Text(sub,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.tpInkSub)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _proDayCard(BuildContext context, int proDays) {
    return GestureDetector(
      onTap: () => setState(() => _useProDay = !_useProDay),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.tpCard,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(
            color: _useProDay ? kPrimary : context.tpInkSub.withValues(alpha: 0.2),
            width: _useProDay ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            const Text('★', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Utiliser un jour Pro offert',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: context.tpInk)),
                  Text('$proDays jour(s) restant(s) cette semaine — gratuit',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.tpInkSub)),
                ],
              ),
            ),
            Icon(
              _useProDay
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              color: _useProDay ? kPrimary : context.tpInkSub,
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceCard(BuildContext context,
      {required int amount, required int days, required String mode}) {
    final dim = _useProDay;
    final desc = mode == 'weekly_flat'
        ? 'Forfait semaine (7 jours)'
        : '$days jour(s) de mise en avant';
    return Opacity(
      opacity: dim ? 0.45 : 1,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.tpCard,
          borderRadius: BorderRadius.circular(Radii.md),
          boxShadow: Shadows.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tarif du boost',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.tpInkSub)),
                  const SizedBox(height: 2),
                  Text(desc,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.tpInk)),
                ],
              ),
            ),
            Text(
              amount > 0 ? _fmtMoney(amount) : 'Gratuit',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: context.tpInk,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cta(BuildContext context, {required int amount}) {
    final proFree = _useProDay;
    final label = proFree
        ? 'Activer mon jour Pro offert'
        : amount > 0
            ? 'Booster pour ${_fmtMoney(amount)}'
            : 'Booster mon événement';
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: _submitting ? null : () => _submit(proFree: proFree),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: _goldRose,
            borderRadius: BorderRadius.circular(Radii.md),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x33EC4899), blurRadius: 12, offset: Offset(0, 4)),
            ],
          ),
          alignment: Alignment.center,
          child: _submitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.4, color: Colors.white),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _activeView(BuildContext context, Map<String, dynamic> active) {
    final endsAt = _fmtDate(active['ends_at'] as String?);
    return ListView(
      padding: const EdgeInsets.fromLTRB(Sp.md, 4, Sp.md, Sp.lg),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: _goldRose,
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
          child: Column(
            children: [
              const Icon(Icons.rocket_launch_rounded,
                  color: Colors.white, size: 40),
              const SizedBox(height: 14),
              const Text(
                'Boost actif 🚀',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                endsAt.isNotEmpty
                    ? 'Ton événement est mis en avant jusqu\'au $endsAt.'
                    : 'Ton événement est mis en avant.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Sp.md),
        _benefits(context),
      ],
    );
  }
}

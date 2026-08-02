import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_exception.dart';
import '../../core/services/payment_service.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/pay_method_logo.dart';

/// Feuille de paiement réutilisable (abonnement Pro, boost…).
///
/// Choix du moyen de paiement → POST /payments/create/ → ouverture de la page
/// Jeko → polling du statut. Renvoie `true` si le paiement est confirmé.
///
/// En pré-lancement (`PAYMENTS_ENABLED=False`), le backend renvoie
/// `payments_disabled` → la feuille affiche « bientôt disponible » et renvoie `false`.
Future<bool> showPaymentSheet(
  BuildContext context,
  WidgetRef ref, {
  required String purpose, // 'subscription' | 'boost'
  String? objectId,
  required int amount,
  required String title,
}) async {
  final paid = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    builder: (_) => _PaymentSheet(
      purpose: purpose, objectId: objectId, amount: amount, title: title,
    ),
  );
  return paid ?? false;
}

enum _Phase { select, polling, disabled, failure }

class _PaymentSheet extends ConsumerStatefulWidget {
  final String purpose;
  final String? objectId;
  final int amount;
  final String title;
  const _PaymentSheet({
    required this.purpose,
    required this.objectId,
    required this.amount,
    required this.title,
  });

  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  PayMethod _method = PayMethod.wave;
  _Phase _phase = _Phase.select;
  bool _starting = false;
  String? _paymentId;
  Timer? _poll;
  String _failureMsg = '';

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  String _fmt(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    return '${b.toString()} FCFA';
  }

  Future<void> _start() async {
    setState(() => _starting = true);
    try {
      final init = await ref.read(paymentServiceProvider).createPayment(
            purpose: widget.purpose,
            method: _method,
            objectId: widget.objectId,
          );
      _paymentId = init.paymentId;
      // Pré-lancement (PAYMENTS_ENABLED=False + PAYMENTS_AUTO_APPROVE=True) :
      // le paiement revient déjà « success », rien à ouvrir ni à attendre.
      if (init.status == 'success') {
        if (!mounted) return;
        Navigator.of(context).pop(true);
        return;
      }
      if (init.redirectUrl != null && init.redirectUrl!.isNotEmpty) {
        await launchUrl(Uri.parse(init.redirectUrl!),
            mode: LaunchMode.externalApplication);
      }
      if (!mounted) return;
      setState(() => _phase = _Phase.polling);
      _startPolling();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'payments_disabled') {
        setState(() => _phase = _Phase.disabled);
      } else {
        setState(() {
          _phase = _Phase.failure;
          _failureMsg = e.message;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.failure;
        _failureMsg = 'Impossible de démarrer le paiement.';
      });
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _startPolling() {
    var ticks = 0;
    _poll = Timer.periodic(const Duration(seconds: 4), (t) async {
      ticks++;
      if (ticks > 75 || _paymentId == null) {
        t.cancel();
        return;
      }
      try {
        final status =
            await ref.read(paymentServiceProvider).getStatus(_paymentId!);
        if (!mounted) return;
        if (status == 'success') {
          t.cancel();
          Navigator.of(context).pop(true);
        } else if (status == 'error' || status == 'expired') {
          t.cancel();
          setState(() {
            _phase = _Phase.failure;
            _failureMsg = 'Le paiement n\'a pas abouti.';
          });
        }
      } catch (_) {/* on retentera au prochain tick */}
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(Sp.md, 14, Sp.md, Sp.lg),
        decoration: BoxDecoration(
          color: context.tpCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: switch (_phase) {
          _Phase.select => _selectView(context),
          _Phase.polling => _pollingView(context),
          _Phase.disabled => _disabledView(context),
          _Phase.failure => _failureView(context),
        },
      ),
    );
  }

  Widget _grip(BuildContext context) => Center(
        child: Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: context.tpInkMute.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      );

  Widget _selectView(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _grip(context),
        Text(widget.title,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w900, color: context.tpInk)),
        const SizedBox(height: 2),
        Text('Choisis ton moyen de paiement',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.tpInkSub)),
        const SizedBox(height: 16),
        ...PayMethod.values.map(_methodTile),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _starting ? null : _start,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: trackpartyGradient,
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            alignment: Alignment.center,
            child: _starting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Colors.white))
                : Text(
                    widget.amount > 0
                        ? 'Payer ${_fmt(widget.amount)}'
                        : 'Continuer',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _methodTile(PayMethod m) {
    final active = _method == m;
    return GestureDetector(
      onTap: () => setState(() => _method = m),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: context.tpBg,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(
              color: active ? kPrimary : context.tpInkMute.withValues(alpha: 0.15),
              width: active ? 1.6 : 1),
        ),
        child: Row(children: [
          PayMethodLogo(method: m),
          const SizedBox(width: 12),
          Expanded(
            child: Text(m.label,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, color: context.tpInk)),
          ),
          Icon(active ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: active ? kPrimary : context.tpInkMute),
        ]),
      ),
    );
  }

  Widget _pollingView(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _grip(context),
        const SizedBox(height: 6),
        const CircularProgressIndicator(),
        const SizedBox(height: 20),
        Text('Paiement en cours…',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w900, color: context.tpInk)),
        const SizedBox(height: 8),
        Text(
          'Valide le paiement dans ton application ${_method.label}, puis '
          'reviens ici. La confirmation est automatique.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.tpInkSub,
              height: 1.5),
        ),
        const SizedBox(height: 18),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Fermer',
              style: TextStyle(
                  fontWeight: FontWeight.w800, color: context.tpInkSub)),
        ),
      ],
    );
  }

  Widget _disabledView(BuildContext context) =>
      _infoView(context, '🔜', 'Paiement bientôt disponible',
          'Le paiement mobile arrive très vite. On te préviendra dès son ouverture.');

  Widget _failureView(BuildContext context) => _infoView(
      context,
      '⚠️',
      'Paiement non abouti',
      _failureMsg.isNotEmpty ? _failureMsg : 'Réessaie dans un instant.',
      retry: true);

  Widget _infoView(BuildContext context, String emoji, String title, String body,
      {bool retry = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _grip(context),
        Text(emoji, style: const TextStyle(fontSize: 40)),
        const SizedBox(height: 12),
        Text(title,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w900, color: context.tpInk)),
        const SizedBox(height: 8),
        Text(body,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.tpInkSub,
                height: 1.5)),
        const SizedBox(height: 20),
        Row(children: [
          if (retry)
            Expanded(
              child: TextButton(
                onPressed: () => setState(() => _phase = _Phase.select),
                style: TextButton.styleFrom(
                  backgroundColor: kPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Radii.md)),
                ),
                child: const Text('Réessayer',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15)),
              ),
            ),
          if (retry) const SizedBox(width: 10),
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                backgroundColor: retry ? context.tpBg : kPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.md)),
              ),
              child: Text(retry ? 'Annuler' : 'Compris',
                  style: TextStyle(
                      color: retry ? context.tpInk : Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15)),
            ),
          ),
        ]),
      ],
    );
  }
}

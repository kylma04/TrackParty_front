import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_exception.dart';
import '../../core/providers/event_provider.dart';
import '../../core/providers/ticket_provider.dart';
import '../../core/services/payment_service.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_toast.dart';

enum _Phase { select, polling, success, failure }

class PaymentScreen extends ConsumerStatefulWidget {
  final String eventId;
  final String categoryId;
  final String categoryName;
  final int amount;

  const PaymentScreen({
    super.key,
    required this.eventId,
    required this.categoryId,
    required this.categoryName,
    required this.amount,
  });

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  PayMethod _method = PayMethod.wave;
  _Phase _phase = _Phase.select;
  bool _starting = false;
  String? _paymentId;
  Timer? _poll;

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
      final init = await ref.read(paymentServiceProvider).purchaseTicket(
            eventId: widget.eventId,
            categoryId: widget.categoryId,
            method: _method,
          );
      _paymentId = init.paymentId;
      // Ouvre la page de paiement Jeko dans le navigateur.
      if (init.redirectUrl != null && init.redirectUrl!.isNotEmpty) {
        await launchUrl(Uri.parse(init.redirectUrl!),
            mode: LaunchMode.externalApplication);
      }
      if (!mounted) return;
      setState(() => _phase = _Phase.polling);
      _startPolling();
    } on ApiException catch (e) {
      if (mounted) TpToast.error(context, e.message);
    } catch (_) {
      if (mounted) TpToast.error(context, 'Impossible de démarrer le paiement.');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  /// Paiement confirmé : passe en succès ET rafraîchit le détail event (stock
  /// restant) + la liste des billets.
  void _finishSuccess() {
    ref.invalidate(eventDetailProvider(widget.eventId));
    ref.invalidate(myTicketsProvider);
    setState(() => _phase = _Phase.success);
  }

  void _startPolling() {
    // Poll toutes les 4 s ; s'arrête au statut final (≈ jusqu'à 5 min).
    var ticks = 0;
    _poll = Timer.periodic(const Duration(seconds: 4), (t) async {
      ticks++;
      if (ticks > 75 || _paymentId == null) {
        t.cancel();
        return;
      }
      try {
        final status = await ref.read(paymentServiceProvider).getStatus(_paymentId!);
        if (!mounted) return;
        if (status == 'success') {
          t.cancel();
          _finishSuccess();
        } else if (status == 'error' || status == 'expired') {
          t.cancel();
          setState(() => _phase = _Phase.failure);
        }
      } catch (_) {/* on retentera au prochain tick */}
    });
  }

  Future<void> _checkNow() async {
    if (_paymentId == null) return;
    try {
      final status = await ref.read(paymentServiceProvider).getStatus(_paymentId!);
      if (!mounted) return;
      if (status == 'success') {
        _poll?.cancel();
        _finishSuccess();
      } else if (status == 'error' || status == 'expired') {
        _poll?.cancel();
        setState(() => _phase = _Phase.failure);
      } else {
        TpToast.info(context, 'Paiement encore en attente…');
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tpBg,
      body: SafeArea(
        child: Column(
          children: [
            _appBar(context),
            Expanded(child: switch (_phase) {
              _Phase.select => _selectView(context),
              _Phase.polling => _pollingView(context),
              _Phase.success => _resultView(context, ok: true),
              _Phase.failure => _resultView(context, ok: false),
            }),
          ],
        ),
      ),
    );
  }

  Widget _appBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, 12),
      child: Row(children: [
        if (_phase == _Phase.select)
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
                child: Icon(PhosphorIcons.caretLeft(), color: context.tpInk, size: 18),
              ),
            ),
          ),
        const SizedBox(width: 12),
        Text('Paiement',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w900, color: context.tpInk)),
      ]),
    );
  }

  Widget _selectView(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(Sp.md, 4, Sp.md, Sp.lg),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: trackpartyGradient,
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Billet ${widget.categoryName}',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white70)),
            const SizedBox(height: 6),
            Text(_fmt(widget.amount),
                style: const TextStyle(
                    fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white)),
          ]),
        ),
        const SizedBox(height: Sp.lg),
        Text('Moyen de paiement',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w900, color: context.tpInkSub)),
        const SizedBox(height: 10),
        ...PayMethod.values.map((m) => _methodTile(context, m)),
        const SizedBox(height: Sp.lg),
        GestureDetector(
          onTap: _starting ? null : _start,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: trackpartyGradient,
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: _starting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : Text('Payer ${_fmt(widget.amount)}',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
        ),
        const SizedBox(height: 10),
        Text('Tu seras redirigé vers la page sécurisée de paiement.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: context.tpInkMute)),
      ],
    );
  }

  Widget _methodTile(BuildContext context, PayMethod m) {
    final active = _method == m;
    return GestureDetector(
      onTap: () => setState(() => _method = m),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: context.tpCard,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(
            color: active ? kPrimary : context.tpInkMute.withValues(alpha: 0.15),
            width: active ? 1.6 : 1,
          ),
        ),
        child: Row(children: [
          Text(m.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(m.label,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, color: context.tpInk)),
          ),
          Icon(
            active ? Icons.check_circle_rounded : Icons.circle_outlined,
            color: active ? kPrimary : context.tpInkMute,
          ),
        ]),
      ),
    );
  }

  Widget _pollingView(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Sp.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 22),
          Text('Paiement en cours…',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900, color: context.tpInk)),
          const SizedBox(height: 8),
          Text(
            'Valide le paiement dans ton application ${_method.label}, puis reviens ici. '
            'On confirme automatiquement.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: context.tpInkSub, height: 1.5),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: _checkNow,
            child: Text("J'ai payé — vérifier",
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w900, color: kPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _resultView(BuildContext context, {required bool ok}) {
    return Padding(
      padding: const EdgeInsets.all(Sp.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: (ok ? kSuccess : kError).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(ok ? Icons.check_rounded : Icons.close_rounded,
                color: ok ? kSuccess : kError, size: 44),
          ),
          const SizedBox(height: 20),
          Text(ok ? 'Paiement réussi 🎉' : 'Paiement non abouti',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900, color: context.tpInk)),
          const SizedBox(height: 8),
          Text(
            ok
                ? 'Ton billet ${widget.categoryName} est prêt dans « Mes billets ».'
                : 'Aucun montant n’a été débité, ou le paiement a expiré. Tu peux réessayer.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: context.tpInkSub, height: 1.5),
          ),
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () {
                if (ok) {
                  context.pushReplacement('/ticket/${widget.eventId}');
                } else {
                  setState(() => _phase = _Phase.select);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: ok ? trackpartyGradient : null,
                  color: ok ? null : context.tpCard,
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: ok ? null : Border.all(color: context.tpInkMute.withValues(alpha: 0.2)),
                ),
                child: Text(ok ? 'Voir mon billet' : 'Réessayer',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: ok ? Colors.white : context.tpInk)),
              ),
            ),
          ),
          if (!ok) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.pop(),
              child: Text('Annuler',
                  style: TextStyle(fontWeight: FontWeight.w800, color: context.tpInkSub)),
            ),
          ],
        ],
      ),
    );
  }
}

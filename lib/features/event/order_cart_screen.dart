import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_exception.dart';
import '../../core/models/event_model.dart';
import '../../core/providers/event_provider.dart';
import '../../core/providers/ticket_provider.dart';
import '../../core/services/payment_service.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_toast.dart';



enum _Phase { cart, polling, success, failure }

/// Panier de participation : choisir des billets payants (catégories) et/ou des
/// contributions en nature (items à apporter), jusqu'à la limite, puis valider.
/// La partie payante ouvre le paiement Jeko ; la nature est confirmée directement.
class OrderCartScreen extends ConsumerStatefulWidget {
  final EventModel event;
  const OrderCartScreen({super.key, required this.event});

  @override
  ConsumerState<OrderCartScreen> createState() => _OrderCartScreenState();
}

class _OrderCartScreenState extends ConsumerState<OrderCartScreen> {
  final Map<String, int> _paid = {};   // categoryId → qté
  final Map<String, int> _nature = {}; // itemId → qté
  PayMethod _method = PayMethod.wave;
  _Phase _phase = _Phase.cart;
  bool _submitting = false;
  String? _paymentId;
  Timer? _poll;

  EventModel get event => widget.event;

  // On garde les catégories/options ÉPUISÉES dans la liste pour les afficher
  // grisées (« plus de billets »), au lieu de les masquer.
  List<TicketCategoryModel> get _cats => event.ticketCategories
      .where((c) => c.price > 0 && c.onSale)
      .toList();
  List<ContributionItemModel> get _items =>
      event.contributionItems.toList();

  int get _total =>
      _paid.values.fold(0, (s, v) => s + v) + _nature.values.fold(0, (s, v) => s + v);
  int get _paidAmount {
    var a = 0;
    for (final c in _cats) {
      a += c.price * (_paid[c.id] ?? 0);
    }
    return a;
  }

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

  void _bump(Map<String, int> map, String id, int delta) {
    final next = (map[id] ?? 0) + delta;
    setState(() {
      if (next <= 0) {
        map.remove(id);
      } else if (_total - (map[id] ?? 0) + next <= event.maxTicketsPerUserPerEvent) {
        map[id] = next;
      }
    });
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final items = <Map<String, dynamic>>[
        for (final e in _paid.entries)
          {'kind': 'paid', 'category_id': e.key, 'quantity': e.value},
        for (final e in _nature.entries)
          {'kind': 'nature', 'item_id': e.key, 'quantity': e.value},
      ];
      final res = await ref.read(paymentServiceProvider).createOrder(
            eventId: event.id,
            items: items,
            method: _paidAmount > 0 ? _method : null,
          );
      if (res.needsPayment) {
        _paymentId = res.paymentId;
        await launchUrl(Uri.parse(res.redirectUrl!),
            mode: LaunchMode.externalApplication);
        if (!mounted) return;
        setState(() => _phase = _Phase.polling);
        _startPolling();
      } else {
        if (!mounted) return;
        _finishSuccess(); // 100% nature confirmé
      }
    } on ApiException catch (e) {
      if (mounted) TpToast.error(context, e.message);
    } catch (_) {
      if (mounted) TpToast.error(context, 'Impossible de valider la commande.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Commande confirmée : passe en succès ET rafraîchit les vues impactées
  /// (détail event → stock restant, feeds, billets) pour que les places se
  /// décrémentent immédiatement.
  void _finishSuccess() {
    ref.invalidate(eventDetailProvider(event.id));
    ref.invalidate(myTicketsProvider);
    ref.invalidate(nearbyEventsFeedProvider);
    ref.invalidate(trendingEventsFeedProvider);
    setState(() => _phase = _Phase.success);
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
        final s = await ref.read(paymentServiceProvider).getStatus(_paymentId!);
        if (!mounted) return;
        if (s == 'success') {
          t.cancel();
          _finishSuccess();
        } else if (s == 'error' || s == 'expired') {
          t.cancel();
          setState(() => _phase = _Phase.failure);
        }
      } catch (_) {}
    });
  }

  Future<void> _checkNow() async {
    if (_paymentId == null) return;
    final s = await ref.read(paymentServiceProvider).getStatus(_paymentId!);
    if (!mounted) return;
    if (s == 'success') {
      _poll?.cancel();
      _finishSuccess();
    } else if (s == 'error' || s == 'expired') {
      _poll?.cancel();
      setState(() => _phase = _Phase.failure);
    } else {
      TpToast.info(context, 'Paiement encore en attente…');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tpBg,
      body: SafeArea(
        child: Column(children: [
          _appBar(context),
          Expanded(child: switch (_phase) {
            _Phase.cart => _cartView(context),
            _Phase.polling => _pollingView(context),
            _Phase.success => _resultView(context, ok: true),
            _Phase.failure => _resultView(context, ok: false),
          }),
        ]),
      ),
    );
  }

  Widget _appBar(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, 12),
        child: Row(children: [
          if (_phase == _Phase.cart)
            GestureDetector(
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
          const SizedBox(width: 12),
          Text('Je participe',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w900, color: context.tpInk)),
        ]),
      );

  Widget _cartView(BuildContext context) {
    final paidAmount = _paidAmount;
    return Column(children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Sp.md, 4, Sp.md, Sp.md),
          children: [
            if (_cats.isNotEmpty) ...[
              _sectionLabel(context, 'Billets'),
              ..._cats.map((c) => _qtyRow(
                    context,
                    title: c.name,
                    subtitle: _fmt(c.price),
                    qty: _paid[c.id] ?? 0,
                    soldOut: c.isSoldOut,
                    maxQty: c.remaining,
                    onMinus: () => _bump(_paid, c.id, -1),
                    onPlus: () => _bump(_paid, c.id, 1),
                  )),
              const SizedBox(height: 14),
            ],
            if (_items.isNotEmpty) ...[
              _sectionLabel(context, 'Contribuer en nature'),
              ..._items.map((i) => _qtyRow(
                    context,
                    title: '${i.emoji} ${i.name}',
                    subtitle: i.categoryName != null
                        ? 'Billet ${i.categoryName} · à apporter'
                        : 'À apporter',
                    qty: _nature[i.id] ?? 0,
                    soldOut: !i.isAvailable,
                    maxQty: i.quantityRemaining,
                    onMinus: () => _bump(_nature, i.id, -1),
                    onPlus: () => _bump(_nature, i.id, 1),
                  )),
            ],
            const SizedBox(height: 8),
            Text('$_total/${event.maxTicketsPerUserPerEvent} billet${_total > 1 ? 's' : ''} sélectionné${_total > 1 ? 's' : ''}',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: context.tpInkMute)),
            if (paidAmount > 0) ...[
              const SizedBox(height: 18),
              _sectionLabel(context, 'Moyen de paiement'),
              ...PayMethod.values.map((m) => _methodTile(context, m)),
            ],
          ],
        ),
      ),
      _bottomBar(context, paidAmount),
    ]);
  }

  Widget _bottomBar(BuildContext context, int paidAmount) {
    final enabled = _total >= 1 && _total <= event.maxTicketsPerUserPerEvent && !_submitting;
    final label = paidAmount > 0
        ? 'Payer ${_fmt(paidAmount)}'
        : (_total > 0 ? 'Confirmer ma participation' : 'Sélectionne un billet');
    return Container(
      padding: const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, Sp.md),
      decoration: BoxDecoration(
        color: context.tpCard,
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, -2))],
      ),
      child: GestureDetector(
        onTap: enabled ? _submit : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: trackpartyGradient,
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : Text(label,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(t,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w900, color: context.tpInkSub)),
      );

  Widget _qtyRow(BuildContext context,
      {required String title,
      required String subtitle,
      required int qty,
      required VoidCallback onMinus,
      required VoidCallback onPlus,
      bool soldOut = false,
      int? maxQty}) {
    // + bloqué si épuisé, si on atteint la limite globale, ou le stock de la ligne.
    final canAdd = !soldOut &&
        _total < event.maxTicketsPerUserPerEvent &&
        (maxQty == null || qty < maxQty);
    return Opacity(
      opacity: soldOut ? 0.45 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.tpCard,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(
              color: qty > 0 ? kPrimary : context.tpInkMute.withValues(alpha: 0.12),
              width: qty > 0 ? 1.4 : 1),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w800, color: context.tpInk)),
              Text(soldOut ? 'Plus de billets disponibles' : subtitle,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: soldOut ? kError : context.tpInkSub)),
            ]),
          ),
          if (soldOut)
            Text('Épuisé',
                style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w900, color: kError))
          else ...[
            _stepBtn(context, '−', qty > 0 ? onMinus : null),
            SizedBox(
              width: 30,
              child: Center(
                child: Text('$qty',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w900, color: context.tpInk)),
              ),
            ),
            _stepBtn(context, '+', canAdd ? onPlus : null),
          ],
        ]),
      ),
    );
  }

  Widget _stepBtn(BuildContext context, String s, VoidCallback? onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: onTap == null ? context.tpBg : kPrimary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(Radii.tag),
          ),
          alignment: Alignment.center,
          child: Text(s,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: onTap == null ? context.tpInkMute : kPrimary)),
        ),
      );

  Widget _methodTile(BuildContext context, PayMethod m) {
    final active = _method == m;
    return GestureDetector(
      onTap: () => setState(() => _method = m),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: context.tpCard,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(
              color: active ? kPrimary : context.tpInkMute.withValues(alpha: 0.15),
              width: active ? 1.6 : 1),
        ),
        child: Row(children: [
          Text(m.emoji, style: const TextStyle(fontSize: 20)),
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

  Widget _pollingView(BuildContext context) => Padding(
        padding: const EdgeInsets.all(Sp.lg),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 22),
          Text('Paiement en cours…',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900, color: context.tpInk)),
          const SizedBox(height: 8),
          Text(
            'Valide le paiement dans ton application ${_method.label}, puis reviens ici.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: context.tpInkSub, height: 1.5),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: _checkNow,
            child: Text("J'ai payé — vérifier",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kPrimary)),
          ),
        ]),
      );

  Widget _resultView(BuildContext context, {required bool ok}) => Padding(
        padding: const EdgeInsets.all(Sp.lg),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
                color: (ok ? kSuccess : kError).withValues(alpha: 0.15),
                shape: BoxShape.circle),
            child: Icon(ok ? Icons.check_rounded : Icons.close_rounded,
                color: ok ? kSuccess : kError, size: 44),
          ),
          const SizedBox(height: 20),
          Text(ok ? 'C\'est validé 🎉' : 'Paiement non abouti',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900, color: context.tpInk)),
          const SizedBox(height: 8),
          Text(
            ok
                ? 'Tes billets sont disponibles dans « Mes billets ».'
                : 'Aucun montant n\'a été débité, ou le paiement a expiré. Tu peux réessayer.',
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
                  context.pushReplacement('/my-tickets');
                } else {
                  setState(() => _phase = _Phase.cart);
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
                child: Text(ok ? 'Voir mes billets' : 'Réessayer',
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
        ]),
      );
}

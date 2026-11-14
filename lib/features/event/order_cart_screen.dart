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
import '../../core/services/event_service.dart';
import '../../core/services/payment_service.dart';
import '../../core/utils/format.dart';
import '../../core/utils/ticket_rules.dart';
import '../../widgets/pay_method_logo.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_button.dart';
import '../../widgets/tp_screen_header.dart';
import '../../widgets/tp_toast.dart';



enum _Phase { cart, polling, success, failure }

/// Panier de participation : choisir des billets payants (par catégorie, ou à
/// prix unique si l'event n'a pas de catégories) et/ou des contributions en
/// nature (items à apporter), jusqu'à la limite, puis valider. La partie
/// payante ouvre le paiement Jeko ; la nature est confirmée directement.
class OrderCartScreen extends ConsumerStatefulWidget {
  final EventModel event;
  const OrderCartScreen({super.key, required this.event});

  @override
  ConsumerState<OrderCartScreen> createState() => _OrderCartScreenState();
}

class _OrderCartScreenState extends ConsumerState<OrderCartScreen> {
  static const _proposalEmojis = ['🎁', '🍕', '🧃', '🍰', '🎵', '🪑', '📷', '🧊'];

  final Map<String, int> _paid = {};   // categoryId → qté
  // Contribution en nature : une seule par personne et par événement — pas de
  // quantité, un simple choix (ou aucun).
  String? _natureItemId;
  final Map<String, int> _flat = {};   // 'flat' → qté (billet standard, sans catégorie)
  PayMethod _method = PayMethod.wave;
  _Phase _phase = _Phase.cart;
  bool _submitting = false;
  String? _paymentId;
  Timer? _poll;

  // Proposition libre en nature
  InKindProposalModel? _myProposal;
  final _proposalTitleCtrl = TextEditingController();
  final _proposalDescCtrl = TextEditingController();
  String _proposalEmoji = '🎁';
  bool _proposalOpen = false;
  bool _proposalBusy = false;

  EventModel get event => widget.event;

  @override
  void initState() {
    super.initState();
    _myProposal = widget.event.myInKindProposal;
    // Ouvre directement le formulaire si l'événement n'a pas de billets payants/items fixes
    // ou si une proposition précédente a été refusée/annulée.
    if (event.allowInKindProposals &&
        ((_cats.isEmpty && _flatPrice == null && _items.isEmpty) ||
            (_myProposal != null &&
                (_myProposal!.isRejected || _myProposal!.isCancelled)))) {
      _proposalOpen = true;
    }
  }

  bool get _hasActiveProposal =>
      _myProposal != null && (_myProposal!.isPending || _myProposal!.isAccepted);

  bool get _alreadyHasInKind =>
      (event.userParticipation?.isInKind ?? false) || _hasActiveProposal;

  // On garde les catégories/options ÉPUISÉES dans la liste pour les afficher
  // grisées (« plus de billets »), au lieu de les masquer.
  List<TicketCategoryModel> get _cats => event.ticketCategories
      .where((c) => c.price > 0 && c.onSale)
      .toList();
  List<ContributionItemModel> get _items =>
      event.contributionItems.toList();

  // Event payant SANS catégories (prix unique) : le backend n'accepte une
  // ligne « flat » que dans ce cas (voir OrderView.flat_not_allowed).
  int? get _flatPrice {
    final amount = event.contributionAmount?.toInt();
    if (_cats.isEmpty &&
        event.contributionType == 'monetaire' &&
        amount != null &&
        amount > 0) {
      return amount;
    }
    return null;
  }
  int? get _flatRemaining => event.maxParticipants != null
      ? event.maxParticipants! - event.participantsCount
      : null;

  int get _total =>
      _paid.values.fold<int>(0, (s, v) => s + v) +
      (_natureItemId != null ? 1 : 0) +
      _flat.values.fold<int>(0, (s, v) => s + v);
  int get _paidAmount {
    var a = 0;
    for (final c in _cats) {
      a += c.price * (_paid[c.id] ?? 0);
    }
    if (_flatPrice != null) {
      a += _flatPrice! * (_flat['flat'] ?? 0);
    }
    return a;
  }

  @override
  void dispose() {
    _poll?.cancel();
    _proposalTitleCtrl.dispose();
    _proposalDescCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitProposal() async {
    final title = _proposalTitleCtrl.text.trim();
    if (title.length < 2) {
      TpToast.warning(
        context,
        'Décris ton apport en au moins 2 caractères.',
      );
      return;
    }
    setState(() => _proposalBusy = true);
    try {
      final created = await ref.read(eventServiceProvider).submitInKindProposal(
            event.id,
            title: title,
            description: _proposalDescCtrl.text.trim(),
            emoji: _proposalEmoji,
          );
      ref.invalidate(eventDetailProvider(event.id));
      if (!mounted) return;
      setState(() {
        _myProposal = created;
        _natureItemId = null;
        _proposalOpen = false;
        _proposalTitleCtrl.clear();
        _proposalDescCtrl.clear();
      });
      TpToast.success(context, 'Proposition envoyée à l\'organisateur !');
    } on ApiException catch (e) {
      if (mounted) TpToast.error(context, e.message);
    } finally {
      if (mounted) setState(() => _proposalBusy = false);
    }
  }

  Future<void> _withdrawProposal() async {
    setState(() => _proposalBusy = true);
    try {
      await ref.read(eventServiceProvider).withdrawInKindProposal(event.id);
      ref.invalidate(eventDetailProvider(event.id));
      if (!mounted) return;
      setState(() {
        _myProposal = null;
        _proposalOpen = true;
      });
      TpToast.info(context, 'Proposition retirée');
    } on ApiException catch (e) {
      if (mounted) TpToast.error(context, e.message);
    } finally {
      if (mounted) setState(() => _proposalBusy = false);
    }
  }

  void _bump(Map<String, int> map, String id, int delta) {
    final next = (map[id] ?? 0) + delta;
    setState(() {
      if (next <= 0) {
        map.remove(id);
      } else if (isWithinCartTicketLimit(event, _total - (map[id] ?? 0) + next)) {
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
        if (_natureItemId != null)
          {'kind': 'nature', 'item_id': _natureItemId, 'quantity': 1},
        if ((_flat['flat'] ?? 0) > 0)
          {'kind': 'flat', 'quantity': _flat['flat']},
      ];
      final res = await ref.read(paymentServiceProvider).createOrder(
            eventId: event.id,
            items: items,
            method: _paidAmount > 0 ? _method : null,
          );
      if (res.needsPayment) {
        // La commande existe déjà côté serveur à ce stade : si l'ouverture de
        // l'app de paiement échoue (app absente, deep-link invalide), on
        // bascule quand même vers le polling au lieu d'afficher une erreur
        // qui laisserait croire qu'aucune commande n'a été créée (risque de
        // double commande si l'utilisateur retente _submit).
        _paymentId = res.paymentId;
        try {
          await launchUrl(Uri.parse(res.redirectUrl!),
              mode: LaunchMode.externalApplication);
        } catch (e) {
          debugPrint('OrderCart: échec ouverture app de paiement — $e');
          if (mounted) {
            TpToast.error(context, "Impossible d'ouvrir l'application de paiement. "
                'Vérifie qu\'elle est installée, puis suis l\'état ici.');
          }
        }
        if (!mounted) return;
        setState(() => _phase = _Phase.polling);
        _startPolling();
      } else {
        if (!mounted) return;
        _finishSuccess(); // 100% nature confirmé
      }
    } on ApiException catch (e) {
      if (mounted) TpToast.error(context, e.message);
    } catch (e) {
      debugPrint('OrderCart: échec _submit (createOrder) — $e');
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
        // Le délai de polling est dépassé (5 min) : on ne laisse jamais
        // l'utilisateur bloqué sur "Paiement en cours…" sans issue — on
        // bascule vers l'écran d'échec (qui propose de réessayer).
        if (mounted) setState(() => _phase = _Phase.failure);
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
      } catch (e) {
        debugPrint('OrderCart: échec vérification statut paiement — $e');
      }
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
          if (_phase == _Phase.cart) const TpBackButton(),
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
            if (_flatPrice != null) ...[
              _sectionLabel(context, 'Billet'),
              _qtyRow(
                context,
                title: 'Entrée',
                subtitle: formatFcfa(_flatPrice!),
                qty: _flat['flat'] ?? 0,
                soldOut: _flatRemaining != null && _flatRemaining! <= 0,
                maxQty: _flatRemaining,
                onMinus: () => _bump(_flat, 'flat', -1),
                onPlus: () => _bump(_flat, 'flat', 1),
              ),
              const SizedBox(height: 14),
            ] else if (_cats.isNotEmpty) ...[
              _sectionLabel(context, 'Billets'),
              ..._cats.map((c) => _qtyRow(
                    context,
                    title: c.name,
                    subtitle: formatFcfa(c.price),
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
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _alreadyHasInKind
                      ? 'Tu as déjà une contribution en nature active sur cet événement.'
                      : 'Une seule contribution possible par personne',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _alreadyHasInKind ? kWarning : context.tpInkMute,
                  ),
                ),
              ),
              ..._items.map((i) => _natureRow(context, i)),
            ],
            if (event.allowInKindProposals || _myProposal != null) ...[
              const SizedBox(height: 12),
              _sectionLabel(context, 'Proposer un apport en nature'),
              _proposalSection(context),
            ],
            if (_cats.isNotEmpty || _flatPrice != null || _items.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                event.maxTicketsPerUserPerEvent == null
                    ? '$_total billet${_total > 1 ? 's' : ''} sélectionné${_total > 1 ? 's' : ''}'
                    : '$_total/${event.maxTicketsPerUserPerEvent} billet${_total > 1 ? 's' : ''} sélectionné${_total > 1 ? 's' : ''}',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: context.tpInkMute),
              ),
            ],
            if (paidAmount > 0) ...[
              const SizedBox(height: 18),
              _sectionLabel(context, 'Moyen de paiement'),
              ...PayMethod.values.map((m) => _methodTile(context, m)),
            ],
          ],
        ),
      ),
      if (_cats.isNotEmpty || _flatPrice != null || _items.isNotEmpty)
        _bottomBar(context, paidAmount),
    ]);
  }

  Widget _bottomBar(BuildContext context, int paidAmount) {
    final enabled = _total >= 1 &&
      isWithinCartTicketLimit(event, _total) &&
      !_submitting;
    final label = paidAmount > 0
        ? 'Payer ${formatFcfa(paidAmount)}'
        : (_total > 0 ? 'Confirmer ma participation' : 'Sélectionne un billet');
    return Container(
      padding: const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, Sp.md),
      decoration: BoxDecoration(
        color: context.tpCard,
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, -2))],
      ),
      child: TpButton(
        label: label,
        fullWidth: true,
        state: _submitting
            ? TpButtonState.loading
            : (enabled ? TpButtonState.idle : TpButtonState.disabled),
        onPressed: enabled ? _submit : null,
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
        isWithinCartTicketLimit(event, _total + 1) &&
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
                  maxLines: 2, overflow: TextOverflow.ellipsis,
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
            _stepBtn(context, '−', qty > 0 ? onMinus : null, label: 'Retirer $title'),
            SizedBox(
              width: 30,
              child: Center(
                child: Text('$qty',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w900, color: context.tpInk)),
              ),
            ),
            _stepBtn(context, '+', canAdd ? onPlus : null, label: 'Ajouter $title'),
          ],
        ]),
      ),
    );
  }

  /// Ligne de sélection d'une contribution en nature — un choix unique (pas de
  /// quantité) : tapoter sélectionne l'item et désélectionne tout autre choix ;
  /// tapoter à nouveau désélectionne.
  Widget _natureRow(BuildContext context, ContributionItemModel i) {
    final selected = _natureItemId == i.id;
    final soldOut = !i.isAvailable;
    final blocked = _alreadyHasInKind;
    final disabled = soldOut || blocked;
    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: GestureDetector(
        onTap: disabled
            ? null
            : () => setState(() => _natureItemId = selected ? null : i.id),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: context.tpCard,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(
                color: selected ? kPrimary : context.tpInkMute.withValues(alpha: 0.12),
                width: selected ? 1.4 : 1),
          ),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${i.emoji} ${i.name}',
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w800, color: context.tpInk)),
                Text(
                  soldOut
                      ? 'Plus disponible'
                      : blocked
                          ? 'Contribution en nature déjà active'
                          : (i.categoryName != null
                              ? 'Billet ${i.categoryName} · à apporter'
                              : 'À apporter'),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: soldOut ? kError : context.tpInkSub),
                ),
              ]),
            ),
            if (soldOut)
              Text('Épuisé',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: kError))
            else
              Icon(selected ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill) : PhosphorIcons.circle(),
                  color: selected ? kPrimary : context.tpInkMute),
          ]),
        ),
      ),
    );
  }

  Widget _proposalSection(BuildContext context) {
    final p = _myProposal;

    if (p != null && p.isPending) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.tpCard,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: kWarning.withValues(alpha: 0.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(p.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: context.tpInk,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: kWarning.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                  child: const Text(
                    'En attente',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: kWarning,
                    ),
                  ),
                ),
              ],
            ),
            if (p.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                p.description,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.tpInkSub,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'L\'organisateur doit valider ta proposition avant l\'émission du billet.',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: context.tpInkSub,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _proposalBusy ? null : _withdrawProposal,
                style: OutlinedButton.styleFrom(
                  foregroundColor: kError,
                  side: BorderSide(color: kError.withValues(alpha: 0.45)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.button),
                  ),
                ),
                child: _proposalBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Retirer ma proposition',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
        ),
      );
    }

    if (p != null && p.isAccepted) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.tpCard,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: kSuccess.withValues(alpha: 0.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(p.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: context.tpInk,
                    ),
                  ),
                ),
                const Text(
                  'Acceptée',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: kSuccess,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              p.ticketCategoryName != null
                  ? 'Billet attribué (${p.ticketCategoryName}) · À confirmer par le staff à l\'entrée.'
                  : 'Billet en nature attribué · Disponible dans « Mes billets ».',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.tpInkSub,
              ),
            ),
            const SizedBox(height: 10),
            TpButton(
              label: 'Voir mes billets',
              fullWidth: true,
              variant: TpButtonVariant.outline,
              onPressed: () => context.push('/my-tickets'),
            ),
          ],
        ),
      );
    }

    if (event.userParticipation?.isInKind == true) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.tpCard,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: context.tpHair),
        ),
        child: Text(
          'Tu as déjà choisi une contribution en nature pour cet événement.',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: context.tpInkSub,
          ),
        ),
      );
    }

    if (!event.allowInKindProposals) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(
          color: _proposalOpen
              ? kPrimary.withValues(alpha: 0.45)
              : context.tpInkMute.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p != null && (p.isRejected || p.isCancelled)) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (p.isRejected ? kError : context.tpInkMute)
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Text(
                p.isRejected
                    ? 'Proposition précédente refusée${(p.rejectionReason != null && p.rejectionReason!.isNotEmpty) ? ' : ${p.rejectionReason}' : '.'}'
                    : 'Proposition précédente annulée. Tu peux en envoyer une nouvelle.',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: p.isRejected ? kError : context.tpInkSub,
                ),
              ),
            ),
          ],
          GestureDetector(
            onTap: () => setState(() => _proposalOpen = !_proposalOpen),
            child: Row(
              children: [
                const Text('🎁', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Faire une proposition personnalisée',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: context.tpInk,
                        ),
                      ),
                      Text(
                        'Propose un objet, plat ou service à valider par l\'organisateur',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: context.tpInkSub,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _proposalOpen
                      ? PhosphorIcons.caretUp()
                      : PhosphorIcons.caretDown(),
                  size: 16,
                  color: context.tpInkMute,
                ),
              ],
            ),
          ),
          if (_proposalOpen) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _proposalEmojis.map((em) {
                  final sel = _proposalEmoji == em;
                  return GestureDetector(
                    onTap: () => setState(() => _proposalEmoji = em),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: sel
                            ? kPrimary.withValues(alpha: 0.14)
                            : context.tpBg,
                        borderRadius: BorderRadius.circular(Radii.sm),
                        border: Border.all(
                          color: sel ? kPrimary : context.tpHair,
                        ),
                      ),
                      child: Text(em, style: const TextStyle(fontSize: 16)),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _proposalTitleCtrl,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: 'Ce que tu proposes d\'apporter',
                hintText: 'Ex : 2 packs d\'eau minérale ou DJ set 1h',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                isDense: true,
                counterText: '',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _proposalDescCtrl,
              maxLength: 400,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Précisions (optionnel)',
                hintText: 'Quantité, marque, heure d\'arrivée…',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                isDense: true,
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TpButton(
              label: 'Envoyer ma proposition',
              fullWidth: true,
              state:
                  _proposalBusy ? TpButtonState.loading : TpButtonState.idle,
              onPressed: _proposalBusy ? null : _submitProposal,
            ),
          ],
        ],
      ),
    );
  }

  Widget _stepBtn(BuildContext context, String s, VoidCallback? onTap, {required String label}) =>
      Semantics(
        button: true,
        label: label,
        enabled: onTap != null,
        child: GestureDetector(
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
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
            ),
          ),
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
          PayMethodLogo(method: m),
          const SizedBox(width: 12),
          Expanded(
            child: Text(m.label,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, color: context.tpInk)),
          ),
          Icon(active ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill) : PhosphorIcons.circle(),
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
            child: Icon(ok ? PhosphorIconsBold.check : PhosphorIconsBold.x,
                color: ok ? kSuccess : kError, size: 44),
          ),
          const SizedBox(height: 20),
          Text(ok ? 'C\'est validé' : 'Paiement non abouti',
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
          if (ok) ...[
            const SizedBox(height: 6),
            Text('Un reçu t\'a été envoyé par email',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600, color: context.tpInkMute)),
          ],
          const SizedBox(height: 26),
          TpButton(
            label: ok ? 'Voir mes billets' : 'Réessayer',
            fullWidth: true,
            variant: ok ? TpButtonVariant.gradient : TpButtonVariant.outline,
            onPressed: () {
              if (ok) {
                context.pushReplacement('/my-tickets');
              } else {
                setState(() => _phase = _Phase.cart);
              }
            },
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

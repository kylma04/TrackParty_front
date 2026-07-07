import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'dart:async';

import '../../core/models/chat_model.dart';
import '../../core/models/ticket_model.dart';
import '../../core/providers/ticket_provider.dart';
import '../../core/services/invitation_service.dart';
import '../../core/services/ticket_service.dart';
import '../../core/providers/event_provider.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_avatar.dart';
import '../../widgets/tp_confirm_sheet.dart';
import '../../widgets/tp_field.dart';
import '../../widgets/tp_toast.dart';

class TicketScreen extends ConsumerWidget {
  final String eventId;
  // Billet précis (depuis « Mes billets »). Si null, on récupère le 1er billet
  // de l'événement (entrée « Mon billet » depuis le détail d'un event).
  final TicketModel? ticket;
  const TicketScreen({super.key, required this.eventId, this.ticket});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ticket != null) {
      return Scaffold(
        backgroundColor: context.tpBg,
        body: _TicketBody(ticket: ticket!),
      );
    }

    final ticketAsync = ref.watch(myTicketProvider(eventId));

    return Scaffold(
      backgroundColor: context.tpBg,
      body: ticketAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(PhosphorIcons.ticket(), size: 48, color: context.tpInkMute),
            const SizedBox(height: 16),
            Text('Billet introuvable',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.tpInk)),
            const SizedBox(height: 8),
            TextButton(onPressed: () => context.pop(), child: const Text('Retour')),
          ]),
        ),
        data: (ticket) => _TicketBody(ticket: ticket),
      ),
    );
  }
}

class _TicketBody extends StatelessWidget {
  final TicketModel ticket;
  const _TicketBody({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat("EEE d MMM · HH'h'mm", 'fr_FR').format(ticket.eventStart.toLocal());
    final expired = !ticket.isValid;

    return SafeArea(
      child: Column(children: [
        // Nav
        Padding(
          padding: const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, 8),
          child: Row(children: [
            Semantics(
              button: true, label: 'Retour',
              child: GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                    color: context.tpCard,
                    borderRadius: BorderRadius.circular(Radii.md),
                    boxShadow: Shadows.sm),
                child: Icon(PhosphorIcons.caretLeft(), color: context.tpInk, size: 18),
              ),
              ),
            ),
            const SizedBox(width: 12),
            Text('Mon billet',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: context.tpInk)),
          ]),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 8),
              child: _TicketCard(ticket: ticket, dateStr: dateStr, expired: expired),
            ),
          ),
        ),
        if (!expired)
          Padding(
            padding: EdgeInsets.fromLTRB(Sp.md, 8, Sp.md, MediaQuery.of(context).padding.bottom + 16),
            child: Column(children: [
              if (ticket.isTransferable && ticket.eventStart.isAfter(DateTime.now())) ...[
                _TransferButton(ticket: ticket),
                const SizedBox(height: 8),
              ],
              if (ticket.isInKind && !ticket.checkedIn && ticket.eventStart.isAfter(DateTime.now())) ...[
                _CancelNatureButton(ticket: ticket),
                const SizedBox(height: 8),
              ],
              Semantics(
                button: true,
                label: 'Copier le token du billet',
                child: GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: ticket.token));
                  TpToast.success(context, 'Token copié !');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                      color: context.tpCard,
                      borderRadius: BorderRadius.circular(Radii.button),
                      border: Border.all(color: context.tpHair)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(PhosphorIcons.copy(), color: context.tpInkSub, size: 16),
                    const SizedBox(width: 8),
                    Text('Copier le token',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.tpInkSub)),
                  ]),
                ),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final TicketModel ticket;
  final String dateStr;
  final bool expired;

  const _TicketCard({required this.ticket, required this.dateStr, required this.expired});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: BorderRadius.circular(Radii.cardLg),
        boxShadow: Shadows.lg,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        // Header gradient
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: const BoxDecoration(gradient: trackpartyGradient),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(PhosphorIcons.ticket(PhosphorIconsStyle.fill),
                      color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  Text(expired ? 'EXPIRÉ' : 'BILLET VALIDE',
                      style: const TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            Text(ticket.eventTitle,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2)),
            if (ticket.categoryName != null || ticket.isInKind) ...[
              const SizedBox(height: 8),
              Row(children: [
                if (ticket.categoryName != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('🎟️ ${ticket.categoryName}',
                        style: const TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                if (ticket.isInKind) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text('🥗 En nature',
                        style: TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ],
              ]),
              if (ticket.isInKind && ticket.natureItemName != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Article choisi : ${ticket.natureItemName}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
              // Avantages de la catégorie, juste sous le nom.
              if (ticket.categoryAdvantages.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...ticket.categoryAdvantages.map((a) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 4, right: 7),
                            child: Icon(Icons.check_rounded,
                                size: 13, color: Colors.white),
                          ),
                          Expanded(
                            child: Text(a,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    height: 1.35)),
                          ),
                        ],
                      ),
                    )),
              ],
            ],
            const SizedBox(height: 6),
            Row(children: [
              Icon(PhosphorIcons.mapPin(PhosphorIconsStyle.fill), color: Colors.white70, size: 12),
              const SizedBox(width: 4),
              Text(ticket.eventCity,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white70)),
              const SizedBox(width: 12),
              Icon(PhosphorIcons.calendarBlank(PhosphorIconsStyle.fill), color: Colors.white70, size: 12),
              const SizedBox(width: 4),
              Text(dateStr,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white70)),
            ]),
          ]),
        ),
        // Tirets de découpe
        _DashedDivider(color: context.tpHair),
        // QR Code
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(children: [
            Text(ticket.holderName,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w900, color: context.tpInk)),
            const SizedBox(height: 16),
            Stack(alignment: Alignment.center, children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(Radii.lg),
                    boxShadow: Shadows.md),
                child: QrImageView(
                  data: ticket.token,
                  version: QrVersions.auto,
                  size: 200,
                  eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square, color: kInkLight),
                  dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square, color: kInkLight),
                ),
              ),
              if (expired)
                Container(
                  width: 224, height: 224,
                  decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(Radii.lg)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(PhosphorIcons.xCircle(PhosphorIconsStyle.fill),
                        color: kError, size: 40),
                    const SizedBox(height: 8),
                    const Text('EXPIRÉ',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900,
                            color: Colors.white, letterSpacing: 2)),
                  ]),
                ),
              if (ticket.checkedIn && !expired)
                Container(
                  width: 224, height: 224,
                  decoration: BoxDecoration(
                      color: kSuccess.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(Radii.lg)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                        color: Colors.white, size: 40),
                    const SizedBox(height: 8),
                    const Text('SCANNÉ',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900,
                            color: Colors.white, letterSpacing: 2)),
                  ]),
                ),
            ]),
            const SizedBox(height: 14),
            Text(
              ticket.checkedIn
                  ? 'Entrée validée ✓'
                  : expired
                      ? 'Ce billet n\'est plus valide'
                      : 'Présente ce QR à l\'entrée',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: ticket.checkedIn
                      ? kSuccess
                      : expired ? kError : context.tpInkSub),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  final Color color;
  const _DashedDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: CustomPaint(
        size: Size(MediaQuery.of(context).size.width, 20),
        painter: _DashedLinePainter(color: color),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1.5;
    const dashW = 8.0, gap = 6.0;
    double x = 0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + dashW, y), paint);
      x += dashW + gap;
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Transfert de billet ───────────────────────────────────────────────────────

class _TransferButton extends ConsumerWidget {
  final TicketModel ticket;
  const _TransferButton({required this.ticket});

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TransferSheet(ticket: ticket),
    );
    if (ok == true && context.mounted) {
      ref.invalidate(myTicketProvider(ticket.eventId));
      ref.invalidate(myTicketsProvider);
      context.pop(); // l'utilisateur ne détient plus le billet
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _open(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: trackpartyGradient,
          borderRadius: BorderRadius.circular(Radii.button),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(PhosphorIcons.paperPlaneTilt(), color: Colors.white, size: 16),
          const SizedBox(width: 8),
          const Text('Transférer ce billet',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
        ]),
      ),
    );
  }
}

class _CancelNatureButton extends ConsumerWidget {
  final TicketModel ticket;
  const _CancelNatureButton({required this.ticket});

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.tpCard,
        title: Text('Annuler ce billet ?',
            style: TextStyle(fontWeight: FontWeight.w900, color: ctx.tpInk)),
        content: Text(
          'Ta place en nature sera libérée et ce billet ne sera plus valable.',
          style: TextStyle(color: ctx.tpInkSub),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Non', style: TextStyle(color: ctx.tpInkSub))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Annuler le billet',
                  style: TextStyle(color: kError, fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(ticketServiceProvider).cancelTicket(ticket.id);
      ref.invalidate(myTicketsProvider);
      ref.invalidate(myTicketProvider(ticket.eventId));
      ref.invalidate(eventDetailProvider(ticket.eventId));
      if (context.mounted) {
        context.pop();
        TpToast.success(context, 'Billet annulé.');
      }
    } catch (_) {
      if (context.mounted) TpToast.error(context, 'Échec de l\'annulation.');
    }
  }
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _cancel(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: kError.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(Radii.button),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(PhosphorIcons.xCircle(), color: kError, size: 16),
          const SizedBox(width: 8),
          const Text('Annuler ce billet',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: kError)),
        ]),
      ),
    );
  }
}

class _TransferSheet extends ConsumerStatefulWidget {
  final TicketModel ticket;
  const _TransferSheet({required this.ticket});

  @override
  ConsumerState<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends ConsumerState<_TransferSheet> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<UserSearchResult> _results = [];
  bool _loading = false;
  bool _searched = false;
  String? _busyId;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      setState(() {
        _results = [];
        _searched = false;
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    try {
      final res = await ref.read(invitationServiceProvider).searchUsers(q);
      if (!mounted) return;
      setState(() {
        _results = res;
        _loading = false;
        _searched = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _loading = false;
        _searched = true;
      });
    }
  }

  Future<void> _transfer(UserSearchResult user) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await TpConfirmSheet.show(
      context,
      title: 'Transférer à ${user.displayName} ?',
      body: 'Tu perdras l’accès à ce billet : il devient le sien et son QR sera '
          'régénéré. Action définitive.',
      confirmLabel: 'Transférer',
      icon: PhosphorIcons.paperPlaneTilt(),
    );
    if (!confirmed) return;

    setState(() => _busyId = user.id);
    try {
      await ref.read(ticketServiceProvider).transferTicket(widget.ticket.id, user.id);
      if (!mounted) return;
      Navigator.pop(context, true);
      messenger.showSnackBar(
        SnackBar(content: Text('Billet transféré à ${user.displayName}.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busyId = null);
      messenger.showSnackBar(
        const SnackBar(content: Text('Échec du transfert. Réessaie.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.tpBg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(Radii.cardLg)),
        ),
        padding: const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: context.tpHair,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Row(children: [
              Icon(PhosphorIcons.paperPlaneTilt(), color: kPrimary, size: 20),
              const SizedBox(width: 10),
              Text('Transférer le billet',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: context.tpInk)),
            ]),
            const SizedBox(height: 16),
            TpField(
              label: 'Rechercher la personne',
              prefixIcon: PhosphorIcons.magnifyingGlass(),
              controller: _ctrl,
              onChanged: _onChanged,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45),
              child: _buildResults(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: CircularProgressIndicator(color: kPrimary)),
      );
    }
    if (!_searched) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text('Saisis au moins 2 caractères pour rechercher.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.tpInkSub)),
      );
    }
    if (_results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text('Aucun utilisateur trouvé.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.tpInkSub)),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.only(top: 8),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final u = _results[i];
        final busy = _busyId == u.id;
        return GestureDetector(
          onTap: busy ? null : () => _transfer(u),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: context.tpCard,
              borderRadius: BorderRadius.circular(Radii.lg),
            ),
            child: Row(children: [
              TpAvatar(name: u.displayName, imageUrl: u.avatarUrl, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Text(u.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: context.tpInk)),
              ),
              if (busy)
                const SizedBox(
                    width: 16,
                    height: 16,
                    child:
                        CircularProgressIndicator(strokeWidth: 2, color: kPrimary))
              else
                Icon(PhosphorIcons.paperPlaneTilt(),
                    color: kPrimary, size: 18),
            ]),
          ),
        );
      },
    );
  }
}

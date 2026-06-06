import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/models/ticket_model.dart';
import '../../core/providers/ticket_provider.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';

class TicketScreen extends ConsumerWidget {
  final String eventId;
  const TicketScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                    color: context.tpCard,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: Shadows.sm),
                child: Icon(PhosphorIcons.caretLeft(), color: context.tpInk, size: 18),
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
            child: GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: ticket.token));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('Token copié'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                    color: context.tpCard,
                    borderRadius: BorderRadius.circular(14),
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
        borderRadius: BorderRadius.circular(24),
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
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: Shadows.md),
                child: QrImageView(
                  data: ticket.token,
                  version: QrVersions.auto,
                  size: 200,
                  eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square, color: Color(0xFF1B1A2E)),
                  dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square, color: Color(0xFF1B1A2E)),
                ),
              ),
              if (expired)
                Container(
                  width: 224, height: 224,
                  decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(16)),
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
                      color: const Color(0xFF22A865).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(16)),
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
                      ? const Color(0xFF22A865)
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

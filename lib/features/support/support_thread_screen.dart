import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/models/support_model.dart';
import '../../core/services/support_service.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';

class SupportThreadScreen extends ConsumerStatefulWidget {
  final String id;
  const SupportThreadScreen({super.key, required this.id});

  @override
  ConsumerState<SupportThreadScreen> createState() =>
      _SupportThreadScreenState();
}

class _SupportThreadScreenState extends ConsumerState<SupportThreadScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  bool _readSynced = false;
  int _lastCount = -1;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    // Rafraîchit le fil pendant qu'il est ouvert (les nouveaux messages
    // apparaissent sans action de l'utilisateur).
    _poll = Timer.periodic(const Duration(seconds: 7), (_) {
      if (mounted) ref.invalidate(supportTicketProvider(widget.id));
    });
  }

  /// Une fois le fil chargé, les réponses sont marquées lues côté serveur :
  /// on rafraîchit le compteur (badge Aide) et la liste pour refléter ça.
  void _syncReadOnce() {
    if (_readSynced) return;
    _readSynced = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(supportUnreadProvider);
      ref.invalidate(supportTicketsProvider);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final body = _ctrl.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(supportServiceProvider).sendMessage(widget.id, body);
      _ctrl.clear();
      ref.invalidate(supportTicketProvider(widget.id));
      ref.invalidate(supportTicketsProvider);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Échec de l’envoi. Réessaie.')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = ref.watch(supportTicketProvider(widget.id));
    final loaded = ticket.valueOrNull;
    final isClosed = loaded?.status == 'closed';

    return Scaffold(
      backgroundColor: context.tpBg,
      appBar: AppBar(
        backgroundColor: context.tpCard,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(PhosphorIcons.caretLeft(), color: context.tpInk, size: 20),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: ticket.maybeWhen(
          data: (t) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t.subject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: context.tpInk)),
              Text(supportStatusStyle(t.status).$1,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: context.tpInkSub)),
            ],
          ),
          orElse: () => Text('Demande',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: context.tpInk)),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ticket.when(
              skipLoadingOnRefresh: true,
              loading: () =>
                  const Center(child: CircularProgressIndicator(color: kPrimary)),
              error: (_, _) => Center(
                child: TextButton(
                  onPressed: () =>
                      ref.invalidate(supportTicketProvider(widget.id)),
                  child: const Text('Réessayer',
                      style: TextStyle(
                          color: kPrimary, fontWeight: FontWeight.w800)),
                ),
              ),
              data: (t) {
                _syncReadOnce();
                // Ne défile en bas que si de nouveaux messages sont arrivés.
                if (t.messages.length != _lastCount) {
                  _lastCount = t.messages.length;
                  _scrollToBottom();
                }
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(Sp.md, 16, Sp.md, 16),
                  itemCount: t.messages.length,
                  itemBuilder: (_, i) => _Bubble(message: t.messages[i]),
                );
              },
            ),
          ),
          if (loaded == null)
            const SizedBox.shrink()
          else if (isClosed)
            const _ClosedBanner()
          else
            _Composer(
              controller: _ctrl,
              sending: _sending,
              onSend: _send,
            ),
        ],
      ),
    );
  }
}

/// Bandeau affiché quand le ticket est fermé : plus aucune action possible.
class _ClosedBanner extends StatelessWidget {
  const _ClosedBanner();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(Sp.md, 16, Sp.md, 16),
        decoration: BoxDecoration(
          color: context.tpCard,
          border: Border(top: BorderSide(color: context.tpHair)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(PhosphorIcons.lockSimple(PhosphorIconsStyle.fill),
                    color: context.tpInkMute, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Votre préoccupation a été résolue, ce ticket a donc été '
                    'fermé. Veuillez ouvrir un autre ticket si vous avez '
                    'd’autres préoccupations.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                      color: context.tpInkSub,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => context.pushReplacement('/support/new'),
                icon: Icon(PhosphorIcons.plus(), size: 18, color: Colors.white),
                label: const Text('Ouvrir un nouveau ticket',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: Colors.white)),
                style: TextButton.styleFrom(
                  backgroundColor: kPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Radii.button)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final SupportMessage message;
  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final fromSupport = message.isFromSupport;
    return Align(
      alignment: fromSupport ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          gradient: fromSupport ? null : trackpartyGradient,
          color: fromSupport ? context.tpCard : null,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(Radii.lg),
            topRight: const Radius.circular(Radii.lg),
            bottomLeft: Radius.circular(fromSupport ? Radii.xs : Radii.lg),
            bottomRight: Radius.circular(fromSupport ? Radii.lg : Radii.xs),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (fromSupport)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(PhosphorIcons.headset(PhosphorIconsStyle.fill),
                      size: 13, color: kPrimary),
                  const SizedBox(width: 4),
                  const Text('Support TrackParty',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: kPrimary)),
                ]),
              ),
            Text(message.body,
                style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: fromSupport ? context.tpInk : Colors.white)),
            const SizedBox(height: 3),
            Text(supportDateShort(message.createdAt),
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: fromSupport
                        ? context.tpInkMute
                        : Colors.white.withValues(alpha: 0.75))),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(Sp.md, 8, Sp.md, 8),
        decoration: BoxDecoration(
          color: context.tpCard,
          border: Border(top: BorderSide(color: context.tpHair)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.tpInk),
                decoration: InputDecoration(
                  hintText: 'Écris ta réponse…',
                  hintStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.tpInkMute),
                  filled: true,
                  fillColor: context.tpBg,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Radii.cardLg),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: sending ? null : onSend,
              child: Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                    gradient: trackpartyGradient, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Icon(PhosphorIcons.paperPlaneRight(PhosphorIconsStyle.fill),
                        color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

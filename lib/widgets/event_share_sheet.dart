import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../core/models/chat_model.dart';
import '../core/services/chat_service.dart';
import '../core/services/invitation_service.dart';
import '../theme/colors.dart';
import '../theme/gradients.dart';
import '../theme/haptics.dart';
import '../theme/spacing.dart';
import '../theme/theme_ext.dart';
import 'tp_avatar.dart';
import 'tp_toast.dart';

// ── URL helpers ───────────────────────────────────────────────────────────────

String eventDeepLink(String eventId) => 'trackparty://event/$eventId';
String eventWebLink(String eventId)  => 'https://trackparty.ci/event/$eventId';

// ── Entry point ───────────────────────────────────────────────────────────────

void showEventShareSheet(
  BuildContext context, {
  required String eventId,
  required String eventTitle,
  String? eventDescription,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EventShareSheet(
      eventId: eventId,
      eventTitle: eventTitle,
    ),
  );
}

// ── Sheet ─────────────────────────────────────────────────────────────────────

class _EventShareSheet extends ConsumerStatefulWidget {
  final String eventId;
  final String eventTitle;

  const _EventShareSheet({required this.eventId, required this.eventTitle});

  @override
  ConsumerState<_EventShareSheet> createState() => _EventShareSheetState();
}

class _EventShareSheetState extends ConsumerState<_EventShareSheet> {
  // 'home' | 'contacts'
  String _tab = 'home';

  final _searchCtrl  = TextEditingController();
  List<UserSearchResult> _results = [];
  bool _searching    = false;
  String? _sending;   // userId being sent to
  Timer? _debounce;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  String get _shareText =>
      '🎉 Rejoins-moi à « ${widget.eventTitle} » sur TrackParty !\n'
      '${eventWebLink(widget.eventId)}';

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: eventDeepLink(widget.eventId)));
    TpToast.success(context, 'Lien copié !');
  }

  Future<void> _shareNative() async {
    await Share.share(_shareText, subject: widget.eventTitle);
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() { _results = []; _searching = false; });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final res = await ref.read(invitationServiceProvider).searchUsers(q.trim());
        if (mounted) setState(() { _results = res; _searching = false; });
      } catch (_) {
        if (mounted) setState(() { _results = []; _searching = false; });
      }
    });
  }

  Future<void> _sendToContact(UserSearchResult user) async {
    setState(() => _sending = user.id);
    try {
      final chatSvc = ref.read(chatServiceProvider);
      final room    = await chatSvc.getOrCreatePrivateRoom(user.id);
      final msg     = '🎉 Hey ! Regarde cet événement :\n'
                      '« ${widget.eventTitle} »\n'
                      '${eventDeepLink(widget.eventId)}';
      await chatSvc.sendMessage(room.id, msg);
      if (!mounted) return;
      Navigator.of(context).pop();
      context.push('/chat/${room.id}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = null);
      TpToast.error(context, 'Impossible d\'envoyer le message');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: context.tpBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.cardLg)),
      ),
      padding: EdgeInsets.fromLTRB(Sp.md, 20, Sp.md, bottomInset + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(width: 36, height: 4,
            decoration: BoxDecoration(color: context.tpHair, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),

        // Header
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(gradient: trackpartyGradient, borderRadius: BorderRadius.circular(Radii.md)),
            child: Icon(PhosphorIcons.shareNetwork(), color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Partager l\'événement',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: context.tpInk)),
              Text(widget.eventTitle,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.tpInkSub)),
            ]),
          ),
        ]),
        const SizedBox(height: 20),

        if (_tab == 'home') ...[
          // ── Actions principales ──────────────────────────────────────────────
          Row(children: [
            _ActionBtn(
              icon: PhosphorIcons.copy(),
              label: 'Copier\nle lien',
              color: kPrimary,
              onTap: _copyLink,
            ),
            const SizedBox(width: 12),
            _ActionBtn(
              icon: PhosphorIcons.shareNetwork(),
              label: 'Partager\nvia…',
              color: kSuccess,
              onTap: _shareNative,
            ),
            const SizedBox(width: 12),
            _ActionBtn(
              icon: PhosphorIcons.chatCircleDots(),
              label: 'Envoyer\ndans l\'appli',
              color: kViolet,
              onTap: () => setState(() => _tab = 'contacts'),
            ),
          ]),
          const SizedBox(height: 16),

          // ── Aperçu lien ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
                color: context.tpCard,
                borderRadius: BorderRadius.circular(Radii.button),
                border: Border.all(color: context.tpHair)),
            child: Row(children: [
              Icon(PhosphorIcons.link(), color: context.tpInkMute, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(eventDeepLink(widget.eventId),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.tpInkSub),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),
        ] else ...[
          // ── Recherche contacts ───────────────────────────────────────────────
          Row(children: [
            Semantics(
              button: true,
              label: 'Retour',
              child: GestureDetector(
                onTap: () => setState(() { _tab = 'home'; _searchCtrl.clear(); _results = []; }),
                child: Container(
                  width: 44, height: 44,
                  alignment: Alignment.center,
                  child: Icon(PhosphorIcons.arrowLeft(), color: context.tpInk, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: _onSearch,
                style: TextStyle(fontSize: 14, color: context.tpInk),
                decoration: InputDecoration(
                  hintText: 'Recherche un ami…',
                  hintStyle: TextStyle(color: context.tpInkMute),
                  prefixIcon: Icon(PhosphorIcons.magnifyingGlass(), color: context.tpInkMute, size: 18),
                  filled: true,
                  fillColor: context.tpCard,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.button),
                      borderSide: BorderSide(color: context.tpHair)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.button),
                      borderSide: BorderSide(color: context.tpHair)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.button),
                      borderSide: const BorderSide(color: kPrimary, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          if (_searching)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_results.isEmpty && _searchCtrl.text.trim().length >= 2)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text('Aucun résultat',
                  style: TextStyle(fontSize: 14, color: context.tpInkSub)),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _results.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (_, i) {
                  final u = _results[i];
                  final isSending = _sending == u.id;
                  return Semantics(
                    button: true,
                    label: 'Envoyer l\'invitation à ${u.displayName}',
                    child: GestureDetector(
                    onTap: isSending ? null : () => _sendToContact(u),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                          color: context.tpCard,
                          borderRadius: BorderRadius.circular(Radii.md),
                          border: Border.all(color: context.tpHair)),
                      child: Row(children: [
                        TpAvatar(name: u.displayName, imageUrl: u.avatarUrl, size: 38),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(u.displayName,
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700, color: context.tpInk)),
                        ),
                        isSending
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: kPrimary))
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                    color: kPrimary.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(Radii.sm)),
                                child: Text('Envoyer',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kPrimary)),
                              ),
                      ]),
                    ),
                    ),
                  );
                },
              ),
            ),
        ],
      ]),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: () { Haptics.medium(); onTap(); },
          child: Column(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(Radii.lg),
                border: Border.all(color: color.withValues(alpha: 0.25))),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.tpInkSub)),
        ]),
        ),
      ),
    );
  }
}

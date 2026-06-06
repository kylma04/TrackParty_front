import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/models/chat_model.dart';
import '../../core/providers/chat_provider.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_avatar.dart';

class InvitationsScreen extends ConsumerStatefulWidget {
  const InvitationsScreen({super.key});

  @override
  ConsumerState<InvitationsScreen> createState() => _InvitationsScreenState();
}

class _InvitationsScreenState extends ConsumerState<InvitationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(invitationsProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final invitationsAsync = ref.watch(invitationsProvider);

    return Scaffold(
      backgroundColor: context.tpBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: invitationsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2),
                ),
                error: (e, _) => _buildError(context),
                data: (invitations) {
                  final pending = invitations.where((i) => i.isPending).toList();
                  if (pending.isEmpty) return _buildEmpty(context);
                  return _buildList(context, pending);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: context.tpCard,
                borderRadius: BorderRadius.circular(12),
                boxShadow: Shadows.sm,
              ),
              child: Icon(PhosphorIcons.caretLeft(), color: context.tpInk, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Text('Invitations',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
                color: context.tpInk, letterSpacing: -0.6)),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, List<InvitationModel> invitations) {
    return RefreshIndicator(
      color: kPrimary,
      onRefresh: () => ref.read(invitationsProvider.notifier).refresh(),
      child: ListView.builder(
        padding: EdgeInsets.only(
          top: Sp.sm,
          bottom: MediaQuery.of(context).padding.bottom + 80,
        ),
        itemCount: invitations.length,
        itemBuilder: (_, i) => _InvitationCard(invitation: invitations[i]),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('🎉', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        Text('Aucune invitation en attente',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: context.tpInk)),
        const SizedBox(height: 4),
        Text('Tu verras ici les invitations à des événements.',
          style: TextStyle(fontSize: 13, color: context.tpInkSub),
          textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('⚠️', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        Text('Impossible de charger les invitations',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.tpInk)),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => ref.read(invitationsProvider.notifier).refresh(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(gradient: trackpartyGradient, borderRadius: BorderRadius.circular(12)),
            child: const Text('Réessayer',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ]),
    );
  }
}

// ── Carte invitation ──────────────────────────────────────────────────────────

class _InvitationCard extends ConsumerStatefulWidget {
  final InvitationModel invitation;
  const _InvitationCard({required this.invitation});

  @override
  ConsumerState<_InvitationCard> createState() => _InvitationCardState();
}

class _InvitationCardState extends ConsumerState<_InvitationCard> {
  bool _loading = false;

  Future<void> _handleAccept() async {
    final event = widget.invitation.event;
    if (event != null && event.needsContribution) {
      final result = await showModalBottomSheet<({String itemId, int qty})>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => _ContribPickerSheet(items: event.contributionItems),
      );
      if (!mounted || result == null) return;
      await _respond('accept', contributionItemId: result.itemId, quantity: result.qty);
    } else {
      await _respond('accept');
    }
  }

  Future<void> _respond(String action, {String? contributionItemId, int quantity = 1}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await ref.read(invitationsProvider.notifier).respondToInvitation(
        widget.invitation.id,
        action,
        contributionItemId: contributionItemId,
        quantity: quantity,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(action == 'accept' ? '🎉 Invitation acceptée !' : 'Invitation refusée'),
          backgroundColor: action == 'accept' ? kPrimary : null,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        if (action == 'accept' && widget.invitation.event != null) {
          context.push('/event/${widget.invitation.event!.id}');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Une erreur est survenue'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv   = widget.invitation;
    final event = inv.event;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.md),
      child: Container(
        decoration: BoxDecoration(
          color: context.tpCard,
          borderRadius: BorderRadius.circular(20),
          boxShadow: Shadows.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // En-tête
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  TpAvatar(
                    name: inv.sender.displayName,
                    imageUrl: inv.sender.avatarUrl,
                    size: 48,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(inv.sender.displayName,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900,
                              color: context.tpInk)),
                        Text('t\'invite à un événement 🎉',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                              color: context.tpInkSub)),
                      ],
                    ),
                  ),
                  Text(
                    _fmtDate(inv.createdAt),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.tpInkMute),
                  ),
                ],
              ),
            ),

            // Carte événement
            if (event != null)
              GestureDetector(
                onTap: () => context.push('/event/${event.id}'),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  decoration: BoxDecoration(
                    color: context.tpBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.tpHair),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (event.coverImageUrl != null)
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: Image.network(
                            event.coverImageUrl!,
                            height: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              height: 120,
                              color: kPrimary.withValues(alpha: 0.1),
                              child: const Center(child: Text('🎉', style: TextStyle(fontSize: 40))),
                            ),
                          ),
                        )
                      else
                        Container(
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: trackpartyGradient,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          child: const Center(child: Text('🎉', style: TextStyle(fontSize: 40))),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(event.title,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900,
                                  color: context.tpInk, letterSpacing: -0.3),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Row(children: [
                              Icon(PhosphorIcons.calendar(), size: 13, color: context.tpInkMute),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('EEE d MMM · HH\'h\'mm', 'fr_FR').format(event.startAt.toLocal()),
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.tpInkSub),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Boutons réponse
            if (inv.isPending)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _loading ? null : () => _respond('refuse'),
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: context.tpBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.tpHair),
                          ),
                          child: Center(
                            child: Text('Refuser',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                                  color: context.tpInkSub)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: _loading ? null : _handleAccept,
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: trackpartyGradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: Shadows.brand,
                          ),
                          child: Center(
                            child: _loading
                                ? const SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('Accepter 🎉',
                                    style: TextStyle(fontSize: 14,
                                        fontWeight: FontWeight.w800, color: Colors.white)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: inv.isAccepted
                        ? kPrimary.withValues(alpha: 0.1)
                        : context.tpHair,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      inv.isAccepted ? '✅ Invitation acceptée' : '❌ Invitation refusée',
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800,
                        color: inv.isAccepted ? kPrimary : context.tpInkMute,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'maintenant';
    if (diff.inHours < 1) return '${diff.inMinutes} min';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return DateFormat('d MMM', 'fr_FR').format(dt);
  }
}

// ── Sélecteur de contribution ─────────────────────────────────────────────────

class _ContribPickerSheet extends StatefulWidget {
  final List<InvitationContribItem> items;
  const _ContribPickerSheet({required this.items});

  @override
  State<_ContribPickerSheet> createState() => _ContribPickerSheetState();
}

class _ContribPickerSheetState extends State<_ContribPickerSheet> {
  String? _selectedId;
  int _qty = 1;

  InvitationContribItem? get _selected =>
      _selectedId == null ? null : widget.items.where((i) => i.id == _selectedId).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final sel = _selected;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 44, height: 5,
              decoration: BoxDecoration(color: const Color(0xFFECECF3), borderRadius: BorderRadius.circular(3))),
          const SizedBox(height: 16),
          Text('Que vas-tu apporter ?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                  color: Theme.of(context).textTheme.bodyLarge?.color, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text('Choisis un item pour accepter l\'invitation',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodySmall?.color)),
          const SizedBox(height: 16),
          ...widget.items.map((item) {
            final isSelected = _selectedId == item.id;
            return GestureDetector(
              onTap: item.isAvailable ? () => setState(() { _selectedId = item.id; _qty = 1; }) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: !item.isAvailable
                      ? const Color(0xFFECECF3)
                      : isSelected ? kPrimary.withValues(alpha: 0.08) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? kPrimary : const Color(0xFFECECF3),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(children: [
                  Text(item.emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.name,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                            color: item.isAvailable ? const Color(0xFF1B1A2E) : const Color(0xFFA2A1B5))),
                    Text(item.isAvailable
                        ? '${item.quantityRemaining} restant${item.quantityRemaining > 1 ? 's' : ''}'
                        : 'Complet',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: item.isAvailable ? const Color(0xFF6B6A82) : kError)),
                  ])),
                  if (isSelected) Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), color: kPrimary, size: 22),
                ]),
              ),
            );
          }),
          if (sel != null) ...[
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              GestureDetector(
                onTap: _qty > 1 ? () => setState(() => _qty--) : null,
                child: Container(width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: _qty > 1 ? kPrimary : const Color(0xFFECECF3),
                      borderRadius: BorderRadius.circular(10)),
                    alignment: Alignment.center,
                    child: Text('−', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                        color: _qty > 1 ? Colors.white : const Color(0xFFA2A1B5)))),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('$_qty', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              ),
              GestureDetector(
                onTap: _qty < sel.quantityRemaining ? () => setState(() => _qty++) : null,
                child: Container(width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: _qty < sel.quantityRemaining ? kPrimary : const Color(0xFFECECF3),
                      borderRadius: BorderRadius.circular(10)),
                    alignment: Alignment.center,
                    child: Text('+', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                        color: _qty < sel.quantityRemaining ? Colors.white : const Color(0xFFA2A1B5)))),
              ),
            ]),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedId == null
                  ? null
                  : () => Navigator.pop(context, (itemId: _selectedId!, qty: _qty)),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                disabledBackgroundColor: const Color(0xFFECECF3),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                _selectedId == null ? 'Choisis un item' : 'Confirmer et accepter',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                    color: _selectedId == null ? const Color(0xFFA2A1B5) : Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

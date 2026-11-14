import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/api/api_exception.dart';
import '../../core/models/event_model.dart';
import '../../core/providers/event_provider.dart';
import '../../core/services/event_service.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_avatar.dart';
import '../../widgets/tp_screen_header.dart';
import '../../widgets/tp_toast.dart';

/// Écran organisateur/co-organisateur pour consulter et valider ou refuser
/// les propositions libres de contributions en nature des participants.
class InKindProposalsScreen extends ConsumerStatefulWidget {
  final String eventId;
  final String eventTitle;

  const InKindProposalsScreen({
    super.key,
    required this.eventId,
    this.eventTitle = '',
  });

  @override
  ConsumerState<InKindProposalsScreen> createState() =>
      _InKindProposalsScreenState();
}

class _InKindProposalsScreenState extends ConsumerState<InKindProposalsScreen> {
  List<InKindProposalModel>? _proposals;
  bool _loading = true;
  String? _error;
  String _filter = 'all'; // 'all' | 'pending' | 'accepted' | 'rejected'
  final Set<String> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ref
          .read(eventServiceProvider)
          .getInKindProposals(widget.eventId, status: 'all');
      if (!mounted) return;
      setState(() {
        _proposals = list;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<InKindProposalModel> get _filteredProposals {
    final all = _proposals ?? const [];
    if (_filter == 'all') {
      // Met les propositions en attente en haut de liste pour action rapide.
      final pending = all.where((p) => p.isPending);
      final others = all.where((p) => !p.isPending);
      return [...pending, ...others];
    }
    return all.where((p) => p.status == _filter).toList();
  }

  Future<String?> _pickTicketCategory(
    List<TicketCategoryModel> categories,
  ) async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: ctx.tpCard,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Radii.sheet),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          Sp.md,
          Sp.sm,
          Sp.md,
          MediaQuery.of(ctx).padding.bottom + Sp.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: ctx.tpHair,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Catégorie de billet à attribuer',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: ctx.tpInk,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Cette place en nature s\'ajoute aux places payantes sans réduire leur stock.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ctx.tpInkSub,
              ),
            ),
            const SizedBox(height: 12),
            ...categories.map((cat) {
              final dotColor = _parseHex(cat.color) ?? kPrimary;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => Navigator.of(ctx).pop(cat.id),
                  borderRadius: BorderRadius.circular(Radii.md),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: ctx.tpBg,
                      borderRadius: BorderRadius.circular(Radii.md),
                      border: Border.all(color: ctx.tpHair),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            cat.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: ctx.tpInk,
                            ),
                          ),
                        ),
                        Text(
                          cat.price > 0 ? '${cat.price} FCFA' : 'Gratuit',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: ctx.tpInkSub,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          PhosphorIcons.caretRight(),
                          size: 16,
                          color: ctx.tpInkMute,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<String?> _askRejectionReason() async {
    final ctrl = TextEditingController();
    final res = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refuser la proposition'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tu peux préciser un court motif (facultatif) qui sera visible par le participant.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLength: 200,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Ex : Nous avons déjà assez de boissons',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kError),
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Refuser'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return res;
  }

  Future<void> _respond(
    InKindProposalModel proposal, {
    required bool accept,
    required List<TicketCategoryModel> categories,
  }) async {
    if (_busyIds.contains(proposal.id)) return;

    String? categoryId;
    String? reason;
    if (accept && categories.isNotEmpty) {
      categoryId = await _pickTicketCategory(categories);
      if (!mounted || categoryId == null) return;
    } else if (!accept) {
      reason = await _askRejectionReason();
      if (!mounted || reason == null) return;
    }

    setState(() => _busyIds.add(proposal.id));
    try {
      await ref.read(eventServiceProvider).respondInKindProposal(
            widget.eventId,
            proposal.id,
            accept: accept,
            ticketCategoryId: categoryId,
            rejectionReason: reason,
          );
      ref.invalidate(eventStatsProvider(widget.eventId));
      ref.invalidate(eventDetailProvider(widget.eventId));
      await _load();
      if (!mounted) return;
      if (accept) {
        TpToast.success(context, 'Proposition acceptée · Billet envoyé !');
      } else {
        TpToast.info(context, 'Proposition refusée');
      }
    } on ApiException catch (e) {
      if (mounted) TpToast.error(context, e.message);
    } finally {
      if (mounted) setState(() => _busyIds.remove(proposal.id));
    }
  }

  Color? _parseHex(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      final clean = hex.replaceFirst('#', '');
      return Color(int.parse(clean.length == 6 ? 'FF$clean' : clean, radix: 16));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = ref.watch(eventDetailProvider(widget.eventId)).valueOrNull;
    final title = widget.eventTitle.isNotEmpty
        ? widget.eventTitle
        : (event?.title ?? 'Propositions');
    final categories = event?.ticketCategories ?? const <TicketCategoryModel>[];
    final all = _proposals ?? const <InKindProposalModel>[];
    final pendingCount = all.where((p) => p.isPending).length;
    final items = _filteredProposals;

    return Scaffold(
      backgroundColor: context.tpBg,
      body: SafeArea(
        child: Column(
          children: [
            TpScreenHeader(
              title: 'Propositions en nature',
              subtitle: title,
              trailing: IconButton(
                onPressed: _load,
                icon: Icon(PhosphorIcons.arrowsClockwise(), color: context.tpInk),
              ),
            ),
            if (!_loading && _error == null)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, 10),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Toutes (${all.length})',
                      selected: _filter == 'all',
                      onTap: () => setState(() => _filter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'En attente ($pendingCount)',
                      selected: _filter == 'pending',
                      onTap: () => setState(() => _filter = 'pending'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Acceptées',
                      selected: _filter == 'accepted',
                      onTap: () => setState(() => _filter = 'accepted'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Refusées',
                      selected: _filter == 'rejected',
                      onTap: () => setState(() => _filter = 'rejected'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(Sp.lg),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: context.tpInkSub),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: _load,
                                  child: const Text('Réessayer'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : items.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(Sp.lg),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      PhosphorIcons.gift(),
                                      size: 44,
                                      color: context.tpInkMute,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Aucune proposition pour ce filtre',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: context.tpInk,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Les apports proposés par les participants apparaîtront ici.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: context.tpInkSub,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  Sp.md,
                                  4,
                                  Sp.md,
                                  Sp.xl,
                                ),
                                itemCount: items.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (_, i) {
                                  final p = items[i];
                                  return _ProposalCard(
                                    proposal: p,
                                    busy: _busyIds.contains(p.id),
                                    onAccept: () => _respond(
                                      p,
                                      accept: true,
                                      categories: categories,
                                    ),
                                    onReject: () => _respond(
                                      p,
                                      accept: false,
                                      categories: categories,
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? kPrimary : context.tpCard,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(
            color: selected ? kPrimary : context.tpHair,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : context.tpInkSub,
          ),
        ),
      ),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  final InKindProposalModel proposal;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _ProposalCard({
    required this.proposal,
    required this.busy,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM · HH:mm', 'fr_FR');
    final (Color badgeColor, String badgeLabel) = switch (proposal.status) {
      'accepted' => (kSuccess, 'Acceptée'),
      'rejected' => (kError, 'Refusée'),
      'cancelled' => (context.tpInkMute, 'Annulée'),
      _ => (kWarning, 'En attente'),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(
          color: proposal.isPending
              ? kWarning.withValues(alpha: 0.45)
              : context.tpHair,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TpAvatar(
                name: proposal.userName,
                imageUrl: proposal.userAvatarUrl,
                size: 38,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      proposal.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: context.tpInk,
                      ),
                    ),
                    Text(
                      dateFmt.format(proposal.createdAt.toLocal()),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.tpInkMute,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.tpBg,
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(proposal.emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        proposal.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: context.tpInk,
                        ),
                      ),
                    ),
                  ],
                ),
                if (proposal.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    proposal.description,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.tpInkSub,
                      height: 1.35,
                    ),
                  ),
                ],
                if (proposal.ticketCategoryName != null &&
                    proposal.ticketCategoryName!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Catégorie attribuée : ${proposal.ticketCategoryName}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: kSuccess,
                    ),
                  ),
                ],
                if (proposal.rejectionReason != null &&
                    proposal.rejectionReason!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Motif : ${proposal.rejectionReason}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: kError,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (proposal.isPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kError,
                      side: BorderSide(color: kError.withValues(alpha: 0.45)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Radii.button),
                      ),
                    ),
                    child: const Text(
                      'Refuser',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: busy ? null : onAccept,
                    style: FilledButton.styleFrom(
                      backgroundColor: kSuccess,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Radii.button),
                      ),
                    ),
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Accepter et envoyer le billet',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

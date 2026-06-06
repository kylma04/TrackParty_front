import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/models/promoter_model.dart';
import '../../core/providers/auth_provider.dart' show authNotifierProvider, AuthAuthenticated;
import '../../core/providers/promoter_provider.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_avatar.dart';

class ReviewsScreen extends ConsumerStatefulWidget {
  final String promoterId;
  const ReviewsScreen({super.key, required this.promoterId});
  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen> {
  int _filter = 0;

  static const _filterLabels = ['Tous', '5 ★', '4 ★', '3 ★ et -'];

  List<ReviewItem> _applyFilter(List<ReviewItem> reviews) {
    switch (_filter) {
      case 1: return reviews.where((r) => r.rating == 5).toList();
      case 2: return reviews.where((r) => r.rating == 4).toList();
      case 3: return reviews.where((r) => r.rating <= 3).toList();
      default: return reviews;
    }
  }

  bool _isOwner() {
    final auth = ref.read(authNotifierProvider).valueOrNull;
    if (auth is AuthAuthenticated) return auth.user.id == widget.promoterId;
    return false;
  }

  void _showReplySheet(ReviewItem review) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReplySheet(
        reviewerName: review.reviewerName,
        ctrl: ctrl,
        onSubmit: (reply) async {
          await ref
              .read(promoterReviewsProvider(widget.promoterId).notifier)
              .replyToReview(review.id, reply);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(promoterReviewsProvider(widget.promoterId));
    final profileAsync = ref.watch(promoterProfileProvider(widget.promoterId));

    final promoterName = profileAsync.valueOrNull?.displayName ?? '…';
    final avgRating = profileAsync.valueOrNull?.avgRating ?? 0.0;
    final isOwner = _isOwner();

    return Scaffold(
      backgroundColor: context.tpBg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          _buildNav(context, promoterName),
          Expanded(
            child: reviewsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('Impossible de charger les avis',
                    style: TextStyle(fontSize: 14, color: context.tpInkSub)),
                  const SizedBox(height: 12),
                  Semantics(
                    button: true, label: 'Réessayer',
                    child: GestureDetector(
                    onTap: () => ref.invalidate(promoterReviewsProvider(widget.promoterId)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: trackpartyGradient, borderRadius: BorderRadius.circular(Radii.md)),
                      child: const Text('Réessayer',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                    ),
                  ),
                ]),
              ),
              data: (allReviews) {
                final reviews = _applyFilter(allReviews);
                return ListView(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 20),
                  children: [
                    _buildSummary(context, allReviews, avgRating),
                    _buildFilters(context, allReviews),
                    if (reviews.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(Sp.md, 32, Sp.md, 0),
                        child: Center(
                          child: Text('Aucun avis pour ce filtre',
                            style: TextStyle(fontSize: 13, color: context.tpInkSub))),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Sp.md),
                        child: Column(
                          children: reviews.map((r) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ReviewCard(
                              review: r,
                              isOwner: isOwner,
                              onReply: () => _showReplySheet(r),
                            ),
                          )).toList(),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildNav(BuildContext context, String name) {
    final reviewsAsync = ref.watch(promoterReviewsProvider(widget.promoterId));
    final count = reviewsAsync.valueOrNull?.length ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, 8),
      child: Row(children: [
        Semantics(button: true, label: 'Retour',
          child: GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: context.tpCard,
                  borderRadius: BorderRadius.circular(Radii.md), boxShadow: Shadows.sm),
              child: Icon(PhosphorIcons.caretLeft(), color: context.tpInk, size: 18)),
          )),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Avis · $name',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900,
                color: context.tpInk, letterSpacing: -0.4)),
          Text('$count avis',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.tpInkSub)),
        ]),
      ]),
    );
  }

  Widget _buildSummary(BuildContext context, List<ReviewItem> reviews, double avg) {
    final dist = List.filled(5, 0);
    for (final r in reviews) {
      if (r.rating >= 1 && r.rating <= 5) dist[r.rating - 1]++;
    }
    final total = reviews.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 8, Sp.md, 0),
      child: Container(
        padding: const EdgeInsets.all(Sp.md),
        decoration: BoxDecoration(
          color: context.tpCard, borderRadius: BorderRadius.circular(Radii.card), boxShadow: Shadows.md),
        child: Row(children: [
          Column(children: [
            Text(avg > 0 ? avg.toStringAsFixed(1) : '–',
              style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900,
                  color: context.tpInk, letterSpacing: -1.5, height: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: List.generate(5, (i) => Icon(
                  PhosphorIcons.star(PhosphorIconsStyle.fill), size: 12,
                  color: i < avg.round() ? kWarning : kWarning.withValues(alpha: 0.30))),
              ),
            ),
            Text('$total avis',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: context.tpInkSub)),
          ]),
          const SizedBox(width: Sp.md),
          Expanded(
            child: Column(
              children: List.generate(5, (idx) {
                final star = 5 - idx;
                final count = dist[star - 1];
                final pct = total > 0 ? count / total : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    Text('$star', style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w800, color: context.tpInkSub)),
                    const SizedBox(width: 4),
                    Icon(PhosphorIcons.star(PhosphorIconsStyle.fill), size: 10, color: kWarning),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: context.tpHair,
                          valueColor: AlwaysStoppedAnimation(
                            star >= 4 ? kWarning : star >= 3 ? context.tpInkMute : kError),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(width: 28,
                      child: Text('${(pct * 100).round()}%',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                            color: context.tpInkSub))),
                  ]),
                );
              }),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildFilters(BuildContext context, List<ReviewItem> allReviews) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 14, Sp.md, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_filterLabels.length, (i) {
            final active = i == _filter;
            final label = i == 0 ? 'Tous (${allReviews.length})' : _filterLabels[i];
            return Semantics(
              label: label, selected: active, button: true,
              child: GestureDetector(
                onTap: () => setState(() => _filter = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: EdgeInsets.only(right: i < _filterLabels.length - 1 ? 8 : 0),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: active ? trackpartyGradient : null,
                    color: active ? null : context.tpCard,
                    borderRadius: BorderRadius.circular(Radii.md),
                    border: active ? null : Border.all(color: context.tpHair),
                    boxShadow: active
                        ? [const BoxShadow(color: Color(0x407C3AED), blurRadius: 10)] : null,
                  ),
                  child: Text(label,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                        color: active ? Colors.white : context.tpInk)),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ── Review card ────────────────────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  final ReviewItem review;
  final bool isOwner;
  final VoidCallback? onReply;

  const _ReviewCard({required this.review, this.isOwner = false, this.onReply});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.tpCard, borderRadius: BorderRadius.circular(Radii.card), boxShadow: Shadows.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reviewer header
          Row(children: [
            TpAvatar(name: review.reviewerName, imageUrl: review.reviewerAvatarUrl, size: 40),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(review.reviewerName,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: context.tpInk)),
              const SizedBox(height: 2),
              Row(children: [
                ...List.generate(5, (i) => Icon(PhosphorIcons.star(PhosphorIconsStyle.fill),
                  size: 11, color: i < review.rating ? kWarning : kWarning.withValues(alpha: 0.25))),
                const SizedBox(width: 4),
                Text('· ${review.dateLabel}',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: context.tpInkMute)),
              ]),
            ])),
          ]),
          // Event chip
          if (review.eventTitle != null && review.eventTitle!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(gradient: gradientSoft, borderRadius: BorderRadius.circular(Radii.sm)),
              child: Text('📍 ${review.eventTitle}',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kPrimary)),
            ),
          ],
          // Comment
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review.comment,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: context.tpInk, height: 1.45)),
          ],
          // Tags
          if (review.tagLabels.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6,
              children: review.tagLabels.map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: context.tpBg, borderRadius: BorderRadius.circular(Radii.pill)),
                child: Text(t, style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700, color: context.tpInk)),
              )).toList()),
          ],
          // Organizer reply
          if (review.organizerReply != null && review.organizerReply!.isNotEmpty) ...[
            const SizedBox(height: 10),
            _OrganizerReply(reply: review.organizerReply!, replyAt: review.replyAt),
          ],
          // Reply button (owner, no reply yet)
          if (isOwner && (review.organizerReply == null || review.organizerReply!.isEmpty)) ...[
            const SizedBox(height: 10),
            Semantics(
              button: true, label: 'Répondre à l\'avis',
              child: GestureDetector(
              onTap: onReply,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIcons.arrowBendUpLeft(), color: kPrimary, size: 14),
                  const SizedBox(width: 6),
                  Text('Répondre',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kPrimary)),
                ],
              ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Réponse de l'organisateur ──────────────────────────────────────────────────

class _OrganizerReply extends StatelessWidget {
  final String reply;
  final DateTime? replyAt;
  const _OrganizerReply({required this.reply, this.replyAt});

  String _relativeDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return "aujourd'hui";
    if (diff.inDays == 1) return 'il y a 1 jour';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} jours';
    if (diff.inDays < 14) return 'il y a 1 semaine';
    return 'il y a ${diff.inDays ~/ 7} semaines';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(Radii.button),
        border: Border.all(color: kPrimary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                gradient: trackpartyGradient,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('RÉPONSE',
                style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white)),
            ),
            const SizedBox(width: 8),
            Text('Organisateur',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.tpInkSub)),
            if (replyAt != null) ...[
              Text(' · ${_relativeDate(replyAt!)}',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: context.tpInkMute)),
            ],
          ]),
          const SizedBox(height: 6),
          Text(reply,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: context.tpInk, height: 1.4)),
        ],
      ),
    );
  }
}

// ── Bottom sheet de réponse ────────────────────────────────────────────────────

class _ReplySheet extends StatefulWidget {
  final String reviewerName;
  final TextEditingController ctrl;
  final Future<void> Function(String reply) onSubmit;

  const _ReplySheet({
    required this.reviewerName,
    required this.ctrl,
    required this.onSubmit,
  });

  @override
  State<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends State<_ReplySheet> {
  bool _loading = false;

  Future<void> _submit() async {
    final text = widget.ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _loading = true);
    try {
      await widget.onSubmit(text);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, Sp.md + bottom),
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.cardLg)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: context.tpHair, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text('Répondre à ${widget.reviewerName}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: context.tpInk)),
          const SizedBox(height: 4),
          Text('Votre réponse sera visible par tous les visiteurs.',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.tpInkSub)),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: context.tpBg,
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(color: context.tpHair),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: TextField(
              controller: widget.ctrl,
              autofocus: true,
              maxLines: 4,
              maxLength: 500,
              onChanged: (_) => setState(() {}),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.tpInk),
              decoration: InputDecoration(
                hintText: 'Merci pour votre avis…',
                hintStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.tpInkMute),
                border: InputBorder.none,
                counterStyle: TextStyle(fontSize: 10, color: context.tpInkMute),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: Semantics(
              button: true, label: 'Publier la réponse',
              child: GestureDetector(
              onTap: _loading || widget.ctrl.text.trim().isEmpty ? null : _submit,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: widget.ctrl.text.trim().isEmpty ? null : trackpartyGradient,
                  color: widget.ctrl.text.trim().isEmpty ? context.tpHair : null,
                  borderRadius: BorderRadius.circular(Radii.button),
                  boxShadow: widget.ctrl.text.trim().isNotEmpty ? Shadows.brand : null,
                ),
                child: Center(
                  child: _loading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Publier la réponse',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: widget.ctrl.text.trim().isEmpty
                                ? context.tpInkMute : Colors.white,
                          )),
                ),
              ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_avatar.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ReviewsScreen extends StatefulWidget {
  final String promoterId;
  const ReviewsScreen({super.key, required this.promoterId});
  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  int _filter = 0;
  static const _filters = ['Tous (128)', '5 étoiles', 'Ambiance', 'Boissons'];

  static const _distribution = [(5, 78), (4, 16), (3, 4), (2, 1), (1, 1)];

  static const _reviews = [
    _Review(
      name: 'Awa Coulibaly', rating: 5, date: 'il y a 3 jours',
      event: 'Afro Sunset Rooftop',
      text: "Sunset incroyable, sets afrobeats au top. La vue sur le Plateau était dingue 🌅 Karim a tout géré au millimètre.",
      tags: ['🎵 Ambiance', '🍾 Boissons', '👥 Monde sympa'],
      likes: 12,
      reply: "Merci Awa 🙏 c'est ce genre de retour qui me motive. À très vite pour la prochaine ✨",
      replyDate: 'il y a 2 jours',
    ),
    _Review(
      name: 'Marc K.', rating: 5, date: 'il y a 1 semaine',
      event: 'Beach Day Assinie',
      text: "Beach day parfait. Organisation au top, le bus à l'heure, l'ambiance qui monte d'un cran à chaque heure.",
      tags: ['📍 Lieu', '⏰ Ponctualité'],
      likes: 8,
    ),
    _Review(
      name: 'Cyril Adingra', rating: 4, date: 'il y a 2 semaines',
      event: 'Vinyl Night Plateau',
      text: "Très belle soirée, juste un peu trop monde sur la fin. Le set était excellent par contre 🎶",
      tags: ['🎵 Ambiance'],
      likes: 3,
      reply: "Bien noté Cyril, on va capper à 40 personnes pour le prochain Vinyl Night 👌",
      replyDate: 'il y a 2 semaines',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tpBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildNav(context),
            Expanded(
              child: ListView(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 20),
                children: [
                  _buildSummary(context),
                  _buildFilters(context),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Sp.md),
                    child: Column(
                      children: _reviews.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ReviewCard(review: r),
                      )).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNav(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, 8),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Retour',
            child: GestureDetector(
              onTap: () => context.pop(),
              child: Container(width: 44, height: 44,
                decoration: BoxDecoration(color: context.tpCard, borderRadius: BorderRadius.circular(12), boxShadow: Shadows.sm),
                child: Icon(PhosphorIcons.caretLeft(), color: context.tpInk, size: 18)),
            ),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Avis · Karim Diallo',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: context.tpInk, letterSpacing: -0.4)),
            Text('128 avis · Promoteur Or',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.tpInkSub)),
          ]),
        ],
      ),
    );
  }

  Widget _buildSummary(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 8, Sp.md, 0),
      child: Container(
        padding: const EdgeInsets.all(Sp.md),
        decoration: BoxDecoration(color: context.tpCard, borderRadius: BorderRadius.circular(20), boxShadow: Shadows.md),
        child: Row(
          children: [
            // Big rating
            Column(children: [
              Text('4.8',
                style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: context.tpInk, letterSpacing: -1.5, height: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: List.generate(5, (i) => Icon(PhosphorIcons.star(PhosphorIconsStyle.fill),
                    size: 12, color: i < 4 ? kWarning : kWarning.withValues(alpha: 0.30))),
                ),
              ),
              Text('128 avis',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: context.tpInkSub)),
            ]),
            const SizedBox(width: Sp.md),
            // Distribution
            Expanded(
              child: Column(
                children: _distribution.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    Text('${d.$1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: context.tpInkSub)),
                    const SizedBox(width: 4),
                    Icon(PhosphorIcons.star(PhosphorIconsStyle.fill), size: 10, color: kWarning),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: d.$2 / 100,
                          backgroundColor: context.tpHair,
                          valueColor: AlwaysStoppedAnimation(
                            d.$1 >= 4 ? kWarning : d.$1 >= 3 ? context.tpInkMute : kError),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(width: 28,
                      child: Text('${d.$2}%',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: context.tpInkSub))),
                  ]),
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 14, Sp.md, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_filters.length, (i) {
            final active = i == _filter;
            return Semantics(
              label: _filters[i],
              selected: active,
              button: true,
              child: GestureDetector(
                onTap: () => setState(() => _filter = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: EdgeInsets.only(right: i < _filters.length - 1 ? 8 : 0),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: active ? trackpartyGradient : null,
                    color: active ? null : context.tpCard,
                    borderRadius: BorderRadius.circular(12),
                    border: active ? null : Border.all(color: context.tpHair),
                    boxShadow: active ? [const BoxShadow(color: Color(0x407C3AED), blurRadius: 10)] : null,
                  ),
                  child: Text(_filters[i],
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

class _Review {
  final String name, event, text, date;
  final int rating, likes;
  final List<String> tags;
  final String? reply, replyDate;
  const _Review({required this.name, required this.rating, required this.date,
    required this.event, required this.text, required this.tags,
    required this.likes, this.reply, this.replyDate});
}

class _ReviewCard extends StatelessWidget {
  final _Review review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: Shadows.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author
          Row(children: [
            TpAvatar(name: review.name, size: 40),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(review.name,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: context.tpInk)),
              const SizedBox(height: 2),
              Row(children: [
                ...List.generate(5, (i) => Icon(PhosphorIcons.star(PhosphorIconsStyle.fill),
                  size: 11, color: i < review.rating ? kWarning : kWarning.withValues(alpha: 0.25))),
                const SizedBox(width: 4),
                Text('· ${review.date}',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: context.tpInkMute)),
              ]),
            ])),
          ]),
          const SizedBox(height: 8),
          // Event badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(gradient: gradientSoft, borderRadius: BorderRadius.circular(8)),
            child: Text('📍 ${review.event}',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kPrimary)),
          ),
          const SizedBox(height: 8),
          Text(review.text,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.tpInk, height: 1.45)),
          if (review.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: review.tags.map((t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(color: context.tpBg, borderRadius: BorderRadius.circular(999)),
              child: Text(t, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: context.tpInk)),
            )).toList()),
          ],
          const SizedBox(height: 10),
          // Actions
          Row(children: [
            Icon(PhosphorIcons.heart(), color: context.tpInkSub, size: 14),
            const SizedBox(width: 4),
            Text('${review.likes}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: context.tpInkSub)),
            const SizedBox(width: 14),
            Icon(PhosphorIcons.chatCircle(), color: context.tpInkSub, size: 14),
            const SizedBox(width: 4),
            Text('Répondre',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: context.tpInkSub)),
          ]),
          // Promoter reply
          if (review.reply != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: gradientSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kPrimary.withValues(alpha: 0.10)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const TpAvatar(name: 'Karim D', size: 24),
                  const SizedBox(width: 6),
                  Text('Karim Diallo',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: context.tpInk)),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(gradient: trackpartyGradient, borderRadius: BorderRadius.circular(4)),
                    child: const Text('★', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 4),
                  Text('· ${review.replyDate}',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: context.tpInkMute)),
                ]),
                const SizedBox(height: 6),
                Text(review.reply!,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.tpInk, height: 1.45)),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

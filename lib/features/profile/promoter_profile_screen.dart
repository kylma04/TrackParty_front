import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/promoter_service.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_avatar.dart';
import 'trust_score_sheet.dart';
import 'report_sheet.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class PromoterProfileScreen extends ConsumerStatefulWidget {
  final String id;
  const PromoterProfileScreen({super.key, required this.id});
  @override
  ConsumerState<PromoterProfileScreen> createState() => _PromoterProfileScreenState();
}

class _PromoterProfileScreenState extends ConsumerState<PromoterProfileScreen> {
  bool _following      = false;
  bool _followLoading  = false;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _loadFollowState();
  }

  Future<void> _loadFollowState() async {
    try {
      final following = await ref.read(promoterServiceProvider).isFollowing(widget.id);
      if (mounted) setState(() => _following = following);
    } catch (_) {}
  }

  Future<void> _toggleFollow() async {
    if (_followLoading) return;
    setState(() => _followLoading = true);
    try {
      final svc = ref.read(promoterServiceProvider);
      if (_following) {
        await svc.unfollow(widget.id);
      } else {
        await svc.follow(widget.id);
      }
      setState(() => _following = !_following);
    } catch (_) {} finally {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  static const _events = [
    ('Afro Sunset Rooftop', 'Sam 24 Mai · 21h', 47, 'soirée'),
    ('Beach Day Assinie',    'Dim 1 Juin · 14h',  92, 'plage'),
    ('Vinyl Night · Plateau','Sam 7 Juin · 22h',  28, 'musique'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tpBg,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context),
            _buildStatsCard(context),
            _buildCtas(context),
            _buildBio(context),
            _buildTabs(context),
            _buildContent(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SizedBox(
      height: 320,
      child: Stack(
        children: [
          // Gradient background
          Container(
            height: 320,
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [kPrimary, kSecondary, kTertiary]),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
            ),
            child: Stack(children: [
              Positioned(top: -60, right: -40,
                child: Container(width: 200, height: 200, decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [Colors.white.withValues(alpha: 0.18), Colors.transparent])))),
              Positioned(bottom: -40, left: -40,
                child: Container(width: 220, height: 220, decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [kAccent.withValues(alpha: 0.32), Colors.transparent])))),
            ]),
          ),
          // Controls
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Semantics(
                    button: true,
                    label: 'Retour',
                    child: _GlassBtn(icon: PhosphorIcons.caretLeft(), onTap: () => context.pop()),
                  ),
                  Semantics(
                    button: true,
                    label: 'Signaler ce profil',
                    child: _GlassBtn(
                      icon: PhosphorIcons.dotsThreeVertical(),
                      onTap: () => ReportSheet.show(context, targetType: 'user', targetId: widget.id, blockUserId: widget.id),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Avatar + name
          Positioned(
            top: 110, left: 0, right: 0,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  child: const TpAvatar(name: 'Karim Diallo', size: 104, ringColor: Colors.white),
                ),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('Karim Diallo',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: coralGradient,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('★ Promoteur', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ]),
                const SizedBox(height: 8),
                // Rating pill glass
                Semantics(
                  button: true,
                  label: 'Voir le score de confiance',
                  child: GestureDetector(
                    onTap: () => TrustScoreSheet.show(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        ...List.generate(4, (_) => Icon(PhosphorIcons.star(PhosphorIconsStyle.fill), color: kWarning, size: 12)),
                        Icon(PhosphorIcons.star(PhosphorIconsStyle.fill), color: Colors.white38, size: 12),
                        const SizedBox(width: 6),
                        const Text('4.8', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                        const SizedBox(width: 4),
                        Text('· Promoteur Or', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.85))),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(Sp.md, -32, Sp.md, 0),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: BorderRadius.circular(22),
        boxShadow: Shadows.lg,
      ),
      child: Row(
        children: [
          _Stat(n: '38',   l: 'Événements'),
          Container(width: 1, height: 40, color: context.tpHair),
          _Stat(n: '2.4K', l: 'Participants'),
          Container(width: 1, height: 40, color: context.tpHair),
          _Stat(n: '847',  l: 'Abonnés'),
        ],
      ),
    );
  }

  Widget _buildCtas(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 16, Sp.md, 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: _following ? 'Se désabonner de Karim Diallo' : 'Suivre Karim Diallo',
              child: GestureDetector(
                onTap: _toggleFollow,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: _following ? null : trackpartyGradient,
                    color: _following ? context.tpCard : null,
                    borderRadius: BorderRadius.circular(14),
                    border: _following ? Border.all(color: context.tpHair) : null,
                    boxShadow: _following ? null : Shadows.brand,
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(_following ? PhosphorIcons.check() : PhosphorIcons.plus(),
                      color: _following ? kPrimary : Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(_following ? 'Abonné ✓' : 'Suivre',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                          color: _following ? kPrimary : Colors.white)),
                  ]),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              button: true,
              label: 'Envoyer un message à Karim Diallo',
              child: GestureDetector(
                onTap: () => context.push('/chat/1'),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: context.tpCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kPrimary, width: 2),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(PhosphorIcons.chatCircle(), color: kPrimary, size: 18),
                    SizedBox(width: 6),
                    Text('Message', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kPrimary)),
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBio(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 4, Sp.md, 16),
      child: Text(
        'Promoteur depuis 2022 · Rooftops, beach parties & afrobeats nights à Abidjan. #TrackParty',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.tpInkSub, height: 1.45),
      ),
    );
  }

  Widget _buildTabs(BuildContext context) {
    final tabs = [('À venir', 4), ('Passés', 34), ('Avis', 128)];
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.tpHair))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Sp.md),
        child: Row(
          children: List.generate(tabs.length, (i) {
            final active = i == _tab;
            return Expanded(
              child: Semantics(
                label: tabs[i].$1,
                selected: active,
                button: true,
                child: GestureDetector(
                  onTap: () => setState(() => _tab = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(
                        color: active ? kPrimary : Colors.transparent, width: 3)),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(tabs[i].$1,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                            color: active ? kPrimary : context.tpInkSub)),
                      const SizedBox(width: 4),
                      Text('${tabs[i].$2}',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: context.tpInkMute)),
                    ]),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_tab == 2) {
      return Semantics(
        button: true,
        label: 'Voir tous les avis de Karim Diallo',
        child: GestureDetector(
          onTap: () => context.push('/promoter/${widget.id}/reviews'),
          child: Padding(
            padding: const EdgeInsets.all(Sp.md),
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                gradient: gradientSoft, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kPrimary.withValues(alpha: 0.2)),
              ),
              alignment: Alignment.center,
              child: const Text('Voir tous les avis →',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kPrimary)),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(Sp.md),
      child: Column(
        children: _events.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _MiniEventRow(title: e.$1, date: e.$2, going: e.$3, cat: e.$4),
        )).toList(),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
class _GlassBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    ),
  );
}

class _Stat extends StatelessWidget {
  final String n, l;
  const _Stat({required this.n, required this.l});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Text(n, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: context.tpInk, letterSpacing: -0.6)),
      const SizedBox(height: 1),
      Text(l, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.tpInkSub)),
    ]),
  );
}

class _MiniEventRow extends StatelessWidget {
  final String title, date, cat;
  final int going;
  const _MiniEventRow({required this.title, required this.date, required this.going, required this.cat});

  static const _colors = {'soirée': Color(0xFFEC4899), 'plage': Color(0xFFF59E0B), 'musique': Color(0xFF7C3AED)};
  static const _emojis = {'soirée': '🎉', 'plage': '🏖', 'musique': '🎵'};

  @override
  Widget build(BuildContext context) {
    final color = _colors[cat] ?? kPrimary;
    final emoji = _emojis[cat] ?? '🎉';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: context.tpCard, borderRadius: BorderRadius.circular(18), boxShadow: Shadows.sm),
      child: Row(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Stack(children: [
              Center(child: Text(emoji, style: const TextStyle(fontSize: 28))),
              Positioned(top: 4, left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(6)),
                  child: Text(emoji, style: const TextStyle(fontSize: 8)),
                )),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: context.tpInk, letterSpacing: -0.3)),
              const SizedBox(height: 3),
              Text('$date · $going viennent',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.tpInkSub)),
            ]),
          ),
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: kPrimary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
            child: Icon(PhosphorIcons.caretRight(), color: kPrimary, size: 20),
          ),
        ],
      ),
    );
  }
}

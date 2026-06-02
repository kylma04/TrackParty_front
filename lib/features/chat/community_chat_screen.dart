import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_avatar.dart';


class CommunityChatScreen extends StatelessWidget {
  final String promoterId;
  const CommunityChatScreen({super.key, required this.promoterId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tpBg,
      body: Column(
        children: [
          _buildHeader(context),
          _buildReadOnlyBanner(),
          Expanded(child: _buildContent(context)),
          _buildComposer(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: trackpartyGradient),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // Orbe décoratif
            Positioned(
              top: -40, right: -40,
              child: Container(
                width: 160, height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [Colors.white.withValues(alpha: 0.15), Colors.transparent]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.md, 8, Sp.md, 12),
              child: Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'Retour',
                    child: GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.chevron_left, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Group avatar
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                    ),
                    child: Icon(Icons.group_outlined, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Text("Karim's Crew",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900,
                                color: Colors.white, letterSpacing: -0.3)),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('★', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w900)),
                          ),
                        ]),
                        Text('847 membres · Communauté publique',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.85))),
                      ],
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Plus d\'options',
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.more_vert, color: Colors.white, size: 20),
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

  Widget _buildReadOnlyBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 10, Sp.md, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF6E8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x55F59E0B)),
        ),
        child: const Row(
          children: [
            Text('🔔', style: TextStyle(fontSize: 14)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Lecture seule · Seul Karim et les co-admins peuvent poster. Tu peux réagir et commenter.',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: Color(0xFF8A6515), height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.md),
      children: [
        // Day separator
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: context.tpHair, borderRadius: BorderRadius.circular(999)),
            child: Text("Aujourd'hui · 14h",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: context.tpInkSub)),
          ),
        ),
        const SizedBox(height: 12),
        // Post 1
        _CommunityPost(
          author: 'Karim Diallo',
          time: '14:02',
          text: "Yo la team 👋 Ce samedi on remet ça au Rooftop K8 ! Vibes Afro Sunset comme d'hab, on vise les 80 personnes 🌅",
          showMedia: true,
          caption: 'Rooftop K8 · Plateau · Sam 24 Mai',
          reactions: const [('🔥', 42), ('❤️', 28), ('🎉', 19)],
          comments: 12,
        ),
        const SizedBox(height: 8),
        // Member comments
        _MemberComment(name: 'Awa Coulibaly', text: 'Présente 🙌 j\'apporte le garba aussi pour les affamés'),
        _MemberComment(name: 'Marc K.', text: 'J\'arrive avec deux potes 🎵'),
        const SizedBox(height: 12),
        // Post 2
        _CommunityPost(
          author: 'Karim Diallo',
          time: '12:30',
          text: '📸 Petit retour sur le dernier Beach Day Assinie — merci à vous tous pour cette ambiance 🌊',
          showMedia: true,
          reactions: const [('❤️', 156), ('🔥', 89), ('🏖', 34)],
          comments: 48,
        ),
      ],
    );
  }

  Widget _buildComposer(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(Sp.md, 10, Sp.md,
          10 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: context.tpCard,
        border: Border(top: BorderSide(color: context.tpHair)),
      ),
      child: Row(
        children: [
          const TpAvatar(name: 'Abby K', size: 36),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(color: context.tpBg, borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Commenter…',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.tpInkMute)),
                  ),
                  const Text('😊', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(gradient: trackpartyGradient, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.send_outlined, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }
}

// ── Community Post ────────────────────────────────────────────────────────────
class _CommunityPost extends StatelessWidget {
  final String author, time, text;
  final bool showMedia;
  final String? caption;
  final List<(String, int)> reactions;
  final int comments;

  const _CommunityPost({
    required this.author, required this.time, required this.text,
    this.showMedia = false, this.caption, required this.reactions, required this.comments,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: Shadows.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author row
          Row(
            children: [
              TpAvatar(name: author, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(author,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: context.tpInk)),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(gradient: trackpartyGradient, borderRadius: BorderRadius.circular(4)),
                        child: const Text('★', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: kPrimary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Admin',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kPrimary)),
                      ),
                    ]),
                    Text(time,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: context.tpInkMute)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Text
          Text(text,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.tpInk, height: 1.45)),
          if (showMedia) ...[
            const SizedBox(height: 10),
            Stack(
              children: [
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    gradient: coralGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                if (caption != null)
                  Positioned(
                    bottom: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('📍 $caption',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          // Reactions + comments
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: reactions.map((r) => Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: context.tpBg, borderRadius: BorderRadius.circular(999)),
                  child: Text('${r.$1} ${r.$2}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: context.tpInk)),
                )).toList(),
              ),
              Row(
                children: [
                  Icon(Icons.chat_bubble_outline, color: context.tpInkSub, size: 14),
                  const SizedBox(width: 4),
                  Text('$comments',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: context.tpInkSub)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Member comment ────────────────────────────────────────────────────────────
class _MemberComment extends StatelessWidget {
  final String name, text;
  const _MemberComment({required this.name, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 0, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TpAvatar(name: name, size: 32),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: context.tpCard,
                borderRadius: BorderRadius.circular(16),
                boxShadow: Shadows.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: context.tpInk)),
                  const SizedBox(height: 1),
                  Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.tpInk, height: 1.4)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

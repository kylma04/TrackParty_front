import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/theme_ext.dart';

// ── Wrapper shimmer ───────────────────────────────────────────────────────────

class TpShimmer extends StatelessWidget {
  final Widget child;
  const TpShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor:      isDark ? const Color(0xFF1E2240) : const Color(0xFFE8E8EE),
      highlightColor: isDark ? const Color(0xFF2A2F50) : const Color(0xFFF5F5FA),
      child: child,
    );
  }
}

// ── Primitives ────────────────────────────────────────────────────────────────

class SkBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double radius;

  const SkBox({super.key, this.width, this.height, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height ?? 14,
      decoration: BoxDecoration(
        color: context.tpHair,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class SkLine extends StatelessWidget {
  final double? width;
  final double height;

  const SkLine({super.key, this.width, this.height = 12});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.tpHair,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }
}

class SkCircle extends StatelessWidget {
  final double size;
  const SkCircle({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: context.tpHair,
        shape: BoxShape.circle,
      ),
    );
  }
}

// ── Skeletons composites ──────────────────────────────────────────────────────

/// Ligne conversation (chat_list, notifications)
class SkRowItem extends StatelessWidget {
  final double avatarSize;
  final int lines;
  const SkRowItem({super.key, this.avatarSize = 52, this.lines = 2});

  @override
  Widget build(BuildContext context) {
    return TpShimmer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          SkCircle(size: avatarSize),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkLine(width: 140),
                if (lines >= 2) ...[
                  const SizedBox(height: 8),
                  SkLine(height: 10),
                ],
                if (lines >= 3) ...[
                  const SizedBox(height: 6),
                  SkLine(width: 80, height: 10),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          SkLine(width: 40, height: 10),
        ]),
      ),
    );
  }
}

/// Carte événement verticale (tickets, listes)
class SkEventCard extends StatelessWidget {
  const SkEventCard({super.key});

  @override
  Widget build(BuildContext context) {
    return TpShimmer(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: context.tpCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SkBox(width: double.infinity, height: 120, radius: 16),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SkLine(width: 180),
              const SizedBox(height: 8),
              SkLine(width: 120, height: 10),
              const SizedBox(height: 6),
              SkLine(width: 90, height: 10),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Header profil (promoter / my_profile)
class SkProfileHeader extends StatelessWidget {
  const SkProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return TpShimmer(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SkBox(width: double.infinity, height: 180, radius: 0),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SkLine(width: 160, height: 18),
            const SizedBox(height: 8),
            SkLine(width: 100, height: 12),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: SkBox(height: 52, radius: 12)),
              const SizedBox(width: 10),
              Expanded(child: SkBox(height: 52, radius: 12)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

/// Header écran détail événement
class SkEventDetail extends StatelessWidget {
  const SkEventDetail({super.key});

  @override
  Widget build(BuildContext context) {
    return TpShimmer(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SkBox(width: double.infinity, height: 340, radius: 0),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SkLine(height: 22),
            const SizedBox(height: 12),
            SkLine(width: 200, height: 14),
            const SizedBox(height: 20),
            Row(children: [
              SkCircle(size: 44),
              const SizedBox(width: 8),
              SkCircle(size: 44),
              const SizedBox(width: 8),
              SkCircle(size: 44),
            ]),
            const SizedBox(height: 24),
            SkBox(width: double.infinity, height: 52, radius: 14),
          ]),
        ),
      ]),
    );
  }
}

/// Liste de skeletons (répète un builder N fois)
class SkList extends StatelessWidget {
  final int count;
  final Widget Function(int) builder;

  const SkList({super.key, this.count = 5, required this.builder});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: count,
      itemBuilder: (_, i) => builder(i),
    );
  }
}

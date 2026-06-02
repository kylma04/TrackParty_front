import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/gradients.dart';
import '../theme/spacing.dart';
import '../theme/theme_ext.dart';

enum TpBadgeVariant { category, contrib, promoter, custom }

class TpBadge extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color backgroundColor;
  final Gradient? gradient;
  final String? emoji;

  const TpBadge({
    super.key,
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    this.gradient,
    this.emoji,
  });

  factory TpBadge.category(String category) {
    final styles = _categoryStyles[category.toLowerCase()] ??
        (bg: const Color(0xFFF3F4F6), text: kInkSubLight, emoji: '🎉');
    return TpBadge(
      label: category,
      textColor: styles.text,
      backgroundColor: styles.bg,
      emoji: styles.emoji,
    );
  }

  factory TpBadge.contrib(String type) {
    return switch (type.toLowerCase()) {
      'gratuit' => const TpBadge(
          label: 'Gratuit',
          textColor: kContribFreeText,
          backgroundColor: kContribFreeBg,
          emoji: '💸',
        ),
      'en nature' => const TpBadge(
          label: 'En nature',
          textColor: kContribNatureText,
          backgroundColor: kContribNatureBg,
          emoji: '🎁',
        ),
      'payant' => const TpBadge(
          label: 'Payant',
          textColor: kContribPaidText,
          backgroundColor: kContribPaidBg,
          emoji: '💰',
        ),
      _ => const TpBadge(
          label: 'Gratuit',
          textColor: kContribFreeText,
          backgroundColor: kContribFreeBg,
        ),
    };
  }

  factory TpBadge.promoter() {
    return const TpBadge(
      label: 'Promoteur',
      textColor: Colors.white,
      backgroundColor: Colors.transparent,
      gradient: trackpartyGradient,
    );
  }

  static const _categoryStyles = <String, ({Color bg, Color text, String emoji})>{
    'musique': (bg: Color(0xFFF3E8FF), text: Color(0xFF7C3AED), emoji: '🎵'),
    'soirée': (bg: Color(0xFFFCE7F3), text: Color(0xFFDB2777), emoji: '🎉'),
    'cuisine': (bg: Color(0xFFFFF7ED), text: Color(0xFFEA580C), emoji: '🍽'),
    'sport': (bg: Color(0xFFECFEFF), text: Color(0xFF0891B2), emoji: '⚽'),
    'art': (bg: Color(0xFFF0FDF4), text: Color(0xFF16A34A), emoji: '🎨'),
    'plage': (bg: Color(0xFFFFFBEB), text: Color(0xFFD97706), emoji: '🏖'),
  };

  @override
  Widget build(BuildContext context) {
    // In dark mode, use a 15% tint of the text color as background so pastel
    // light-mode badges don't look washed out on dark surfaces.
    final effectiveBg = gradient != null
        ? null
        : context.isDark
            ? textColor.withValues(alpha: 0.15)
            : backgroundColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: effectiveBg,
        gradient: gradient,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji != null) ...[
            Text(emoji!, style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 4),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: textColor,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

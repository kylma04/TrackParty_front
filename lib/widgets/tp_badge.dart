import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/theme_ext.dart';
import 'tp_icons.dart';

enum TpBadgeVariant { category, contrib, promoter, custom }

const _kWarningBg = Color(0xFFFFF3E0);

class TpBadge extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color backgroundColor;
  final Gradient? gradient;
  final String? emoji;
  final IconData? icon;

  const TpBadge({
    super.key,
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    this.gradient,
    this.emoji,
    this.icon,
  });

  factory TpBadge.category(String category) {
    final meta = tpCategoryMeta(category);
    return TpBadge(
      label: category,
      textColor: meta.color,
      backgroundColor: meta.lightBg,
      icon: meta.icon,
    );
  }

  /// Badge de catégorie d'événement : affiche le libellé fourni et privilégie
  /// l'icône vectorielle TrackParty (tout en conservant l'emoji saisi par le
  /// promoteur sur la catégorie personnalisée « autre » s'il diffère de `✨`).
  factory TpBadge.eventCategory({
    required String category,
    required String label,
    String? emoji,
  }) {
    final norm = normalizeTpCategory(category);
    final meta = tpCategoryMeta(norm);
    final useCustomEmoji = norm == 'autre' && hasCustomUserEmoji(emoji);
    return TpBadge(
      label: label,
      textColor: meta.color,
      backgroundColor: meta.lightBg,
      emoji: useCustomEmoji ? emoji!.trim() : null,
      icon: useCustomEmoji ? null : meta.icon,
    );
  }

  factory TpBadge.contrib(String type) {
    return switch (type.toLowerCase()) {
      'payant' || 'monetaire' => TpBadge(
        label: 'Payant',
        textColor: kContribPaidText,
        backgroundColor: kContribPaidBg,
        icon: PhosphorIcons.coins(PhosphorIconsStyle.fill),
      ),
      _ => TpBadge(
        label: 'Gratuit',
        textColor: kContribFreeText,
        backgroundColor: kContribFreeBg,
        icon: PhosphorIcons.ticket(PhosphorIconsStyle.fill),
      ),
    };
  }

  factory TpBadge.visibility(bool isPrivate) {
    return isPrivate
        ? TpBadge(
            label: 'Privé',
            textColor: kWarning,
            backgroundColor: _kWarningBg,
            icon: PhosphorIcons.lockSimple(PhosphorIconsStyle.fill),
          )
        : TpBadge(
            label: 'Public',
            textColor: kContribFreeText,
            backgroundColor: kContribFreeBg,
            icon: PhosphorIcons.globeSimple(PhosphorIconsStyle.fill),
          );
  }

  factory TpBadge.promoter() {
    return TpBadge(
      label: 'Promoteur',
      textColor: Colors.white,
      backgroundColor: kPrimary,
      icon: PhosphorIcons.megaphoneSimple(PhosphorIconsStyle.fill),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBg = gradient != null
        ? null
        : context.isDark
        ? textColor.withValues(alpha: 0.16)
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
          if (icon != null) ...[
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
          ] else if (emoji != null && emoji!.isNotEmpty) ...[
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

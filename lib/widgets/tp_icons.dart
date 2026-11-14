import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/colors.dart';

/// Métadonnées graphiques officielles d'une catégorie TrackParty.
class TpCategoryMeta {
  final String id;
  final String label;
  final Color color;
  final Color lightBg;
  final IconData icon;
  final IconData outlineIcon;

  const TpCategoryMeta({
    required this.id,
    required this.label,
    required this.color,
    required this.lightBg,
    required this.icon,
    required this.outlineIcon,
  });
}

/// Normalise les variantes d'identifiants de catégories (accents, casse, alias).
String normalizeTpCategory(String raw) {
  final k = raw.trim().toLowerCase();
  return switch (k) {
    'musique' || 'music' => 'musique',
    'soirée' || 'soiree' || 'party' => 'soiree',
    'cuisine' || 'food' => 'cuisine',
    'sport' || 'sports' => 'sport',
    'art' || 'culture' => 'art',
    'plage' || 'beach' => 'plage',
    'tech' => 'tech',
    'business' => 'business',
    _ => 'autre',
  };
}

/// Table centralisée des catégories TrackParty (remplace les emojis système).
final Map<String, TpCategoryMeta> tpCategoryRegistry = {
  'musique': TpCategoryMeta(
    id: 'musique',
    label: 'Musique',
    color: kCategoryMusic,
    lightBg: const Color(0xFFEDEEFC),
    icon: PhosphorIcons.musicNotes(PhosphorIconsStyle.fill),
    outlineIcon: PhosphorIcons.musicNotes(),
  ),
  'soiree': TpCategoryMeta(
    id: 'soiree',
    label: 'Soirée',
    color: kCategoryParty,
    lightBg: const Color(0xFFFFEDE8),
    icon: PhosphorIcons.discoBall(PhosphorIconsStyle.fill),
    outlineIcon: PhosphorIcons.discoBall(),
  ),
  'cuisine': TpCategoryMeta(
    id: 'cuisine',
    label: 'Cuisine',
    color: kCategoryFood,
    lightBg: const Color(0xFFFEF3E6),
    icon: PhosphorIcons.forkKnife(PhosphorIconsStyle.fill),
    outlineIcon: PhosphorIcons.forkKnife(),
  ),
  'sport': TpCategoryMeta(
    id: 'sport',
    label: 'Sport',
    color: kCategorySport,
    lightBg: const Color(0xFFE6F7F7),
    icon: PhosphorIcons.basketball(PhosphorIconsStyle.fill),
    outlineIcon: PhosphorIcons.basketball(),
  ),
  'art': TpCategoryMeta(
    id: 'art',
    label: 'Art',
    color: kCategoryArt,
    lightBg: const Color(0xFFF0F9E8),
    icon: PhosphorIcons.palette(PhosphorIconsStyle.fill),
    outlineIcon: PhosphorIcons.palette(),
  ),
  'plage': TpCategoryMeta(
    id: 'plage',
    label: 'Plage',
    color: kCategoryBeach,
    lightBg: const Color(0xFFEAF1FE),
    icon: PhosphorIcons.sunHorizon(PhosphorIconsStyle.fill),
    outlineIcon: PhosphorIcons.sunHorizon(),
  ),
  'tech': TpCategoryMeta(
    id: 'tech',
    label: 'Tech',
    color: const Color(0xFF0284C7),
    lightBg: const Color(0xFFE0F2FE),
    icon: PhosphorIcons.cpu(PhosphorIconsStyle.fill),
    outlineIcon: PhosphorIcons.cpu(),
  ),
  'business': TpCategoryMeta(
    id: 'business',
    label: 'Business',
    color: const Color(0xFF475569),
    lightBg: const Color(0xFFF1F5F9),
    icon: PhosphorIcons.briefcase(PhosphorIconsStyle.fill),
    outlineIcon: PhosphorIcons.briefcase(),
  ),
  'autre': TpCategoryMeta(
    id: 'autre',
    label: 'Autre',
    color: const Color(0xFF64748B),
    lightBg: const Color(0xFFF1F5F9),
    icon: PhosphorIcons.ticket(PhosphorIconsStyle.fill),
    outlineIcon: PhosphorIcons.ticket(),
  ),
};

/// Retourne les métadonnées vectorielles d'une catégorie (fallback sur `autre`).
TpCategoryMeta tpCategoryMeta(String category, {String? customLabel}) {
  final norm = normalizeTpCategory(category);
  final base = tpCategoryRegistry[norm] ?? tpCategoryRegistry['autre']!;
  if (norm == 'autre' && customLabel != null && customLabel.trim().isNotEmpty) {
    return TpCategoryMeta(
      id: 'autre',
      label: customLabel.trim(),
      color: base.color,
      lightBg: base.lightBg,
      icon: base.icon,
      outlineIcon: base.outlineIcon,
    );
  }
  return base;
}

/// Retourne l'icône Phosphor adaptée à la catégorie (sans emoji OS générique).
IconData tpCategoryIconData(
  String category, {
  bool filled = true,
}) {
  final meta = tpCategoryMeta(category);
  return filled ? meta.icon : meta.outlineIcon;
}

/// Indique si un emoji saisi par l'utilisateur pour « Autre » est un vrai choix
/// personnalisé (excluant les anciens fallbacks génériques `✨`).
bool hasCustomUserEmoji(String? emoji) {
  final trimmed = emoji?.trim() ?? '';
  return trimmed.isNotEmpty && trimmed != '✨';
}

/// Widget d'icône de catégorie propre : privilégie l'icône vectorielle maison,
/// tout en conservant l'emoji saisi par le créateur lorsqu'il a choisi un symbole
/// spécifique sur la catégorie « Autre ».
class TpCategoryIcon extends StatelessWidget {
  final String category;
  final String? customEmoji;
  final double size;
  final Color? color;
  final bool filled;

  const TpCategoryIcon({
    super.key,
    required this.category,
    this.customEmoji,
    this.size = 16,
    this.color,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    final norm = normalizeTpCategory(category);
    if (norm == 'autre' && hasCustomUserEmoji(customEmoji)) {
      return Text(
        customEmoji!.trim(),
        style: TextStyle(fontSize: size, height: 1.0),
      );
    }
    final meta = tpCategoryMeta(norm);
    return Icon(
      filled ? meta.icon : meta.outlineIcon,
      size: size,
      color: color ?? meta.color,
    );
  }
}

/// Icône + couleur associées aux notifications TrackParty.
(IconData, Color) tpNotificationIconMeta(String type) {
  return switch (type) {
    'new_message' => (PhosphorIcons.chatCircle(PhosphorIconsStyle.fill), kPrimary),
    'missed_call' => (PhosphorIcons.phoneX(PhosphorIconsStyle.fill), kError),
    'invitation' => (PhosphorIcons.ticket(PhosphorIconsStyle.fill), kPrimary),
    'invitation_accepted' => (PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), kSuccess),
    'event_updated' => (PhosphorIcons.pencilSimple(PhosphorIconsStyle.fill), kInfo),
    'event_cancelled' => (PhosphorIcons.prohibit(PhosphorIconsStyle.fill), kError),
    'new_follower' => (PhosphorIcons.userPlus(PhosphorIconsStyle.fill), kSecondary),
    'new_review' => (PhosphorIcons.star(PhosphorIconsStyle.fill), kWarning),
    'participation_confirmed' => (PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), kSuccess),
    'in_kind_proposal' => (PhosphorIcons.gift(PhosphorIconsStyle.fill), kWarning),
    'in_kind_accepted' => (PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), kSuccess),
    'in_kind_rejected' => (PhosphorIcons.prohibit(PhosphorIconsStyle.fill), kError),
    'broadcast' => (PhosphorIcons.megaphone(PhosphorIconsStyle.fill), kPrimary),
    _ => (PhosphorIcons.bell(PhosphorIconsStyle.fill), kPrimary),
  };
}

/// Icône et couleur pour les niveaux de promoteur / confiance.
(IconData, String, Color) tpTierMeta(String tier) {
  return switch (tier) {
    'gold' => (PhosphorIcons.trophy(PhosphorIconsStyle.fill), 'Or', kWarning),
    'silver' => (PhosphorIcons.medal(PhosphorIconsStyle.fill), 'Argent', const Color(0xFF94A3B8)),
    _ => (PhosphorIcons.medal(PhosphorIconsStyle.fill), 'Bronze', const Color(0xFFB45309)),
  };
}

/// Dessine directement sur un [ui.Canvas] (pins carte Google Maps) un pictogramme
/// vectoriel net centré sur [center] dans un carré de côté [size].
void drawTpCategoryGlyph(
  ui.Canvas canvas,
  String category,
  Offset center,
  double size,
  Color color,
) {
  final norm = normalizeTpCategory(category);
  final s = size / 24.0;
  canvas.save();
  canvas.translate(center.dx - 12 * s, center.dy - 12 * s);
  canvas.scale(s, s);

  final fill = Paint()
    ..color = color
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  final stroke = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.1
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  switch (norm) {
    case 'musique':
      // Double croche nette
      canvas.drawCircle(const Offset(7.2, 17.5), 3.0, fill);
      canvas.drawCircle(const Offset(16.8, 15.8), 3.0, fill);
      final stem = Path()
        ..moveTo(9.4, 17.5)
        ..lineTo(9.4, 6.2)
        ..lineTo(19.0, 4.4)
        ..lineTo(19.0, 15.8);
      canvas.drawPath(stem, stroke);
      canvas.drawLine(const Offset(9.4, 9.6), const Offset(19.0, 7.8), stroke);
    case 'soiree':
      // Éclat festif / boule à facettes stylisée + rayons
      canvas.drawCircle(const Offset(12, 13.2), 5.8, stroke);
      canvas.drawLine(const Offset(12, 3.0), const Offset(12, 7.4), stroke);
      canvas.drawLine(const Offset(6.2, 13.2), const Offset(17.8, 13.2), stroke);
      canvas.drawLine(const Offset(12, 7.6), const Offset(12, 18.8), stroke);
      canvas.drawCircle(const Offset(4.8, 6.8), 1.3, fill);
      canvas.drawCircle(const Offset(19.2, 6.8), 1.3, fill);
    case 'cuisine':
      // Fourchette & couteau géométriques
      canvas.drawLine(const Offset(7.5, 4.0), const Offset(7.5, 9.2), stroke);
      canvas.drawLine(const Offset(5.2, 4.0), const Offset(5.2, 8.2), stroke);
      canvas.drawLine(const Offset(9.8, 4.0), const Offset(9.8, 8.2), stroke);
      canvas.drawPath(
        Path()
          ..moveTo(5.2, 8.2)
          ..quadraticBezierTo(7.5, 10.6, 9.8, 8.2),
        stroke,
      );
      canvas.drawLine(const Offset(7.5, 10.2), const Offset(7.5, 20.0), stroke);
      final knife = Path()
        ..moveTo(16.5, 4.0)
        ..lineTo(16.5, 20.0);
      canvas.drawPath(knife, stroke);
      canvas.drawPath(
        Path()
          ..moveTo(16.5, 4.0)
          ..quadraticBezierTo(19.5, 7.0, 16.5, 12.0)
          ..close(),
        fill,
      );
    case 'sport':
      // Ballon géométrique
      canvas.drawCircle(const Offset(12, 12), 7.8, stroke);
      canvas.drawLine(const Offset(4.4, 12), const Offset(19.6, 12), stroke);
      canvas.drawPath(
        Path()
          ..moveTo(8.2, 5.2)
          ..quadraticBezierTo(11.6, 12, 8.2, 18.8),
        stroke,
      );
      canvas.drawPath(
        Path()
          ..moveTo(15.8, 5.2)
          ..quadraticBezierTo(12.4, 12, 15.8, 18.8),
        stroke,
      );
    case 'art':
      // Palette artiste stylisée
      final pal = Path()
        ..moveTo(12, 4.2)
        ..cubicTo(17.2, 4.2, 20, 7.4, 20, 11.4)
        ..cubicTo(20, 13.8, 18.2, 14.8, 16.2, 14.8)
        ..lineTo(14.5, 14.8)
        ..cubicTo(13.2, 14.8, 12.8, 15.8, 13.4, 17.0)
        ..cubicTo(14.0, 18.4, 13.0, 19.8, 11.4, 19.8)
        ..cubicTo(7.0, 19.8, 4.0, 16.2, 4.0, 11.8)
        ..cubicTo(4.0, 7.2, 7.4, 4.2, 12, 4.2)
        ..close();
      canvas.drawPath(pal, stroke);
      canvas.drawCircle(const Offset(8.4, 10.0), 1.2, fill);
      canvas.drawCircle(const Offset(11.8, 7.8), 1.2, fill);
      canvas.drawCircle(const Offset(15.6, 9.6), 1.2, fill);
    case 'plage':
      // Soleil à l'horizon + vague
      canvas.drawArc(
        Rect.fromCircle(center: const Offset(12, 13.5), radius: 4.5),
        math.pi,
        math.pi,
        false,
        stroke,
      );
      canvas.drawLine(const Offset(4.0, 13.5), const Offset(20.0, 13.5), stroke);
      canvas.drawLine(const Offset(12, 4.8), const Offset(12, 6.8), stroke);
      canvas.drawLine(const Offset(6.2, 7.4), const Offset(7.5, 8.7), stroke);
      canvas.drawLine(const Offset(17.8, 7.4), const Offset(16.5, 8.7), stroke);
      canvas.drawPath(
        Path()
          ..moveTo(4.5, 17.5)
          ..quadraticBezierTo(8.2, 15.4, 12.0, 17.5)
          ..quadraticBezierTo(15.8, 19.6, 19.5, 17.5),
        stroke,
      );
    default:
      // Ticket TrackParty simplifié pour "autre"
      final ticket = RRect.fromRectAndRadius(
        const Rect.fromLTWH(4.0, 6.8, 16.0, 10.4),
        const Radius.circular(2.4),
      );
      canvas.drawRRect(ticket, stroke);
      canvas.drawLine(const Offset(9.5, 8.2), const Offset(9.5, 15.8), stroke);
      canvas.drawCircle(const Offset(14.5, 12.0), 1.5, fill);
  }

  canvas.restore();
}

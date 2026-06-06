import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/colors.dart';
import '../theme/gradients.dart';
import '../theme/spacing.dart';
import '../theme/theme_ext.dart';
import '../widgets/tp_avatar.dart';
import '../widgets/tp_badge.dart';
import '../widgets/tp_photo.dart';

/// Affiche un aperçu de l'événement tel qu'il apparaîtra aux utilisateurs.
void showEventPreviewSheet(
  BuildContext context, {
  required String title,
  required String description,
  required String? category,
  required String? customCategoryLabel,
  required String? customCategoryEmoji,
  required String? coverUrl,
  required DateTime? startAt,
  required DateTime? endAt,
  required String addressLabel,
  required String city,
  required String quartier,
  required String visibility,
  required String contribMode,
  required int capacity,
  required String organizerName,
  required String? organizerAvatarUrl,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EventPreviewSheet(
      title: title,
      description: description,
      category: category,
      customCategoryLabel: customCategoryLabel,
      customCategoryEmoji: customCategoryEmoji,
      coverUrl: coverUrl,
      startAt: startAt,
      endAt: endAt,
      addressLabel: addressLabel,
      city: city,
      quartier: quartier,
      visibility: visibility,
      contribMode: contribMode,
      capacity: capacity,
      organizerName: organizerName,
      organizerAvatarUrl: organizerAvatarUrl,
    ),
  );
}

class _EventPreviewSheet extends StatelessWidget {
  final String title;
  final String description;
  final String? category;
  final String? customCategoryLabel;
  final String? customCategoryEmoji;
  final String? coverUrl;
  final DateTime? startAt;
  final DateTime? endAt;
  final String addressLabel;
  final String city;
  final String quartier;
  final String visibility;
  final String contribMode;
  final int capacity;
  final String organizerName;
  final String? organizerAvatarUrl;

  const _EventPreviewSheet({
    required this.title,
    required this.description,
    required this.category,
    required this.customCategoryLabel,
    required this.customCategoryEmoji,
    required this.coverUrl,
    required this.startAt,
    required this.endAt,
    required this.addressLabel,
    required this.city,
    required this.quartier,
    required this.visibility,
    required this.contribMode,
    required this.capacity,
    required this.organizerName,
    required this.organizerAvatarUrl,
  });

  String get _displayEmoji {
    if (category == 'autre' && customCategoryEmoji != null && customCategoryEmoji!.isNotEmpty) {
      return customCategoryEmoji!;
    }
    const emojis = {
      'musique': '🎵', 'soiree': '🎉', 'cuisine': '🍽',
      'sport': '⚽', 'art': '🎨', 'plage': '🏖',
    };
    return emojis[category] ?? '✨';
  }

  String get _displayCategory {
    if (category == 'autre' && customCategoryLabel != null && customCategoryLabel!.isNotEmpty) {
      return customCategoryLabel!;
    }
    const labels = {
      'musique': 'Musique', 'soiree': 'Soirée', 'cuisine': 'Cuisine',
      'sport': 'Sport', 'art': 'Art', 'plage': 'Plage', 'autre': 'Autre',
    };
    return labels[category] ?? (category ?? 'Autre');
  }

  String _fmtDate(DateTime dt) => DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(dt);
  String _fmtTime(DateTime dt) => DateFormat('HH:mm').format(dt);

  String get _contribLabel {
    return switch (contribMode) {
      'nature'    => 'Contribution nature',
      'monetaire' => 'Contribution monétaire',
      _           => 'Gratuit',
    };
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * 0.92;
    return Container(
      height: h,
      decoration: BoxDecoration(
        color: context.tpBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.cardLg)),
      ),
      child: Column(children: [
        // Handle + header
        Padding(
          padding: const EdgeInsets.fromLTRB(Sp.md, 14, Sp.md, 0),
          child: Column(children: [
            Container(width: 36, height: 4,
                decoration: BoxDecoration(color: context.tpHair, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 14),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: kAccent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(Radii.sm)),
                child: Text('APERÇU',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900,
                        color: kAccent, letterSpacing: 0.5)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Comme vu par les invités',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.tpInkSub)),
              ),
              Semantics(
                button: true, label: 'Fermer',
                child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(PhosphorIcons.x(), color: context.tpInk, size: 20),
                ),
              ),
            ]),
            const SizedBox(height: 14),
          ]),
        ),

        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 40),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

              // Cover
              SizedBox(
                height: 240,
                child: Stack(fit: StackFit.expand, children: [
                  coverUrl != null
                      ? CachedNetworkImage(
                          imageUrl: coverUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorWidget: (ctx, url, err) => const TpPhoto(),
                          placeholder: (ctx, url) => const TpPhoto(),
                        )
                      : const TpPhoto(),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.transparent, context.tpBg],
                        stops: const [0, 0.55, 1.0],
                      ),
                    ),
                  ),
                  // Badges
                  Positioned(
                    bottom: 52, left: Sp.md, right: Sp.md,
                    child: Row(children: [
                      TpBadge.category('$_displayEmoji $_displayCategory'),
                      const SizedBox(width: 6),
                      if (contribMode != 'gratuit')
                        TpBadge.contrib(_contribLabel),
                    ]),
                  ),
                  // Title in hero
                  Positioned(
                    bottom: 12, left: Sp.md, right: Sp.md,
                    child: Text(
                      title.isEmpty ? 'Titre de l\'événement' : title,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w900,
                          color: Colors.white, letterSpacing: -0.5),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ),

              // Organizer card
              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.md, 16, Sp.md, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.tpCard,
                    borderRadius: BorderRadius.circular(Radii.lg),
                    boxShadow: const [BoxShadow(color: Color(0x0D1B1A2E), blurRadius: 8)],
                  ),
                  child: Row(children: [
                    TpAvatar(name: organizerName, imageUrl: organizerAvatarUrl, size: 42),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(organizerName,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.tpInk)),
                        Text('Organisateur',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.tpInkSub)),
                      ]),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          gradient: trackpartyGradient, borderRadius: BorderRadius.circular(Radii.sm)),
                      child: const Text('Suivre',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ]),
                ),
              ),

              // Info grid
              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.md, 16, Sp.md, 0),
                child: Column(children: [
                  _InfoRow(
                    icon: PhosphorIcons.calendarBlank(PhosphorIconsStyle.fill),
                    iconColor: kPrimary,
                    title: startAt != null ? _fmtDate(startAt!) : 'Date à définir',
                    sub: startAt != null
                        ? 'à ${_fmtTime(startAt!)}${endAt != null ? ' · fin ${_fmtTime(endAt!)}' : ''}'
                        : '',
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
                    iconColor: kTertiary,
                    title: addressLabel.isNotEmpty ? addressLabel : 'Lieu à définir',
                    sub: [quartier, city].where((s) => s.isNotEmpty).join(', '),
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: PhosphorIcons.usersThree(PhosphorIconsStyle.fill),
                    iconColor: kAccent,
                    title: '$capacity places',
                    sub: visibility == 'private' ? 'Événement privé' : 'Événement public',
                  ),
                ]),
              ),

              // Description
              if (description.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(Sp.md, 20, Sp.md, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('À propos',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: context.tpInk)),
                    const SizedBox(height: 8),
                    Text(description,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                            color: context.tpInkSub, height: 1.5)),
                  ]),
                ),
              ],

              const SizedBox(height: 20),
              // CTA preview (non-functional)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Sp.md),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: trackpartyGradient,
                    borderRadius: BorderRadius.circular(Radii.lg),
                    boxShadow: [BoxShadow(
                        color: kPrimary.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('Participer', style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String sub;
  const _InfoRow({required this.icon, required this.iconColor, required this.title, required this.sub});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(Radii.button)),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.tpInk)),
          if (sub.isNotEmpty)
            Text(sub, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.tpInkSub)),
        ])),
      ]);
}

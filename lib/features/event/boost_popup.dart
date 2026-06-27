import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/models/event_model.dart';
import '../../core/providers/event_provider.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';

const _maxPerDay = 2;

/// Décide et affiche le popup d'événement boosté à l'ouverture de l'app.
/// Cap : [_maxPerDay] popups par jour, persistés via secure storage. Le 1er
/// du jour = le plus proche/épinglé (ordre serveur), les suivants = aléatoires.
class BoostPopupController {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _kDate = 'boost_popup_date';
  static const _kCount = 'boost_popup_count';
  static const _kSeen = 'boost_popup_seen';

  static bool _showing = false;

  static String _today() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  /// Purge le suivi local (popups vus aujourd'hui, compteur). Appelé au
  /// changement d'identité pour ne pas reporter l'état d'un compte sur le suivant.
  static Future<void> clearTracking() async {
    await Future.wait([
      _storage.delete(key: _kDate),
      _storage.delete(key: _kCount),
      _storage.delete(key: _kSeen),
    ]);
  }

  static Future<void> maybeShow(BuildContext context, WidgetRef ref) async {
    if (_showing) return;

    final today = _today();
    final storedDate = await _storage.read(key: _kDate);
    var count = 0;
    var seen = <String>[];
    if (storedDate == today) {
      count = int.tryParse(await _storage.read(key: _kCount) ?? '0') ?? 0;
      final raw = await _storage.read(key: _kSeen) ?? '';
      seen = raw.isEmpty ? <String>[] : raw.split(',');
    }
    if (count >= _maxPerDay) return;

    List<EventModel> events;
    try {
      events = await ref.read(boostedPopupProvider.future);
    } catch (_) {
      return;
    }
    final fresh = events.where((e) => !seen.contains(e.id)).toList();
    if (fresh.isEmpty) return;

    // 1er popup du jour → le plus prioritaire (ordre serveur) ; ensuite aléatoire.
    final picked = count == 0 ? fresh.first : fresh[Random().nextInt(fresh.length)];

    if (!context.mounted) return;
    _showing = true;
    await _show(context, picked);
    _showing = false;

    seen.add(picked.id);
    await _storage.write(key: _kDate, value: today);
    await _storage.write(key: _kCount, value: '${count + 1}');
    await _storage.write(key: _kSeen, value: seen.join(','));
  }

  static Future<void> _show(BuildContext context, EventModel event) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => _BoostPopupDialog(event: event),
    );
  }
}

class _BoostPopupDialog extends StatelessWidget {
  final EventModel event;
  const _BoostPopupDialog({required this.event});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat("EEE d MMM · HH'h'mm", 'fr_FR')
        .format(event.startAt.toLocal());

    return Dialog(
      backgroundColor: context.tpCard,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.cardLg)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cover + overlays ─────────────────────────────────────────────
          Stack(
            children: [
              SizedBox(
                height: 168,
                width: double.infinity,
                child: event.coverImageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: event.coverImageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (ctx, url, err) =>
                            const DecoratedBox(decoration: BoxDecoration(gradient: trackpartyGradient)),
                        placeholder: (ctx, url) =>
                            const DecoratedBox(decoration: BoxDecoration(gradient: trackpartyGradient)),
                      )
                    : const DecoratedBox(decoration: BoxDecoration(gradient: trackpartyGradient)),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFEC4899)]),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.star_rounded, size: 13, color: Colors.white),
                    SizedBox(width: 3),
                    Text('Sponsorisé',
                        style: TextStyle(
                            fontSize: 10.5, fontWeight: FontWeight.w900, color: Colors.white)),
                  ]),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Semantics(
                  button: true,
                  label: 'Fermer',
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Contenu ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  event.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: context.tpInk,
                    letterSpacing: -0.4,
                    height: 1.15,
                  ),
                ),
                // Promoteur + badge (bronze/argent/or) + Pro
                const SizedBox(height: 7),
                Row(children: [
                  Flexible(
                    child: Text('par ${event.organizerName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: context.tpInkSub)),
                  ),
                  if (event.organizerBadgeLevel != null) ...[
                    const SizedBox(width: 6),
                    _badgeChip(event.organizerBadgeLevel!),
                  ],
                  if (event.organizerIsPro) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFFF59E0B), Color(0xFFEC4899)]),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text('PRO',
                          style: TextStyle(
                              fontSize: 9.5, fontWeight: FontWeight.w900, color: Colors.white)),
                    ),
                  ],
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Icon(PhosphorIcons.calendarBlank(), size: 15, color: context.tpInkSub),
                  const SizedBox(width: 6),
                  Text(date,
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700, color: context.tpInkSub)),
                ]),
                if (event.city.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(PhosphorIcons.mapPin(), size: 15, color: context.tpInkSub),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        event.quartier.isNotEmpty ? '${event.quartier}, ${event.city}' : event.city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700, color: context.tpInkSub),
                      ),
                    ),
                  ]),
                ],
                // Prix
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: kPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    event.priceFrom != null
                        ? 'À partir de ${_fmtPrice(event.priceFrom!)}'
                        : 'Gratuit',
                    style: TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w900, color: kPrimary),
                  ),
                ),
                // Description
                if ((event.description ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    event.description!.trim(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: context.tpInkSub),
                  ),
                ],
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: context.tpCardAlt,
                          borderRadius: BorderRadius.circular(Radii.md),
                        ),
                        child: Text('Plus tard',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w800, color: context.tpInk)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push('/event/${event.id}');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: trackpartyGradient,
                          borderRadius: BorderRadius.circular(Radii.md),
                        ),
                        child: const Text('Voir les détails',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtPrice(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    return '${b.toString()} FCFA';
  }

  Widget _badgeChip(String level) {
    final (String emoji, String label, Color color) = switch (level) {
      'gold' => ('🏆', 'Or', const Color(0xFFF59E0B)),
      'silver' => ('🥈', 'Argent', const Color(0xFF94A3B8)),
      _ => ('🥉', 'Bronze', const Color(0xFFB45309)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1),
      ),
      child: Text('$emoji $label',
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: color)),
    );
  }
}

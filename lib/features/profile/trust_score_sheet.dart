import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';

class TrustScoreSheet extends StatelessWidget {
  const TrustScoreSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const TrustScoreSheet(),
    );
  }

  static const _criteria = [
    (label: 'Note moyenne (4.8/5)',          weight: 40, fill: 96,  color: Color(0xFFF97316), emoji: '⭐'),
    (label: 'Taux de présence (88%)',         weight: 20, fill: 88,  color: Color(0xFF7C3AED), emoji: '🎯'),
    (label: 'Événements organisés (38)',      weight: 20, fill: 95,  color: Color(0xFFEC4899), emoji: '📅'),
    (label: 'Ancienneté du compte (3 ans)',   weight: 10, fill: 75,  color: Color(0xFF06B6D4), emoji: '🌱'),
    (label: 'Aucun signalement validé',       weight: 10, fill: 100, color: Color(0xFF22A865), emoji: '🛡'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Grabber
          Container(width: 44, height: 5,
            decoration: BoxDecoration(color: context.tpHair, borderRadius: BorderRadius.circular(3))),
          const SizedBox(height: 8),
          // Hero
          Column(children: [
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                gradient: coralGradient,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [const BoxShadow(color: Color(0x66F97316), blurRadius: 28, offset: Offset(0, 12))],
              ),
              alignment: Alignment.center,
              child: const Text('🏆', style: TextStyle(fontSize: 42)),
            ),
            const SizedBox(height: 12),
            const Text('PROMOTEUR OR',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kAccent, letterSpacing: 0.5)),
            const SizedBox(height: 4),
            RichText(text: TextSpan(children: [
              TextSpan(text: '92',
                style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: context.tpInk, letterSpacing: -1.5, height: 1)),
              TextSpan(text: ' / 100',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.tpInkSub, height: 1)),
            ])),
            const SizedBox(height: 4),
            Text('Score de confiance',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.tpInkSub)),
          ]),
          const SizedBox(height: 20),
          // Global progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: 0.92,
              backgroundColor: context.tpHair,
              valueColor: const AlwaysStoppedAnimation<Color>(kPrimary),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 24),
          // Breakdown label
          Align(
            alignment: Alignment.centerLeft,
            child: Text('DÉTAIL DES CRITÈRES',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900,
                  color: context.tpInkSub, letterSpacing: 0.3)),
          ),
          const SizedBox(height: 12),
          // Criteria
          ...TrustScoreSheet._criteria.map((c) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(children: [
              Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: c.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(c.emoji, style: const TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(c.label,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: context.tpInk))),
                Text('${c.weight}%',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: c.color)),
              ]),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 42),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: c.fill / 100,
                    backgroundColor: context.tpHair,
                    valueColor: AlwaysStoppedAnimation(c.color),
                    minHeight: 5,
                  ),
                ),
              ),
            ]),
          )),
          const SizedBox(height: 6),
          // Hint card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: gradientSoft, borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              const Text('💡', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: 'Continuez comme ça ! ',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: context.tpInk)),
                  TextSpan(text: '8 événements de plus pour passer au statut Platine.',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.tpInk, height: 1.4)),
                ])),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

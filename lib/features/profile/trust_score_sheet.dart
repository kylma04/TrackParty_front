import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/promoter_model.dart';
import '../../core/providers/promoter_provider.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';

class TrustScoreSheet extends ConsumerWidget {
  final String userId;
  const TrustScoreSheet({super.key, required this.userId});

  static Future<void> show(BuildContext context, {required String userId}) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ProviderScope(
        child: TrustScoreSheet(userId: userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scoreAsync = ref.watch(promoterTrustScoreProvider(userId));

    return Container(
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(Sp.md, 12, Sp.md,
          MediaQuery.of(context).padding.bottom + 24),
      child: scoreAsync.when(
        loading: () => const SizedBox(height: 200,
            child: Center(child: CircularProgressIndicator())),
        error: (_, _) => SizedBox(height: 200,
          child: Center(
            child: Text('Impossible de charger le score',
              style: TextStyle(fontSize: 13, color: context.tpInkSub)))),
        data: (data) => _buildContent(context, data),
      ),
    );
  }

  Widget _buildContent(BuildContext context, TrustScoreData data) {
    final badgeGradient = _badgeGradient(data.badgeLevel);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 44, height: 5,
          decoration: BoxDecoration(color: context.tpHair, borderRadius: BorderRadius.circular(3))),
        const SizedBox(height: 8),
        Container(
          width: 88, height: 88,
          decoration: BoxDecoration(
            gradient: badgeGradient,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(
              color: _badgeGlowColor(data.badgeLevel).withValues(alpha: 0.4),
              blurRadius: 28, offset: const Offset(0, 12))],
          ),
          alignment: Alignment.center,
          child: Text(_badgeEmoji(data.badgeLevel), style: const TextStyle(fontSize: 42)),
        ),
        const SizedBox(height: 12),
        Text(data.badgeLabel,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900,
              color: _badgeGlowColor(data.badgeLevel), letterSpacing: 0.5)),
        const SizedBox(height: 4),
        RichText(text: TextSpan(children: [
          TextSpan(text: '${data.score}',
            style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900,
                color: context.tpInk, letterSpacing: -1.5, height: 1)),
          TextSpan(text: ' / 100',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                color: context.tpInkSub, height: 1)),
        ])),
        const SizedBox(height: 4),
        Text('Score de confiance',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.tpInkSub)),
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: data.score / 100,
            backgroundColor: context.tpHair,
            valueColor: const AlwaysStoppedAnimation<Color>(kPrimary),
            minHeight: 10,
          ),
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('DÉTAIL DES CRITÈRES',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900,
                color: context.tpInkSub, letterSpacing: 0.3)),
        ),
        const SizedBox(height: 12),
        ...data.criteria.map((c) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(children: [
            Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: c.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
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
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(gradient: gradientSoft, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            const Text('💡', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(data.tip,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.tpInk, height: 1.4)),
            ),
          ]),
        ),
      ],
    );
  }

  LinearGradient _badgeGradient(String level) {
    switch (level) {
      case 'gold':
        return const LinearGradient(
          colors: [Color(0xFFF97316), Color(0xFFF59E0B)],
          begin: Alignment.topLeft, end: Alignment.bottomRight);
      case 'silver':
        return const LinearGradient(
          colors: [Color(0xFF94A3B8), Color(0xFF64748B)],
          begin: Alignment.topLeft, end: Alignment.bottomRight);
      default:
        return const LinearGradient(
          colors: [Color(0xFFCD7F32), Color(0xFFA0522D)],
          begin: Alignment.topLeft, end: Alignment.bottomRight);
    }
  }

  Color _badgeGlowColor(String level) {
    switch (level) {
      case 'gold':   return const Color(0xFFF97316);
      case 'silver': return const Color(0xFF64748B);
      default:       return const Color(0xFFCD7F32);
    }
  }

  String _badgeEmoji(String level) {
    switch (level) {
      case 'gold':   return '🏆';
      case 'silver': return '🥈';
      default:       return '🥉';
    }
  }
}

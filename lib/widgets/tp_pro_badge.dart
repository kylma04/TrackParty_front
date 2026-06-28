import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Badge « PRO » (abonnement Promoteur Pro actif).
class TpProBadge extends StatelessWidget {
  final double fontSize;
  const TpProBadge({super.key, this.fontSize = 10});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFEC4899)],
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(PhosphorIcons.crown(PhosphorIconsStyle.fill),
            color: Colors.white, size: fontSize + 1),
        const SizedBox(width: 4),
        Text('PRO',
            style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.5)),
      ]),
    );
  }
}

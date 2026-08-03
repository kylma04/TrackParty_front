import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/theme_ext.dart';

/// Une action listée dans un [TpActionSheet] — tap = ferme le sheet puis
/// exécute [onTap].
class TpActionSheetItem {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool danger;
  final bool dividerBefore;

  const TpActionSheetItem({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
    this.danger = false,
    this.dividerBefore = false,
  });
}

/// Bottom sheet d'actions générique (icône + libellé + sous-titre optionnel) —
/// utilisé pour les menus "⋮" de gestion (groupe, événement, communauté).
class TpActionSheet extends StatelessWidget {
  final List<TpActionSheetItem> items;

  const TpActionSheet({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(Sp.md),
      padding: const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, Sp.md),
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: BorderRadius.circular(Radii.cardLg),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: context.tpHair, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            for (final item in items) ...[
              if (item.dividerBefore) Divider(color: context.tpHair, height: 24),
              _tile(context, item),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, TpActionSheetItem item) {
    final color = item.danger ? kError : context.tpInk;
    return Semantics(
      button: true, label: item.label,
      child: GestureDetector(
        onTap: () { Navigator.pop(context); item.onTap(); },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            Icon(item.icon, color: item.danger ? color : context.tpInkSub, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
                  if (item.subtitle != null)
                    Text(item.subtitle!, style: TextStyle(fontSize: 12, color: context.tpInkSub)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

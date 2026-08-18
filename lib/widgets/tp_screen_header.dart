import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/shadows.dart';
import '../theme/spacing.dart';
import '../theme/theme_ext.dart';

/// Bouton retour rond 44×44 — dupliqué à l'identique dans une dizaine
/// d'écrans avant extraction ici (correction/évolution centralisée).
class TpBackButton extends StatelessWidget {
  final VoidCallback? onTap;
  const TpBackButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Retour',
      child: GestureDetector(
        onTap: onTap ?? () => context.pop(),
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: context.tpCard,
            borderRadius: BorderRadius.circular(Radii.md),
            boxShadow: Shadows.sm,
          ),
          child: Icon(PhosphorIcons.caretLeft(), color: context.tpInk, size: 18),
        ),
      ),
    );
  }
}

/// En-tête d'écran standard : bouton retour + titre (+ sous-titre / action
/// de fin optionnels). Couvre le cas « back + titre » répété dans la
/// plupart des écrans secondaires (co-organisateurs, dashboard, boost...).
class TpScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onBack;
  final EdgeInsetsGeometry padding;

  const TpScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onBack,
    this.padding = const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, 12),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(children: [
        TpBackButton(onTap: onBack),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: context.tpInk)),
              if (subtitle != null)
                Text(subtitle!,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.tpInkSub)),
            ],
          ),
        ),
        ?trailing,
      ]),
    );
  }
}

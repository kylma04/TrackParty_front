import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/theme_ext.dart';

/// Bottom sheet de confirmation mobile-first.
/// Remplace les AlertDialog sur les actions destructives.
class TpConfirmSheet extends StatelessWidget {
  final String title;
  final String? body;
  final String confirmLabel;
  final Color confirmColor;
  final String cancelLabel;
  final IconData? icon;

  const TpConfirmSheet({
    super.key,
    required this.title,
    this.body,
    required this.confirmLabel,
    this.confirmColor = kError,
    this.cancelLabel = 'Annuler',
    this.icon,
  });

  static Future<bool> show(
    BuildContext context, {
    required String title,
    String? body,
    required String confirmLabel,
    Color confirmColor = kError,
    String cancelLabel = 'Annuler',
    IconData? icon,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => TpConfirmSheet(
        title: title,
        body: body,
        confirmLabel: confirmLabel,
        confirmColor: confirmColor,
        cancelLabel: cancelLabel,
        icon: icon,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
      ),
      padding: EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44, height: 5,
              decoration: BoxDecoration(
                color: context.tpHair,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (icon != null) ...[
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: confirmColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: confirmColor, size: 26),
            ),
            const SizedBox(height: 14),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: context.tpInk,
              letterSpacing: -0.3,
            ),
          ),
          if (body != null) ...[
            const SizedBox(height: 8),
            Text(
              body!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.tpInkSub,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 24),
          // Bouton confirmer
          Semantics(
            button: true,
            label: confirmLabel,
            child: GestureDetector(
              onTap: () => Navigator.pop(context, true),
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  color: confirmColor,
                  borderRadius: BorderRadius.circular(Radii.button),
                ),
                alignment: Alignment.center,
                child: Text(
                  confirmLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Bouton annuler
          Semantics(
            button: true,
            label: cancelLabel,
            child: GestureDetector(
              onTap: () => Navigator.pop(context, false),
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  color: context.tpBg,
                  borderRadius: BorderRadius.circular(Radii.button),
                ),
                alignment: Alignment.center,
                child: Text(
                  cancelLabel,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.tpInk,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

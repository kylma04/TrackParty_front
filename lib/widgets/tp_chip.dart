import 'package:flutter/material.dart';
import '../theme/gradients.dart';
import '../theme/spacing.dart';
import '../theme/theme_ext.dart';

class TpFilterChip extends StatelessWidget {
  final String label;
  final String? emoji;
  final bool active;
  final VoidCallback onTap;

  const TpFilterChip({
    super.key,
    required this.label,
    this.emoji,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      selected: active,
      child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: active
            ? BoxDecoration(
                gradient: trackpartyGradient,
                borderRadius: BorderRadius.circular(Radii.md),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x407C3AED),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              )
            : BoxDecoration(
                color: context.tpCard,
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(color: context.tpHair),
              ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null) ...[
              Text(emoji!, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : context.tpInkSub,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class TpFilterChipRow extends StatelessWidget {
  final List<String> labels;
  final List<String?> emojis;
  final int activeIndex;
  final void Function(int) onChanged;

  const TpFilterChipRow({
    super.key,
    required this.labels,
    required this.activeIndex,
    required this.onChanged,
    List<String?>? emojis,
  }) : emojis = emojis ?? const [];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Sp.md),
      child: Row(
        children: List.generate(labels.length, (i) {
          return Padding(
            padding: EdgeInsets.only(right: i < labels.length - 1 ? Sp.sm : 0),
            child: TpFilterChip(
              label: labels[i],
              emoji: i < emojis.length ? emojis[i] : null,
              active: i == activeIndex,
              onTap: () => onChanged(i),
            ),
          );
        }),
      ),
    );
  }
}

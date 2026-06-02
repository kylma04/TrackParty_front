import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';

class TpBottomSheet extends StatelessWidget {
  final Widget child;
  final bool showGrabber;
  final EdgeInsets? padding;

  const TpBottomSheet({
    super.key,
    required this.child,
    this.showGrabber = true,
    this.padding,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    bool showGrabber = true,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      builder: (_) => TpBottomSheet(showGrabber: showGrabber, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? kCardDark : kCardLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F1B1A2E),
            blurRadius: 32,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: padding ?? const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, Sp.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showGrabber) ...[
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? kHairDark : const Color(0xFFD9D8E5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

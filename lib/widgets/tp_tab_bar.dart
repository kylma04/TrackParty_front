import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/gradients.dart';
import '../theme/shadows.dart';


class TpTabBar extends StatelessWidget {
  final int activeIndex;
  final void Function(int) onTap;
  final VoidCallback onCreateTap;

  const TpTabBar({
    super.key,
    required this.activeIndex,
    required this.onTap,
    required this.onCreateTap,
  });

  static final _items = [
    _TabItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Accueil'),
    _TabItem(icon: Icons.map_outlined, activeIcon: Icons.map, label: 'Carte'),
    _TabItem(icon: Icons.add, activeIcon: Icons.add, label: ''),
    _TabItem(icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble, label: 'Messages'),
    _TabItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? kCardDark : Colors.white;
    final hair = isDark ? kHairDark : kHairLight;
    final inactiveColor = isDark ? kInkMuteDark : kInkMuteLight;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: hair, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                children: List.generate(_items.length, (i) {
                  if (i == 2) {
                    return const Expanded(child: SizedBox());
                  }
                  final item = _items[i];
                  final tabIndex = i > 2 ? i - 1 : i;
                  final active = activeIndex == tabIndex;
                  return Expanded(
                    child: Semantics(
                      label: item.label,
                      selected: active,
                      button: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onTap(tabIndex),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              active ? item.activeIcon : item.icon,
                              color: active ? kPrimary : inactiveColor,
                              size: 24,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: active ? FontWeight.w800 : FontWeight.w700,
                                color: active ? kPrimary : inactiveColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            // Solid primary dot — gradient was diluting the CTA hierarchy
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: active ? 16 : 0,
                              height: 3,
                              decoration: BoxDecoration(
                                color: active ? kPrimary : Colors.transparent,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
              // Central elevated "+" button
              Positioned(
                top: -20,
                left: 0,
                right: 0,
                child: Center(
                  child: Semantics(
                    label: 'Créer un événement',
                    button: true,
                    child: GestureDetector(
                      onTap: onCreateTap,
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          gradient: trackpartyGradient,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: bg, width: 3),
                          boxShadow: Shadows.brand,
                        ),
                        child: Icon(Icons.add, color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _TabItem({required this.icon, required this.activeIcon, required this.label});
}

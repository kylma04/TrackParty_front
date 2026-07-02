import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/gradients.dart';
import '../theme/haptics.dart';
import '../theme/shadows.dart';
import '../theme/theme_ext.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class TpTabBar extends StatelessWidget {
  final int activeIndex;
  final void Function(int) onTap;
  final VoidCallback onCreateTap;
  /// Bulles de notification par index d'onglet (0=Accueil, 1=Carte,
  /// 2=Messages, 3=Profil). Une entrée > 0 affiche une pastille sur l'icône.
  final Map<int, int> badges;

  const TpTabBar({
    super.key,
    required this.activeIndex,
    required this.onTap,
    required this.onCreateTap,
    this.badges = const {},
  });

  static final _items = [
    _TabItem(icon: PhosphorIcons.house(), activeIcon: PhosphorIcons.house(PhosphorIconsStyle.fill), label: 'Accueil'),
    _TabItem(icon: PhosphorIcons.mapTrifold(), activeIcon: PhosphorIcons.mapTrifold(PhosphorIconsStyle.fill), label: 'Carte'),
    _TabItem(icon: PhosphorIcons.plus(), activeIcon: PhosphorIcons.plus(), label: ''),
    _TabItem(icon: PhosphorIcons.chatCircle(), activeIcon: PhosphorIcons.chatCircle(PhosphorIconsStyle.fill), label: 'Messages'),
    _TabItem(icon: PhosphorIcons.user(), activeIcon: PhosphorIcons.user(PhosphorIconsStyle.fill), label: 'Profil'),
  ];

  Widget _iconWithBadge(BuildContext context, IconData icon, bool active, int badge) {
    final iconWidget = Icon(icon, color: active ? kPrimary : context.tpInkMute, size: 24);
    if (badge <= 0) return iconWidget;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        iconWidget,
        Positioned(
          right: -7,
          top: -5,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: badge > 9 ? 4 : 0),
            constraints: const BoxConstraints(minWidth: 16),
            height: 16,
            decoration: BoxDecoration(
              color: kError,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.tpCard, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              badge > 9 ? '9+' : '$badge',
              style: const TextStyle(
                fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white, height: 1),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.tpCard,
        border: Border(top: BorderSide(color: context.tpHair, width: 1)),
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
                  final badge = badges[tabIndex] ?? 0;
                  return Expanded(
                    child: Semantics(
                      label: badge > 0 ? '${item.label}, $badge non lus' : item.label,
                      selected: active,
                      button: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () { Haptics.selection(); onTap(tabIndex); },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _iconWithBadge(
                              context,
                              active ? item.activeIcon : item.icon,
                              active,
                              badge,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: active ? FontWeight.w800 : FontWeight.w700,
                                color: active ? kPrimary : context.tpInkMute,
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
                      onTap: () { Haptics.medium(); onCreateTap(); },
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          gradient: trackpartyGradient,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: context.tpCard, width: 3),
                          boxShadow: Shadows.brand,
                        ),
                        child: Icon(PhosphorIcons.plus(), color: Colors.white, size: 28),
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

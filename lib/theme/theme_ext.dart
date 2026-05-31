import 'package:flutter/material.dart';
import 'colors.dart';

extension AppColors on BuildContext {
  bool get isDark    => Theme.of(this).brightness == Brightness.dark;
  Color get tpBg     => isDark ? kBgDark      : kBgLight;
  Color get tpCard   => isDark ? kCardDark     : kCardLight;
  Color get tpCardAlt=> isDark ? kCardAltDark  : kCardLight;
  Color get tpInk    => isDark ? kInkDark      : kInkLight;
  Color get tpInkSub => isDark ? kInkSubDark   : kInkSubLight;
  Color get tpInkMute=> isDark ? kInkMuteDark  : kInkMuteLight;
  Color get tpHair   => isDark ? kHairDark     : kHairLight;
}

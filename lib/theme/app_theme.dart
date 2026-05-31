import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'colors.dart';
import 'typography.dart';

class AppTheme {
  static ThemeData get light {
    final colorScheme = const ColorScheme.light(
      primary: kPrimary,
      secondary: kSecondary,
      tertiary: kTertiary,
      surface: kCardLight,
      onSurface: kInkLight,
      error: kError,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: kBgLight,
      textTheme: buildTextTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: kCardLight,
        foregroundColor: kInkLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      dividerColor: kHairLight,
      dividerTheme: const DividerThemeData(color: kHairLight, thickness: 1),
    );
  }

  static ThemeData get dark {
    final colorScheme = const ColorScheme.dark(
      primary: kPrimary,
      secondary: kSecondary,
      tertiary: kTertiary,
      surface: kCardDark,
      onSurface: kInkDark,
      error: kError,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: kBgDark,
      textTheme: buildTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: kCardDark,
        foregroundColor: kInkDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      dividerColor: kHairDark,
      dividerTheme: const DividerThemeData(color: kHairDark, thickness: 1),
    );
  }
}

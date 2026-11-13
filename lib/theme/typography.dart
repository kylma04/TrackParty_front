import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

TextTheme buildTextTheme([TextTheme? base]) {
  final b = base ?? const TextTheme();
  return b.copyWith(
    // Display — splash, hero
    displayLarge: GoogleFonts.notoSansDisplay(
      fontSize: 48,
      fontWeight: FontWeight.w900,
      letterSpacing: -1.4,
      height: 1.0,
    ),
    // H1 — page titles
    displayMedium: GoogleFonts.notoSansDisplay(
      fontSize: 30,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.9,
      height: 1.1,
    ),
    // H2 — section headers
    displaySmall: GoogleFonts.notoSansDisplay(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      height: 1.15,
    ),
    // H3 — card titles
    headlineMedium: GoogleFonts.notoSansDisplay(
      fontSize: 19,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.35,
    ),
    headlineSmall: GoogleFonts.notoSansDisplay(
      fontSize: 17,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
    ),
    // Buttons
    titleMedium: GoogleFonts.notoSansDisplay(
      fontSize: 16,
      fontWeight: FontWeight.w700,
    ),
    // Card titles
    titleSmall: GoogleFonts.notoSansDisplay(
      fontSize: 15,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.25,
    ),
    bodyLarge: GoogleFonts.lato(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.45,
    ),
    bodyMedium: GoogleFonts.lato(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    bodySmall: GoogleFonts.lato(
      fontSize: 12,
      fontWeight: FontWeight.w700,
    ),
    labelLarge: GoogleFonts.lato(
      fontSize: 13,
      fontWeight: FontWeight.w700,
    ),
    labelMedium: GoogleFonts.lato(
      fontSize: 11,
      fontWeight: FontWeight.w700,
    ),
    // Eyebrow — UPPERCASE
    labelSmall: GoogleFonts.notoSansDisplay(
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.6,
    ),
  );
}

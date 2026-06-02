import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

TextTheme buildTextTheme([TextTheme? base]) {
  final b = base ?? const TextTheme();
  return b.copyWith(
    // Display — splash, hero
    displayLarge: GoogleFonts.nunito(
      fontSize: 52,
      fontWeight: FontWeight.w900,
      letterSpacing: -1.5,
      height: 1.0,
    ),
    // H1 — page titles
    displayMedium: GoogleFonts.nunito(
      fontSize: 30,
      fontWeight: FontWeight.w900,
      letterSpacing: -1.0,
      height: 1.1,
    ),
    // H2 — section headers
    displaySmall: GoogleFonts.nunito(
      fontSize: 22,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.6,
      height: 1.15,
    ),
    // H3 — card titles
    headlineMedium: GoogleFonts.nunito(
      fontSize: 19,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.4,
    ),
    headlineSmall: GoogleFonts.nunito(
      fontSize: 17,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.4,
    ),
    // Buttons
    titleMedium: GoogleFonts.nunito(
      fontSize: 16,
      fontWeight: FontWeight.w800,
    ),
    // Card titles
    titleSmall: GoogleFonts.nunito(
      fontSize: 15,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.3,
    ),
    bodyLarge: GoogleFonts.nunito(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.45,
    ),
    bodyMedium: GoogleFonts.nunito(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    bodySmall: GoogleFonts.nunito(
      fontSize: 12,
      fontWeight: FontWeight.w700,
    ),
    labelLarge: GoogleFonts.nunito(
      fontSize: 13,
      fontWeight: FontWeight.w800,
    ),
    labelMedium: GoogleFonts.nunito(
      fontSize: 11,
      fontWeight: FontWeight.w800,
    ),
    // Eyebrow — UPPERCASE
    labelSmall: GoogleFonts.nunito(
      fontSize: 10,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.5,
    ),
  );
}

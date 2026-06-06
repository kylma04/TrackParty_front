import 'package:flutter/material.dart';
import 'colors.dart';

const trackpartyGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [kPrimary, kSecondary, kTertiary],
);

const coralGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [kAccent, kTertiary],
);

// 0.12 × 255 ≈ 31 = 0x1F — const-safe version
const gradientSoft = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0x1F4F46E5), Color(0x1F7C3AED), Color(0x1FEC4899)],
);

// Category gradients for map pins & cards
const Map<String, LinearGradient> categoryGradients = {
  'musique': LinearGradient(
    colors: [kCategoryMusic, kPrimary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  'soirée': LinearGradient(
    colors: [kCategoryParty, kAccent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  'cuisine': LinearGradient(
    colors: [kAccent, kCategoryParty],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  'sport': LinearGradient(
    colors: [kCategorySport, kSecondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  'art': LinearGradient(
    colors: [kCategoryArt, kCategorySport],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  'plage': LinearGradient(
    colors: [kCategoryBeach, kAccent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
};

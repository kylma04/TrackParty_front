import 'package:flutter/material.dart';
import 'colors.dart';

// Surfaces unies (aplats propres sans dégradés multicolores).
const trackpartyGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [kPrimary, kPrimary],
);

const coralGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [kAccent, kAccent],
);

// Réservé aux features "boost"/sponsoring (event_boost_screen.dart, boost_popup.dart).
const goldGradient = LinearGradient(colors: [kTertiary, kTertiary]);

const gradientSoft = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0x14FF4B26), Color(0x14FF4B26)],
);

// Aplats de catégories pour pins carte & vignettes.
const Map<String, LinearGradient> categoryGradients = {
  'musique': LinearGradient(colors: [kCategoryMusic, kCategoryMusic]),
  'soirée': LinearGradient(colors: [kCategoryParty, kCategoryParty]),
  'cuisine': LinearGradient(colors: [kCategoryFood, kCategoryFood]),
  'sport': LinearGradient(colors: [kCategorySport, kCategorySport]),
  'art': LinearGradient(colors: [kCategoryArt, kCategoryArt]),
  'plage': LinearGradient(colors: [kCategoryBeach, kCategoryBeach]),
};

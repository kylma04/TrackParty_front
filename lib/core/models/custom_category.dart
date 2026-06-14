/// Catégorie personnalisée existante (renvoyée par l'API `events/custom-categories/`).
class CustomCategory {
  final String label;
  final String emoji;
  final int count;

  const CustomCategory({
    required this.label,
    required this.emoji,
    required this.count,
  });

  factory CustomCategory.fromJson(Map<String, dynamic> j) => CustomCategory(
        label: j['label'] as String,
        emoji: (j['emoji'] as String?)?.isNotEmpty == true ? j['emoji'] as String : '✨',
        count: (j['count'] as int?) ?? 0,
      );
}

/// Définition d'une catégorie standard, source unique pour les filtres
/// (feed + carte). Le slug correspond à la valeur backend.
class CategoryDef {
  final String slug;
  final String label;
  final String emoji;
  const CategoryDef(this.slug, this.label, this.emoji);
}

const kStandardCategories = <CategoryDef>[
  CategoryDef('musique', 'Musique', '🎵'),
  CategoryDef('soiree', 'Soirée', '🎉'),
  CategoryDef('cuisine', 'Cuisine', '🍽'),
  CategoryDef('sport', 'Sport', '⚽'),
  CategoryDef('art', 'Art', '🎨'),
  CategoryDef('plage', 'Plage', '🏖'),
];

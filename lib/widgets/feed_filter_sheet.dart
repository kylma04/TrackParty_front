import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/models/custom_category.dart';
import '../core/providers/event_provider.dart';
import '../theme/colors.dart';
import '../theme/gradients.dart';
import '../theme/haptics.dart';
import '../theme/spacing.dart';
import '../theme/theme_ext.dart';

Future<void> showFeedFilterSheet(BuildContext context) {
  final media = MediaQuery.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // Empêche la feuille de passer sous la barre d'état (heure / batterie)
    useSafeArea: true,
    // Plafonne la hauteur à 80 % de l'écran
    constraints: BoxConstraints(
      maxHeight: media.size.height * 0.8,
    ),
    builder: (_) => const _FeedFilterSheet(),
  );
}

const _dateChips  = ['Tous ✨', 'Ce soir 🌙', 'Weekend 🎉', 'Gratuit 💸'];
const _dateValues = ['upcoming', 'tonight', 'weekend', 'upcoming'];

class _FeedFilterSheet extends ConsumerStatefulWidget {
  const _FeedFilterSheet();

  @override
  ConsumerState<_FeedFilterSheet> createState() => _FeedFilterSheetState();
}

class _FeedFilterSheetState extends ConsumerState<_FeedFilterSheet> {
  late String  _sortBy;
  late double  _radiusKm;
  late String? _category;
  late String? _customLabel;
  late String  _dateFilter;
  late bool    _freeOnly;

  @override
  void initState() {
    super.initState();
    final f = ref.read(feedFiltersProvider);
    _sortBy      = f.sortBy;
    _radiusKm    = f.radiusKm;
    _category    = f.category;
    _customLabel = f.customLabel;
    _dateFilter  = f.dateFilter;
    _freeOnly    = f.freeOnly;
  }

  void _apply() {
    ref.read(feedFiltersProvider.notifier).state = FeedFilters(
      sortBy:      _sortBy,
      radiusKm:    _radiusKm,
      category:    _category,
      customLabel: _customLabel,
      dateFilter:  _dateFilter,
      freeOnly:    _freeOnly,
    );
    Navigator.of(context).pop();
  }

  void _reset() {
    setState(() {
      _sortBy      = 'start_at';
      _radiusKm    = 25;
      _category    = null;
      _customLabel = null;
      _dateFilter  = 'upcoming';
      _freeOnly    = false;
    });
  }

  void _selectCategory({String? category, String? customLabel}) {
    setState(() {
      _category    = category;
      _customLabel = customLabel;
    });
  }

  /// Catégories affichées en grille 2 colonnes.
  Widget _buildCategoryGrid(BuildContext context) {
    final customCats =
        ref.watch(customCategoriesProvider).valueOrNull ?? const <CustomCategory>[];

    final chips = <Widget>[
      _CatGridChip(
        label: 'Tout 🌟',
        active: _category == null && _customLabel == null,
        onTap: () => _selectCategory(),
      ),
      for (final c in kStandardCategories)
        _CatGridChip(
          label: '${c.label} ${c.emoji}',
          active: _category == c.slug && _customLabel == null,
          onTap: () => _selectCategory(category: c.slug),
        ),
      _CatGridChip(
        label: 'Autre ✨',
        active: _category == 'autre' && _customLabel == null,
        onTap: () => _selectCategory(category: 'autre'),
      ),
      for (final cc in customCats.take(12))
        _CatGridChip(
          label: '${cc.emoji} ${cc.label}',
          active: _customLabel?.toLowerCase() == cc.label.toLowerCase(),
          onTap: () => _selectCategory(category: 'autre', customLabel: cc.label),
        ),
    ];

    return _grid(chips);
  }

  /// Dispose les puces en grille 2 colonnes (chaque puce remplit sa cellule).
  Widget _grid(List<Widget> chips) {
    return LayoutBuilder(
      builder: (context, c) {
        final itemWidth = (c.maxWidth - Sp.xs) / 2;
        return Wrap(
          spacing: Sp.xs,
          runSpacing: Sp.xs,
          children: chips
              .map((chip) => SizedBox(width: itemWidth, child: chip))
              .toList(),
        );
      },
    );
  }

  int get _activeDateIndex {
    if (_freeOnly) return 3;
    return switch (_dateFilter) {
      'tonight' => 1,
      'weekend' => 2,
      _         => 0,
    };
  }

  void _selectDate(int i) {
    setState(() {
      if (i == 3) {
        _freeOnly   = true;
        _dateFilter = 'upcoming';
      } else {
        _freeOnly   = false;
        _dateFilter = _dateValues[i];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.cardLg)),
      ),
      padding: EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, bottom + Sp.md),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    color: context.tpHair, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: Sp.md),

            // Header
            Row(children: [
              Text('Filtres & Tri',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: context.tpInk)),
              const Spacer(),
              Semantics(
                button: true,
                label: 'Réinitialiser les filtres',
                child: GestureDetector(
                  onTap: () { Haptics.light(); _reset(); },
                  child: const Text('Réinitialiser',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kPrimary)),
                ),
              ),
            ]),
            const SizedBox(height: Sp.md),

            // Catégorie
            Text('Catégorie',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.tpInkSub)),
            const SizedBox(height: 8),
            _buildCategoryGrid(context),
            const SizedBox(height: Sp.md),

            // Période
            Text('Période',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.tpInkSub)),
            const SizedBox(height: 8),
            _grid([
              for (var i = 0; i < _dateChips.length; i++)
                _CatGridChip(
                  label: _dateChips[i],
                  active: i == _activeDateIndex,
                  onTap: () => _selectDate(i),
                ),
            ]),
            const SizedBox(height: Sp.md),

            // Trier par
            Text('Trier par',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.tpInkSub)),
            const SizedBox(height: 8),
            _SortOption(
              icon: PhosphorIcons.calendarBlank(),
              label: 'Date',
              sublabel: 'Les prochains d\'abord',
              value: 'start_at',
              selected: _sortBy,
              onTap: () => setState(() => _sortBy = 'start_at'),
            ),
            const SizedBox(height: 8),
            _SortOption(
              icon: PhosphorIcons.fire(),
              label: 'Popularité',
              sublabel: 'Les plus fréquentés d\'abord',
              value: '-participants_count',
              selected: _sortBy,
              onTap: () => setState(() => _sortBy = '-participants_count'),
            ),
            const SizedBox(height: 8),
            _SortOption(
              icon: PhosphorIcons.mapPin(),
              label: 'Distance',
              sublabel: 'Les plus proches d\'abord',
              value: 'distance',
              selected: _sortBy,
              onTap: () => setState(() => _sortBy = 'distance'),
            ),

            const SizedBox(height: Sp.md),

            // Rayon
            Row(children: [
              Text('Rayon de recherche',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.tpInkSub)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: kPrimary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(Radii.sm)),
                child: Text('${_radiusKm.round()} km',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: kPrimary)),
              ),
            ]),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: kPrimary,
                inactiveTrackColor: context.tpHair,
                thumbColor: kPrimary,
                overlayColor: kPrimary.withValues(alpha: 0.12),
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              ),
              child: Slider(
                value: _radiusKm,
                min: 5,
                max: 100,
                divisions: 19,
                onChanged: (v) => setState(() => _radiusKm = v),
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('5 km', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.tpInkMute)),
              Text('100 km', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.tpInkMute)),
            ]),

            const SizedBox(height: Sp.md),

            // Apply
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _apply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg)),
                  elevation: 0,
                ),
                child: const Text('Appliquer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Puce de catégorie qui remplit sa cellule (grille 2 colonnes) et ellipse
/// les libellés trop longs.
class _CatGridChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _CatGridChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      selected: active,
      child: GestureDetector(
        onTap: () { Haptics.selection(); onTap(); },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: active
              ? BoxDecoration(
                  gradient: trackpartyGradient,
                  borderRadius: BorderRadius.circular(Radii.md),
                  boxShadow: const [
                    BoxShadow(color: Color(0x407C3AED), blurRadius: 12, offset: Offset(0, 4)),
                  ],
                )
              : BoxDecoration(
                  color: context.tpCard,
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(color: context.tpHair),
                ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : context.tpInkSub,
            ),
          ),
        ),
      ),
    );
  }
}

class _SortOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final String value;
  final String selected;
  final VoidCallback onTap;

  const _SortOption({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = value == selected;
    return Semantics(
      button: true,
      label: label,
      selected: isActive,
      child: GestureDetector(
      onTap: () { Haptics.selection(); onTap(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? kPrimary.withValues(alpha: 0.08) : context.tpBg,
          borderRadius: BorderRadius.circular(Radii.button),
          border: Border.all(
            color: isActive ? kPrimary : context.tpHair,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: (isActive ? kPrimary : context.tpInkSub).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(Radii.tag)),
            child: Icon(icon, color: isActive ? kPrimary : context.tpInkSub, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800,
                      color: isActive ? kPrimary : context.tpInk)),
              Text(sublabel,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.tpInkSub)),
            ]),
          ),
          if (isActive)
            Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), color: kPrimary, size: 20),
        ]),
      ),
      ),
    );
  }
}

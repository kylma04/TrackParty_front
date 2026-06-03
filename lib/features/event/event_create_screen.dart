import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'dart:async';

import '../../core/api/api_exception.dart';
import '../../core/models/chat_model.dart';
import '../../core/services/cloudinary_service.dart';
import '../../core/services/co_organizer_service.dart';
import '../../core/services/event_service.dart';
import '../../core/services/invitation_service.dart';
import 'location_picker_screen.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_avatar.dart';
import '../../widgets/tp_button.dart';

class EventCreateScreen extends ConsumerStatefulWidget {
  const EventCreateScreen({super.key});

  @override
  ConsumerState<EventCreateScreen> createState() => _EventCreateScreenState();
}

class _EventCreateScreenState extends ConsumerState<EventCreateScreen> {
  final _titleCtrl    = TextEditingController();
  final _descCtrl     = TextEditingController();
  final _capacityCtrl = TextEditingController(text: '80');

  String? _category;
  String? _customCategoryLabel;
  String? _customCategoryEmoji;
  String  _visibility  = 'public';
  // contribution_type values match backend: 'gratuit', 'nature', 'monetaire'
  String  _contribMode = 'gratuit';
  int     _capacity    = 80;

  DateTime? _startAt;
  DateTime? _endAt;

  // Location
  String _addressLabel = '';
  String _city         = 'Abidjan';
  String _quartier     = '';
  double _lat          = 5.3484;   // centre Abidjan par défaut
  double _lng          = -4.0168;

  TpButtonState _publishState = TpButtonState.idle;

  String? _coverUrl;
  bool    _coverLoading = false;

  // Co-organisateurs à inviter après création
  final List<UserSearchResult> _pendingCoOrgs = [];

  final List<_Item> _items = [
    _Item(emoji: '🍾', label: 'Bouteille (vin/spiritueux)', qty: 50),
    _Item(emoji: '🍰', label: 'Plat sucré ou snack',       qty: 12),
    _Item(emoji: '🎧', label: 'Sono / DJ set',             qty: 1),
  ];

  static const _categories = [
    ('musique', '🎵', 'Musique',  Color(0xFF7C3AED)),
    ('soiree',  '🎉', 'Soirée',   Color(0xFFEC4899)),
    ('cuisine', '🍽', 'Cuisine',  Color(0xFFF97316)),
    ('sport',   '⚽', 'Sport',    Color(0xFF06B6D4)),
    ('art',     '🎨', 'Art',      Color(0xFF84CC16)),
    ('plage',   '🏖', 'Plage',    Color(0xFFF59E0B)),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _capacityCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmtDate(DateTime dt) => DateFormat('EEE d MMM', 'fr_FR').format(dt);
  String _fmtTime(DateTime dt) => DateFormat('HH:mm').format(dt);

  String get _locationLabel => _addressLabel.isNotEmpty ? _addressLabel : 'Lieu';
  String get _locationSub   => _quartier.isNotEmpty ? '$_quartier, $_city' : 'Appuyer pour choisir';

  // ── Date/time picker ──────────────────────────────────────────────────────

  Future<void> _pickDateTime({required bool isEnd}) async {
    final now = DateTime.now();
    final initial = isEnd ? (_endAt ?? _startAt?.add(const Duration(hours: 5)) ?? now) : (_startAt ?? now);

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
    );
    if (time == null || !mounted) return;

    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isEnd) {
        _endAt = dt;
      } else {
        _startAt = dt;
        if (_endAt != null && _endAt!.isBefore(dt)) _endAt = null;
      }
    });
  }

  // ── Location bottom sheet ─────────────────────────────────────────────────

  Future<void> _pickLocation() async {
    final addrCtrl  = TextEditingController(text: _addressLabel);
    final cityCtrl  = TextEditingController(text: _city);
    final quartCtrl = TextEditingController(text: _quartier);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tpCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        bool gpsLoading = false;
        return StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: EdgeInsets.fromLTRB(
              Sp.md, 20, Sp.md,
              MediaQuery.of(ctx).viewInsets.bottom + Sp.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lieu de l\'événement',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: ctx.tpInk)),
                const SizedBox(height: 14),

                // Boutons GPS + carte
                Row(children: [
                  Expanded(
                    child: _LocationActionBtn(
                      icon: PhosphorIcons.crosshair(),
                      label: gpsLoading ? 'Localisation…' : 'Ma position',
                      loading: gpsLoading,
                      onTap: () async {
                        setSheet(() => gpsLoading = true);
                        try {
                          LocationPermission perm = await Geolocator.checkPermission();
                          if (perm == LocationPermission.denied) {
                            perm = await Geolocator.requestPermission();
                          }
                          if (perm != LocationPermission.denied &&
                              perm != LocationPermission.deniedForever) {
                            final pos = await Geolocator.getCurrentPosition(
                              desiredAccuracy: LocationAccuracy.high,
                            );
                            if (mounted) {
                              setState(() {
                                _lat = pos.latitude;
                                _lng = pos.longitude;
                              });
                            }
                            // Reste sur le sheet — l'utilisateur complète l'adresse
                            if (ctx.mounted) setSheet(() => gpsLoading = false);
                          } else {
                            if (ctx.mounted) setSheet(() => gpsLoading = false);
                          }
                        } catch (_) {
                          if (ctx.mounted) setSheet(() => gpsLoading = false);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _LocationActionBtn(
                      icon: PhosphorIcons.mapTrifold(),
                      label: 'Choisir sur la carte',
                      onTap: () async {
                        // On NE ferme PAS le sheet — on pousse la carte par-dessus
                        final result = await Navigator.push<LocationPickerResult>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LocationPickerScreen(
                              initialLat: _lat,
                              initialLng: _lng,
                            ),
                          ),
                        );
                        if (result != null && mounted) {
                          setState(() {
                            _lat = result.lat;
                            _lng = result.lng;
                          });
                          // Force le rebuild du sheet pour afficher les nouvelles coordonnées
                          if (ctx.mounted) setSheet(() {});
                        }
                      },
                    ),
                  ),
                ]),
                const SizedBox(height: 12),

                // Coordonnées actuelles
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: ctx.tpBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    Icon(PhosphorIcons.mapPin(), color: kPrimary, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      '${_lat.toStringAsFixed(5)},  ${_lng.toStringAsFixed(5)}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ctx.tpInkSub),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),

                _LocationField(ctrl: addrCtrl, label: 'Adresse (ex: Rooftop K8)'),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _LocationField(ctrl: quartCtrl, label: 'Quartier')),
                  const SizedBox(width: 10),
                  Expanded(child: _LocationField(ctrl: cityCtrl, label: 'Ville')),
                ]),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: TpButton(
                    label: 'Confirmer',
                    onPressed: () {
                      setState(() {
                        _addressLabel = addrCtrl.text.trim();
                        _city = cityCtrl.text.trim().isNotEmpty ? cityCtrl.text.trim() : 'Abidjan';
                        _quartier = quartCtrl.text.trim();
                      });
                      Navigator.pop(ctx);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Validation ────────────────────────────────────────────────────────────

  String? _validate() {
    if (_titleCtrl.text.trim().isEmpty) return 'Le titre est obligatoire.';
    if (_category == null) return 'Choisis une catégorie.';
    if (_startAt == null) return 'Choisis une date et heure.';
    if (_contribMode == 'nature' && _items.isEmpty) {
      return 'Ajoute au moins un item de contribution.';
    }
    return null;
  }

  // ── Cover photo ───────────────────────────────────────────────────────────

  Future<void> _pickCover() async {
    if (_coverLoading) return;
    setState(() => _coverLoading = true);
    try {
      final url = await ref.read(cloudinaryServiceProvider).pickAndUpload(folder: 'covers');
      if (url != null && mounted) setState(() => _coverUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur photo : ${e.toString()}'), backgroundColor: kError),
        );
      }
    } finally {
      if (mounted) setState(() => _coverLoading = false);
    }
  }

  // ── Publish ───────────────────────────────────────────────────────────────

  Future<void> _publish() async {
    final error = _validate();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: kError),
      );
      return;
    }

    setState(() => _publishState = TpButtonState.loading);

    try {
      final data = <String, dynamic>{
        'title':             _titleCtrl.text.trim(),
        'description':       _descCtrl.text.trim(),
        'category':          _category,
        'status':            'published',
        'start_at':          _startAt!.toIso8601String(),
        if (_endAt != null) 'end_at': _endAt!.toIso8601String(),
        'latitude':          _lat,
        'longitude':         _lng,
        'address_label':     _addressLabel,
        'city':              _city,
        'quartier':          _quartier,
        'visibility':        _visibility,
        'contribution_type': _contribMode,
        'max_participants':  _capacity,
        if (_coverUrl != null) 'cover_cloud_url': _coverUrl,
        if (_category == 'autre' && _customCategoryLabel != null) ...{
          'custom_category_label': _customCategoryLabel,
          'custom_category_emoji': _customCategoryEmoji ?? '✨',
        },
        if (_contribMode == 'nature')
          'contribution_items': _items.map((i) => {
            'name':           i.label,
            'emoji':          i.emoji,
            'quantity_total': i.qty,
          }).toList(),
      };

      final event = await ref.read(eventServiceProvider).createEvent(data);

      // Send co-organizer invitations
      if (_pendingCoOrgs.isNotEmpty) {
        final svc = ref.read(coOrganizerServiceProvider);
        for (final coOrg in _pendingCoOrgs) {
          try {
            await svc.invite(event.id, coOrg.id);
          } catch (_) {}
        }
      }

      if (mounted) {
        setState(() => _publishState = TpButtonState.idle);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Événement publié !'),
            backgroundColor: kSuccess,
          ),
        );
        context.go('/feed');
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _publishState = TpButtonState.idle);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: kError),
        );
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tpBg,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).padding.top)),
              SliverToBoxAdapter(child: _buildHeader(context)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(Sp.md, 8, Sp.md, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildCoverPhoto(context),
                    const SizedBox(height: 14),
                    _buildTitleField(context),
                    const SizedBox(height: 14),
                    _buildDescField(context),
                    const SizedBox(height: 14),
                    _buildCategories(context),
                    const SizedBox(height: 14),
                    _buildDateLocation(),
                    const SizedBox(height: 14),
                    _buildVisibility(),
                    const SizedBox(height: 14),
                    _buildContribMode(),
                    if (_contribMode == 'nature') ...[
                      const SizedBox(height: 14),
                      _buildItemsList(context),
                    ],
                    const SizedBox(height: 14),
                    _buildCapacity(context),
                    const SizedBox(height: 14),
                    _buildCoOrganizers(context),
                  ]),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _buildBottomCta(context),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, 8),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Fermer',
            child: GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: context.tpCard,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: Shadows.sm,
                ),
                child: Icon(PhosphorIcons.x(), color: context.tpInk, size: 18),
              ),
            ),
          ),
          Expanded(
            child: Text('Nouvel événement',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900,
                  color: context.tpInk, letterSpacing: -0.4)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: kPrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('Brouillon',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kPrimary)),
          ),
        ],
      ),
    );
  }

  // ── Cover photo ───────────────────────────────────────────────────────────

  Widget _buildCoverPhoto(BuildContext context) {
    return Semantics(
      button: true,
      label: _coverUrl != null ? 'Changer la photo de couverture' : 'Ajouter une photo de couverture',
      child: GestureDetector(
        onTap: _coverLoading ? null : _pickCover,
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            gradient: _coverUrl == null ? gradientSoft : null,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kPrimary.withValues(alpha: 0.33), width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: _coverUrl != null
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(_coverUrl!, fit: BoxFit.cover),
                    if (_coverLoading)
                      Container(color: Colors.black54,
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                    Positioned(
                      bottom: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(PhosphorIcons.camera(), color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          const Text('Changer', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                        ]),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_coverLoading)
                      const CircularProgressIndicator(color: kPrimary, strokeWidth: 2)
                    else ...[
                      Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          gradient: trackpartyGradient,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: Shadows.brand,
                        ),
                        child: Icon(PhosphorIcons.camera(), color: Colors.white, size: 26),
                      ),
                      const SizedBox(height: 8),
                      Text('Ajouter une photo',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: context.tpInk)),
                      const SizedBox(height: 2),
                      Text('16:9 recommandé · max 5 Mo',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.tpInkSub)),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  // ── Titre ─────────────────────────────────────────────────────────────────

  Widget _buildTitleField(BuildContext context) {
    return _CreateField(
      label: 'Titre',
      child: TextField(
        controller: _titleCtrl,
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: context.tpInk),
        decoration: InputDecoration(
          hintText: 'Nom de l\'événement',
          hintStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: context.tpInkMute),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  // ── Description ───────────────────────────────────────────────────────────

  Widget _buildDescField(BuildContext context) {
    return AnimatedBuilder(
      animation: _descCtrl,
      builder: (_, _) => _CreateField(
        label: 'Description',
        extra: Text(
          '${_descCtrl.text.length} / 280',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.tpInkMute),
        ),
        child: TextField(
          controller: _descCtrl,
          maxLines: 3,
          maxLength: 280,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
              color: context.tpInkSub, height: 1.45),
          decoration: InputDecoration(
            hintText: 'Décris ton événement…',
            hintStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.tpInkMute),
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
            counterText: '',
          ),
        ),
      ),
    );
  }

  // ── Catégories ────────────────────────────────────────────────────────────

  Widget _buildCategories(BuildContext context) {
    final isCustomActive = _category == 'autre' && _customCategoryLabel != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Catégorie'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: [
            // Catégories prédéfinies
            ..._categories.map((cat) {
              final (key, emoji, label, color) = cat;
              final active = _category == key;
              return Semantics(
                button: true, label: '$emoji $label', selected: active,
                child: GestureDetector(
                  onTap: () => setState(() {
                    _category = key;
                    _customCategoryLabel = null;
                    _customCategoryEmoji = null;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: active ? color : context.tpCard,
                      borderRadius: BorderRadius.circular(12),
                      border: active ? null : Border.all(color: context.tpHair, width: 1.5),
                      boxShadow: active
                          ? [BoxShadow(color: color.withValues(alpha: 0.33), blurRadius: 14, offset: const Offset(0, 6))]
                          : null,
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(emoji, style: const TextStyle(fontSize: 15)),
                      const SizedBox(width: 6),
                      Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                          color: active ? Colors.white : context.tpInk)),
                    ]),
                  ),
                ),
              );
            }),

            // Option "Personnaliser"
            Semantics(
              button: true,
              label: isCustomActive ? 'Catégorie personnalisée sélectionnée' : 'Créer une catégorie',
              selected: isCustomActive,
              child: GestureDetector(
                onTap: () => _showCustomCategorySheet(context),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isCustomActive ? trackpartyGradient : null,
                    color: isCustomActive ? null : context.tpCard,
                    borderRadius: BorderRadius.circular(12),
                    border: isCustomActive
                        ? null
                        : Border.all(
                            color: kPrimary.withValues(alpha: 0.4),
                            width: 1.5,
                            strokeAlign: BorderSide.strokeAlignInside,
                          ),
                    boxShadow: isCustomActive
                        ? [const BoxShadow(color: Color(0x407C3AED), blurRadius: 14, offset: Offset(0, 6))]
                        : null,
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      isCustomActive ? (_customCategoryEmoji ?? '✨') : '✏️',
                      style: const TextStyle(fontSize: 15),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isCustomActive ? _customCategoryLabel! : 'Personnaliser',
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800,
                        color: isCustomActive ? Colors.white : kPrimary,
                      ),
                    ),
                    if (isCustomActive) ...[
                      const SizedBox(width: 4),
                      Icon(PhosphorIcons.pencilSimple(),
                        size: 12, color: Colors.white.withValues(alpha: 0.8)),
                    ],
                  ]),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showCustomCategorySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomCategorySheet(
        initialLabel: _customCategoryLabel,
        initialEmoji: _customCategoryEmoji,
        onConfirm: (label, emoji) {
          setState(() {
            _category = 'autre';
            _customCategoryLabel = label;
            _customCategoryEmoji = emoji;
          });
        },
      ),
    );
  }

  // ── Date & Lieu ───────────────────────────────────────────────────────────

  Widget _buildDateLocation() {
    return Row(
      children: [
        Expanded(
          child: _SelectCard(
            icon: PhosphorIcons.calendar(),
            iconColor: kPrimary,
            label: 'Date · Heure',
            value: _startAt != null ? _fmtDate(_startAt!) : 'Choisir',
            sub: _startAt != null
                ? '${_fmtTime(_startAt!)}${_endAt != null ? ' — ${_fmtTime(_endAt!)}' : ''}'
                : 'Appuyer pour définir',
            onTap: () => _pickDateTime(isEnd: false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SelectCard(
            icon: PhosphorIcons.mapPin(),
            iconColor: kAccent,
            label: 'Lieu',
            value: _locationLabel,
            sub: _locationSub,
            onTap: _pickLocation,
          ),
        ),
      ],
    );
  }

  // ── Visibilité ────────────────────────────────────────────────────────────

  Widget _buildVisibility() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Visibilité'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _VisCard(
              emoji: '🌍', title: 'Public', sub: 'Visible sur la carte',
              active: _visibility == 'public',
              onTap: () => setState(() => _visibility = 'public'),
            )),
            const SizedBox(width: 8),
            Expanded(child: _VisCard(
              emoji: '🔒', title: 'Privé', sub: 'Sur invitation',
              active: _visibility == 'private',
              onTap: () => setState(() => _visibility = 'private'),
            )),
          ],
        ),
      ],
    );
  }

  // ── Mode de contribution ──────────────────────────────────────────────────

  Widget _buildContribMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Mode de contribution'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _ModeCard(
              emoji: '💸', title: 'Gratuit', sub: 'Aucune',
              active: _contribMode == 'gratuit',
              onTap: () => setState(() => _contribMode = 'gratuit'),
            )),
            const SizedBox(width: 8),
            Expanded(child: _ModeCard(
              emoji: '🎁', title: 'En nature', sub: '${_items.length} items',
              active: _contribMode == 'nature',
              onTap: () => setState(() => _contribMode = 'nature'),
            )),
            const SizedBox(width: 8),
            Expanded(child: _ModeCard(
              emoji: '💰', title: 'Payant', sub: 'Montant',
              active: _contribMode == 'monetaire',
              onTap: () => setState(() => _contribMode = 'monetaire'),
            )),
          ],
        ),
      ],
    );
  }

  // ── Liste d'items ─────────────────────────────────────────────────────────

  Widget _buildItemsList(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x0A1B1A2E), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Items à apporter',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: context.tpInk)),
              Semantics(
                button: true,
                label: 'Ajouter un item',
                child: GestureDetector(
                  onTap: () => _showItemDialog(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: trackpartyGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(PhosphorIcons.plus(), color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        const Text('Ajouter',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._items.asMap().entries.map((e) => _ItemRow(
            item: e.value,
            isFirst: e.key == 0,
            onTap: () => _showItemDialog(editIndex: e.key),
            onRemove: () => setState(() => _items.removeAt(e.key)),
          )),
        ],
      ),
    );
  }

  // ── Capacité ──────────────────────────────────────────────────────────────

  void _setCapacity(int value) {
    final v = value.clamp(1, 9999);
    setState(() => _capacity = v);
    _capacityCtrl.value = TextEditingValue(
      text: '$v',
      selection: TextSelection.collapsed(offset: '$v'.length),
    );
  }

  Widget _buildCapacity(BuildContext context) {
    return _CreateField(
      label: 'Capacité maximale',
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Diminuer la capacité',
            child: GestureDetector(
              onTap: () => _setCapacity(_capacity - 1),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: context.tpBg, borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: Text('−', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: context.tpInk)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _capacityCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: context.tpInk),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                suffixText: 'pers.',
                suffixStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.tpInkSub),
              ),
              onChanged: (v) {
                final n = int.tryParse(v);
                if (n != null && n > 0) setState(() => _capacity = n.clamp(1, 9999));
              },
            ),
          ),
          const SizedBox(width: 10),
          Semantics(
            button: true,
            label: 'Augmenter la capacité',
            child: GestureDetector(
              onTap: () => _setCapacity(_capacity + 1),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(gradient: trackpartyGradient, borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: const Text('+', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Co-organisateurs ──────────────────────────────────────────────────────

  void _showAddCoOrg() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CoOrgSearchSheet(
        alreadySelected: _pendingCoOrgs.map((u) => u.id).toSet(),
        onAdd: (user) {
          if (!_pendingCoOrgs.any((u) => u.id == user.id)) {
            setState(() => _pendingCoOrgs.add(user));
          }
        },
      ),
    );
  }

  Widget _buildCoOrganizers(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x0A1B1A2E), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _SectionLabel('Co-organisateurs'),
              Semantics(
                button: true,
                label: 'Inviter un co-organisateur',
                child: GestureDetector(
                  onTap: _showAddCoOrg,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: trackpartyGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(PhosphorIcons.plus(), color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        const Text('Inviter',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_pendingCoOrgs.isEmpty) ...[
            const SizedBox(height: 10),
            Text('Aucun co-organisateur ajouté.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.tpInkMute)),
          ] else ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _pendingCoOrgs.map((user) => _CoOrgChip(
                user: user,
                onRemove: () => setState(() => _pendingCoOrgs.remove(user)),
              )).toList(),
            ),
            const SizedBox(height: 6),
            Text('Les invitations seront envoyées après publication.',
              style: TextStyle(fontSize: 11, color: context.tpInkMute)),
          ],
        ],
      ),
    );
  }

  // ── Bottom CTA ────────────────────────────────────────────────────────────

  Widget _buildBottomCta(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md,
          Sp.md + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [context.tpBg.withValues(alpha: 0), context.tpBg, context.tpBg],
          stops: const [0, 0.4, 1],
        ),
      ),
      child: Row(
        children: [
          TpButton(
            label: 'Aperçu',
            variant: TpButtonVariant.outline,
            onPressed: () {},
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TpButton(
              label: 'Publier',
              icon: PhosphorIcons.check(),
              state: _publishState,
              onPressed: _publish,
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom sheet ajout/édition item ──────────────────────────────────────

  void _showItemDialog({int? editIndex}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemSheet(
        initial: editIndex != null ? _items[editIndex] : null,
        onSave: (item) {
          setState(() {
            if (editIndex != null) {
              _items[editIndex] = item;
            } else {
              _items.add(item);
            }
          });
        },
        onDelete: editIndex != null
            ? () => setState(() => _items.removeAt(editIndex))
            : null,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Composants locaux
// ════════════════════════════════════════════════════════════════════════════

// ── Sheet catégorie personnalisée ─────────────────────────────────────────────

class _CustomCategorySheet extends StatefulWidget {
  final String? initialLabel;
  final String? initialEmoji;
  final void Function(String label, String emoji) onConfirm;

  const _CustomCategorySheet({
    this.initialLabel,
    this.initialEmoji,
    required this.onConfirm,
  });

  @override
  State<_CustomCategorySheet> createState() => _CustomCategorySheetState();
}

class _CustomCategorySheetState extends State<_CustomCategorySheet> {
  late final TextEditingController _labelCtrl;
  late final TextEditingController _emojiCtrl;
  final FocusNode _emojiFocus = FocusNode();
  final FocusNode _labelFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.initialLabel ?? '');
    _emojiCtrl = TextEditingController(text: widget.initialEmoji ?? '');
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _emojiCtrl.dispose();
    _emojiFocus.dispose();
    _labelFocus.dispose();
    super.dispose();
  }

  String get _preview {
    final t = _emojiCtrl.text.trim();
    return t.isEmpty ? '✨' : t;
  }

  void _confirm() {
    final label = _labelCtrl.text.trim();
    if (label.isEmpty) return;
    widget.onConfirm(label, _emojiCtrl.text.trim().isEmpty ? '✨' : _emojiCtrl.text.trim());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.tpCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, Sp.md),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 44, height: 5,
                  decoration: BoxDecoration(
                    color: context.tpHair,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text('Créer une catégorie',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                    color: context.tpInk, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text('Choisis un emoji et donne un nom à ta catégorie.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.tpInkSub)),
              const SizedBox(height: 20),

              // Emoji preview + champ
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => _emojiFocus.requestFocus(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 76, height: 76,
                      decoration: BoxDecoration(
                        color: kPrimary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _emojiFocus.hasFocus
                              ? kPrimary
                              : kPrimary.withValues(alpha: 0.18),
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Text(
                          _preview,
                          key: ValueKey(_preview),
                          style: const TextStyle(fontSize: 40),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('EMOJI', style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w900,
                          color: context.tpInkSub, letterSpacing: 0.5,
                        )),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: context.tpBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.tpHair),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _emojiCtrl,
                                  focusNode: _emojiFocus,
                                  style: const TextStyle(fontSize: 24, height: 1.2),
                                  textInputAction: TextInputAction.next,
                                  onChanged: (_) => setState(() {}),
                                  onSubmitted: (_) => _labelFocus.requestFocus(),
                                  decoration: InputDecoration(
                                    hintText: '😀',
                                    hintStyle: TextStyle(fontSize: 24, color: context.tpInkMute),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                              Icon(Icons.emoji_emotions_outlined,
                                color: context.tpInkMute, size: 20),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Utilise le clavier emoji de ton téléphone',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                              color: context.tpInkMute),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Text('NOM DE LA CATÉGORIE', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w900,
                color: context.tpInkSub, letterSpacing: 0.5,
              )),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: context.tpBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.tpHair),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: TextField(
                  controller: _labelCtrl,
                  focusNode: _labelFocus,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.tpInk),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _confirm(),
                  decoration: InputDecoration(
                    hintText: 'ex: Mariage, Graduation, Gaming…',
                    hintStyle: TextStyle(fontSize: 14, color: context.tpInkMute),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),

              const SizedBox(height: 20),

              AnimatedBuilder(
                animation: _labelCtrl,
                builder: (_, __) => TpButton(
                  label: 'Créer "${_labelCtrl.text.trim().isEmpty ? '…' : _labelCtrl.text.trim()}"',
                  icon: PhosphorIcons.check(),
                  state: _labelCtrl.text.trim().isEmpty ? TpButtonState.disabled : TpButtonState.idle,
                  onPressed: _labelCtrl.text.trim().isEmpty ? null : _confirm,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sheet ajout/édition item de contribution ─────────────────────────────────

class _ItemSheet extends StatefulWidget {
  final _Item? initial;
  final void Function(_Item) onSave;
  final VoidCallback? onDelete;

  const _ItemSheet({this.initial, required this.onSave, this.onDelete});

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  late final TextEditingController _emojiCtrl;
  late final TextEditingController _labelCtrl;
  late int _qty;
  final FocusNode _emojiFocus = FocusNode();
  final FocusNode _labelFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _emojiCtrl = TextEditingController(text: widget.initial?.emoji ?? '');
    _labelCtrl = TextEditingController(text: widget.initial?.label ?? '');
    _qty = widget.initial?.qty ?? 5;
  }

  @override
  void dispose() {
    _emojiCtrl.dispose();
    _labelCtrl.dispose();
    _emojiFocus.dispose();
    _labelFocus.dispose();
    super.dispose();
  }

  String get _preview {
    final t = _emojiCtrl.text.trim();
    return t.isEmpty ? '❓' : t;
  }

  void _setQty(int v) => setState(() => _qty = v.clamp(1, 9999));

  void _save() {
    final label = _labelCtrl.text.trim();
    final emoji = _emojiCtrl.text.trim();
    if (label.isEmpty) return;
    widget.onSave(_Item(
      emoji: emoji.isEmpty ? '🎁' : emoji,
      label: label,
      qty:   _qty,
    ));
    Navigator.pop(context);
  }

  void _delete() {
    widget.onDelete?.call();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit  = widget.initial != null;
    final bottom  = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.tpCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, Sp.md),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 44, height: 5,
                  decoration: BoxDecoration(color: context.tpHair, borderRadius: BorderRadius.circular(3)),
                ),
              ),
              const SizedBox(height: 16),

              // Titre
              Text(
                isEdit ? 'Modifier l\'item' : 'Ajouter un item',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                    color: context.tpInk, letterSpacing: -0.5),
              ),
              const SizedBox(height: 20),

              // ── Aperçu emoji + champ ────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Grand aperçu (appuie → focus sur le champ)
                  GestureDetector(
                    onTap: () => _emojiFocus.requestFocus(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 76, height: 76,
                      decoration: BoxDecoration(
                        color: kPrimary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _emojiFocus.hasFocus
                              ? kPrimary
                              : kPrimary.withValues(alpha: 0.18),
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Text(
                          _preview,
                          key: ValueKey(_preview),
                          style: const TextStyle(fontSize: 40),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('EMOJI', style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w900,
                          color: context.tpInkSub, letterSpacing: 0.5,
                        )),
                        const SizedBox(height: 6),

                        // Champ emoji
                        Container(
                          decoration: BoxDecoration(
                            color: context.tpBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.tpHair),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _emojiCtrl,
                                  focusNode: _emojiFocus,
                                  style: const TextStyle(fontSize: 24, height: 1.2),
                                  keyboardType: TextInputType.text,
                                  textInputAction: TextInputAction.next,
                                  onChanged: (_) => setState(() {}),
                                  onSubmitted: (_) => _labelFocus.requestFocus(),
                                  decoration: InputDecoration(
                                    hintText: '😀',
                                    hintStyle: TextStyle(fontSize: 24, color: context.tpInkMute),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  // Pas de maxLength : un emoji peut valoir plusieurs code units
                                ),
                              ),
                              Icon(Icons.emoji_emotions_outlined,
                                color: context.tpInkMute, size: 20),
                            ],
                          ),
                        ),

                        const SizedBox(height: 4),
                        Text(
                          'Utilise le clavier emoji de ton téléphone 😊',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                              color: context.tpInkMute),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Nom de l'item ────────────────────────────────────────────
              Text('NOM DE L\'ITEM', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w900,
                color: context.tpInkSub, letterSpacing: 0.5,
              )),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: context.tpBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.tpHair),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: TextField(
                  controller: _labelCtrl,
                  focusNode: _labelFocus,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.tpInk),
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: 'ex: Bouteille de vin, Snacks, DJ set…',
                    hintStyle: TextStyle(fontSize: 14, color: context.tpInkMute),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Quantité ─────────────────────────────────────────────────
              Text('QUANTITÉ MAX', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w900,
                color: context.tpInkSub, letterSpacing: 0.5,
              )),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: context.tpBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.tpHair),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    _QtyBtn(
                      label: '−',
                      enabled: _qty > 1,
                      onTap: () => _setQty(_qty - 1),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '$_qty',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                              color: context.tpInk, letterSpacing: -0.5),
                        ),
                      ),
                    ),
                    _QtyBtn(
                      label: '+',
                      enabled: _qty < 9999,
                      onTap: () => _setQty(_qty + 1),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Actions ──────────────────────────────────────────────────
              Row(
                children: [
                  if (widget.onDelete != null) ...[
                    Semantics(
                      button: true,
                      label: 'Supprimer cet item',
                      child: GestureDetector(
                        onTap: _delete,
                        child: Container(
                          height: 50,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          decoration: BoxDecoration(
                            color: kError.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(
                            child: Text('Supprimer',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kError)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: TpButton(
                      label: isEdit ? 'Enregistrer' : 'Ajouter',
                      icon: isEdit ? PhosphorIcons.check() : PhosphorIcons.plus(),
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  const _QtyBtn({required this.label, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 44, height: 44,
        decoration: BoxDecoration(
          gradient: enabled ? trackpartyGradient : null,
          color: enabled ? null : context.tpHair,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w900,
            color: enabled ? Colors.white : context.tpInkMute,
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900,
        color: context.tpInkSub, letterSpacing: 0.3));
}

class _CreateField extends StatelessWidget {
  final String label;
  final Widget? extra;
  final Widget child;
  const _CreateField({required this.label, required this.child, this.extra});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x0A1B1A2E), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label.toUpperCase(),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900,
                    color: context.tpInkSub, letterSpacing: 0.3)),
              extra ?? const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _SelectCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String sub;
  final VoidCallback onTap;

  const _SelectCard({
    required this.icon, required this.iconColor,
    required this.label, required this.value,
    required this.sub, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.tpCard,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Color(0x0A1B1A2E), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, color: iconColor, size: 18),
                const SizedBox(width: 6),
                Text(label.toUpperCase(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900,
                      color: context.tpInkSub, letterSpacing: 0.3)),
              ]),
              const SizedBox(height: 6),
              Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900,
                  color: context.tpInk, letterSpacing: -0.2)),
              const SizedBox(height: 1),
              Text(sub, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: context.tpInkSub)),
            ],
          ),
        ),
      ),
    );
  }
}

class _VisCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String sub;
  final bool active;
  final VoidCallback onTap;
  const _VisCard({required this.emoji, required this.title, required this.sub,
    required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      selected: active,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: active ? trackpartyGradient : null,
            color: active ? null : context.tpCard,
            borderRadius: BorderRadius.circular(16),
            border: active ? null : Border.all(color: context.tpHair, width: 1.5),
            boxShadow: active
                ? [const BoxShadow(color: Color(0x4D7C3AED), blurRadius: 16, offset: Offset(0, 6))]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 4),
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900,
                  color: active ? Colors.white : context.tpInk)),
              const SizedBox(height: 2),
              Text(sub, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: active ? Colors.white.withValues(alpha: 0.85) : context.tpInkSub)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String sub;
  final bool active;
  final VoidCallback onTap;
  const _ModeCard({required this.emoji, required this.title, required this.sub,
    required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      selected: active,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            gradient: active ? trackpartyGradient : null,
            color: active ? null : context.tpCard,
            borderRadius: BorderRadius.circular(16),
            border: active ? null : Border.all(color: context.tpHair, width: 1.5),
            boxShadow: active
                ? [const BoxShadow(color: Color(0x4D7C3AED), blurRadius: 16, offset: Offset(0, 6))]
                : null,
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 2),
              Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900,
                  color: active ? Colors.white : context.tpInk)),
              const SizedBox(height: 1),
              Text(sub, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: active ? Colors.white.withValues(alpha: 0.85) : context.tpInkSub),
                textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _Item {
  final String emoji;
  final String label;
  final int qty;
  const _Item({required this.emoji, required this.label, required this.qty});
}

class _ItemRow extends StatelessWidget {
  final _Item item;
  final bool isFirst;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  const _ItemRow({required this.item, required this.isFirst, required this.onTap, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!isFirst) Divider(height: 1, color: context.tpHair),
        Semantics(
          button: true,
          label: 'Modifier ${item.label}',
          child: GestureDetector(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: context.tpBg, borderRadius: BorderRadius.circular(10)),
                    alignment: Alignment.center,
                    child: Text(item.emoji, style: const TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.label,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.tpInk)),
                        Text('Appuyer pour modifier',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: context.tpInkMute)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: context.tpBg, borderRadius: BorderRadius.circular(8)),
                    child: Text('×${item.qty}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: context.tpInk)),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: 'Supprimer ${item.label}',
                    child: GestureDetector(
                      onTap: onRemove,
                      child: Icon(PhosphorIcons.minusCircle(), color: kError, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CoOrgChip extends StatelessWidget {
  final UserSearchResult user;
  final VoidCallback onRemove;
  const _CoOrgChip({required this.user, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
      decoration: BoxDecoration(
        color: kPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kPrimary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TpAvatar(name: user.displayName, imageUrl: user.avatarUrl, size: 24),
          const SizedBox(width: 8),
          Text(user.displayName,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kPrimary)),
          if (user.isPromoter) ...[
            const SizedBox(width: 4),
            const Text('⭐', style: TextStyle(fontSize: 10)),
          ],
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Retirer ${user.displayName}',
            child: GestureDetector(
              onTap: onRemove,
              child: Icon(PhosphorIcons.x(), color: kPrimary, size: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Recherche de co-organisateurs ─────────────────────────────────────────────

class _CoOrgSearchSheet extends ConsumerStatefulWidget {
  final Set<String> alreadySelected;
  final void Function(UserSearchResult) onAdd;

  const _CoOrgSearchSheet({
    required this.alreadySelected,
    required this.onAdd,
  });

  @override
  ConsumerState<_CoOrgSearchSheet> createState() => _CoOrgSearchSheetState();
}

class _CoOrgSearchSheetState extends ConsumerState<_CoOrgSearchSheet> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<UserSearchResult> _results = [];
  bool _searching = false;
  final Set<String> _justAdded = {};

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String q) async {
    if (q.trim().length < 2) {
      setState(() { _results = []; _searching = false; });
      return;
    }
    setState(() => _searching = true);
    try {
      final res = await ref.read(invitationServiceProvider).searchUsers(q.trim());
      if (mounted) setState(() { _results = res; _searching = false; });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _add(UserSearchResult user) {
    widget.onAdd(user);
    setState(() => _justAdded.add(user.id));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${user.displayName} ajouté comme co-organisateur ✓'),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: kSuccess,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        Sp.md, 12, Sp.md,
        Sp.md + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 44, height: 5,
                decoration: BoxDecoration(
                  color: context.tpHair,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Titre
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Inviter un co-organisateur',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                            color: context.tpInk, letterSpacing: -0.5)),
                      const SizedBox(height: 2),
                      Text('Recherche par nom ou email',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                            color: context.tpInkSub)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Champ de recherche
            Container(
              decoration: BoxDecoration(
                color: context.tpBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.tpHair),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Icon(PhosphorIcons.magnifyingGlass(), color: context.tpInkMute, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      autofocus: true,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.tpInk),
                      decoration: InputDecoration(
                        hintText: 'Nom ou adresse email…',
                        hintStyle: TextStyle(fontSize: 14, color: context.tpInkMute, fontWeight: FontWeight.w500),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onChanged: _onSearch,
                    ),
                  ),
                  if (_searching)
                    const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: kPrimary),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Résultats
            if (_results.isEmpty && _ctrl.text.length >= 2 && !_searching)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text('Aucun utilisateur trouvé',
                  style: TextStyle(fontSize: 14, color: context.tpInkSub,
                      fontWeight: FontWeight.w600)),
              )
            else if (_results.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('Tape un nom ou un email pour chercher…',
                  style: TextStyle(fontSize: 13, color: context.tpInkMute,
                      fontWeight: FontWeight.w600)),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.40,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: context.tpHair),
                  itemBuilder: (_, i) {
                    final user    = _results[i];
                    final added   = _justAdded.contains(user.id) ||
                        widget.alreadySelected.contains(user.id);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          TpAvatar(
                            name: user.displayName,
                            imageUrl: user.avatarUrl,
                            size: 44,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user.displayName,
                                  style: TextStyle(fontSize: 14,
                                      fontWeight: FontWeight.w900, color: context.tpInk)),
                                if (user.isPromoter)
                                  Text('⭐ Promoteur',
                                    style: TextStyle(fontSize: 11,
                                        fontWeight: FontWeight.w700, color: kPrimary)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: added ? null : () => _add(user),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: added ? null : trackpartyGradient,
                                color: added ? context.tpHair : null,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                added ? '✓ Ajouté' : 'Ajouter',
                                style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w800,
                                  color: added ? context.tpInkMute : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _LocationActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool loading;
  final VoidCallback onTap;
  const _LocationActionBtn({
    required this.icon, required this.label, required this.onTap, this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: loading ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            color: kPrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: loading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: kPrimary),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: kPrimary, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800, color: kPrimary,
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

// Champ texte utilisé dans le bottom sheet de localisation
class _LocationField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  const _LocationField({required this.ctrl, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.text,
      style: TextStyle(fontSize: 14, color: context.tpInk),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 12, color: context.tpInkSub),
        filled: true,
        fillColor: context.tpBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
    );
  }
}

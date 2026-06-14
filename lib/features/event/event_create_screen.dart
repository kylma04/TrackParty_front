import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'dart:async';

import '../../core/api/api_exception.dart';
import '../../core/models/chat_model.dart';
import '../../core/models/event_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/cloudinary_service.dart';
import '../../core/services/co_organizer_service.dart';
import '../../core/services/event_service.dart';
import '../../core/services/invitation_service.dart';
import '../../widgets/event_preview_sheet.dart';
import 'location_picker_screen.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_avatar.dart';
import '../../widgets/tp_button.dart';

// ════════════════════════════════════════════════════════════════════════════
// Écran principal — stepper 3 étapes
// ════════════════════════════════════════════════════════════════════════════

class EventCreateScreen extends ConsumerStatefulWidget {
  final EventModel? initialEvent;
  final bool isClone;

  const EventCreateScreen({super.key, this.initialEvent, this.isClone = false});

  bool get isEditing => initialEvent != null && !isClone;

  @override
  ConsumerState<EventCreateScreen> createState() => _EventCreateScreenState();
}

class _EventCreateScreenState extends ConsumerState<EventCreateScreen> {
  final PageController _pageCtrl = PageController();
  int _step = 0; // 0, 1, 2

  // ── Champs ────────────────────────────────────────────────────────────────
  final _titleCtrl    = TextEditingController();
  final _descCtrl     = TextEditingController();
  final _capacityCtrl = TextEditingController(text: '80');
  final _minAgeCtrl = TextEditingController();

  String? _category;
  String? _customCategoryLabel;
  String? _customCategoryEmoji;
  String  _visibility  = 'public';
  String  _contribMode = 'gratuit';
  int     _capacity    = 80;
  int? _minAge;

  DateTime? _startAt;
  DateTime? _endAt;

  String _addressLabel = '';
  String _city         = 'Abidjan';
  String _quartier     = '';
  double _lat          = 5.3484;
  double _lng          = -4.0168;

  TpButtonState _publishState = TpButtonState.idle;

  String? _coverUrl;
  bool    _coverLoading = false;

  final List<UserSearchResult> _pendingCoOrgs = [];

  final List<_Item> _items = [
    _Item(emoji: '🍾', label: 'Bouteille (vin/spiritueux)', qty: 50),
    _Item(emoji: '🍰', label: 'Plat sucré ou snack',       qty: 12),
    _Item(emoji: '🎧', label: 'Sono / DJ set',             qty: 1),
  ];

  static const _categories = [
    ('musique', '🎵', 'Musique',  kSecondary),
    ('soiree',  '🎉', 'Soirée',   kTertiary),
    ('cuisine', '🍽', 'Cuisine',  kAccent),
    ('sport',   '⚽', 'Sport',    kInfo),
    ('art',     '🎨', 'Art',      kCategoryArt),
    ('plage',   '🏖', 'Plage',    kWarning),
  ];

  // ── Init ──────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final ev = widget.initialEvent;
    if (ev != null) {
      _titleCtrl.text      = widget.isClone ? 'Copie de ${ev.title}' : ev.title;
      _descCtrl.text       = ev.description ?? '';
      _category            = ev.category;
      _customCategoryLabel = ev.customCategoryLabel;
      _customCategoryEmoji = ev.customCategoryEmoji;
      _visibility          = ev.visibility;
      _contribMode         = ev.contributionType;
      _capacity            = ev.maxParticipants ?? 80;
      _capacityCtrl.text   = _capacity.toString();
      _minAge = ev.minAge;
      if (_minAge != null) {
        _minAgeCtrl.text = _minAge.toString();
      }
      if (!widget.isClone) {
        _startAt = ev.startAt;
        _endAt   = ev.endAt;
      }
      _addressLabel = ev.addressLabel;
      _city         = ev.city;
      _quartier     = ev.quartier;
      _lat          = ev.latitude  ?? 5.3484;
      _lng          = ev.longitude ?? -4.0168;
      _coverUrl     = ev.coverImageUrl;
      if (ev.contributionItems.isNotEmpty) {
        _items.clear();
        _items.addAll(ev.contributionItems.map(
          (i) => _Item(emoji: i.emoji, label: i.name, qty: i.quantityTotal),
        ));
      }
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _capacityCtrl.dispose();
    _minAgeCtrl.dispose();
    super.dispose();
  }

  // ── Navigation entre étapes ───────────────────────────────────────────────

  void _goToStep(int step) {
    setState(() => _step = step);
    _pageCtrl.animateToPage(
      step,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  /// Validation partielle selon l'étape
  String? _validateStep(int step) {
    if (step == 0) {
      if (_titleCtrl.text.trim().isEmpty) return 'Le titre est obligatoire.';
      if (_category == null) return 'Choisis une catégorie.';
    }
    if (step == 1) {
      if (_startAt == null) return 'Choisis une date et heure.';
      if (_contribMode == 'nature' && _items.isEmpty) {
        return 'Ajoute au moins un item de contribution.';
      }
    }
    return null;
  }

  void _nextStep() {
    final error = _validateStep(_step);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: kError),
      );
      return;
    }
    if (_step < 2) _goToStep(_step + 1);
  }

  void _prevStep() {
    if (_step > 0) _goToStep(_step - 1);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmtDate(DateTime dt) => DateFormat('EEE d MMM', 'fr_FR').format(dt);
  String _fmtTime(DateTime dt) => DateFormat('HH:mm').format(dt);
  String _fmtFull(DateTime dt) => DateFormat('EEE d MMM · HH:mm', 'fr_FR').format(dt);

  String get _locationLabel => _addressLabel.isNotEmpty ? _addressLabel : 'Lieu non défini';
  String get _locationSub   => _quartier.isNotEmpty ? '$_quartier, $_city' : _city;

  String get _categoryLabel {
    if (_category == 'autre') return _customCategoryLabel ?? 'Personnalisé';
    final found = _categories.where((c) => c.$1 == _category);
    if (found.isEmpty) return 'Non défini';
    return '${found.first.$2} ${found.first.$3}';
  }

  String get _contribLabel {
    switch (_contribMode) {
      case 'gratuit':   return '💸 Gratuit';
      case 'nature':    return '🎁 En nature (${_items.length} items)';
      case 'monetaire': return '💰 Payant';
      default:          return _contribMode;
    }
  }

  // ── Date/time picker ──────────────────────────────────────────────────────

  Future<void> _pickDateTime({required bool isEnd}) async {
    final now = DateTime.now();
    final initial = isEnd
        ? (_endAt ?? _startAt?.add(const Duration(hours: 5)) ?? now)
        : (_startAt ?? now);

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
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.cardLg)),
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
                            if (mounted) setState(() { _lat = pos.latitude; _lng = pos.longitude; });
                          }
                        } catch (_) {}
                        if (ctx.mounted) setSheet(() => gpsLoading = false);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _LocationActionBtn(
                      icon: PhosphorIcons.mapTrifold(),
                      label: 'Choisir sur la carte',
                      onTap: () async {
                        final result = await context.push<LocationPickerResult>(
                          '/location-picker',
                          extra: {'lat': _lat, 'lng': _lng},
                        );
                        if (result != null && mounted) {
                          setState(() { _lat = result.lat; _lng = result.lng; });
                          if (ctx.mounted) setSheet(() {});
                        }
                      },
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: ctx.tpBg, borderRadius: BorderRadius.circular(Radii.tag)),
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

  // ── Capacité ──────────────────────────────────────────────────────────────

  void _setCapacity(int value) {
    final v = value.clamp(1, 9999);
    setState(() => _capacity = v);
    _capacityCtrl.value = TextEditingValue(
      text: '$v',
      selection: TextSelection.collapsed(offset: '$v'.length),
    );
  }

  // ── Publish ───────────────────────────────────────────────────────────────

  Future<void> _publish() async {
    final authState = ref.read(authNotifierProvider).valueOrNull;
    final user = authState is AuthAuthenticated ? authState.user : null;

    if (!widget.isEditing && user?.identityVerificationStatus != 'approved') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vous devez vérifier votre identité avant de créer un événement.',
          ),
          backgroundColor: kError,
        ),
      );
      context.push('/identity-verification');
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
        if (_minAge != null) 'min_age': _minAge,
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

      final svc = ref.read(eventServiceProvider);
      final EventModel event;
      if (widget.isEditing) {
        event = await svc.updateEvent(widget.initialEvent!.id, data);
      } else {
        event = await svc.createEvent(data);
      }

      if (!widget.isEditing && _pendingCoOrgs.isNotEmpty) {
        final coOrgSvc = ref.read(coOrganizerServiceProvider);
        for (final coOrg in _pendingCoOrgs) {
          try { await coOrgSvc.invite(event.id, coOrg.id); } catch (_) {}
        }
      }

      if (mounted) {
        setState(() => _publishState = TpButtonState.idle);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEditing ? 'Événement mis à jour !' : 'Événement publié !'),
            backgroundColor: kSuccess,
          ),
        );
        if (widget.isEditing) context.pop();
        else context.go('/feed');
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

  // ── Preview ───────────────────────────────────────────────────────────────

  void _showPreview() {
    final authState = ref.read(authNotifierProvider).valueOrNull;
    final me = authState is AuthAuthenticated ? authState.user : null;
    showEventPreviewSheet(
      context,
      title:               _titleCtrl.text.trim(),
      description:         _descCtrl.text.trim(),
      category:            _category,
      customCategoryLabel: _customCategoryLabel,
      customCategoryEmoji: _customCategoryEmoji,
      coverUrl:            _coverUrl,
      startAt:             _startAt,
      endAt:               _endAt,
      addressLabel:        _addressLabel,
      city:                _city,
      quartier:            _quartier,
      visibility:          _visibility,
      contribMode:         _contribMode,
      capacity:            _capacity,
      organizerName:       me?.displayName ?? 'Moi',
      organizerAvatarUrl:  me?.avatarUrl,
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // Build
  // ════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tpBg,
      body: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),
          _buildHeader(context),
          _buildStepIndicator(context),
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1(context),
                _buildStep2(context),
                _buildStep3(context),
              ],
            ),
          ),
          _buildBottomNav(context),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    const titles = ['Infos générales', 'Détails pratiques', 'Récap & publication'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, 4),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: _step == 0 ? 'Fermer' : 'Étape précédente',
            child: GestureDetector(
              onTap: _step == 0 ? () => context.pop() : _prevStep,
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: context.tpCard,
                  borderRadius: BorderRadius.circular(Radii.md),
                  boxShadow: Shadows.sm,
                ),
                child: Icon(
                  _step == 0 ? PhosphorIcons.x() : PhosphorIcons.arrowLeft(),
                  color: context.tpInk, size: 18,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              titles[_step],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w900,
                color: context.tpInk, letterSpacing: -0.4,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: kPrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(Radii.tag),
            ),
            child: Text(
              '${_step + 1} / 3',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kPrimary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step indicator ────────────────────────────────────────────────────────

  Widget _buildStepIndicator(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 8, Sp.md, 4),
      child: Row(
        children: List.generate(3, (i) {
          final done   = i < _step;
          final active = i == _step;
          return Expanded(
            child: GestureDetector(
              onTap: done ? () => _goToStep(i) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 4,
                margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: active || done ? trackpartyGradient : null,
                  color: (active || done) ? null : context.tpHair,
                  boxShadow: active
                      ? [const BoxShadow(color: Color(0x337C3AED), blurRadius: 8, offset: Offset(0, 2))]
                      : null,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // Étape 1 — Titre · Description · Catégorie · Photo
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildStep1(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, 24),
      child: Column(
        children: [
          _buildCoverPhoto(context),
          const SizedBox(height: 14),
          _buildTitleField(context),
          const SizedBox(height: 14),
          _buildDescField(context),
          const SizedBox(height: 14),
          _buildCategories(context),
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
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: kPrimary.withValues(alpha: 0.33), width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: _coverUrl != null
              ? Stack(fit: StackFit.expand, children: [
                  CachedNetworkImage(imageUrl: _coverUrl!, fit: BoxFit.cover),
                  if (_coverLoading)
                    Container(
                      color: Colors.black54,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    ),
                  Positioned(
                    bottom: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(Radii.tag),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(PhosphorIcons.camera(), color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        const Text('Changer',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                      ]),
                    ),
                  ),
                ])
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
          border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
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
            border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero, counterText: '',
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
                      borderRadius: BorderRadius.circular(Radii.md),
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
            // Personnaliser
            Semantics(
              button: true,
              label: isCustomActive ? 'Catégorie personnalisée' : 'Créer une catégorie',
              selected: isCustomActive,
              child: GestureDetector(
                onTap: () => _showCustomCategorySheet(context),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isCustomActive ? trackpartyGradient : null,
                    color: isCustomActive ? null : context.tpCard,
                    borderRadius: BorderRadius.circular(Radii.md),
                    border: isCustomActive
                        ? null
                        : Border.all(color: kPrimary.withValues(alpha: 0.4), width: 1.5),
                    boxShadow: isCustomActive
                        ? [const BoxShadow(color: Color(0x407C3AED), blurRadius: 14, offset: Offset(0, 6))]
                        : null,
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(isCustomActive ? (_customCategoryEmoji ?? '✨') : '✏️',
                      style: const TextStyle(fontSize: 15)),
                    const SizedBox(width: 6),
                    Text(
                      isCustomActive ? _customCategoryLabel! : 'Personnaliser',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                          color: isCustomActive ? Colors.white : kPrimary),
                    ),
                    if (isCustomActive) ...[
                      const SizedBox(width: 4),
                      Icon(PhosphorIcons.pencilSimple(), size: 12, color: Colors.white.withValues(alpha: 0.8)),
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

  // ════════════════════════════════════════════════════════════════════════
  // Étape 2 — Date · Lieu · Visibilité · Contribution · Capacité · Co-orgs
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildStep2(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, 24),
      child: Column(
        children: [
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
          _buildMinAge(context),
          const SizedBox(height: 14),
          _buildCoOrganizers(context),
        ],
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
        Row(children: [
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
        ]),
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
        Row(children: [
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
        ]),
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
                button: true, label: 'Ajouter un item',
                child: GestureDetector(
                  onTap: () => _showItemDialog(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(gradient: trackpartyGradient, borderRadius: BorderRadius.circular(Radii.tag)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(PhosphorIcons.plus(), color: Colors.white, size: 12),
                      const SizedBox(width: 4),
                      const Text('Ajouter', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                    ]),
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

  void _showItemDialog({int? editIndex}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemSheet(
        initial: editIndex != null ? _items[editIndex] : null,
        onSave: (item) {
          setState(() {
            if (editIndex != null) _items[editIndex] = item;
            else _items.add(item);
          });
        },
        onDelete: editIndex != null ? () => setState(() => _items.removeAt(editIndex)) : null,
      ),
    );
  }

  // ── Capacité ──────────────────────────────────────────────────────────────

  Widget _buildCapacity(BuildContext context) {
    return _CreateField(
      label: 'Capacité maximale',
      child: Row(
        children: [
          Semantics(
            button: true, label: 'Diminuer la capacité',
            child: GestureDetector(
              onTap: () => _setCapacity(_capacity - 1),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: context.tpBg, borderRadius: BorderRadius.circular(Radii.md)),
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
                border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
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
            button: true, label: 'Augmenter la capacité',
            child: GestureDetector(
              onTap: () => _setCapacity(_capacity + 1),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(gradient: trackpartyGradient, borderRadius: BorderRadius.circular(Radii.md)),
                alignment: Alignment.center,
                child: const Text('+', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinAge(BuildContext context) {
  return _CreateField(
    label: 'Âge minimum',
    child: TextField(
      controller: _minAgeCtrl,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: context.tpInk,
      ),
      decoration: InputDecoration(
        hintText: 'Ex: 18',
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
        suffixText: 'ans',
        suffixStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: context.tpInkSub,
        ),
      ),
      onChanged: (v) {
        final n = int.tryParse(v);
        setState(() {
          _minAge = n != null && n > 0 ? n : null;
        });
      },
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
                button: true, label: 'Inviter un co-organisateur',
                child: GestureDetector(
                  onTap: _showAddCoOrg,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(gradient: trackpartyGradient, borderRadius: BorderRadius.circular(Radii.tag)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(PhosphorIcons.plus(), color: Colors.white, size: 12),
                      const SizedBox(width: 4),
                      const Text('Inviter', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                    ]),
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

  // ════════════════════════════════════════════════════════════════════════
  // Étape 3 — Récap & publication
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildStep3(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bandeau cover
          if (_coverUrl != null)
            Container(
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.card),
                boxShadow: Shadows.sm,
              ),
              clipBehavior: Clip.antiAlias,
              child: CachedNetworkImage(imageUrl: _coverUrl!, fit: BoxFit.cover, width: double.infinity),
            )
          else
            Container(
              height: 100,
              decoration: BoxDecoration(
                gradient: gradientSoft,
                borderRadius: BorderRadius.circular(Radii.card),
                border: Border.all(color: kPrimary.withValues(alpha: 0.2), width: 1.5),
              ),
              alignment: Alignment.center,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(PhosphorIcons.image(), color: kPrimary.withValues(alpha: 0.4), size: 32),
                const SizedBox(height: 4),
                Text('Aucune photo de couverture',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.tpInkMute)),
              ]),
            ),

          const SizedBox(height: 16),

          // Titre + catégorie
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.tpCard,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Color(0x0A1B1A2E), blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _RecapRow(
                icon: PhosphorIcons.textT(),
                label: 'Titre',
                value: _titleCtrl.text.trim().isEmpty ? 'Non défini' : _titleCtrl.text.trim(),
                valueStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: context.tpInk),
              ),
              if (_descCtrl.text.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                _RecapRow(
                  icon: PhosphorIcons.alignLeft(),
                  label: 'Description',
                  value: _descCtrl.text.trim(),
                  maxLines: 3,
                ),
              ],
              const SizedBox(height: 12),
              _RecapRow(
                icon: PhosphorIcons.tag(),
                label: 'Catégorie',
                value: _categoryLabel,
              ),
            ]),
          ),

          const SizedBox(height: 12),

          // Date & Lieu
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.tpCard,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Color(0x0A1B1A2E), blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _RecapRow(
                icon: PhosphorIcons.calendar(),
                label: 'Début',
                value: _startAt != null ? _fmtFull(_startAt!) : '⚠️ Non défini',
                valueColor: _startAt == null ? kError : null,
              ),
              if (_endAt != null) ...[
                const SizedBox(height: 12),
                _RecapRow(
                  icon: PhosphorIcons.calendarCheck(),
                  label: 'Fin',
                  value: _fmtFull(_endAt!),
                ),
              ],
              const SizedBox(height: 12),
              _RecapRow(
                icon: PhosphorIcons.mapPin(),
                label: 'Lieu',
                value: _addressLabel.isNotEmpty ? _addressLabel : 'Non précisé',
                sub: _quartier.isNotEmpty ? '$_quartier, $_city' : _city,
              ),
            ]),
          ),

          const SizedBox(height: 12),

          // Paramètres
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.tpCard,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Color(0x0A1B1A2E), blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _RecapRow(
                icon: PhosphorIcons.eye(),
                label: 'Visibilité',
                value: _visibility == 'public' ? '🌍 Public' : '🔒 Privé',
              ),
              const SizedBox(height: 12),
              _RecapRow(
                icon: PhosphorIcons.gift(),
                label: 'Contribution',
                value: _contribLabel,
              ),
              const SizedBox(height: 12),
              _RecapRow(
                icon: PhosphorIcons.users(),
                label: 'Capacité max',
                value: '$_capacity participants',
              ),
              if (_pendingCoOrgs.isNotEmpty) ...[
                const SizedBox(height: 12),
                _RecapRow(
                  icon: PhosphorIcons.userPlus(),
                  label: 'Co-organisateurs',
                  value: _pendingCoOrgs.map((u) => u.displayName).join(', '),
                ),
              ],
            ]),
          ),

          // Items contribution si nature
          if (_contribMode == 'nature' && _items.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.tpCard,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [BoxShadow(color: Color(0x0A1B1A2E), blurRadius: 8, offset: Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(PhosphorIcons.package(), color: kPrimary, size: 16),
                    const SizedBox(width: 8),
                    Text('Items à apporter',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: context.tpInkSub)),
                  ]),
                  const SizedBox(height: 10),
                  ..._items.asMap().entries.map((e) => Padding(
                    padding: EdgeInsets.only(top: e.key > 0 ? 8 : 0),
                    child: Row(children: [
                      Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(color: context.tpBg, borderRadius: BorderRadius.circular(Radii.tag)),
                        alignment: Alignment.center,
                        child: Text(e.value.emoji, style: const TextStyle(fontSize: 15)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(e.value.label,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.tpInk)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: context.tpBg, borderRadius: BorderRadius.circular(Radii.sm)),
                        child: Text('×${e.value.qty}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: context.tpInkSub)),
                      ),
                    ]),
                  )),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Avertissement si données manquantes
          if (_startAt == null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kError.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(color: kError.withValues(alpha: 0.25)),
              ),
              child: Row(children: [
                Icon(PhosphorIcons.warningCircle(), color: kError, size: 18),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('La date de début est obligatoire.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kError)),
                ),
              ]),
            ),
        ],
      ),
    );
  }

  // ── Bottom nav ────────────────────────────────────────────────────────────

  Widget _buildBottomNav(BuildContext context) {
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
          // Aperçu disponible à l'étape 3
          if (_step == 2) ...[
            TpButton(
              label: 'Aperçu',
              variant: TpButtonVariant.outline,
              onPressed: _showPreview,
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: _step < 2
                ? TpButton(
                    label: _step == 0 ? 'Suivant : Détails pratiques' : 'Suivant : Récap',
                    icon: PhosphorIcons.arrowRight(),
                    onPressed: _nextStep,
                  )
                : TpButton(
                    label: widget.isEditing ? 'Enregistrer' : widget.isClone ? 'Dupliquer' : 'Publier',
                    icon: PhosphorIcons.rocketLaunch(),
                    state: _publishState,
                    onPressed: _startAt == null ? null : _publish,
                  ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Widget _RecapRow — ligne dans le récap
// ════════════════════════════════════════════════════════════════════════════

class _RecapRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final int maxLines;
  final TextStyle? valueStyle;
  final Color? valueColor;

  const _RecapRow({
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
    this.maxLines = 2,
    this.valueStyle,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: kPrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(Radii.tag),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: kPrimary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900,
                    color: context.tpInkSub, letterSpacing: 0.4),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: valueStyle ?? TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: valueColor ?? context.tpInk,
                ),
              ),
              if (sub != null) ...[
                const SizedBox(height: 1),
                Text(sub!,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.tpInkSub)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Composants locaux (identiques à l'original)
// ════════════════════════════════════════════════════════════════════════════

class _CustomCategorySheet extends StatefulWidget {
  final String? initialLabel;
  final String? initialEmoji;
  final void Function(String label, String emoji) onConfirm;
  const _CustomCategorySheet({this.initialLabel, this.initialEmoji, required this.onConfirm});
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
    _labelCtrl.dispose(); _emojiCtrl.dispose();
    _emojiFocus.dispose(); _labelFocus.dispose();
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        ),
        padding: const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, Sp.md),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 44, height: 5,
                decoration: BoxDecoration(color: context.tpHair, borderRadius: BorderRadius.circular(3)))),
              const SizedBox(height: 16),
              Text('Créer une catégorie',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: context.tpInk, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text('Choisis un emoji et donne un nom à ta catégorie.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.tpInkSub)),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Semantics(
                    button: true, label: 'Sélectionner un emoji',
                    child: GestureDetector(
                      onTap: () => _emojiFocus.requestFocus(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 76, height: 76,
                        decoration: BoxDecoration(
                          color: kPrimary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(Radii.card),
                          border: Border.all(
                            color: _emojiFocus.hasFocus ? kPrimary : kPrimary.withValues(alpha: 0.18),
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Text(_preview, key: ValueKey(_preview), style: const TextStyle(fontSize: 40)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('EMOJI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900,
                            color: context.tpInkSub, letterSpacing: 0.5)),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(color: context.tpBg,
                              borderRadius: BorderRadius.circular(Radii.md),
                              border: Border.all(color: context.tpHair)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Row(children: [
                            Expanded(
                              child: TextField(
                                controller: _emojiCtrl, focusNode: _emojiFocus,
                                style: const TextStyle(fontSize: 24, height: 1.2),
                                textInputAction: TextInputAction.next,
                                onChanged: (_) => setState(() {}),
                                onSubmitted: (_) => _labelFocus.requestFocus(),
                                decoration: InputDecoration(
                                  hintText: '😀',
                                  hintStyle: TextStyle(fontSize: 24, color: context.tpInkMute),
                                  border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            Icon(Icons.emoji_emotions_outlined, color: context.tpInkMute, size: 20),
                          ]),
                        ),
                        const SizedBox(height: 4),
                        Text('Utilise le clavier emoji de ton téléphone',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: context.tpInkMute)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('NOM DE LA CATÉGORIE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900,
                  color: context.tpInkSub, letterSpacing: 0.5)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(color: context.tpBg,
                    borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: context.tpHair)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: TextField(
                  controller: _labelCtrl, focusNode: _labelFocus, autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.tpInk),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _confirm(),
                  decoration: InputDecoration(
                    hintText: 'ex: Mariage, Graduation, Gaming…',
                    hintStyle: TextStyle(fontSize: 14, color: context.tpInkMute),
                    border: InputBorder.none, isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 20),
              AnimatedBuilder(
                animation: _labelCtrl,
                builder: (_, _) => TpButton(
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
    _emojiCtrl.dispose(); _labelCtrl.dispose();
    _emojiFocus.dispose(); _labelFocus.dispose();
    super.dispose();
  }

  String get _preview { final t = _emojiCtrl.text.trim(); return t.isEmpty ? '❓' : t; }
  void _setQty(int v) => setState(() => _qty = v.clamp(1, 9999));

  void _save() {
    final label = _labelCtrl.text.trim();
    final emoji = _emojiCtrl.text.trim();
    if (label.isEmpty) return;
    widget.onSave(_Item(emoji: emoji.isEmpty ? '🎁' : emoji, label: label, qty: _qty));
    Navigator.pop(context);
  }

  void _delete() { widget.onDelete?.call(); Navigator.pop(context); }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.tpCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        ),
        padding: const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, Sp.md),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 44, height: 5,
                decoration: BoxDecoration(color: context.tpHair, borderRadius: BorderRadius.circular(3)))),
              const SizedBox(height: 16),
              Text(isEdit ? 'Modifier l\'item' : 'Ajouter un item',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: context.tpInk, letterSpacing: -0.5)),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Semantics(
                    button: true, label: 'Sélectionner un emoji',
                    child: GestureDetector(
                      onTap: () => _emojiFocus.requestFocus(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 76, height: 76,
                        decoration: BoxDecoration(
                          color: kPrimary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(Radii.card),
                          border: Border.all(
                            color: _emojiFocus.hasFocus ? kPrimary : kPrimary.withValues(alpha: 0.18),
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Text(_preview, key: ValueKey(_preview), style: const TextStyle(fontSize: 40)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('EMOJI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900,
                            color: context.tpInkSub, letterSpacing: 0.5)),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(color: context.tpBg,
                              borderRadius: BorderRadius.circular(Radii.md),
                              border: Border.all(color: context.tpHair)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Row(children: [
                            Expanded(
                              child: TextField(
                                controller: _emojiCtrl, focusNode: _emojiFocus,
                                style: const TextStyle(fontSize: 24, height: 1.2),
                                keyboardType: TextInputType.text,
                                textInputAction: TextInputAction.next,
                                onChanged: (_) => setState(() {}),
                                onSubmitted: (_) => _labelFocus.requestFocus(),
                                decoration: InputDecoration(
                                  hintText: '😀',
                                  hintStyle: TextStyle(fontSize: 24, color: context.tpInkMute),
                                  border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            Icon(Icons.emoji_emotions_outlined, color: context.tpInkMute, size: 20),
                          ]),
                        ),
                        const SizedBox(height: 4),
                        Text('Utilise le clavier emoji de ton téléphone 😊',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: context.tpInkMute)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('NOM DE L\'ITEM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900,
                  color: context.tpInkSub, letterSpacing: 0.5)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(color: context.tpBg,
                    borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: context.tpHair)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: TextField(
                  controller: _labelCtrl, focusNode: _labelFocus,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.tpInk),
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: 'ex: Bouteille de vin, Snacks, DJ set…',
                    hintStyle: TextStyle(fontSize: 14, color: context.tpInkMute),
                    border: InputBorder.none, isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('QUANTITÉ MAX', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900,
                  color: context.tpInkSub, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(color: context.tpBg,
                    borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: context.tpHair)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(children: [
                  _QtyBtn(label: '−', enabled: _qty > 1, onTap: () => _setQty(_qty - 1)),
                  Expanded(child: Center(child: Text('$_qty',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                        color: context.tpInk, letterSpacing: -0.5)))),
                  _QtyBtn(label: '+', enabled: _qty < 9999, onTap: () => _setQty(_qty + 1)),
                ]),
              ),
              const SizedBox(height: 24),
              Row(children: [
                if (widget.onDelete != null) ...[
                  Semantics(
                    button: true, label: 'Supprimer cet item',
                    child: GestureDetector(
                      onTap: _delete,
                      child: Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(
                          color: kError.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(Radii.button),
                        ),
                        child: const Center(child: Text('Supprimer',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kError))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(child: TpButton(
                  label: isEdit ? 'Enregistrer' : 'Ajouter',
                  icon: isEdit ? PhosphorIcons.check() : PhosphorIcons.plus(),
                  onPressed: _save,
                )),
              ]),
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
    return Semantics(
      button: true, label: label,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: enabled ? trackpartyGradient : null,
            color: enabled ? null : context.tpHair,
            borderRadius: BorderRadius.circular(Radii.tag),
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
              color: enabled ? Colors.white : context.tpInkMute)),
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
  const _SelectCard({required this.icon, required this.iconColor, required this.label,
    required this.value, required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true, label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.tpCard,
            borderRadius: BorderRadius.circular(Radii.lg),
            boxShadow: const [BoxShadow(color: Color(0x0A1B1A2E), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          ]),
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
      button: true, label: title, selected: active,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: active ? trackpartyGradient : null,
            color: active ? null : context.tpCard,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: active ? null : Border.all(color: context.tpHair, width: 1.5),
            boxShadow: active
                ? [const BoxShadow(color: Color(0x4D7C3AED), blurRadius: 16, offset: Offset(0, 6))]
                : null,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900,
                color: active ? Colors.white : context.tpInk)),
            const SizedBox(height: 2),
            Text(sub, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: active ? Colors.white.withValues(alpha: 0.85) : context.tpInkSub)),
          ]),
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
      button: true, label: title, selected: active,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            gradient: active ? trackpartyGradient : null,
            color: active ? null : context.tpCard,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: active ? null : Border.all(color: context.tpHair, width: 1.5),
            boxShadow: active
                ? [const BoxShadow(color: Color(0x4D7C3AED), blurRadius: 16, offset: Offset(0, 6))]
                : null,
          ),
          child: Column(children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 2),
            Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900,
                color: active ? Colors.white : context.tpInk)),
            const SizedBox(height: 1),
            Text(sub, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                color: active ? Colors.white.withValues(alpha: 0.85) : context.tpInkSub),
              textAlign: TextAlign.center),
          ]),
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
    return Column(children: [
      if (!isFirst) Divider(height: 1, color: context.tpHair),
      Semantics(
        button: true, label: 'Modifier ${item.label}',
        child: GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: context.tpBg, borderRadius: BorderRadius.circular(Radii.tag)),
                alignment: Alignment.center,
                child: Text(item.emoji, style: const TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.label,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.tpInk)),
                Text('Appuyer pour modifier',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: context.tpInkMute)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: context.tpBg, borderRadius: BorderRadius.circular(Radii.sm)),
                child: Text('×${item.qty}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: context.tpInk)),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true, label: 'Supprimer ${item.label}',
                child: GestureDetector(
                  onTap: onRemove,
                  child: Icon(PhosphorIcons.minusCircle(), color: kError, size: 20),
                ),
              ),
            ]),
          ),
        ),
      ),
    ]);
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
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: kPrimary.withValues(alpha: 0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
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
          button: true, label: 'Retirer ${user.displayName}',
          child: GestureDetector(
            onTap: onRemove,
            child: Icon(PhosphorIcons.x(), color: kPrimary, size: 14),
          ),
        ),
      ]),
    );
  }
}

class _CoOrgSearchSheet extends ConsumerStatefulWidget {
  final Set<String> alreadySelected;
  final void Function(UserSearchResult) onAdd;
  const _CoOrgSearchSheet({required this.alreadySelected, required this.onAdd});
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
  void dispose() { _ctrl.dispose(); _debounce?.cancel(); super.dispose(); }

  void _onSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String q) async {
    if (q.trim().length < 2) { setState(() { _results = []; _searching = false; }); return; }
    setState(() => _searching = true);
    try {
      final res = await ref.read(invitationServiceProvider).searchUsers(q.trim());
      if (mounted) setState(() { _results = res; _searching = false; });
    } catch (_) { if (mounted) setState(() => _searching = false); }
  }

  void _add(UserSearchResult user) {
    widget.onAdd(user);
    setState(() => _justAdded.add(user.id));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${user.displayName} ajouté comme co-organisateur ✓'),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
      backgroundColor: kSuccess,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
      ),
      padding: EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, Sp.md + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 44, height: 5,
            decoration: BoxDecoration(color: context.tpHair, borderRadius: BorderRadius.circular(3)))),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Inviter un co-organisateur',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                    color: context.tpInk, letterSpacing: -0.5)),
              const SizedBox(height: 2),
              Text('Recherche par nom ou email',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.tpInkSub)),
            ])),
          ]),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(color: context.tpBg,
                borderRadius: BorderRadius.circular(Radii.button), border: Border.all(color: context.tpHair)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(children: [
              Icon(PhosphorIcons.magnifyingGlass(), color: context.tpInkMute, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _ctrl, autofocus: true,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.tpInk),
                  decoration: InputDecoration(
                    hintText: 'Nom ou adresse email…',
                    hintStyle: TextStyle(fontSize: 14, color: context.tpInkMute, fontWeight: FontWeight.w500),
                    border: InputBorder.none, isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: _onSearch,
                ),
              ),
              if (_searching)
                const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: kPrimary)),
            ]),
          ),
          const SizedBox(height: 12),
          if (_results.isEmpty && _ctrl.text.length >= 2 && !_searching)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text('Aucun utilisateur trouvé',
                style: TextStyle(fontSize: 14, color: context.tpInkSub, fontWeight: FontWeight.w600)),
            )
          else if (_results.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Tape un nom ou un email pour chercher…',
                style: TextStyle(fontSize: 13, color: context.tpInkMute, fontWeight: FontWeight.w600)),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.40),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _results.length,
                separatorBuilder: (_, _) => Divider(height: 1, color: context.tpHair),
                itemBuilder: (_, i) {
                  final user  = _results[i];
                  final added = _justAdded.contains(user.id) || widget.alreadySelected.contains(user.id);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(children: [
                      TpAvatar(name: user.displayName, imageUrl: user.avatarUrl, size: 44),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(user.displayName,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: context.tpInk)),
                        if (user.isPromoter)
                          Text('⭐ Promoteur',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kPrimary)),
                      ])),
                      const SizedBox(width: 10),
                      Semantics(
                        button: true, label: added ? 'Déjà ajouté' : 'Ajouter ${user.displayName}',
                        child: GestureDetector(
                          onTap: added ? null : () => _add(user),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: added ? null : trackpartyGradient,
                              color: added ? context.tpHair : null,
                              borderRadius: BorderRadius.circular(Radii.tag),
                            ),
                            child: Text(
                              added ? '✓ Ajouté' : 'Ajouter',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                                  color: added ? context.tpInkMute : Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ]),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class _LocationActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool loading;
  final VoidCallback onTap;
  const _LocationActionBtn({required this.icon, required this.label, required this.onTap, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true, label: label,
      child: GestureDetector(
        onTap: loading ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            color: kPrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(Radii.button),
          ),
          child: loading
              ? const SizedBox.square(dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: kPrimary))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(icon, color: kPrimary, size: 18),
                  const SizedBox(width: 6),
                  Flexible(child: Text(label, textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kPrimary))),
                ]),
        ),
      ),
    );
  }
}

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
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
    );
  }
}
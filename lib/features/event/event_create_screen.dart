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
import '../../core/providers/event_provider.dart';
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
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController(text: '80');
  final _minAgeCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  String? _category;
  String? _customCategoryLabel;
  String? _customCategoryEmoji;
  String _visibility = 'public';
  String _contribMode = 'gratuit';
  // Tarification d'un event payant : 'single' (prix unique) ou 'category' (par catégorie).
  String _priceMode = 'single';
  // Contribution en nature acceptée en plus du prix (items à apporter).
  bool _natureEnabled = false;
  // Toggle unique : afficher publiquement les compteurs de places.
  bool _showTicketCounts = false;
  bool _showPrivateEventPublicly = false;
  int _capacity = 80;
  int? _minAge;

  DateTime? _startAt;
  DateTime? _endAt;

  String _addressLabel = '';
  String _city = 'Abidjan';
  String _quartier = '';
  double _lat = 5.3484;
  double _lng = -4.0168;
  // false tant que l'utilisateur n'a pas choisi de lieu réel : la carte
  // s'ouvre alors sur sa position GPS (et non sur le défaut Abidjan).
  bool _locationSet = false;

  TpButtonState _publishState = TpButtonState.idle;

  String? _coverUrl;
  bool _coverLoading = false;

  final List<UserSearchResult> _pendingCoOrgs = [];

  final List<_Item> _items = [];
  final List<_CatDraft> _ticketCategories = [];

  static const _categories = [
    ('musique', '🎵', 'Musique', kSecondary),
    ('soiree', '🎉', 'Soirée', kTertiary),
    ('cuisine', '🍽', 'Cuisine', kAccent),
    ('sport', '⚽', 'Sport', kInfo),
    ('art', '🎨', 'Art', kCategoryArt),
    ('plage', '🏖', 'Plage', kWarning),
  ];

  // ── Init ──────────────────────────────────────────────────────────────────

  /// Nouvel événement : on positionne le lieu par défaut sur la position GPS de
  /// l'utilisateur (au lieu du défaut Abidjan). Sans effet en mode édition.
  Future<void> _setDefaultLocationFromGps() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      if (mounted) {
        setState(() {
          _lat = pos.latitude;
          _lng = pos.longitude;
          _locationSet = true;
        });
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    final ev = widget.initialEvent;
    if (ev == null) {
      _setDefaultLocationFromGps();
    }
    if (ev != null) {
      _titleCtrl.text = widget.isClone ? 'Copie de ${ev.title}' : ev.title;
      _descCtrl.text = ev.description ?? '';
      _category = ev.category;
      _customCategoryLabel = ev.customCategoryLabel;
      _customCategoryEmoji = ev.customCategoryEmoji;
      _visibility = ev.visibility;
      _showPrivateEventPublicly = ev.showPrivateEventPublicly;
      _showTicketCounts = ev.showTicketCounts;
      // 'nature' a fusionné dans 'monetaire' (sécurité si une donnée ancienne traîne).
      _contribMode = ev.contributionType == 'nature'
          ? 'monetaire'
          : ev.contributionType;
      if (ev.contributionAmount != null && ev.contributionAmount! > 0) {
        _amountCtrl.text = ev.contributionAmount!.toStringAsFixed(0);
      }
      _capacity = ev.maxParticipants ?? 80;
      _capacityCtrl.text = _capacity.toString();
      _minAge = ev.minAge;
      if (_minAge != null) {
        _minAgeCtrl.text = _minAge.toString();
      }
      if (!widget.isClone) {
        _startAt = ev.startAt;
        _endAt = ev.endAt;
      }
      _addressLabel = ev.addressLabel;
      _city = ev.city;
      _quartier = ev.quartier;
      _lat = ev.latitude ?? 5.3484;
      _lng = ev.longitude ?? -4.0168;
      _locationSet = ev.latitude != null && ev.longitude != null;
      _coverUrl = ev.coverImageUrl;
      if (ev.contributionItems.isNotEmpty) {
        _items.clear();
        _items.addAll(
          ev.contributionItems.map(
            (i) => _Item(
              emoji: i.emoji,
              label: i.name,
              qty: i.quantityTotal,
              categoryName: i.categoryName,
            ),
          ),
        );
        _natureEnabled = true;
      }
      // Tarification : par catégorie si des catégories existent, sinon prix unique.
      _priceMode = ev.ticketCategories.isNotEmpty ? 'category' : 'single';
      if (ev.ticketCategories.isNotEmpty) {
        // Préchargement immédiat depuis la vue publique (sans capacité)…
        _ticketCategories.clear();
        _ticketCategories.addAll(
          ev.ticketCategories.map(
            (c) => _CatDraft(
              name: c.name,
              price: c.price,
              advantages: List<String>.from(c.advantages),
              color: c.color,
            ),
          ),
        );
        // …puis affinage avec les champs complets (capacité, places restantes).
        _loadFullCategories(ev.id);
      }
    }
  }

  Future<void> _loadFullCategories(String eventId) async {
    try {
      final raw = await ref.read(eventServiceProvider).getEventCategories(eventId);
      if (!mounted || raw.isEmpty) return;
      setState(() {
        _ticketCategories
          ..clear()
          ..addAll(raw.map((c) => _CatDraft(
                name: c['name'] as String? ?? '',
                price: (c['price'] as num?)?.toInt() ?? 0,
                capacity: (c['capacity'] as num?)?.toInt(),
                advantages: (c['advantages'] as List<dynamic>?)
                        ?.map((e) => e.toString())
                        .toList() ??
                    const [],
                color: c['color'] as String? ?? '',
                showRemaining: c['show_remaining'] as bool? ?? true,
              )));
      });
    } catch (_) {
      // On garde le préchargement public en cas d'échec.
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _capacityCtrl.dispose();
    _minAgeCtrl.dispose();
    _amountCtrl.dispose();
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
      if (_contribMode == 'monetaire') {
        if (_priceMode == 'category') {
          if (_ticketCategories.isEmpty) {
            return 'Ajoute au moins une catégorie de billet.';
          }
          // Garde-fou : chaque catégorie doit avoir un nombre de places défini.
          final uncapped = _ticketCategories
              .where((c) => c.capacity == null || c.capacity! <= 0)
              .toList();
          if (uncapped.isNotEmpty) {
            final n = uncapped.first.name.trim();
            return 'Définis le nombre de places de chaque catégorie'
                '${n.isEmpty ? '' : ' (« $n »)'}.';
          }
        } else {
          final amount = int.tryParse(_amountCtrl.text.trim()) ?? 0;
          final natureOk = _natureEnabled && _items.isNotEmpty;
          if (amount <= 0 && !natureOk) {
            return 'Indique un prix unique ou ajoute une contribution en nature.';
          }
        }
        if (_natureEnabled && _items.isEmpty) {
          return 'Ajoute au moins un item à apporter, ou décoche la contribution en nature.';
        }
        // En mode catégorie, chaque option nature doit cibler une catégorie.
        if (_natureEnabled && _priceMode == 'category') {
          final noCat = _items
              .where((i) => i.categoryName == null || i.categoryName!.isEmpty)
              .toList();
          if (noCat.isNotEmpty) {
            return 'Associe chaque option en nature à une catégorie (« ${noCat.first.label} »).';
          }
        }
      }
    }
    return null;
  }

  void _nextStep() {
    final error = _validateStep(_step);
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error), backgroundColor: kError));
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
  String _fmtFull(DateTime dt) =>
      DateFormat('EEE d MMM · HH:mm', 'fr_FR').format(dt);

  String get _locationLabel =>
      _addressLabel.isNotEmpty ? _addressLabel : 'Lieu non défini';
  String get _locationSub =>
      _quartier.isNotEmpty ? '$_quartier, $_city' : _city;

  String get _categoryLabel {
    if (_category == 'autre') return _customCategoryLabel ?? 'Personnalisé';
    final found = _categories.where((c) => c.$1 == _category);
    if (found.isEmpty) return 'Non défini';
    return '${found.first.$2} ${found.first.$3}';
  }

  String get _contribLabel {
    switch (_contribMode) {
      case 'gratuit':
        return '💸 Gratuit';
      case 'monetaire':
        final parts = <String>[];
        if (_priceMode == 'category') {
          if (_ticketCategories.isNotEmpty) {
            parts.add('${_ticketCategories.length} catégorie${_ticketCategories.length > 1 ? 's' : ''}');
          }
        } else {
          final amount = int.tryParse(_amountCtrl.text.trim()) ?? 0;
          if (amount > 0) parts.add('$amount FCFA');
        }
        if (_natureEnabled && _items.isNotEmpty) {
          parts.add('${_items.length} en nature');
        }
        return '💰 Payant${parts.isNotEmpty ? ' · ${parts.join(' / ')}' : ''}';
      default:
        return _contribMode;
    }
  }

  // ── Date/time picker ──────────────────────────────────────────────────────

  Future<void> _pickDateTime({required bool isEnd}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Date minimale : aujourd'hui pour le début ; le jour du début pour la fin.
    final firstDate = isEnd && _startAt != null
        ? DateTime(_startAt!.year, _startAt!.month, _startAt!.day)
        : today;

    final base = isEnd
        ? (_endAt ?? _startAt?.add(const Duration(hours: 5)) ?? now)
        : (_startAt ?? now);
    // initialDate doit toujours être >= firstDate.
    final initial = base.isBefore(firstDate) ? firstDate : base;

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
    );
    if (time == null || !mounted) return;

    final dt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    // Empêche un début dans le passé (ex. aujourd'hui mais heure déjà écoulée).
    if (!isEnd && dt.isBefore(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('L\'événement ne peut pas commencer dans le passé.'),
        ),
      );
      return;
    }
    // La fin doit être après le début.
    if (isEnd && _startAt != null && !dt.isAfter(_startAt!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La fin doit être après le début.')),
      );
      return;
    }

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
    final addrCtrl = TextEditingController(text: _addressLabel);
    final cityCtrl = TextEditingController(text: _city);
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
              Sp.md,
              20,
              Sp.md,
              MediaQuery.of(ctx).viewInsets.bottom + Sp.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lieu de l\'événement',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: ctx.tpInk,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _LocationActionBtn(
                        icon: PhosphorIcons.crosshair(),
                        label: gpsLoading ? 'Localisation…' : 'Ma position',
                        loading: gpsLoading,
                        onTap: () async {
                          setSheet(() => gpsLoading = true);
                          try {
                            LocationPermission perm =
                                await Geolocator.checkPermission();
                            if (perm == LocationPermission.denied) {
                              perm = await Geolocator.requestPermission();
                            }
                            if (perm != LocationPermission.denied &&
                                perm != LocationPermission.deniedForever) {
                              final pos = await Geolocator.getCurrentPosition(
                                desiredAccuracy: LocationAccuracy.high,
                              );
                              if (mounted)
                                setState(() {
                                  _lat = pos.latitude;
                                  _lng = pos.longitude;
                                  _locationSet = true;
                                });
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
                          final result = await context
                              .push<LocationPickerResult>(
                                '/location-picker',
                                extra: _locationSet
                                    ? {'lat': _lat, 'lng': _lng}
                                    : const <String, dynamic>{},
                              );
                          if (result != null && mounted) {
                            setState(() {
                              _lat = result.lat;
                              _lng = result.lng;
                              _locationSet = true;
                            });
                            if (ctx.mounted) setSheet(() {});
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: ctx.tpBg,
                    borderRadius: BorderRadius.circular(Radii.tag),
                  ),
                  child: Row(
                    children: [
                      Icon(PhosphorIcons.mapPin(), color: kPrimary, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        '${_lat.toStringAsFixed(5)},  ${_lng.toStringAsFixed(5)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: ctx.tpInkSub,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _LocationField(
                  ctrl: addrCtrl,
                  label: 'Adresse (ex: Rooftop K8)',
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _LocationField(ctrl: quartCtrl, label: 'Quartier'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _LocationField(ctrl: cityCtrl, label: 'Ville'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: TpButton(
                    label: 'Confirmer',
                    onPressed: () {
                      setState(() {
                        _addressLabel = addrCtrl.text.trim();
                        _city = cityCtrl.text.trim().isNotEmpty
                            ? cityCtrl.text.trim()
                            : 'Abidjan';
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
      final url = await ref
          .read(cloudinaryServiceProvider)
          .pickAndUpload(folder: 'covers');
      if (url != null && mounted) setState(() => _coverUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur photo : ${e.toString()}'),
            backgroundColor: kError,
          ),
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
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'category': _category,
        'status': 'published',
        'start_at': _startAt!.toIso8601String(),
        if (_endAt != null) 'end_at': _endAt!.toIso8601String(),
        'latitude': _lat,
        'longitude': _lng,
        'address_label': _addressLabel,
        'city': _city,
        'quartier': _quartier,
        'visibility': _visibility,
        'show_private_event_publicly':
          _visibility == 'private' ? _showPrivateEventPublicly : false,
        'show_ticket_counts': _showTicketCounts,
        'contribution_type': _contribMode,
        'max_participants': _effectiveCapacity,
        if (_minAge != null) 'min_age': _minAge,
        if (_coverUrl != null) 'cover_cloud_url': _coverUrl,
        if (_category == 'autre' && _customCategoryLabel != null) ...{
          'custom_category_label': _customCategoryLabel,
          'custom_category_emoji': _customCategoryEmoji ?? '✨',
        },
        'contribution_amount':
            (_contribMode == 'monetaire' && _priceMode == 'single')
            ? int.tryParse(_amountCtrl.text.trim())
            : null,
        'contribution_items':
            (_contribMode == 'monetaire' && _natureEnabled)
            ? _items
                  .map(
                    (i) => {
                      'name': i.label,
                      'emoji': i.emoji,
                      'quantity_total': i.qty,
                      if (i.categoryName != null) 'category_name': i.categoryName,
                    },
                  )
                  .toList()
            : <Map<String, dynamic>>[],
        'ticket_categories':
            (_contribMode == 'monetaire' && _priceMode == 'category')
            ? _ticketCategories.asMap().entries.map((e) => e.value.toJson(e.key)).toList()
            : <Map<String, dynamic>>[],
      };
      final svc = ref.read(eventServiceProvider);
      final EventModel event;
      if (widget.isEditing) {
        event = await svc.updateEvent(widget.initialEvent!.id, data);
      } else {
        event = await svc.createEvent(data);
      }

      var failedCoOrgInvites = 0;
      if (!widget.isEditing && _pendingCoOrgs.isNotEmpty) {
        final coOrgSvc = ref.read(coOrganizerServiceProvider);
        for (final coOrg in _pendingCoOrgs) {
          try {
            await coOrgSvc.invite(event.id, coOrg.id);
          } catch (e) {
            debugPrint('EventCreate: échec invitation co-organisateur ${coOrg.id} — $e');
            failedCoOrgInvites++;
          }
        }
      }

      // Rafraîchir les listes pour que l'événement apparaisse/se mette à jour
      // sans actualisation manuelle (feed + compteurs profil + détail).
      ref.invalidate(nearbyEventsFeedProvider);
      ref.invalidate(trendingEventsFeedProvider);
      ref.invalidate(myEventStatsProvider);
      if (widget.isEditing) {
        ref.invalidate(eventDetailProvider(event.id));
      }

      if (mounted) {
        setState(() => _publishState = TpButtonState.idle);
        final baseMsg = widget.isEditing ? 'Événement mis à jour !' : 'Événement publié !';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failedCoOrgInvites > 0
                  ? '$baseMsg $failedCoOrgInvites invitation${failedCoOrgInvites > 1 ? 's' : ''} '
                      'co-organisateur ${failedCoOrgInvites > 1 ? 'ont' : 'a'} échoué.'
                  : baseMsg,
            ),
            backgroundColor: failedCoOrgInvites > 0 ? kWarning : kSuccess,
          ),
        );
        if (widget.isEditing)
          context.pop();
        else
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

  // ── Preview ───────────────────────────────────────────────────────────────

  void _showPreview() {
    final authState = ref.read(authNotifierProvider).valueOrNull;
    final me = authState is AuthAuthenticated ? authState.user : null;
    showEventPreviewSheet(
      context,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      category: _category,
      customCategoryLabel: _customCategoryLabel,
      customCategoryEmoji: _customCategoryEmoji,
      coverUrl: _coverUrl,
      startAt: _startAt,
      endAt: _endAt,
      addressLabel: _addressLabel,
      city: _city,
      quartier: _quartier,
      visibility: _visibility,
      contribMode: _contribMode,
      capacity: _effectiveCapacity ?? 0,
      organizerName: me?.displayName ?? 'Moi',
      organizerAvatarUrl: me?.avatarUrl,
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
            // .builder (pas la liste `children`) : ne construit que l'étape
            // affichée, au lieu de reconstruire les 3 étapes du formulaire à
            // chaque frappe/toggle ailleurs dans l'écran.
            child: PageView.builder(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              itemBuilder: (context, i) => switch (i) {
                0 => _buildStep1(context),
                1 => _buildStep2(context),
                _ => _buildStep3(context),
              },
            ),
          ),
          _buildBottomNav(context),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    const titles = [
      'Infos générales',
      'Détails pratiques',
      'Récap & publication',
    ];
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.tpCard,
                  borderRadius: BorderRadius.circular(Radii.md),
                  boxShadow: Shadows.sm,
                ),
                child: Icon(
                  _step == 0 ? PhosphorIcons.x() : PhosphorIcons.arrowLeft(),
                  color: context.tpInk,
                  size: 18,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              titles[_step],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: context.tpInk,
                letterSpacing: -0.4,
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
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: kPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step indicator ────────────────────────────────────────────────────────

  static const _stepLabels = ['Infos générales', 'Détails pratiques', 'Récapitulatif'];

  Widget _buildStepIndicator(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 8, Sp.md, 4),
      child: Row(
        children: List.generate(3, (i) {
          final done = i < _step;
          final active = i == _step;
          return Expanded(
            child: Semantics(
              button: done,
              label: 'Étape ${i + 1} : ${_stepLabels[i]}',
              selected: active,
              child: GestureDetector(
                onTap: done ? () => _goToStep(i) : null,
                child: SizedBox(
                  height: 44,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: double.infinity,
                      height: 4,
                      margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: (active || done) ? kPrimary : context.tpHair,
                        boxShadow: active
                            ? [
                                const BoxShadow(
                                  color: Color(0x337C3AED),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
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
      label: _coverUrl != null
          ? 'Changer la photo de couverture'
          : 'Ajouter une photo de couverture',
      child: GestureDetector(
        onTap: _coverLoading ? null : _pickCover,
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            gradient: _coverUrl == null ? gradientSoft : null,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(
              color: kPrimary.withValues(alpha: 0.33),
              width: 2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: _coverUrl != null
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(imageUrl: _coverUrl!, fit: BoxFit.cover),
                    if (_coverLoading)
                      Container(
                        color: Colors.black54,
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(Radii.tag),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              PhosphorIcons.camera(),
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Changer',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_coverLoading)
                      const CircularProgressIndicator(
                        color: kPrimary,
                        strokeWidth: 2,
                      )
                    else ...[
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: trackpartyGradient,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: Shadows.brand,
                        ),
                        child: Icon(
                          PhosphorIcons.camera(),
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ajouter une photo',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: context.tpInk,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '16:9 recommandé · max 5 Mo',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.tpInkSub,
                        ),
                      ),
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
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: context.tpInk,
        ),
        decoration: InputDecoration(
          hintText: 'Nom de l\'événement',
          hintStyle: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: context.tpInkMute,
          ),
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
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: context.tpInkMute,
          ),
        ),
        child: TextField(
          controller: _descCtrl,
          maxLines: 3,
          maxLength: 280,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: context.tpInkSub,
            height: 1.45,
          ),
          decoration: InputDecoration(
            hintText: 'Décris ton événement…',
            hintStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: context.tpInkMute,
            ),
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
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._categories.map((cat) {
              final (key, emoji, label, color) = cat;
              final active = _category == key;
              return Semantics(
                button: true,
                label: '$emoji $label',
                selected: active,
                child: GestureDetector(
                  onTap: () => setState(() {
                    _category = key;
                    _customCategoryLabel = null;
                    _customCategoryEmoji = null;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: active ? color : context.tpCard,
                      borderRadius: BorderRadius.circular(Radii.md),
                      border: active
                          ? null
                          : Border.all(color: context.tpHair, width: 1.5),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.33),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 15)),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: active ? Colors.white : context.tpInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            // Personnaliser
            Semantics(
              button: true,
              label: isCustomActive
                  ? 'Catégorie personnalisée'
                  : 'Créer une catégorie',
              selected: isCustomActive,
              child: GestureDetector(
                onTap: () => _showCustomCategorySheet(context),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isCustomActive ? kPrimary : context.tpCard,
                    borderRadius: BorderRadius.circular(Radii.md),
                    border: isCustomActive
                        ? null
                        : Border.all(
                            color: kPrimary.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                    boxShadow: isCustomActive
                        ? [
                            const BoxShadow(
                              color: Color(0x407C3AED),
                              blurRadius: 14,
                              offset: Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isCustomActive ? (_customCategoryEmoji ?? '✨') : '✏️',
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isCustomActive
                            ? _customCategoryLabel!
                            : 'Personnaliser',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isCustomActive ? Colors.white : kPrimary,
                        ),
                      ),
                      if (isCustomActive) ...[
                        const SizedBox(width: 4),
                        Icon(
                          PhosphorIcons.pencilSimple(),
                          size: 12,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ],
                    ],
                  ),
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
          if (_contribMode == 'monetaire') ...[
            const SizedBox(height: 14),
            _buildPaidOptions(context),
          ],
          const SizedBox(height: 14),
          if (_isCategoryPricing)
            _buildDerivedCapacityNote(context)
          else
            _buildCapacity(context),
          const SizedBox(height: 14),
          _buildShowCountsToggle(context),
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
        Row(
          children: [
            Expanded(
              child: _VisCard(
                emoji: '🌍',
                title: 'Public',
                sub: 'Visible sur la carte',
                active: _visibility == 'public',
                onTap: () => setState(() {
                  _visibility = 'public';
                  _showPrivateEventPublicly = false;
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _VisCard(
                emoji: '🔒',
                title: 'Privé',
                sub: 'Sur invitation',
                active: _visibility == 'private',
                onTap: () => setState(() => _visibility = 'private'),
              ),
            ),
          ],
        ),
        if (_visibility == 'private') ...[
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text(
              'Rendre l’événement visible publiquement'
            ),
            subtitle: const Text(
              'Les détails resteront protégés pour les personnes non invitée'
            ),
            value: _showPrivateEventPublicly,
            onChanged: (value) {
              setState(() {
                _showPrivateEventPublicly = value;
              });
            },
          ),
        ]
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
            Expanded(
              child: _ModeCard(
                emoji: '💸',
                title: 'Gratuit',
                sub: 'Entrée libre',
                active: _contribMode == 'gratuit',
                onTap: () => setState(() => _contribMode = 'gratuit'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ModeCard(
                emoji: '💰',
                title: 'Payant',
                sub: 'Prix unique ou catégories',
                active: _contribMode == 'monetaire',
                onTap: () => setState(() => _contribMode = 'monetaire'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Options payantes : prix + contribution en nature optionnelle ──────────

  Widget _buildPaidOptions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Choix de tarification : prix unique OU par catégorie ──────────────
        const _SectionLabel('Tarification'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ModeCard(
                emoji: '🎟️',
                title: 'Prix unique',
                sub: 'Un seul tarif',
                active: _priceMode == 'single',
                onTap: () => setState(() => _priceMode = 'single'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ModeCard(
                emoji: '🏷️',
                title: 'Par catégorie',
                sub: 'Standard, VIP…',
                active: _priceMode == 'category',
                onTap: () => setState(() => _priceMode = 'category'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Champ prix unique OU section catégories ───────────────────────────
        if (_priceMode == 'single')
          _CreateField(
            label: 'Prix du billet (FCFA)',
            child: TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: context.tpInk,
              ),
              decoration: InputDecoration(
                hintText: 'Ex. 5000',
                hintStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.tpInkMute,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          )
        else
          _buildCategoriesSection(context),

        const SizedBox(height: 18),

        // ── Contribution en nature : case à cocher qui révèle les items ───────
        _buildNatureToggle(context),
        if (_natureEnabled) ...[
          const SizedBox(height: 4),
          Text(
            'Le participant pourra apporter un de ces items au lieu (ou en plus) de payer.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.tpInkMute,
            ),
          ),
          const SizedBox(height: 10),
          _buildItemsList(context),
        ],
      ],
    );
  }

  Widget _buildShowCountsToggle(BuildContext context) {
    return Semantics(
      button: true,
      toggled: _showTicketCounts,
      label: 'Afficher les nombres de places',
      child: GestureDetector(
        onTap: () => setState(() => _showTicketCounts = !_showTicketCounts),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: context.tpCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _showTicketCounts
                  ? kPrimary
                  : context.tpInkMute.withValues(alpha: 0.18),
              width: _showTicketCounts ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              const Text('👁️', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Afficher les nombres de places',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: context.tpInk,
                      ),
                    ),
                    Text(
                      'Billets restants et places prises visibles par tous',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.tpInkSub,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                _showTicketCounts
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                color: _showTicketCounts ? kPrimary : context.tpInkMute,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNatureToggle(BuildContext context) {
    return Semantics(
      button: true,
      toggled: _natureEnabled,
      label: 'Accepter une contribution en nature',
      child: GestureDetector(
        onTap: () => setState(() => _natureEnabled = !_natureEnabled),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: context.tpCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _natureEnabled
                  ? kPrimary
                  : context.tpInkMute.withValues(alpha: 0.18),
              width: _natureEnabled ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              const Text('🥗', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contribution en nature',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: context.tpInk,
                      ),
                    ),
                    Text(
                      'Proposer une liste d\'items à apporter',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.tpInkSub,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                _natureEnabled
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                color: _natureEnabled ? kPrimary : context.tpInkMute,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Liste d'items ─────────────────────────────────────────────────────────

  Widget _buildItemsList(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: BorderRadius.circular(18),
        boxShadow: Shadows.card,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Items à apporter',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: context.tpInk,
                ),
              ),
              Semantics(
                button: true,
                label: 'Ajouter un item',
                child: GestureDetector(
                  onTap: () => _showItemDialog(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: kPrimary,
                      borderRadius: BorderRadius.circular(Radii.tag),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          PhosphorIcons.plus(),
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Ajouter',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._items.asMap().entries.map(
            (e) => _ItemRow(
              item: e.value,
              isFirst: e.key == 0,
              onTap: () => _showItemDialog(editIndex: e.key),
              onRemove: () => setState(() => _items.removeAt(e.key)),
            ),
          ),
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
        categoryMode: _priceMode == 'category',
        categories: _ticketCategories
            .map((c) => c.name.trim())
            .where((n) => n.isNotEmpty)
            .toList(),
        onSave: (item) {
          setState(() {
            if (editIndex != null)
              _items[editIndex] = item;
            else
              _items.add(item);
          });
        },
        onDelete: editIndex != null
            ? () => setState(() => _items.removeAt(editIndex))
            : null,
      ),
    );
  }

  // ── Catégories de billets ─────────────────────────────────────────────────

  Widget _buildCategoriesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _SectionLabel('Catégories de billets'),
            Semantics(
              button: true,
              label: 'Ajouter une catégorie',
              child: GestureDetector(
                onTap: () => _openCategorySheet(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: kPrimary,
                    borderRadius: BorderRadius.circular(Radii.tag),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(PhosphorIcons.plus(), color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    const Text('Catégorie',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ]),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Ex. VIP1 2 000 · VIP2 5 000 — chaque catégorie a son prix, ses places et ses avantages.',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: context.tpInkMute),
        ),
        const SizedBox(height: 10),
        if (_ticketCategories.isEmpty)
          Text(
            'Aucune catégorie pour l’instant. Ajoutes-en une, ou laisse un prix simple ci-dessous.',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: context.tpInkSub),
          )
        else
          ..._ticketCategories.asMap().entries.map((e) => _CatRow(
                draft: e.value,
                onTap: () => _openCategorySheet(editIndex: e.key),
                onRemove: () =>
                    setState(() => _ticketCategories.removeAt(e.key)),
              )),
      ],
    );
  }

  void _openCategorySheet({int? editIndex}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategorySheet(
        initial: editIndex != null ? _ticketCategories[editIndex] : null,
        onSave: (cat) {
          setState(() {
            if (editIndex != null) {
              _ticketCategories[editIndex] = cat;
            } else {
              _ticketCategories.add(cat);
            }
          });
        },
        onDelete: editIndex != null
            ? () => setState(() => _ticketCategories.removeAt(editIndex))
            : null,
      ),
    );
  }

  // ── Capacité ──────────────────────────────────────────────────────────────

  /// En tarification par catégorie, la capacité globale est dérivée de la somme
  /// des places de chaque catégorie (donc le champ manuel est masqué).
  bool get _isCategoryPricing =>
      _contribMode == 'monetaire' && _priceMode == 'category';

  /// Somme des places des catégories payantes ; null si une catégorie est
  /// illimitée (ou si aucune) → capacité illimitée.
  int? get _paidCapacity {
    if (_ticketCategories.isEmpty) return null;
    if (_ticketCategories.any((c) => c.capacity == null)) return null;
    return _ticketCategories.fold<int>(0, (s, c) => s + (c.capacity ?? 0));
  }

  /// Places en nature (additives) : 1 unité = 1 place, somme des options.
  int get _naturePlaces => (_contribMode == 'monetaire' && _natureEnabled)
      ? _items.fold<int>(0, (s, i) => s + i.qty)
      : 0;

  /// Capacité effective = places payantes + places en nature (additives).
  /// En mode catégorie, le payant = somme des catégories ; sinon = saisie manuelle.
  int? get _effectiveCapacity {
    if (_isCategoryPricing) {
      final paid = _paidCapacity;
      if (paid == null) return null; // une catégorie illimitée → illimité
      return paid + _naturePlaces;
    }
    return _capacity + _naturePlaces;
  }

  Widget _buildDerivedCapacityNote(BuildContext context) {
    final cap = _effectiveCapacity;
    final nature = _naturePlaces;
    final detail = nature > 0
        ? 'catégories + $nature en nature'
        : 'somme de tes catégories de billets';
    return _CreateField(
      label: 'Capacité maximale',
      child: Row(
        children: [
          Icon(PhosphorIcons.users(), color: context.tpInkSub, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              cap == null
                  ? 'Illimitée — définie par tes catégories de billets'
                  : '$cap places — $detail',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: context.tpInkSub,
              ),
            ),
          ),
        ],
      ),
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.tpBg,
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                alignment: Alignment.center,
                child: Text(
                  '−',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: context.tpInk,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _capacityCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: context.tpInk,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                suffixText: 'pers.',
                suffixStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.tpInkSub,
                ),
              ),
              onChanged: (v) {
                final n = int.tryParse(v);
                if (n != null && n > 0)
                  setState(() => _capacity = n.clamp(1, 9999));
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: kPrimary,
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                alignment: Alignment.center,
                child: const Text(
                  '+',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
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
        boxShadow: Shadows.card,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: kPrimary,
                      borderRadius: BorderRadius.circular(Radii.tag),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          PhosphorIcons.plus(),
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Inviter',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_pendingCoOrgs.isEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Aucun co-organisateur ajouté.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.tpInkMute,
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _pendingCoOrgs
                  .map(
                    (user) => _CoOrgChip(
                      user: user,
                      onRemove: () =>
                          setState(() => _pendingCoOrgs.remove(user)),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 6),
            Text(
              'Les invitations seront envoyées après publication.',
              style: TextStyle(fontSize: 11, color: context.tpInkMute),
            ),
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
              child: CachedNetworkImage(
                imageUrl: _coverUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            )
          else
            Container(
              height: 100,
              decoration: BoxDecoration(
                gradient: gradientSoft,
                borderRadius: BorderRadius.circular(Radii.card),
                border: Border.all(
                  color: kPrimary.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    PhosphorIcons.image(),
                    color: kPrimary.withValues(alpha: 0.4),
                    size: 32,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Aucune photo de couverture',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.tpInkMute,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Titre + catégorie
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.tpCard,
              borderRadius: BorderRadius.circular(18),
              boxShadow: Shadows.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RecapRow(
                  icon: PhosphorIcons.textT(),
                  label: 'Titre',
                  value: _titleCtrl.text.trim().isEmpty
                      ? 'Non défini'
                      : _titleCtrl.text.trim(),
                  valueStyle: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: context.tpInk,
                  ),
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
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Date & Lieu
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.tpCard,
              borderRadius: BorderRadius.circular(18),
              boxShadow: Shadows.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RecapRow(
                  icon: PhosphorIcons.calendar(),
                  label: 'Début',
                  value: _startAt != null
                      ? _fmtFull(_startAt!)
                      : '⚠️ Non défini',
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
                  value: _addressLabel.isNotEmpty
                      ? _addressLabel
                      : 'Non précisé',
                  sub: _quartier.isNotEmpty ? '$_quartier, $_city' : _city,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Paramètres
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.tpCard,
              borderRadius: BorderRadius.circular(18),
              boxShadow: Shadows.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  value: _effectiveCapacity == null
                      ? 'Illimitée'
                      : '$_effectiveCapacity participants',
                ),
                if (_pendingCoOrgs.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _RecapRow(
                    icon: PhosphorIcons.userPlus(),
                    label: 'Co-organisateurs',
                    value: _pendingCoOrgs.map((u) => u.displayName).join(', '),
                  ),
                ],
              ],
            ),
          ),

          // Items de contribution en nature (mode payant)
          if (_contribMode == 'monetaire' && _items.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.tpCard,
                borderRadius: BorderRadius.circular(18),
                boxShadow: Shadows.card,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(PhosphorIcons.package(), color: kPrimary, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Items à apporter',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: context.tpInkSub,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ..._items.asMap().entries.map(
                    (e) => Padding(
                      padding: EdgeInsets.only(top: e.key > 0 ? 8 : 0),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: context.tpBg,
                              borderRadius: BorderRadius.circular(Radii.tag),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              e.value.emoji,
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              e.value.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: context.tpInk,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: context.tpBg,
                              borderRadius: BorderRadius.circular(Radii.sm),
                            ),
                            child: Text(
                              '×${e.value.qty}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: context.tpInkSub,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
              child: Row(
                children: [
                  Icon(PhosphorIcons.warningCircle(), color: kError, size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'La date de début est obligatoire.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kError,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Bottom nav ────────────────────────────────────────────────────────────

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        Sp.md,
        Sp.md,
        Sp.md,
        Sp.md + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            context.tpBg.withValues(alpha: 0),
            context.tpBg,
            context.tpBg,
          ],
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
                    label: _step == 0
                        ? 'Suivant : Détails pratiques'
                        : 'Suivant : Récap',
                    icon: PhosphorIcons.arrowRight(),
                    onPressed: _nextStep,
                  )
                : TpButton(
                    label: widget.isEditing
                        ? 'Enregistrer'
                        : widget.isClone
                        ? 'Dupliquer'
                        : 'Publier',
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
          width: 32,
          height: 32,
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
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: context.tpInkSub,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style:
                    valueStyle ??
                    TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: valueColor ?? context.tpInk,
                    ),
              ),
              if (sub != null) ...[
                const SizedBox(height: 1),
                Text(
                  sub!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.tpInkSub,
                  ),
                ),
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

/// Sélecteur d'emoji (avatar 76×76 + champ de saisie) partagé entre
/// _CustomCategorySheet et _ItemSheet — factorisé pour éviter la duplication.
/// Se reconstruit lui-même (AnimatedBuilder sur le controller + le focus) au
/// lieu de dépendre d'un setState() de l'écran parent à chaque frappe.
class _EmojiPickerField extends StatelessWidget {
  final TextEditingController emojiCtrl;
  final FocusNode emojiFocus;
  final FocusNode labelFocus;
  final String helperText;
  final String fallbackEmoji;

  const _EmojiPickerField({
    required this.emojiCtrl,
    required this.emojiFocus,
    required this.labelFocus,
    this.helperText = 'Utilise le clavier emoji de ton téléphone',
    this.fallbackEmoji = '✨',
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([emojiCtrl, emojiFocus]),
      builder: (context, _) {
        final preview = emojiCtrl.text.trim().isEmpty ? fallbackEmoji : emojiCtrl.text.trim();
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Semantics(
              button: true,
              label: 'Sélectionner un emoji',
              child: GestureDetector(
                onTap: () => emojiFocus.requestFocus(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: kPrimary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(Radii.card),
                    border: Border.all(
                      color: emojiFocus.hasFocus
                          ? kPrimary
                          : kPrimary.withValues(alpha: 0.18),
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Text(
                      preview,
                      key: ValueKey(preview),
                      style: const TextStyle(fontSize: 40),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EMOJI',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: context.tpInkSub,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: context.tpBg,
                      borderRadius: BorderRadius.circular(Radii.md),
                      border: Border.all(color: context.tpHair),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: emojiCtrl,
                            focusNode: emojiFocus,
                            style: const TextStyle(
                              fontSize: 24,
                              height: 1.2,
                            ),
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) => labelFocus.requestFocus(),
                            decoration: InputDecoration(
                              hintText: '😀',
                              hintStyle: TextStyle(
                                fontSize: 24,
                                color: context.tpInkMute,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.emoji_emotions_outlined,
                          color: context.tpInkMute,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    helperText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: context.tpInkMute,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

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

  void _confirm() {
    final label = _labelCtrl.text.trim();
    if (label.isEmpty) return;
    widget.onConfirm(
      label,
      _emojiCtrl.text.trim().isEmpty ? '✨' : _emojiCtrl.text.trim(),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: context.tpCard,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Radii.sheet),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, Sp.md),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: context.tpHair,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Créer une catégorie',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: context.tpInk,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choisis un emoji et donne un nom à ta catégorie.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.tpInkSub,
                ),
              ),
              const SizedBox(height: 20),
              _EmojiPickerField(
                emojiCtrl: _emojiCtrl,
                emojiFocus: _emojiFocus,
                labelFocus: _labelFocus,
              ),
              const SizedBox(height: 16),
              Text(
                'NOM DE LA CATÉGORIE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: context.tpInkSub,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: context.tpBg,
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(color: context.tpHair),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: TextField(
                  controller: _labelCtrl,
                  focusNode: _labelFocus,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.tpInk,
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _confirm(),
                  decoration: InputDecoration(
                    hintText: 'ex: Mariage, Graduation, Gaming…',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: context.tpInkMute,
                    ),
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
                builder: (_, _) => TpButton(
                  label:
                      'Créer "${_labelCtrl.text.trim().isEmpty ? '…' : _labelCtrl.text.trim()}"',
                  icon: PhosphorIcons.check(),
                  state: _labelCtrl.text.trim().isEmpty
                      ? TpButtonState.disabled
                      : TpButtonState.idle,
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
  final List<String> categories; // noms des catégories (mode par catégorie)
  final bool categoryMode;
  const _ItemSheet({
    this.initial,
    required this.onSave,
    this.onDelete,
    this.categories = const [],
    this.categoryMode = false,
  });
  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  late final TextEditingController _emojiCtrl;
  late final TextEditingController _labelCtrl;
  late final TextEditingController _qtyCtrl;
  late int _qty;
  String? _selectedCategory;
  final FocusNode _emojiFocus = FocusNode();
  final FocusNode _labelFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _emojiCtrl = TextEditingController(text: widget.initial?.emoji ?? '');
    _labelCtrl = TextEditingController(text: widget.initial?.label ?? '');
    _qty = widget.initial?.qty ?? 5;
    _qtyCtrl = TextEditingController(text: '$_qty');
    final init = widget.initial?.categoryName;
    _selectedCategory = (init != null && widget.categories.contains(init))
        ? init
        : (widget.categoryMode && widget.categories.isNotEmpty
            ? widget.categories.first
            : null);
  }

  @override
  void dispose() {
    _emojiCtrl.dispose();
    _labelCtrl.dispose();
    _qtyCtrl.dispose();
    _emojiFocus.dispose();
    _labelFocus.dispose();
    super.dispose();
  }

  void _setQty(int v) => setState(() {
        _qty = v.clamp(1, 9999);
        _qtyCtrl.text = '$_qty';
        _qtyCtrl.selection =
            TextSelection.collapsed(offset: _qtyCtrl.text.length);
      });

  void _save() {
    final label = _labelCtrl.text.trim();
    final emoji = _emojiCtrl.text.trim();
    if (label.isEmpty) return;
    if (widget.categoryMode && _selectedCategory == null) return;
    widget.onSave(
      _Item(
        emoji: emoji.isEmpty ? '🎁' : emoji,
        label: label,
        qty: _qty,
        categoryName: widget.categoryMode ? _selectedCategory : null,
      ),
    );
    Navigator.pop(context);
  }

  void _delete() {
    widget.onDelete?.call();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: context.tpCard,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Radii.sheet),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, Sp.md),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: context.tpHair,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isEdit ? 'Modifier l\'item' : 'Ajouter un item',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: context.tpInk,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 20),
              _EmojiPickerField(
                emojiCtrl: _emojiCtrl,
                emojiFocus: _emojiFocus,
                labelFocus: _labelFocus,
                helperText: 'Utilise le clavier emoji de ton téléphone 😊',
                fallbackEmoji: '❓',
              ),
              const SizedBox(height: 16),
              Text(
                'NOM DE L\'ITEM',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: context.tpInkSub,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: context.tpBg,
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(color: context.tpHair),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: TextField(
                  controller: _labelCtrl,
                  focusNode: _labelFocus,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.tpInk,
                  ),
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: 'ex: Bouteille de vin, Snacks, DJ set…',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: context.tpInkMute,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              if (widget.categoryMode) ...[
                const SizedBox(height: 16),
                Text(
                  'CATÉGORIE OBTENUE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: context.tpInkSub,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: context.tpBg,
                    borderRadius: BorderRadius.circular(Radii.md),
                    border: Border.all(color: context.tpHair),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    dropdownColor: context.tpCard,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.tpInk,
                    ),
                    items: widget.categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCategory = v),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Venir avec cet item donne un billet de cette catégorie.',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: context.tpInkMute,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'PLACES EN NATURE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: context.tpInkSub,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: context.tpBg,
                  borderRadius: BorderRadius.circular(Radii.md),
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
                      child: TextField(
                        controller: _qtyCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: context.tpInk,
                          letterSpacing: -0.5,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (v) {
                          final n = int.tryParse(v);
                          if (n != null) _qty = n.clamp(1, 9999);
                        },
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
                            borderRadius: BorderRadius.circular(Radii.button),
                          ),
                          child: const Center(
                            child: Text(
                              'Supprimer',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: kError,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: TpButton(
                      label: isEdit ? 'Enregistrer' : 'Ajouter',
                      icon: isEdit
                          ? PhosphorIcons.check()
                          : PhosphorIcons.plus(),
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
  const _QtyBtn({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: enabled ? kPrimary : context.tpHair,
            borderRadius: BorderRadius.circular(Radii.tag),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: enabled ? Colors.white : context.tpInkMute,
            ),
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
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w900,
      color: context.tpInkSub,
      letterSpacing: 0.3,
    ),
  );
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
        boxShadow: Shadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: context.tpInkSub,
                  letterSpacing: 0.3,
                ),
              ),
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

/// GestureDetector avec un léger effet d'échelle au press (0.97, 100ms —
/// même signature que TpButton) : retour tactile visuel cohérent, réutilisé
/// par les cartes de sélection du formulaire qui n'en avaient aucun.
class _PressableScale extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  const _PressableScale({required this.onTap, required this.child});

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
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
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: _PressableScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.tpCard,
            borderRadius: BorderRadius.circular(Radii.lg),
            boxShadow: Shadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: iconColor, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: context.tpInkSub,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: context.tpInk,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                sub,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: context.tpInkSub,
                ),
              ),
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
  const _VisCard({
    required this.emoji,
    required this.title,
    required this.sub,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      selected: active,
      child: _PressableScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: active ? kPrimary : context.tpCard,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: active
                ? null
                : Border.all(color: context.tpHair, width: 1.5),
            boxShadow: active
                ? [
                    const BoxShadow(
                      color: Color(0x4D7C3AED),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: active ? Colors.white : context.tpInk,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: active
                      ? Colors.white.withValues(alpha: 0.85)
                      : context.tpInkSub,
                ),
              ),
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
  const _ModeCard({
    required this.emoji,
    required this.title,
    required this.sub,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      selected: active,
      child: _PressableScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: active ? kPrimary : context.tpCard,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: active
                ? null
                : Border.all(color: context.tpHair, width: 1.5),
            boxShadow: active
                ? [
                    const BoxShadow(
                      color: Color(0x4D7C3AED),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: active ? Colors.white : context.tpInk,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                sub,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: active
                      ? Colors.white.withValues(alpha: 0.85)
                      : context.tpInkSub,
                ),
                textAlign: TextAlign.center,
              ),
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
  final int qty; // nombre de places en nature pour cette option (1 unité = 1 place)
  final String? categoryName; // catégorie rattachée (mode par catégorie)
  const _Item({
    required this.emoji,
    required this.label,
    required this.qty,
    this.categoryName,
  });
}

// ── Catégories de billets : brouillon, ligne, et éditeur ──────────────────────

const _catPalette = [
  '#4F46E5', '#7C3AED', '#EC4899', '#F97316',
  '#22A865', '#06B6D4', '#F59E0B', '#8B5CF6',
  '#EF4444', '#FACC15',
];

const _catPaletteNames = {
  '#4F46E5': 'Indigo', '#7C3AED': 'Violet', '#EC4899': 'Rose', '#F97316': 'Orange',
  '#22A865': 'Vert', '#06B6D4': 'Cyan', '#F59E0B': 'Ambre', '#8B5CF6': 'Mauve',
  '#EF4444': 'Rouge', '#FACC15': 'Jaune',
};

Color _hexColor(String c, [Color fallback = kPrimary]) {
  if (c.length == 7 && c.startsWith('#')) {
    final v = int.tryParse(c.substring(1), radix: 16);
    if (v != null) return Color(0xFF000000 | v);
  }
  return fallback;
}

class _CatDraft {
  String name;
  int price;
  int? capacity;
  List<String> advantages;
  String color;
  bool showRemaining;
  _CatDraft({
    required this.name,
    required this.price,
    this.capacity,
    this.advantages = const [],
    this.color = '',
    this.showRemaining = true,
  });

  Map<String, dynamic> toJson(int order) => {
        'name': name,
        'price': price,
        if (capacity != null) 'capacity': capacity,
        'advantages': advantages,
        if (color.isNotEmpty) 'color': color,
        'show_remaining': showRemaining,
        'order': order,
      };
}

class _CatRow extends StatelessWidget {
  final _CatDraft draft;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  const _CatRow(
      {required this.draft, required this.onTap, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final sub = [
      '${draft.price} FCFA',
      if (draft.capacity != null) '${draft.capacity} places',
      if (draft.advantages.isNotEmpty)
        '${draft.advantages.length} avantage${draft.advantages.length > 1 ? 's' : ''}',
    ].join(' · ');
    return Semantics(
      button: true,
      label: 'Modifier la catégorie ${draft.name}',
      child: GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.tpCard,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: context.tpHair),
        ),
        child: Row(children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
                color: _hexColor(draft.color), shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(draft.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: context.tpInk)),
              Text(sub,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: context.tpInkSub)),
            ]),
          ),
          Semantics(
            button: true,
            label: 'Supprimer la catégorie ${draft.name}',
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 44, height: 44,
                alignment: Alignment.center,
                child: Icon(PhosphorIcons.trash(), color: kError, size: 18),
              ),
            ),
          ),
        ]),
      ),
      ),
    );
  }
}

class _CategorySheet extends StatefulWidget {
  final _CatDraft? initial;
  final void Function(_CatDraft) onSave;
  final VoidCallback? onDelete;
  const _CategorySheet(
      {this.initial, required this.onSave, this.onDelete});

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _capacityCtrl;
  final _advCtrl = TextEditingController();
  late List<String> _advantages;
  late String _color;
  late bool _showRemaining;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _nameCtrl = TextEditingController(text: i?.name ?? '');
    _priceCtrl = TextEditingController(text: i != null ? i.price.toString() : '');
    _capacityCtrl = TextEditingController(text: i?.capacity?.toString() ?? '');
    _advantages = List<String>.from(i?.advantages ?? const []);
    _color = (i != null && i.color.isNotEmpty) ? i.color : _catPalette.first;
    _showRemaining = i?.showRemaining ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _capacityCtrl.dispose();
    _advCtrl.dispose();
    super.dispose();
  }

  void _addAdvantage() {
    final t = _advCtrl.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _advantages.add(t);
      _advCtrl.clear();
    });
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    final price = int.tryParse(_priceCtrl.text.trim());
    if (name.isEmpty || price == null || price < 0) return;
    widget.onSave(_CatDraft(
      name: name,
      price: price,
      capacity: int.tryParse(_capacityCtrl.text.trim()),
      advantages: _advantages,
      color: _color,
      showRemaining: _showRemaining,
    ));
    Navigator.pop(context);
  }

  InputDecoration _dec(BuildContext c, String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: c.tpInkMute),
        filled: true,
        fillColor: c.tpCard,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.button),
            borderSide: BorderSide.none),
      );

  @override
  Widget build(BuildContext context) {
    final inputStyle = TextStyle(
        fontSize: 14, fontWeight: FontWeight.w700, color: context.tpInk);
    final labelStyle = TextStyle(
        fontSize: 12.5, fontWeight: FontWeight.w800, color: context.tpInkSub);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.tpBg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(Radii.cardLg)),
        ),
        padding: const EdgeInsets.fromLTRB(Sp.md, 14, Sp.md, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: context.tpHair,
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              Text(
                  widget.initial == null
                      ? 'Nouvelle catégorie'
                      : 'Modifier la catégorie',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: context.tpInk)),
              const SizedBox(height: 16),
              Text('Nom (libre)', style: labelStyle),
              const SizedBox(height: 6),
              TextField(
                  controller: _nameCtrl,
                  decoration: _dec(context, 'Ex. VIP1, Carré Or…'),
                  style: inputStyle),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Prix (FCFA)', style: labelStyle),
                        const SizedBox(height: 6),
                        TextField(
                            controller: _priceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: _dec(context, 'Ex. 5000'),
                            style: inputStyle),
                      ]),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Places (vide = illimité)', style: labelStyle),
                        const SizedBox(height: 6),
                        TextField(
                            controller: _capacityCtrl,
                            keyboardType: TextInputType.number,
                            decoration: _dec(context, 'Ex. 100'),
                            style: inputStyle),
                      ]),
                ),
              ]),
              const SizedBox(height: 14),
              Text('Couleur', style: labelStyle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _catPalette.map((c) {
                  final selected = _color == c;
                  return Semantics(
                    button: true,
                    label: _catPaletteNames[c] ?? 'Couleur',
                    selected: selected,
                    child: GestureDetector(
                      onTap: () => setState(() => _color = c),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _hexColor(c),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: selected ? context.tpInk : Colors.transparent,
                                  width: 2.5),
                            ),
                            child: selected
                                ? Icon(PhosphorIconsBold.check, color: Colors.white, size: 16)
                                : null,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Text('Avantages', style: labelStyle),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _advCtrl,
                    onSubmitted: (_) => _addAdvantage(),
                    decoration: _dec(context, 'Ex. Accès backstage'),
                    style: inputStyle,
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: 'Ajouter un avantage',
                  child: GestureDetector(
                    onTap: _addAdvantage,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: kPrimary,
                          borderRadius: BorderRadius.circular(Radii.md)),
                      child: Icon(PhosphorIcons.plus(), color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ]),
              if (_advantages.isNotEmpty) ...[
                const SizedBox(height: 10),
                ..._advantages.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        Icon(PhosphorIcons.checkCircle(), color: kSuccess, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(e.value,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: context.tpInk)),
                        ),
                        Semantics(
                          button: true,
                          label: 'Retirer l\'avantage ${e.value}',
                          child: GestureDetector(
                            onTap: () => setState(() => _advantages.removeAt(e.key)),
                            child: Container(
                              width: 44, height: 44,
                              alignment: Alignment.center,
                              child: Icon(PhosphorIcons.x(),
                                  color: context.tpInkMute, size: 16),
                            ),
                          ),
                        ),
                      ]),
                    )),
              ],
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Afficher les places restantes',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: context.tpInk)),
                value: _showRemaining,
                onChanged: (v) => setState(() => _showRemaining = v),
              ),
              const SizedBox(height: 14),
              Row(children: [
                if (widget.onDelete != null) ...[
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        widget.onDelete!();
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: kError.withValues(alpha: 0.10),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Radii.button)),
                      ),
                      child: const Text('Supprimer',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, color: kError)),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  flex: 2,
                  child: TpButton(
                      label: 'Enregistrer', fullWidth: true, onPressed: _save),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final _Item item;
  final bool isFirst;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  const _ItemRow({
    required this.item,
    required this.isFirst,
    required this.onTap,
    required this.onRemove,
  });

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
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: context.tpBg,
                      borderRadius: BorderRadius.circular(Radii.tag),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      item.emoji,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.tpInk,
                          ),
                        ),
                        Text(
                          item.categoryName != null
                              ? '→ ${item.categoryName} · ${item.qty} place${item.qty > 1 ? 's' : ''}'
                              : '${item.qty} place${item.qty > 1 ? 's' : ''} en nature',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: context.tpInkMute,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: context.tpBg,
                      borderRadius: BorderRadius.circular(Radii.sm),
                    ),
                    child: Text(
                      '×${item.qty}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: context.tpInk,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: 'Supprimer ${item.label}',
                    child: GestureDetector(
                      onTap: onRemove,
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        child: Icon(
                          PhosphorIcons.minusCircle(),
                          color: kError,
                          size: 20,
                        ),
                      ),
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
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: kPrimary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TpAvatar(name: user.displayName, imageUrl: user.avatarUrl, size: 24),
          const SizedBox(width: 8),
          Text(
            user.displayName,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: kPrimary,
            ),
          ),
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
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(PhosphorIcons.x(), color: kPrimary, size: 14),
              ),
            ),
          ),
        ],
      ),
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
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final res = await ref
          .read(invitationServiceProvider)
          .searchUsers(q.trim());
      if (mounted)
        setState(() {
          _results = res;
          _searching = false;
        });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _add(UserSearchResult user) {
    widget.onAdd(user);
    setState(() => _justAdded.add(user.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${user.displayName} ajouté comme co-organisateur ✓'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        backgroundColor: kSuccess,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Radii.sheet),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        Sp.md,
        12,
        Sp.md,
        Sp.md + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: context.tpHair,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inviter un co-organisateur',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: context.tpInk,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Recherche par nom ou email',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.tpInkSub,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: context.tpBg,
                borderRadius: BorderRadius.circular(Radii.button),
                border: Border.all(color: context.tpHair),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Icon(
                    PhosphorIcons.magnifyingGlass(),
                    color: context.tpInkMute,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      autofocus: true,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.tpInk,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Nom ou adresse email…',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: context.tpInkMute,
                          fontWeight: FontWeight.w500,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                      ),
                      onChanged: _onSearch,
                    ),
                  ),
                  if (_searching)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: kPrimary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_results.isEmpty && _ctrl.text.length >= 2 && !_searching)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Aucun utilisateur trouvé',
                  style: TextStyle(
                    fontSize: 14,
                    color: context.tpInkSub,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else if (_results.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Tape un nom ou un email pour chercher…',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.tpInkMute,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.40,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: context.tpHair),
                  itemBuilder: (_, i) {
                    final user = _results[i];
                    final added =
                        _justAdded.contains(user.id) ||
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
                                Text(
                                  user.displayName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: context.tpInk,
                                  ),
                                ),
                                if (user.isPromoter)
                                  Text(
                                    '⭐ Promoteur',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: kPrimary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Semantics(
                            button: true,
                            label: added
                                ? 'Déjà ajouté'
                                : 'Ajouter ${user.displayName}',
                            child: GestureDetector(
                              onTap: added ? null : () => _add(user),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: added ? context.tpHair : kPrimary,
                                  borderRadius: BorderRadius.circular(
                                    Radii.tag,
                                  ),
                                ),
                                child: Text(
                                  added ? '✓ Ajouté' : 'Ajouter',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: added
                                        ? context.tpInkMute
                                        : Colors.white,
                                  ),
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
    required this.icon,
    required this.label,
    required this.onTap,
    this.loading = false,
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
            borderRadius: BorderRadius.circular(Radii.button),
          ),
          child: loading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: kPrimary,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: kPrimary, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: kPrimary,
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        isDense: true,
      ),
    );
  }
}

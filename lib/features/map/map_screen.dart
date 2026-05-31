import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/event_model.dart';
import '../../core/services/event_service.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_badge.dart';

// ── Catégories ────────────────────────────────────────────────────────────────

class _Cat {
  final Color color;
  final String emoji;
  final String label;
  const _Cat(this.color, this.emoji, this.label);
}

// Keys match backend category slugs (no accents)
const _cats = {
  'soiree':  _Cat(Color(0xFFEC4899), '🎉', 'Soirée'),
  'cuisine': _Cat(Color(0xFFF97316), '🍽', 'Cuisine'),
  'sport':   _Cat(Color(0xFF06B6D4), '⚽', 'Sport'),
  'musique': _Cat(Color(0xFF7C3AED), '🎵', 'Musique'),
  'art':     _Cat(Color(0xFF84CC16), '🎨', 'Art'),
  'plage':   _Cat(Color(0xFFF59E0B), '🏖', 'Plage'),
  'autre':   _Cat(Color(0xFF6B7280), '✨', 'Autre'),
};

_Cat _catFor(String? cat) => _cats[cat] ?? _cats['autre']!;

// ── Helpers ───────────────────────────────────────────────────────────────────

String _fmtDistance(double km) {
  if (km < 1) return '${(km * 1000).round()} m';
  return '${km.toStringAsFixed(1)} km';
}

String _fmtDateShort(DateTime dt) {
  final now      = DateTime.now();
  final isToday  = dt.year == now.year && dt.month == now.month && dt.day == now.day;
  final tomorrow = now.add(const Duration(days: 1));
  final isTomorrow = dt.year == tomorrow.year && dt.month == tomorrow.month && dt.day == tomorrow.day;

  final hhmm = DateFormat("HH'h'mm").format(dt).replaceAll('h00', 'h');
  if (isToday)    return 'Ce soir · $hhmm';
  if (isTomorrow) return 'Demain · $hhmm';
  return '${DateFormat('EEE d MMM', 'fr_FR').format(dt)} · $hhmm';
}

double _kmBetween(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLng = (lng2 - lng1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLng / 2) * sin(dLng / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

// ── Style carte custom ────────────────────────────────────────────────────────

const _mapStyle = '''[
  {"elementType":"geometry","stylers":[{"color":"#E8E4DC"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#6B6A82"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#F7F7FB"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#A8D5E5"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#5A8DA6"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#FFFFFF"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#F4EFE5"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#FFFFFF"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#EDE8DE"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#9CA3AF"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#C9D9C2"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#C9D9C2"}]},
  {"featureType":"poi","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#6B6A82"},{"fontWeight":"800"}]}
]''';

// ═══════════════════════════════════════════════════════════════════════════
// Screen
// ═══════════════════════════════════════════════════════════════════════════

class MapScreen extends ConsumerStatefulWidget {
  final double? destinationLat;
  final double? destinationLng;
  final String? destinationTitle;
  final String? destinationId;

  const MapScreen({
    super.key,
    this.destinationLat,
    this.destinationLng,
    this.destinationTitle,
    this.destinationId,
  });

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController?              _ctrl;
  String?                           _selectedId;
  bool                              _listMode    = false;
  int                               _filterIndex = 0;
  LatLng?                           _userPos;
  BitmapDescriptor?                 _positionIcon;
  Map<String, BitmapDescriptor>     _markerIcons = {};

  // API state
  List<EventModel> _events  = [];
  bool             _loading = true;
  String?          _error;

  static const _abidjan = LatLng(5.3600, -4.0083);
  static const _chips   = ['Tous ✨', '5 km 📍', 'Ce soir 🌙', 'Gratuit 💸'];

  bool get _itineraryMode =>
      widget.destinationLat != null && widget.destinationLng != null;

  LatLng? get _destination => _itineraryMode
      ? LatLng(widget.destinationLat!, widget.destinationLng!)
      : null;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _buildBitmojiMarker().then((icon) {
      if (mounted) setState(() => _positionIcon = icon);
    });
    _requestLocation().then((_) {
      if (_itineraryMode) _fitItinerary();
    });
    if (!_itineraryMode) _loadEvents();
  }

  // ── GPS ────────────────────────────────────────────────────────────────────

  Future<void> _requestLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() => _userPos = LatLng(pos.latitude, pos.longitude));
        if (!_itineraryMode && _filterIndex == 1) _loadEvents();
      }
    } catch (_) {}
  }

  Future<void> _fitItinerary() async {
    if (_destination == null) return;
    // Attend que la carte soit prête (max 2 s)
    for (var i = 0; i < 20; i++) {
      if (_ctrl != null) break;
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (_ctrl == null || !mounted) return;

    final dest = _destination!;
    final origin = _userPos ?? _abidjan;

    final sw = LatLng(
      min(origin.latitude, dest.latitude),
      min(origin.longitude, dest.longitude),
    );
    final ne = LatLng(
      max(origin.latitude, dest.latitude),
      max(origin.longitude, dest.longitude),
    );
    _ctrl!.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(southwest: sw, northeast: ne),
      72,
    ));
  }

  Future<void> _openGoogleMaps() async {
    if (_destination == null) return;
    final dest = _destination!;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${dest.latitude},${dest.longitude}'
      '&travelmode=driving',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Chargement API ─────────────────────────────────────────────────────────

  Future<void> _loadEvents() async {
    setState(() { _loading = true; _error = null; });
    try {
      final service = ref.read(eventServiceProvider);
      String? filter;
      String? contribution;
      double? lat, lng;
      double  radius = 25;

      switch (_filterIndex) {
        case 1: // 5 km
          if (_userPos != null) {
            lat    = _userPos!.latitude;
            lng    = _userPos!.longitude;
            radius = 5;
          }
        case 2: // Ce soir
          filter = 'tonight';
        case 3: // Gratuit
          contribution = 'free';
      }

      final result = await service.getFeed(
        filter: filter,
        contribution: contribution,
        lat: lat,
        lng: lng,
        radius: radius,
        ordering: lat != null ? 'start_at' : 'start_at',
      );

      final withCoords = result.results
          .where((e) => e.latitude != null && e.longitude != null)
          .toList();

      if (mounted) {
        setState(() {
          _events  = withCoords;
          _loading = false;
        });
        _generateMarkersForEvents(withCoords);
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _setFilter(int index) {
    setState(() { _filterIndex = index; _selectedId = null; });
    _loadEvents();
  }

  // ── Bitmoji marker ─────────────────────────────────────────────────────────

  Future<BitmapDescriptor> _buildBitmojiMarker() async {
    const ratio   = 3.0;
    const circleD = 62.0;
    const border  = 5.0;
    const triH    = 14.0;
    const triW    = 18.0;
    const pad     = 10.0;
    final totalW  = circleD + pad * 2;
    final totalH  = circleD + triH + pad * 2;
    final cx = totalW / 2, cy = pad + circleD / 2;

    final recorder = ui.PictureRecorder();
    final canvas   = Canvas(recorder);
    canvas.scale(ratio);

    final shape = Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: circleD / 2))
      ..moveTo(cx - triW / 2, cy + circleD / 2 - 2)
      ..lineTo(cx + triW / 2, cy + circleD / 2 - 2)
      ..lineTo(cx,            cy + circleD / 2 + triH)
      ..close();
    canvas.drawPath(shape.shift(const Offset(0, 4)),
      Paint()..color = Colors.black.withValues(alpha: 0.22)
             ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
    canvas.drawPath(shape, Paint()..color = Colors.white);

    final avatarR = circleD / 2 - border;
    canvas.drawCircle(Offset(cx, cy), avatarR,
      Paint()..shader = const LinearGradient(
        colors: [Color(0xFF4F46E5), Color(0xFFEC4899)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: avatarR)));

    final pb = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: TextAlign.center, fontSize: avatarR * 0.72, maxLines: 1,
    ))..pushStyle(ui.TextStyle(color: const ui.Color(0xFFFFFFFF), fontWeight: ui.FontWeight.bold))
      ..addText('Moi');
    final para = pb.build()..layout(ui.ParagraphConstraints(width: circleD));
    canvas.drawParagraph(para, Offset(pad, cy - para.height / 2));

    final picture = recorder.endRecording();
    final img  = await picture.toImage((totalW * ratio).round(), (totalH * ratio).round());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(data!.buffer.asUint8List(), imagePixelRatio: ratio);
  }

  // ── Marqueurs d'événements ─────────────────────────────────────────────────

  Future<void> _generateMarkersForEvents(List<EventModel> events) async {
    final icons = <String, BitmapDescriptor>{};
    for (final e in events) {
      final cat = _catFor(e.category);
      icons['${e.id}_n'] = await _buildEventMarker(cat.emoji, cat.color, selected: false);
      icons['${e.id}_s'] = await _buildEventMarker(cat.emoji, cat.color, selected: true);
    }
    if (mounted) setState(() => _markerIcons = icons);
  }

  Future<BitmapDescriptor> _buildEventMarker(String emoji, Color color, {required bool selected}) async {
    const ratio   = 3.0;
    final circle  = selected ? 56.0 : 40.0;
    const border  = 3.0;
    const triW    = 16.0;
    const triH    = 12.0;
    const pad     = 12.0;
    final totalW  = circle + pad * 2;
    final totalH  = circle + triH + pad * 2;
    final cx = totalW / 2, cy = pad + circle / 2;

    final recorder = ui.PictureRecorder();
    final canvas   = Canvas(recorder);
    canvas.scale(ratio);

    final fullShape = Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: circle / 2))
      ..moveTo(cx - triW / 2, cy + circle / 2 - 1)
      ..lineTo(cx + triW / 2, cy + circle / 2 - 1)
      ..lineTo(cx,            cy + circle / 2 + triH)
      ..close();
    canvas.drawPath(fullShape.shift(const Offset(0, 4)),
      Paint()..color = const Color(0x40000000)
             ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

    canvas.drawCircle(Offset(cx, cy), circle / 2, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(cx, cy), circle / 2 - border, Paint()..color = color);
    canvas.drawPath(
      Path()
        ..moveTo(cx - triW / 2, cy + circle / 2 - 1)
        ..lineTo(cx + triW / 2, cy + circle / 2 - 1)
        ..lineTo(cx,            cy + circle / 2 + triH)
        ..close(),
      Paint()..color = color,
    );

    final fontSize = selected ? 24.0 : 18.0;
    final pb = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: TextAlign.center, fontSize: fontSize, maxLines: 1,
    ))..addText(emoji);
    final para = pb.build()..layout(ui.ParagraphConstraints(width: circle));
    canvas.drawParagraph(para, Offset(pad, pad + (circle - para.height) / 2));

    final picture = recorder.endRecording();
    final img  = await picture.toImage((totalW * ratio).round(), (totalH * ratio).round());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(data!.buffer.asUint8List(), imagePixelRatio: ratio);
  }

  // ── Markers set ────────────────────────────────────────────────────────────

  Set<Marker> get _markers {
    final set = <Marker>{};

    if (_itineraryMode) {
      // Mode itinéraire : marker de destination uniquement
      if (_destination != null) {
        set.add(Marker(
          markerId: const MarkerId('_destination'),
          position: _destination!,
          icon: _markerIcons.values.firstOrNull ?? BitmapDescriptor.defaultMarker,
          anchor: const Offset(0.5, 0.84),
          zIndexInt: 1,
        ));
      }
    } else {
      for (final e in _events) {
        final sel = _selectedId == e.id;
        set.add(Marker(
          markerId: MarkerId(e.id),
          position: LatLng(e.latitude!, e.longitude!),
          icon: _markerIcons['${e.id}_${sel ? 's' : 'n'}'] ?? BitmapDescriptor.defaultMarker,
          anchor: Offset(0.5, sel ? 0.87 : 0.84),
          zIndexInt: sel ? 1 : 0,
          onTap: () => setState(() => _selectedId = e.id),
        ));
      }
    }

    if (_userPos != null && _positionIcon != null) {
      set.add(Marker(
        markerId: const MarkerId('_me'),
        position: _userPos!,
        icon: _positionIcon!,
        anchor: const Offset(0.5, 0.896),
        zIndexInt: 10,
        onTap: () {},
      ));
    }
    return set;
  }

  Set<Polyline> get _polylines {
    if (!_itineraryMode || _destination == null || _userPos == null) return {};
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: [_userPos!, _destination!],
        color: kPrimary,
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    };
  }

  EventModel? get _selectedEvent =>
      _selectedId == null ? null : _events.where((e) => e.id == _selectedId).firstOrNull;

  String _distanceFor(EventModel e) {
    if (_userPos == null) return '? km';
    final km = _kmBetween(_userPos!.latitude, _userPos!.longitude, e.latitude!, e.longitude!);
    return _fmtDistance(km);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_itineraryMode) return _buildItineraryScaffold();

    return Scaffold(
      body: Stack(
        children: [
          _listMode ? _buildListBody() : _buildMap(),
          _buildTopOverlay(),
          if (!_listMode) _buildMapControls(),
          if (!_listMode && _selectedEvent != null)
            Positioned(
              bottom: 90, left: 12, right: 12,
              child: _PinCard(
                event: _selectedEvent!,
                distance: _distanceFor(_selectedEvent!),
                onClose: () => setState(() => _selectedId = null),
                onView: () => context.push('/event/${_selectedEvent!.id}'),
              ),
            ),
          if (_loading)
            Positioned(
              top: MediaQuery.of(context).padding.top + 170,
              left: 0, right: 0,
              child: const Center(child: _LoadingChip()),
            ),
          if (!_loading && _error != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 170,
              left: Sp.md, right: Sp.md,
              child: _ErrorBanner(onRetry: _loadEvents),
            ),
        ],
      ),
    );
  }

  Widget _buildItineraryScaffold() {
    final distStr = _userPos != null && _destination != null
        ? _fmtDistance(_kmBetween(
            _userPos!.latitude, _userPos!.longitude,
            _destination!.latitude, _destination!.longitude))
        : null;

    return Scaffold(
      body: Stack(
        children: [
          _buildMap(),
          // Header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Sp.md, Sp.sm, Sp.md, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: context.tpCard,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: Shadows.md,
                ),
                child: Row(
                  children: [
                    Semantics(
                      button: true,
                      label: 'Retour',
                      child: GestureDetector(
                        onTap: () => context.go('/map'),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(color: context.tpBg, borderRadius: BorderRadius.circular(10)),
                          child: Icon(PhosphorIcons.caretLeft(), color: context.tpInk, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Itinéraire',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.tpInkSub)),
                          Text(
                            widget.destinationTitle ?? 'Destination',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: context.tpInk),
                          ),
                        ],
                      ),
                    ),
                    if (distStr != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: kPrimary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(distStr,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: kPrimary)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // Bouton ma position
          Positioned(
            right: Sp.md,
            bottom: 160,
            child: Semantics(
              button: true,
              label: 'Recentrer l\'itinéraire',
              child: GestureDetector(
                onTap: _fitItinerary,
                child: Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    gradient: trackpartyGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: Shadows.brand,
                  ),
                  child: Icon(PhosphorIcons.arrowsOut(), color: Colors.white, size: 22),
                ),
              ),
            ),
          ),
          // Bandeau bas : naviguer
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, Sp.md + MediaQuery.of(context).padding.bottom),
              decoration: BoxDecoration(
                color: context.tpCard,
                boxShadow: const [BoxShadow(color: Color(0x1F1B1A2E), blurRadius: 24, offset: Offset(0, -4))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.destinationTitle ?? 'Destination',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: context.tpInk)),
                        if (distStr != null)
                          Text('📍 $distStr depuis ta position',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.tpInkSub)),
                        if (_userPos == null)
                          Text('Position GPS en cours…',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.tpInkMute)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Semantics(
                    button: true,
                    label: 'Ouvrir la navigation dans Google Maps',
                    child: GestureDetector(
                      onTap: _openGoogleMaps,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: trackpartyGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: Shadows.brand,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(PhosphorIcons.navigationArrow(PhosphorIconsStyle.fill), color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            const Text('Naviguer', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Google Map ─────────────────────────────────────────────────────────────

  Widget _buildMap() {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _userPos ?? (_destination ?? _abidjan),
        zoom: 13.5,
      ),
      style: _mapStyle,
      onMapCreated: (ctrl) {
        _ctrl = ctrl;
        if (_itineraryMode) _fitItinerary();
      },
      markers: _markers,
      polylines: _polylines,
      onTap: (_) => setState(() => _selectedId = null),
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
    );
  }

  // ── Corps liste ────────────────────────────────────────────────────────────

  Widget _buildListBody() {
    final topPad = MediaQuery.of(context).padding.top + 162.0;

    if (!_loading && _events.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: topPad + 20),
        child: Center(
          child: Column(
            children: [
              const Text('🎉', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text('Aucun événement ici',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900,
                    color: context.tpInk)),
              const SizedBox(height: 4),
              Text('Sois le premier à en créer un !',
                style: TextStyle(fontSize: 13, color: context.tpInkSub)),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(Sp.md, topPad + 4, Sp.md, 100),
      itemCount: _events.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final e = _events[i];
        return _MapListRow(
          event: e,
          distance: _distanceFor(e),
          onTap: () => context.push('/event/${e.id}'),
        );
      },
    );
  }

  // ── Overlay supérieur (search + toggle + chips) ────────────────────────────

  Widget _buildTopOverlay() {
    return SafeArea(
      bottom: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Search bar ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.md, Sp.sm, Sp.md, 0),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: context.tpCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.tpHair),
                boxShadow: Shadows.md,
              ),
              padding: const EdgeInsets.symmetric(horizontal: Sp.md),
              child: Row(
                children: [
                  Icon(PhosphorIcons.magnifyingGlass(), color: context.tpInkMute, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Abidjan',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.tpInk)),
                  ),
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      gradient: trackpartyGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(PhosphorIcons.slidersHorizontal(), color: Colors.white, size: 16),
                  ),
                ],
              ),
            ),
          ),

          // ── Toggle Carte / Liste + compteur ────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: context.tpCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.tpHair),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ToggleTab(
                        icon: PhosphorIcons.mapPin(),
                        label: 'Carte',
                        active: !_listMode,
                        onTap: () => setState(() { _listMode = false; _selectedId = null; }),
                      ),
                      const SizedBox(width: 2),
                      _ToggleTab(
                        icon: PhosphorIcons.list(),
                        label: 'Liste',
                        active: _listMode,
                        onTap: () => setState(() => _listMode = true),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (_loading)
                  const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: kPrimary),
                  )
                else
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${_events.length}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: kPrimary),
                        ),
                        TextSpan(
                          text: ' events',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.tpInkSub),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ── Chips filtres ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Sp.md),
              child: Row(
                children: List.generate(_chips.length, (i) {
                  final active = i == _filterIndex;
                  return Semantics(
                    button: true,
                    label: _chips[i],
                    selected: active,
                    child: GestureDetector(
                      onTap: () => _setFilter(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(right: Sp.sm),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: active ? trackpartyGradient : null,
                          color: active ? null : context.tpCard,
                          borderRadius: BorderRadius.circular(12),
                          border: active ? null : Border.all(color: context.tpHair),
                          boxShadow: active
                              ? [const BoxShadow(color: Color(0x407C3AED), blurRadius: 10, offset: Offset(0, 4))]
                              : Shadows.sm,
                        ),
                        child: Text(
                          _chips[i],
                          style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800,
                            color: active ? Colors.white : context.tpInkSub,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── GPS + Zoom ─────────────────────────────────────────────────────────────

  Widget _buildMapControls() {
    return Positioned(
      right: Sp.md,
      bottom: _selectedEvent != null ? 230 : 120,
      child: Column(
        children: [
          Semantics(
            button: true,
            label: 'Ma position',
            child: GestureDetector(
              onTap: () => _ctrl?.animateCamera(
                CameraUpdate.newLatLng(_userPos ?? _abidjan)),
              child: Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  gradient: trackpartyGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: Shadows.brand,
                ),
                child: Icon(PhosphorIcons.navigationArrow(), color: Colors.white, size: 24),
              ),
            ),
          ),
          const SizedBox(height: Sp.sm),
          Container(
            width: 50,
            decoration: BoxDecoration(
              color: context.tpCard,
              borderRadius: BorderRadius.circular(16),
              boxShadow: Shadows.md,
            ),
            child: Column(
              children: [
                _ZoomBtn(label: '+', onTap: () => _ctrl?.animateCamera(CameraUpdate.zoomIn())),
                Divider(height: 1, color: context.tpHair),
                _ZoomBtn(label: '−', onTap: () => _ctrl?.animateCamera(CameraUpdate.zoomOut())),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Widgets utilitaires
// ══════════════════════════════════════════════════════════════════════════════

class _LoadingChip extends StatelessWidget {
  const _LoadingChip();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: Shadows.md,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 12, height: 12,
            child: CircularProgressIndicator(strokeWidth: 2, color: kPrimary),
          ),
          const SizedBox(width: 8),
          Text('Chargement…',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.tpInkSub)),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorBanner({required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: kError.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(PhosphorIcons.warning(), color: kError, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Impossible de charger les événements',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kError)),
          ),
          GestureDetector(
            onTap: onRetry,
            child: Text('Réessayer',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kPrimary)),
          ),
        ],
      ),
    );
  }
}

// ── Toggle tab (Carte / Liste) ────────────────────────────────────────────────

class _ToggleTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ToggleTab({required this.icon, required this.label,
    required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      selected: active,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            gradient: active ? trackpartyGradient : null,
            borderRadius: BorderRadius.circular(9),
            boxShadow: active
                ? [const BoxShadow(color: Color(0x4D7C3AED), blurRadius: 6, offset: Offset(0, 2))]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: active ? Colors.white : context.tpInkSub),
              const SizedBox(width: 5),
              Text(label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                    color: active ? Colors.white : context.tpInkSub)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Zoom button ───────────────────────────────────────────────────────────────

class _ZoomBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ZoomBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label == '+' ? 'Zoom avant' : 'Zoom arrière',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 50, height: 50,
          child: Center(
            child: Text(label, style: TextStyle(
              fontSize: 26, fontWeight: FontWeight.w800,
              color: context.tpInk, height: 1)),
          ),
        ),
      ),
    );
  }
}

// ── Pin card (bottom sheet sur tap marqueur) ──────────────────────────────────

class _PinCard extends StatelessWidget {
  final EventModel event;
  final String distance;
  final VoidCallback onClose;
  final VoidCallback onView;

  const _PinCard({
    required this.event, required this.distance,
    required this.onClose, required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final cat = _catFor(event.category);
    return Container(
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [BoxShadow(color: Color(0x2E1B1A2E), blurRadius: 30, offset: Offset(0, -8))],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 76, height: 76,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  image: event.coverImageUrl != null
                      ? DecorationImage(
                          image: NetworkImage(event.coverImageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                  gradient: event.coverImageUrl == null
                      ? LinearGradient(
                          colors: [cat.color, cat.color.withValues(alpha: 0.6)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        )
                      : null,
                ),
                alignment: event.coverImageUrl == null ? Alignment.center : null,
                child: event.coverImageUrl == null
                    ? Text(cat.emoji, style: const TextStyle(fontSize: 32))
                    : null,
              ),
              Positioned(
                top: 4, left: 4,
                child: TpBadge.category(event.category),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900,
                      color: context.tpInk, letterSpacing: -0.3)),
                const SizedBox(height: 4),
                Row(children: [
                  Text('📍 $distance',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: context.tpInkSub)),
                  Text(' · ', style: TextStyle(color: context.tpInkMute)),
                  Expanded(child: Text(_fmtDateShort(event.startAt),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: context.tpInkSub),
                    overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 4),
                Text('${event.participantsCount} viennent',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kSuccess)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              Semantics(
                button: true,
                label: 'Fermer',
                child: GestureDetector(
                  onTap: onClose,
                  child: Icon(PhosphorIcons.x(), color: context.tpInkMute, size: 18),
                ),
              ),
              const SizedBox(height: 8),
              Semantics(
                button: true,
                label: 'Voir l\'événement',
                child: GestureDetector(
                  onTap: onView,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: trackpartyGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: Shadows.brand,
                    ),
                    child: const Text('Voir →',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Row liste ─────────────────────────────────────────────────────────────────

class _MapListRow extends StatelessWidget {
  final EventModel event;
  final String distance;
  final VoidCallback onTap;

  const _MapListRow({required this.event, required this.distance, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cat = _catFor(event.category);
    final max = event.maxParticipants ?? 0;
    final pct = max > 0 ? event.participantsCount / max : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.tpCard,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Color(0x0D1B1A2E), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 76, height: 76,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    image: event.coverImageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(event.coverImageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                    gradient: event.coverImageUrl == null
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [cat.color, cat.color.withValues(alpha: 0.55)],
                          )
                        : null,
                  ),
                  alignment: event.coverImageUrl == null ? Alignment.center : null,
                  child: event.coverImageUrl == null
                      ? Text(cat.emoji, style: const TextStyle(fontSize: 30))
                      : null,
                ),
                Positioned(
                  top: 4, left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: cat.color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(cat.emoji,
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900,
                        color: context.tpInk, letterSpacing: -0.3)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text('par ${event.organizerName}',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                              color: context.tpInkSub)),
                      ),
                      if (event.organizerIsPromoter) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            gradient: trackpartyGradient,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('★',
                            style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900,
                                color: Colors.white)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('📍 $distance · ${_fmtDateShort(event.startAt)}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                        color: context.tpInkSub)),
                  const SizedBox(height: 6),
                  if (max > 0)
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: pct,
                              backgroundColor: context.tpHair,
                              valueColor: AlwaysStoppedAnimation(cat.color),
                              minHeight: 4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('${event.participantsCount}/$max',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                              color: context.tpInkSub)),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

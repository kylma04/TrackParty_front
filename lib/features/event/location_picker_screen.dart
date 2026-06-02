import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';


import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_button.dart';

// ── Return type ───────────────────────────────────────────────────────────────

class LocationPickerResult {
  final double lat;
  final double lng;
  const LocationPickerResult({required this.lat, required this.lng});
}

// ── Screen ────────────────────────────────────────────────────────────────────

class LocationPickerScreen extends StatefulWidget {
  final double initialLat;
  final double initialLng;

  const LocationPickerScreen({
    super.key,
    this.initialLat = 5.3484,
    this.initialLng = -4.0168,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _ctrl = Completer<GoogleMapController>();
  late LatLng _center;
  bool _moving = false;

  @override
  void initState() {
    super.initState();
    _center = LatLng(widget.initialLat, widget.initialLng);
  }

  Future<void> _goToMyLocation() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    final target = LatLng(pos.latitude, pos.longitude);
    final map = await _ctrl.future;
    await map.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Carte ───────────────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _center, zoom: 15),
            onMapCreated: (c) => _ctrl.complete(c),
            onCameraMove: (pos) {
              _center = pos.target;
              if (!_moving) setState(() => _moving = true);
            },
            onCameraIdle: () => setState(() => _moving = false),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          // ── Épingle centrale fixe ────────────────────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  transform: Matrix4.translationValues(0, _moving ? -10 : 0, 0),
                  child: Icon(
                    Icons.location_on,
                    color: kPrimary,
                    size: 52,
                    shadows: const [
                      Shadow(blurRadius: 16, color: Color(0x807C3AED)),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: _moving ? 14 : 8,
                  height: _moving ? 3 : 5,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ],
            ),
          ),

          // ── Header ──────────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, 0),
              child: Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'Fermer',
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: context.tpCard,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: Shadows.sm,
                        ),
                        child: Icon(Icons.close, color: context.tpInk, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: context.tpCard,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: Shadows.sm,
                      ),
                      child: Text(
                        'Déplace la carte, puis confirme',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.tpInk),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Panneau bas ──────────────────────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(Sp.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Coordonnées en temps réel
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: context.tpCard,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: Shadows.sm,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_on_outlined, color: kPrimary, size: 15),
                          const SizedBox(width: 6),
                          Text(
                            '${_center.latitude.toStringAsFixed(5)},  ${_center.longitude.toStringAsFixed(5)}',
                            style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: context.tpInk, fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // Bouton GPS
                        Semantics(
                          button: true,
                          label: 'Ma position actuelle',
                          child: GestureDetector(
                            onTap: _goToMyLocation,
                            child: Container(
                              width: 52, height: 52,
                              decoration: BoxDecoration(
                                gradient: trackpartyGradient,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: const [
                                  BoxShadow(color: Color(0x4D7C3AED), blurRadius: 12, offset: Offset(0, 4)),
                                ],
                              ),
                              child: Icon(Icons.gps_fixed, color: Colors.white, size: 22),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TpButton(
                            label: 'Confirmer cette position',
                            onPressed: () => Navigator.pop(
                              context,
                              LocationPickerResult(lat: _center.latitude, lng: _center.longitude),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/api/api_exception.dart';
import '../../core/models/ticket_model.dart';
import '../../core/services/ticket_service.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';

/// Délai d'affichage du résultat avant reprise automatique du scan.
const Duration _kCheckinResetDelay = Duration(seconds: 18);

class CheckinScannerScreen extends ConsumerStatefulWidget {
  final String eventId;
  final String eventTitle;
  const CheckinScannerScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  @override
  ConsumerState<CheckinScannerScreen> createState() => _CheckinScannerScreenState();
}

class _CheckinScannerScreenState extends ConsumerState<CheckinScannerScreen> {
  final MobileScannerController _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _processing = false;
  _ScanResult? _result;
  Timer? _resetTimer;
  int _secondsLeft = 0;
  // Billet en nature en attente de vérification par le staff : la caméra ne
  // reprend pas tant qu'il n'a pas confirmé ou refusé.
  String? _pendingToken;

  @override
  void dispose() {
    _scanner.dispose();
    _resetTimer?.cancel();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final token = capture.barcodes.firstOrNull?.rawValue;
    if (token == null) return;

    setState(() { _processing = true; _result = null; });
    await _scanner.stop();
    await _performCheckin(token, confirm: false);
  }

  Future<void> _performCheckin(String token, {required bool confirm}) async {
    try {
      final result = await ref
          .read(ticketServiceProvider)
          .checkin(widget.eventId, token, confirm: confirm);
      if (mounted) {
        setState(() => _result = _ScanResult.fromCheckin(result));
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _result = _ScanResult.error(e.message));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _result = _ScanResult.error('Erreur réseau'));
      }
    }

    if (_result?.status == _ScanStatus.pendingConfirmation) {
      // On attend une action explicite du staff (Confirmer/Refuser) : pas de
      // reprise automatique de la caméra tant qu'il n'a pas tranché.
      _pendingToken = token;
      return;
    }

    _pendingToken = null;
    _startResetCountdown();
  }

  /// Décompte (affiché en direct) avant reprise automatique de la caméra. Le
  /// staff n'est pas obligé d'attendre : « Scanner un nouveau ticket » coupe
  /// court via [_resetScanner].
  void _startResetCountdown() {
    _resetTimer?.cancel();
    setState(() => _secondsLeft = _kCheckinResetDelay.inSeconds);
    _resetTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_secondsLeft <= 1) {
        timer.cancel();
        _resetScanner();
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  /// Le staff confirme avoir vérifié que le participant apporte bien sa
  /// contribution en nature : l'entrée est alors matérialisée côté serveur.
  void _confirmInKind() {
    final token = _pendingToken;
    if (token == null) return;
    setState(() => _result = null);
    _performCheckin(token, confirm: true);
  }

  /// Le staff refuse (contribution absente) : rien n'est écrit côté serveur,
  /// le billet reste valable et le participant pourra revenir se faire
  /// scanner une fois sa contribution récupérée.
  void _refuseInKind() {
    _pendingToken = null;
    _resetScanner();
  }

  /// Remet la caméra en route tout de suite — bouton « Scanner un nouveau
  /// ticket » ou fin du décompte, sans attendre le reste du délai.
  void _resetScanner() {
    _resetTimer?.cancel();
    setState(() { _processing = false; _result = null; });
    _scanner.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        MobileScanner(controller: _scanner, onDetect: _onDetect),
        // Overlay cadre de scan
        _ScanOverlay(),
        // Barre de nav
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, 0),
            child: Row(children: [
              Semantics(
                button: true, label: 'Retour',
                child: GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(Radii.md)),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Scanner les entrées',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                  Text(widget.eventTitle,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white70),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
              // Flash toggle
              Semantics(
                button: true, label: 'Activer/désactiver la lampe torche',
                child: GestureDetector(
                onTap: () => _scanner.toggleTorch(),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                      color: Colors.black54, borderRadius: BorderRadius.circular(Radii.md)),
                  child: const Icon(Icons.flash_on, color: Colors.white, size: 20),
                ),
                ),
              ),
            ]),
          ),
        ),
        // Feedback overlay
        if (_result != null)
          _ResultOverlay(
            result: _result!,
            secondsLeft: _secondsLeft,
            onConfirm: _confirmInKind,
            onRefuse: _refuseInKind,
            onScanNext: _resetScanner,
          ),
        // Indicateur de traitement
        if (_processing && _result == null)
          const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
      ]),
    );
  }
}

// ── Résultat du scan ──────────────────────────────────────────────────────────

enum _ScanStatus { success, alreadyChecked, pendingConfirmation, invalid, error }

class _ScanResult {
  final _ScanStatus status;
  final String holderName;
  final String? checkedTime;
  final String message;
  final bool isInKind;
  final String? categoryName;
  final Color? categoryColor;
  final String? natureLabel; // ex. « 🍺 5 bières »

  const _ScanResult({
    required this.status,
    required this.holderName,
    this.checkedTime,
    required this.message,
    this.isInKind = false,
    this.categoryName,
    this.categoryColor,
    this.natureLabel,
  });

  static Color? _parseHex(String? hex) {
    if (hex == null || hex.length != 7 || !hex.startsWith('#')) return null;
    final v = int.tryParse(hex.substring(1), radix: 16);
    return v == null ? null : Color(0xFF000000 | v);
  }

  static _ScanResult _ctx(CheckinResult r, _ScanStatus status,
      {required String holder, String? time, required String message}) {
    final nature = r.natureItemName != null
        ? '${r.natureItemEmoji ?? '🎁'} ${r.natureItemName}'.trim()
        : null;
    return _ScanResult(
      status: status,
      holderName: holder,
      checkedTime: time,
      message: message,
      isInKind: r.isInKind,
      categoryName: r.categoryName,
      categoryColor: _parseHex(r.categoryColor),
      natureLabel: nature,
    );
  }

  factory _ScanResult.fromCheckin(CheckinResult r) {
    if (!r.valid) {
      return _ScanResult._ctx(r, _ScanStatus.invalid,
          holder: r.holderName, message: r.message);
    }
    if (r.alreadyChecked) {
      final timeStr = r.checkedInAt != null
          ? DateFormat('HH\'h\'mm', 'fr_FR').format(r.checkedInAt!.toLocal())
          : '?';
      return _ScanResult._ctx(r, _ScanStatus.alreadyChecked,
          holder: r.holderName, time: timeStr, message: 'Déjà scanné à $timeStr');
    }
    if (r.requiresConfirmation) {
      return _ScanResult._ctx(r, _ScanStatus.pendingConfirmation,
          holder: r.holderName, message: 'Vérifie la contribution avant de valider');
    }
    return _ScanResult._ctx(r, _ScanStatus.success,
        holder: r.holderName, message: 'Entrée validée');
  }

  factory _ScanResult.error(String msg) => _ScanResult(
        status: _ScanStatus.error,
        holderName: '',
        message: msg,
      );

  Color get bgColor => switch (status) {
        _ScanStatus.success            => kSuccess,
        _ScanStatus.alreadyChecked     => kAccent,
        _ScanStatus.pendingConfirmation => kAccent,
        _ScanStatus.invalid            => kError,
        _ScanStatus.error              => kError,
      };

  IconData get icon => switch (status) {
        _ScanStatus.success            => Icons.check_circle_rounded,
        _ScanStatus.alreadyChecked     => Icons.warning_amber_rounded,
        _ScanStatus.pendingConfirmation => Icons.fact_check_rounded,
        _ScanStatus.invalid            => Icons.cancel_rounded,
        _ScanStatus.error              => Icons.error_rounded,
      };
}

class _ResultOverlay extends StatelessWidget {
  final _ScanResult result;
  final int secondsLeft;
  final VoidCallback onConfirm;
  final VoidCallback onRefuse;
  final VoidCallback onScanNext;
  const _ResultOverlay({
    required this.result,
    required this.secondsLeft,
    required this.onConfirm,
    required this.onRefuse,
    required this.onScanNext,
  });

  @override
  Widget build(BuildContext context) {
    final pending = result.status == _ScanStatus.pendingConfirmation;
    final isValid = result.status == _ScanStatus.success ||
        result.status == _ScanStatus.alreadyChecked ||
        pending;
    // Billet payant → cadre coloré de la catégorie autour de l'écran.
    final showFrame =
        !result.isInKind && result.categoryColor != null && isValid;
    // Billet nature encore valable → afficher ce qu'il doit apporter.
    final showNature = result.isInKind &&
        result.natureLabel != null &&
        (result.status == _ScanStatus.success || pending);

    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        decoration: BoxDecoration(
          color: result.bgColor.withValues(alpha: 0.92),
          border: showFrame
              ? Border.all(color: result.categoryColor!, width: 16)
              : null,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(result.icon, color: Colors.white, size: 72),
              const SizedBox(height: 16),
              if (result.holderName.isNotEmpty) ...[
                Text(result.holderName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 8),
              ],
              Text(result.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),

              // Catégorie (puce, dans la couleur de la catégorie si dispo)
              if (result.categoryName != null && isValid) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: result.categoryColor ?? Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
                  ),
                  child: Text('🎟️ ${result.categoryName}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
              ],

              // Nature : ce qu'il doit apporter
              if (showNature) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(Radii.card),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 1.5),
                  ),
                  child: Column(children: [
                    const Text('DOIT APPORTER',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: Colors.white70)),
                    const SizedBox(height: 4),
                    Text(result.natureLabel!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                  ]),
                ),
              ],

              const SizedBox(height: 24),
              if (pending)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onRefuse,
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      label: const Text('Refuser'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onConfirm,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Confirmer'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: result.bgColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ])
              else
                Column(children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onScanNext,
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const Text('Scanner un nouveau ticket'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: result.bgColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('Reprise automatique dans ${secondsLeft}s…',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white70)),
                ]),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Cadre viseur ──────────────────────────────────────────────────────────────

class _ScanOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const side = 240.0;
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    final left = (w - side) / 2;
    final top  = (h - side) / 2 - 40;

    return Stack(children: [
      // Flou sur la caméra tout autour du viseur (zone de scan laissée nette)
      ClipPath(
        clipper: _OverlayHoleClipper(Rect.fromLTWH(left, top, side, side), Radii.lg),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(color: Colors.black.withValues(alpha: 0.35)),
        ),
      ),
      // Coins du cadre
      Positioned(
        left: left, top: top, width: side, height: side,
        child: CustomPaint(painter: _CornerPainter()),
      ),
      // Label
      Positioned(
        left: 0, right: 0, top: top + side + 20,
        child: const Text('Scanne le QR du participant',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white70)),
      ),
    ]);
  }
}

/// Découpe l'écran plein moins un rectangle arrondi (le viseur) — pour que
/// le flou appliqué au-dessus ne couvre pas la zone de scan.
class _OverlayHoleClipper extends CustomClipper<Path> {
  final Rect hole;
  final double radius;
  _OverlayHoleClipper(this.hole, this.radius);

  @override
  Path getClip(Size size) {
    final outer = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final inner = Path()..addRRect(RRect.fromRectAndRadius(hole, Radius.circular(radius)));
    return Path.combine(PathOperation.difference, outer, inner);
  }

  @override
  bool shouldReclip(covariant _OverlayHoleClipper oldClipper) =>
      oldClipper.hole != hole || oldClipper.radius != radius;
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const len = 24.0, r = 12.0;
    // TL
    canvas.drawLine(const Offset(r, 0), const Offset(r + len, 0), paint);
    canvas.drawLine(const Offset(0, r), const Offset(0, r + len), paint);
    canvas.drawArc(const Rect.fromLTWH(0, 0, r * 2, r * 2), -3.14, 1.57, false, paint);
    // TR
    canvas.drawLine(Offset(size.width - r - len, 0), Offset(size.width - r, 0), paint);
    canvas.drawLine(Offset(size.width, r), Offset(size.width, r + len), paint);
    canvas.drawArc(Rect.fromLTWH(size.width - r * 2, 0, r * 2, r * 2), -1.57, 1.57, false, paint);
    // BL
    canvas.drawLine(Offset(0, size.height - r - len), Offset(0, size.height - r), paint);
    canvas.drawLine(Offset(r, size.height), Offset(r + len, size.height), paint);
    canvas.drawArc(Rect.fromLTWH(0, size.height - r * 2, r * 2, r * 2), 1.57, 1.57, false, paint);
    // BR
    canvas.drawLine(Offset(size.width, size.height - r - len), Offset(size.width, size.height - r), paint);
    canvas.drawLine(Offset(size.width - r - len, size.height), Offset(size.width - r, size.height), paint);
    canvas.drawArc(Rect.fromLTWH(size.width - r * 2, size.height - r * 2, r * 2, r * 2), 0, 1.57, false, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

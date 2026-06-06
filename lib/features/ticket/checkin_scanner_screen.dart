import 'dart:async';

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

    try {
      final result = await ref
          .read(ticketServiceProvider)
          .checkin(widget.eventId, token);
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

    _resetTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() { _processing = false; _result = null; });
        _scanner.start();
      }
    });
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
              GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
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
              GestureDetector(
                onTap: () => _scanner.toggleTorch(),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                      color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.flash_on, color: Colors.white, size: 20),
                ),
              ),
            ]),
          ),
        ),
        // Feedback overlay
        if (_result != null)
          _ResultOverlay(result: _result!),
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

enum _ScanStatus { success, alreadyChecked, invalid, error }

class _ScanResult {
  final _ScanStatus status;
  final String holderName;
  final String? checkedTime;
  final String message;

  const _ScanResult({
    required this.status,
    required this.holderName,
    this.checkedTime,
    required this.message,
  });

  factory _ScanResult.fromCheckin(CheckinResult r) {
    if (!r.valid) {
      return _ScanResult(
        status: _ScanStatus.invalid,
        holderName: r.holderName,
        message: r.message,
      );
    }
    if (r.alreadyChecked) {
      final timeStr = r.checkedInAt != null
          ? DateFormat('HH\'h\'mm', 'fr_FR').format(r.checkedInAt!.toLocal())
          : '?';
      return _ScanResult(
        status: _ScanStatus.alreadyChecked,
        holderName: r.holderName,
        checkedTime: timeStr,
        message: 'Déjà scanné à $timeStr',
      );
    }
    return _ScanResult(
      status: _ScanStatus.success,
      holderName: r.holderName,
      message: 'Entrée validée',
    );
  }

  factory _ScanResult.error(String msg) => _ScanResult(
        status: _ScanStatus.error,
        holderName: '',
        message: msg,
      );

  Color get bgColor => switch (status) {
        _ScanStatus.success      => const Color(0xFF22A865),
        _ScanStatus.alreadyChecked => const Color(0xFFF97316),
        _ScanStatus.invalid      => kError,
        _ScanStatus.error        => kError,
      };

  IconData get icon => switch (status) {
        _ScanStatus.success        => Icons.check_circle_rounded,
        _ScanStatus.alreadyChecked => Icons.warning_amber_rounded,
        _ScanStatus.invalid        => Icons.cancel_rounded,
        _ScanStatus.error          => Icons.error_rounded,
      };
}

class _ResultOverlay extends StatelessWidget {
  final _ScanResult result;
  const _ResultOverlay({required this.result});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        color: result.bgColor.withValues(alpha: 0.92),
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
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20)),
                child: const Text('Reprend dans 3s…',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white70)),
              ),
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
      // Fond semi-transparent
      ColorFiltered(
        colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.5), BlendMode.srcOut),
        child: Stack(children: [
          Container(decoration: const BoxDecoration(color: Colors.black, backgroundBlendMode: BlendMode.dstOut)),
          Positioned(
            left: left, top: top, width: side, height: side,
            child: Container(
              decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ]),
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

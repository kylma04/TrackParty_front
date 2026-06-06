import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/theme_ext.dart';

class OtpCountdown extends StatefulWidget {
  final Duration duration;
  final VoidCallback? onExpired;

  const OtpCountdown({super.key, required this.duration, this.onExpired});

  @override
  State<OtpCountdown> createState() => _OtpCountdownState();
}

class _OtpCountdownState extends State<OtpCountdown> {
  late int _totalSeconds;
  late int _secondsLeft;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _totalSeconds = widget.duration.inSeconds;
    _secondsLeft  = _totalSeconds;
    _start();
  }

  void _start() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        setState(() => _secondsLeft = 0);
        _timer?.cancel();
        widget.onExpired?.call();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _expired => _secondsLeft == 0;

  double get _progress => _secondsLeft / _totalSeconds;

  String get _label {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Color get _color {
    if (_expired) return kError;
    if (_secondsLeft <= 60) return kWarning;
    return kPrimary;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.xs),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 1.0, end: _progress),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
            builder: (_, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 4,
              backgroundColor: context.tpHair,
              valueColor: AlwaysStoppedAnimation<Color>(_color),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Timer display
        if (_expired)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: kError.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(Radii.tag),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.timer_off_rounded, size: 15, color: kError),
              const SizedBox(width: 6),
              Text('Code expiré',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kError)),
            ]),
          )
        else
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.timer_rounded, size: 15, color: _color),
            const SizedBox(width: 5),
            Text(
              'Expire dans ',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.tpInkSub),
            ),
            Text(
              _label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: _color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ]),
      ],
    );
  }
}

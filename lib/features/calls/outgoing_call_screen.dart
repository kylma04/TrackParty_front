import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/services/call_service.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import 'active_call_screen.dart';

class OutgoingCallScreen extends StatefulWidget {
  final String callType;
  final String remoteUserName;
  final String? remoteUserAvatarUrl;

  const OutgoingCallScreen({
    super.key,
    required this.callType,
    required this.remoteUserName,
    this.remoteUserAvatarUrl,
  });

  @override
  State<OutgoingCallScreen> createState() => _OutgoingCallScreenState();
}

class _OutgoingCallScreenState extends State<OutgoingCallScreen> {
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    CallService().stateNotifier.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    CallService().stateNotifier.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted || _popped) return;
    final s = CallService().state;
    if (s.status == CallStatus.active) {
      _popped = true;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ActiveCallScreen()),
      );
    } else if (s.status == CallStatus.idle) {
      _pop();
    }
  }

  void _pop() {
    if (!mounted || _popped) return;
    _popped = true;
    Navigator.pop(context);
  }

  /// Raccroche sans bloquer l'UI — pop immédiat.
  void _hangup() {
    _pop();
    CallService().hangup().catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.callType == 'video';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, _) => _hangup(),
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0F1A),
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isVideo ? PhosphorIcons.videoCamera() : PhosphorIcons.phone(),
                    color: Colors.white38, size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isVideo ? 'Appel vidéo' : 'Appel audio',
                    style: const TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              _PulsingOutgoingAvatar(
                name: widget.remoteUserName,
                avatarUrl: widget.remoteUserAvatarUrl,
              ),

              const SizedBox(height: 28),

              Text(
                widget.remoteUserName,
                style: const TextStyle(
                  color: Colors.white, fontSize: 30,
                  fontWeight: FontWeight.w800, letterSpacing: -0.8,
                ),
              ),

              const SizedBox(height: 12),

              _RingingText(),

              const Spacer(flex: 3),

              GestureDetector(
                onTap: _hangup,
                child: Container(
                  width: 68, height: 68,
                  decoration: const BoxDecoration(
                    color: Color(0xFFCC2222),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(PhosphorIcons.phoneSlash(), color: Colors.white, size: 28),
                ),
              ),

              const SizedBox(height: 12),
              const Text('Raccrocher',
                style: TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.w600)),

              const SizedBox(height: 56),
            ],
          ),
        ),
      ),
    );
  }
}

// ── "Sonnerie…" animé ─────────────────────────────────────────────────────────

class _RingingText extends StatefulWidget {
  @override
  State<_RingingText> createState() => _RingingTextState();
}

class _RingingTextState extends State<_RingingText> {
  int _dots = 1;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _dots = _dots % 3 + 1);
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Text(
      'Sonnerie${'.' * _dots}',
      style: const TextStyle(color: Colors.white54, fontSize: 16),
    );
  }
}

// ── Avatar avec pulse ─────────────────────────────────────────────────────────

class _PulsingOutgoingAvatar extends StatefulWidget {
  final String name;
  final String? avatarUrl;
  const _PulsingOutgoingAvatar({required this.name, this.avatarUrl});

  @override
  State<_PulsingOutgoingAvatar> createState() => _PulsingOutgoingAvatarState();
}

class _PulsingOutgoingAvatarState extends State<_PulsingOutgoingAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _scale   = Tween(begin: 1.0, end: 1.28).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _opacity = Tween(begin: 0.25, end: 0.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  String _initials() {
    final p = widget.name.trim().split(' ');
    if (p.length >= 2) return '${p[0][0]}${p[1][0]}'.toUpperCase();
    return widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, _) => Transform.scale(
            scale: _scale.value,
            child: Container(
              width: 110, height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kPrimary.withValues(alpha: _opacity.value),
              ),
            ),
          ),
        ),
        Container(
          width: 90, height: 90,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: trackpartyGradient),
          child: widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty
              ? ClipOval(child: Image.network(widget.avatarUrl!, fit: BoxFit.cover))
              : Center(
                  child: Text(_initials(),
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
                ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/services/call_service.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import 'active_call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({super.key});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  bool _isAccepting = false;
  bool _popped      = false;

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

  Future<void> _accept() async {
    if (_isAccepting) return;
    setState(() => _isAccepting = true);
    try {
      await CallService().acceptCall();
    } catch (_) {
      // acceptCall a déjà appelé _cleanup → state = idle → _onStateChanged → pop
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  void _reject() {
    _pop();
    CallService().rejectCall().catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final s      = CallService().state;
    final isVideo = s.callType == 'video';
    final name   = s.remoteUserName ?? 'Appel entrant';

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F1A),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // Badge type d'appel
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isVideo ? PhosphorIcons.videoCameraSlash() : PhosphorIcons.phone(),
                    color: Colors.white54, size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isVideo ? 'Appel vidéo entrant' : 'Appel audio entrant',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Avatar avec animation pulse
            _PulsingAvatar(name: name, avatarUrl: s.remoteUserAvatarUrl),

            const SizedBox(height: 28),

            Text(
              name,
              style: const TextStyle(
                color: Colors.white, fontSize: 30,
                fontWeight: FontWeight.w800, letterSpacing: -0.8,
              ),
            ),

            const Spacer(flex: 3),

            // Boutons refuser / accepter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 56),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CallBtn(
                    icon: PhosphorIcons.phoneSlash(),
                    label: 'Refuser',
                    color: const Color(0xFFCC2222),
                    onTap: _reject,
                  ),
                  _CallBtn(
                    icon: isVideo ? PhosphorIcons.videoCamera() : PhosphorIcons.phone(),
                    label: _isAccepting ? '…' : 'Accepter',
                    color: const Color(0xFF166534),
                    onTap: _isAccepting ? null : _accept,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 56),
          ],
        ),
      ),
    );
  }
}

// ── Avatar avec pulse ─────────────────────────────────────────────────────────

class _PulsingAvatar extends StatefulWidget {
  final String name;
  final String? avatarUrl;
  const _PulsingAvatar({required this.name, this.avatarUrl});

  @override
  State<_PulsingAvatar> createState() => _PulsingAvatarState();
}

class _PulsingAvatarState extends State<_PulsingAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
    _scale   = Tween(begin: 1.0, end: 1.35).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = Tween(begin: 0.4, end: 0.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
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
          builder: (_, __) => Transform.scale(
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
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: trackpartyGradient,
          ),
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

// ── Bouton appel ──────────────────────────────────────────────────────────────

class _CallBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _CallBtn({required this.icon, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68, height: 68,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

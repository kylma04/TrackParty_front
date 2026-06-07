import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/services/call_service.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/haptics.dart';
import '../../theme/spacing.dart';

class ActiveCallScreen extends StatefulWidget {
  const ActiveCallScreen({super.key});

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen> {
  final _localRenderer  = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  int    _seconds = 0;
  Timer? _timer;
  bool   _controlsVisible = true;
  Timer? _hideTimer;

  // PiP / vue swap
  bool    _localIsFullscreen = false; // true = caméra locale plein écran, remote en PiP
  Offset? _pipPos;                    // position courante du PiP (null = défaut haut-droite)
  bool    _cameraFlipping = false;    // fade pendant le switch caméra

  static const double _pipW = 96;
  static const double _pipH = 128;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _initRenderers();
    CallService().stateNotifier.addListener(_onStateChanged);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
    _scheduleHideControls();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    _updateStreams();
  }

  void _updateStreams() {
    final s = CallService().state;
    _localRenderer.srcObject  = s.localStream;
    _remoteRenderer.srcObject = s.remoteStream;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _hideTimer?.cancel();
    CallService().stateNotifier.removeListener(_onStateChanged);
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  bool _popped = false;

  void _pop() {
    if (!mounted || _popped) return;
    _popped = true;
    Navigator.pop(context);
  }

  void _onStateChanged() {
    if (!mounted || _popped) return;
    final s = CallService().state;
    _localRenderer.srcObject  = s.localStream;
    _remoteRenderer.srcObject = s.remoteStream;
    if (mounted) setState(() {});
    if (s.status == CallStatus.idle) _pop();
  }

  String _formatDuration() {
    final h = _seconds ~/ 3600;
    final m = (_seconds % 3600) ~/ 60;
    final s = _seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _scheduleHideControls() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _showControls() {
    setState(() => _controlsVisible = true);
    _scheduleHideControls();
  }

  void _hangup() {
    _pop();
    CallService().hangup().catchError((_) {});
  }

  Future<void> _onSwitchCamera() async {
    setState(() => _cameraFlipping = true);
    await CallService().switchCamera();
    if (mounted) setState(() => _cameraFlipping = false);
    _showControls();
  }

  @override
  Widget build(BuildContext context) {
    final s       = CallService().state;
    final isVideo = s.callType == 'video';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, _) { _hangup(); },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: isVideo ? _buildVideoUI(s) : _buildAudioUI(s),
      ),
    );
  }

  // ── Vidéo ─────────────────────────────────────────────────────────────────

  Widget _buildVideoUI(CallState s) {
    // Quand _localIsFullscreen: local occupe le plein écran, remote va en PiP
    final mainRenderer  = _localIsFullscreen ? _localRenderer  : _remoteRenderer;
    final pipRenderer   = _localIsFullscreen ? _remoteRenderer : _localRenderer;
    final mainMirror    = _localIsFullscreen && s.isFrontCamera;
    final pipMirror     = !_localIsFullscreen && s.isFrontCamera;
    final hasMainStream = _localIsFullscreen
        ? s.localStream != null && s.videoEnabled
        : s.remoteStream != null;
    final hasPipStream = _localIsFullscreen
        ? s.remoteStream != null
        : s.localStream != null && s.videoEnabled;

    return Semantics(
      label: 'Afficher les contrôles',
      child: GestureDetector(
        onTap: _showControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Flux principal plein écran
            hasMainStream
                ? RTCVideoView(mainRenderer,
                    mirror: mainMirror,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                : _Placeholder(name: _localIsFullscreen ? null : s.remoteUserName),

            // PiP déplaçable
            if (hasPipStream) _buildPip(s, pipRenderer, pipMirror),

            // Overlay contrôles
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: AnimatedOpacity(
                opacity: _controlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: _buildControls(s, isVideo: true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPip(CallState s, RTCVideoRenderer renderer, bool mirror) {
    final mq = MediaQuery.of(context);
    final defaultPos = Offset(mq.size.width - _pipW - 16, mq.padding.top + 16);
    final pos = _pipPos ?? defaultPos;

    return Positioned(
      left: pos.dx, top: pos.dy,
      child: GestureDetector(
        // Tap: inverser local et remote
        onTap: () => setState(() {
          _localIsFullscreen = !_localIsFullscreen;
          _pipPos = null; // retour à la position par défaut
        }),
        // Drag: déplacer librement dans les limites de l'écran
        onPanUpdate: (d) {
          final next = (_pipPos ?? defaultPos) + d.delta;
          setState(() {
            _pipPos = Offset(
              next.dx.clamp(8.0, mq.size.width - _pipW - 8),
              next.dy.clamp(mq.padding.top + 8.0, mq.size.height - _pipH - 80),
            );
          });
        },
        child: AnimatedOpacity(
          opacity: _cameraFlipping ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            width: _pipW, height: _pipH,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.md),
              boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 16)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.md),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RTCVideoView(renderer,
                    mirror: mirror,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),

                  // Icône "cliquer pour inverser"
                  Positioned(
                    bottom: 6, right: 6,
                    child: _PipBadge(icon: PhosphorIcons.arrowsCounterClockwise()),
                  ),

                  // Icône caméra avant/arrière (seulement quand locale est en PiP)
                  if (!_localIsFullscreen)
                    Positioned(
                      top: 6, left: 6,
                      child: _PipBadge(
                        icon: s.isFrontCamera
                            ? PhosphorIcons.userCircle()
                            : PhosphorIcons.camera(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Audio ─────────────────────────────────────────────────────────────────

  Widget _buildAudioUI(CallState s) {
    return SafeArea(
      child: Column(
        children: [
          const Spacer(flex: 2),
          _RemoteAvatar(name: s.remoteUserName ?? '', avatarUrl: s.remoteUserAvatarUrl),
          const SizedBox(height: 24),
          Text(s.remoteUserName ?? '',
            style: const TextStyle(
                color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(_formatDuration(),
            style: const TextStyle(color: Colors.white54, fontSize: 16)),
          const Spacer(flex: 3),
          _buildControls(s, isVideo: false),
          const SizedBox(height: 56),
        ],
      ),
    );
  }

  // ── Contrôles ─────────────────────────────────────────────────────────────

  Widget _buildControls(CallState s, {required bool isVideo}) {
    return Container(
      decoration: isVideo
          ? BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
                stops: const [0.0, 0.65],
              ),
            )
          : null,
      padding: EdgeInsets.only(
        bottom: isVideo ? 44 : 0,
        top:    isVideo ? 24 : 0,
        left:   32,
        right:  32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isVideo) ...[
            Text(s.remoteUserName ?? '',
              style: const TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(_formatDuration(),
              style: const TextStyle(color: Colors.white54, fontSize: 14)),
            const SizedBox(height: 24),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CtrlBtn(
                icon: s.micEnabled
                    ? PhosphorIcons.microphone()
                    : PhosphorIcons.microphoneSlash(),
                label: s.micEnabled ? 'Micro' : 'Muet',
                active: s.micEnabled,
                onTap: () { CallService().toggleMic(); setState(() {}); },
              ),
              if (isVideo) ...[
                _CtrlBtn(
                  icon: s.videoEnabled
                      ? PhosphorIcons.videoCamera()
                      : PhosphorIcons.videoCameraSlash(),
                  label: s.videoEnabled ? 'Caméra' : 'Caméra off',
                  active: s.videoEnabled,
                  onTap: () { CallService().toggleVideo(); setState(() {}); },
                ),
                _CtrlBtn(
                  icon: PhosphorIcons.phoneSlash(),
                  label: 'Raccrocher',
                  active: false,
                  isHangup: true,
                  onTap: _hangup,
                ),
                _CtrlBtn(
                  icon: PhosphorIcons.cameraRotate(),
                  label: 'Retourner',
                  active: true,
                  onTap: _onSwitchCamera,
                ),
              ] else ...[
                _CtrlBtn(
                  icon: PhosphorIcons.phoneSlash(),
                  label: 'Raccrocher',
                  active: false,
                  isHangup: true,
                  onTap: _hangup,
                ),
                _CtrlBtn(
                  icon: s.speakerEnabled
                      ? PhosphorIcons.speakerHigh()
                      : PhosphorIcons.speakerSlash(),
                  label: s.speakerEnabled ? 'HP' : 'Écouteur',
                  active: s.speakerEnabled,
                  onTap: () { CallService().toggleSpeaker(); setState(() {}); },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── Widgets helpers ───────────────────────────────────────────────────────────

class _PipBadge extends StatelessWidget {
  final IconData icon;
  const _PipBadge({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, color: Colors.white70, size: 12),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String? name;
  const _Placeholder({this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kCallBg,
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(PhosphorIcons.videoCameraSlash(), color: Colors.white24, size: 48),
          const SizedBox(height: 12),
          Text(name ?? '', style: const TextStyle(color: Colors.white38, fontSize: 16)),
        ]),
      ),
    );
  }
}

class _RemoteAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  const _RemoteAvatar({required this.name, this.avatarUrl});

  String _initials() {
    final p = name.trim().split(' ');
    if (p.length >= 2) return '${p[0][0]}${p[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100, height: 100,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: trackpartyGradient),
      child: avatarUrl != null && avatarUrl!.isNotEmpty
          ? ClipOval(child: CachedNetworkImage(
              imageUrl: avatarUrl!, width: 100, height: 100, fit: BoxFit.cover))
          : Center(
              child: Text(_initials(),
                style: const TextStyle(
                    color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800)),
            ),
    );
  }
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool isHangup;
  final VoidCallback onTap;

  const _CtrlBtn({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.isHangup = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isHangup
        ? kCallDecline
        : active
            ? Colors.white.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.08);

    return Semantics(
      button: true,
      label: label,
      toggled: !isHangup ? active : null,
      child: GestureDetector(
        onTap: () { isHangup ? Haptics.heavy() : Haptics.light(); onTap(); },
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 56, height: 56,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon,
              color: active || isHangup ? Colors.white : Colors.white54,
              size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ]),
      ),
    );
  }
}

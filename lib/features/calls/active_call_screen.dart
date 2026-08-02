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
  final _localRenderer = RTCVideoRenderer();
  // Un renderer par AUTRE participant (maillage) — pour un DM il n'y en a
  // qu'un, exactement comme avant.
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};

  int    _seconds = 0;
  Timer? _timer;
  bool   _controlsVisible = true;
  Timer? _hideTimer;

  // PiP / vue swap — pertinent seulement pour un appel à un seul autre
  // participant (DM). Au-delà, la grille remplace ce mécanisme.
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
    _localRenderer.initialize().then((_) {
      _localRenderer.srcObject = CallService().state.localStream;
      if (mounted) setState(() {});
    });
    _syncRemoteRenderers();
    CallService().stateNotifier.addListener(_onStateChanged);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
    _scheduleHideControls();
  }

  /// Crée/détruit les renderers au fil des participants qui rejoignent/partent,
  /// et pousse le flux courant de chacun dans son renderer.
  Future<void> _syncRemoteRenderers() async {
    final s = CallService().state;
    final currentIds = s.participants.map((p) => p.userId).toSet();

    final gone = _remoteRenderers.keys.where((id) => !currentIds.contains(id)).toList();
    for (final id in gone) {
      final r = _remoteRenderers.remove(id);
      await r?.dispose();
    }

    for (final p in s.participants) {
      var r = _remoteRenderers[p.userId];
      if (r == null) {
        r = RTCVideoRenderer();
        await r.initialize();
        _remoteRenderers[p.userId] = r;
      }
      r.srcObject = p.remoteStream;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _hideTimer?.cancel();
    CallService().stateNotifier.removeListener(_onStateChanged);
    _localRenderer.dispose();
    for (final r in _remoteRenderers.values) {
      r.dispose();
    }
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
    if (s.status == CallStatus.idle) { _pop(); return; }
    _localRenderer.srcObject = s.localStream;
    _syncRemoteRenderers();
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

  /// Nom(s) affiché(s) en en-tête : le seul autre participant (DM), ou la
  /// liste des prénoms pour un appel de groupe.
  String _headerLabel(CallState s) {
    if (s.participants.isEmpty) return s.remoteUserName ?? '';
    if (s.participants.length == 1) return s.participants.first.displayName;
    return s.participants.map((p) => p.displayName).join(', ');
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
    CallService().leaveCall().catchError((_) {});
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
    final isGroupView = s.participants.length >= 2;

    return Semantics(
      label: 'Afficher les contrôles',
      child: GestureDetector(
        onTap: _showControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            isGroupView ? _buildRemoteGrid(s) : _buildSingleRemoteBackground(s),
            isGroupView ? _buildLocalPipFixed(s) : _buildSingleRemotePip(s),

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

  // ── DM : fond plein écran + PiP déplaçable/inversable ──────────────────────

  Widget _buildSingleRemoteBackground(CallState s) {
    final other = s.participants.firstOrNull;
    final remoteRenderer = other != null ? _remoteRenderers[other.userId] : null;
    final mainRenderer = _localIsFullscreen ? _localRenderer : remoteRenderer;
    final mainMirror   = _localIsFullscreen && s.isFrontCamera;
    final hasMainStream = _localIsFullscreen
        ? s.localStream != null && s.videoEnabled
        : other?.remoteStream != null;

    return hasMainStream && mainRenderer != null
        ? RTCVideoView(mainRenderer,
            mirror: mainMirror,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
        : _Placeholder(name: _localIsFullscreen ? null : (other?.displayName ?? s.remoteUserName));
  }

  Widget _buildSingleRemotePip(CallState s) {
    final other = s.participants.firstOrNull;
    final remoteRenderer = other != null ? _remoteRenderers[other.userId] : null;
    final pipRenderer = _localIsFullscreen ? remoteRenderer : _localRenderer;
    final pipMirror   = !_localIsFullscreen && s.isFrontCamera;
    final hasPipStream = _localIsFullscreen
        ? other?.remoteStream != null
        : s.localStream != null && s.videoEnabled;

    if (!hasPipStream || pipRenderer == null) return const SizedBox.shrink();
    return _buildPip(s, pipRenderer, pipMirror);
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

  // ── Groupe : grille + PiP local fixe ───────────────────────────────────────

  Widget _buildRemoteGrid(CallState s) {
    final tiles = s.participants;
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          childAspectRatio: 0.75,
        ),
        itemCount: tiles.length,
        itemBuilder: (_, i) {
          final p = tiles[i];
          final renderer = _remoteRenderers[p.userId];
          final hasStream = p.remoteStream != null;
          return Container(
            color: kCallBg,
            child: Stack(
              fit: StackFit.expand,
              children: [
                hasStream && renderer != null
                    ? RTCVideoView(renderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                    : _Placeholder(name: p.displayName),
                Positioned(
                  left: 8, bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(p.displayName,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLocalPipFixed(CallState s) {
    final hasStream = s.localStream != null && s.videoEnabled;
    return Positioned(
      right: 16, top: MediaQuery.of(context).padding.top + 16,
      child: Container(
        width: _pipW, height: _pipH,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.md),
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 16)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.md),
          child: hasStream
              ? RTCVideoView(_localRenderer,
                  mirror: s.isFrontCamera,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
              : Container(
                  color: kCallBg,
                  child: Icon(PhosphorIcons.videoCameraSlash(), color: Colors.white24, size: 20),
                ),
        ),
      ),
    );
  }

  // ── Audio ─────────────────────────────────────────────────────────────────

  Widget _buildAudioUI(CallState s) {
    final others = s.participants;

    return SafeArea(
      child: Column(
        children: [
          const Spacer(flex: 2),
          others.length <= 1
              ? _RemoteAvatar(
                  name: others.firstOrNull?.displayName ?? s.remoteUserName ?? '',
                  avatarUrl: others.firstOrNull?.avatarUrl ?? s.remoteUserAvatarUrl,
                )
              : Wrap(
                  spacing: 16, runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final p in others)
                      _RemoteAvatar(name: p.displayName, avatarUrl: p.avatarUrl, size: 72),
                  ],
                ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(_headerLabel(s),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
          ),
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
            Text(_headerLabel(s),
              textAlign: TextAlign.center,
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
  final double size;
  const _RemoteAvatar({required this.name, this.avatarUrl, this.size = 100});

  String _initials() {
    final p = name.trim().split(' ');
    if (p.length >= 2) return '${p[0][0]}${p[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: trackpartyGradient),
      child: avatarUrl != null && avatarUrl!.isNotEmpty
          ? ClipOval(child: CachedNetworkImage(
              imageUrl: avatarUrl!, width: size, height: size, fit: BoxFit.cover))
          : Center(
              child: Text(_initials(),
                style: TextStyle(
                    color: Colors.white, fontSize: size * 0.36, fontWeight: FontWeight.w800)),
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

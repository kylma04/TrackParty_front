import 'dart:async';
import 'dart:io' show Directory;

import 'package:path_provider/path_provider.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:record/record.dart';

import '../../core/models/chat_model.dart';
import '../../core/providers/auth_provider.dart' show authNotifierProvider, AuthAuthenticated;
import '../../core/providers/chat_provider.dart';
import '../../core/services/call_service.dart';
import '../../core/services/chat_websocket_service.dart';
import '../calls/outgoing_call_screen.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_avatar.dart';

class ChatThreadScreen extends ConsumerStatefulWidget {
  final String roomId;
  const ChatThreadScreen({super.key, required this.roomId});

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _ctrl        = TextEditingController();
  final _scrollCtrl  = ScrollController();
  final _picker      = ImagePicker();
  final _recorder    = AudioRecorder();

  // Typing indicator
  Timer? _typingTimer;
  bool  _isTyping = false;
  String? _typingUserName;
  Timer? _typingClearTimer;
  StreamSubscription<TypingEvent>? _typingSub;

  // Voice recording — style WhatsApp
  _VoiceMode _voiceMode   = _VoiceMode.idle;
  bool       _recordPaused = false;
  int        _recordSecs  = 0;
  String?    _recordPath;
  Timer?     _recordTimer;
  // Drag tracking pendant le hold
  double _holdDragX    = 0;
  double _holdDragY    = 0;
  bool   _holdCancelled = false;
  bool   _holdLocked    = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onTextChanged);

    // Écouter les events de typing du WS
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ws = ref.read(chatWebSocketServiceProvider(widget.roomId));
      _typingSub = ws.typing.listen((e) {
        if (!mounted) return;
        setState(() => _typingUserName = e.userName);
        _typingClearTimer?.cancel();
        _typingClearTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) setState(() => _typingUserName = null);
        });
      });
    });
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTextChanged);
    _ctrl.dispose();
    _scrollCtrl.dispose();
    _typingTimer?.cancel();
    _typingClearTimer?.cancel();
    _typingSub?.cancel();
    _recordTimer?.cancel();
    if (_voiceMode != _VoiceMode.idle) _recorder.stop().catchError((_) {});
    _recorder.dispose();
    ref.read(chatRoomsProvider.notifier).refresh();
    super.dispose();
  }

  void _onTextChanged() {
    if (_ctrl.text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      ref.read(chatWebSocketServiceProvider(widget.roomId)).sendTyping();
    }
    if (_ctrl.text.isEmpty) _isTyping = false;

    // Re-envoyer l'indicateur de saisie toutes les 3 secondes
    _typingTimer?.cancel();
    if (_ctrl.text.isNotEmpty) {
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _isTyping = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendText() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    await ref.read(chatThreadProvider(widget.roomId).notifier).sendTextMessage(text);
    _scrollToBottom();
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    await ref.read(chatThreadProvider(widget.roomId).notifier).sendImageMessage(file);
    _scrollToBottom();
  }

  String _fmtDuration(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── Démarrer l'enregistrement (commun tap + hold) ─────────────────────────

  Future<bool> _beginRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Permission micro refusée — autorise le micro dans les réglages.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        return false;
      }
      final dir  = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      if (mounted) {
        setState(() { _recordPath = path; _recordSecs = 0; _recordPaused = false; });
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted && !_recordPaused) setState(() => _recordSecs++);
        });
      }
      return true;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur micro : $e'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return false;
    }
  }

  // ── Tap unique → mode verrouillé ─────────────────────────────────────────

  Future<void> _onMicTap() async {
    if (_voiceMode != _VoiceMode.idle) return;
    setState(() => _voiceMode = _VoiceMode.locked);
    final ok = await _beginRecording();
    if (!ok && mounted) setState(() => _voiceMode = _VoiceMode.idle);
  }

  // ── Hold → mode maintenu ─────────────────────────────────────────────────

  Future<void> _onHoldStart(LongPressStartDetails _) async {
    if (_voiceMode != _VoiceMode.idle) return;
    _holdDragX = 0; _holdDragY = 0;
    _holdCancelled = false; _holdLocked = false;
    setState(() => _voiceMode = _VoiceMode.holding);
    final ok = await _beginRecording();
    if (!ok && mounted) setState(() => _voiceMode = _VoiceMode.idle);
  }

  void _onHoldMove(LongPressMoveUpdateDetails d) {
    if (_voiceMode != _VoiceMode.holding) return;
    setState(() {
      _holdDragX = d.offsetFromOrigin.dx;
      _holdDragY = d.offsetFromOrigin.dy;
    });
    // Seuils de déclenchement
    if (_holdDragX < -80 && !_holdCancelled && !_holdLocked) {
      _holdCancelled = true;
      _cancelVoice();
    } else if (_holdDragY < -60 && !_holdLocked && !_holdCancelled) {
      _holdLocked = true;
      setState(() => _voiceMode = _VoiceMode.locked);
    }
  }

  Future<void> _onHoldEnd(LongPressEndDetails _) async {
    if (_voiceMode != _VoiceMode.holding) return;
    if (!_holdCancelled && !_holdLocked) await _sendVoice();
  }

  // ── Contrôles en mode verrouillé ─────────────────────────────────────────

  Future<void> _togglePause() async {
    if (_recordPaused) {
      await _recorder.resume();
      setState(() => _recordPaused = false);
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && !_recordPaused) setState(() => _recordSecs++);
      });
    } else {
      await _recorder.pause();
      setState(() => _recordPaused = true);
    }
  }

  Future<void> _sendVoice() async {
    _recordTimer?.cancel();
    final path = await _recorder.stop();
    final secs  = _recordSecs;
    setState(() { _voiceMode = _VoiceMode.idle; _recordPaused = false; });
    if (path != null && secs >= 1) {
      await ref.read(chatThreadProvider(widget.roomId).notifier)
          .sendVoiceMessage(path, secs);
      _scrollToBottom();
    }
  }

  Future<void> _cancelVoice() async {
    _recordTimer?.cancel();
    await _recorder.stop();
    if (mounted) setState(() { _voiceMode = _VoiceMode.idle; _recordPaused = false; });
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatThreadProvider(widget.roomId));
    final room          = ref.watch(chatRoomByIdProvider(widget.roomId));
    final authState     = ref.watch(authNotifierProvider).valueOrNull;
    final me            = authState is AuthAuthenticated ? authState.user : null;

    ref.listen(chatThreadProvider(widget.roomId), (_, next) {
      if (next is AsyncData) _scrollToBottom();
    });

    return Scaffold(
      backgroundColor: context.tpBg,
      body: Column(
        children: [
          _buildNavBar(context, room),
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2)),
              error: (e, _) => Center(
                child: Text('Erreur de chargement',
                  style: TextStyle(color: context.tpInkSub)),
              ),
              data: (msgs) => _buildMessageList(context, msgs, me?.id),
            ),
          ),
          if (_typingUserName != null && _voiceMode == _VoiceMode.idle)
            _TypingIndicator(userName: _typingUserName!),
          // Indicateur de verrouillage (au-dessus du composer, visible en mode hold)
          if (_voiceMode == _VoiceMode.holding)
            _buildLockIndicator(context),
          // Zone du bas
          if (_voiceMode == _VoiceMode.locked || _voiceMode == _VoiceMode.paused)
            _buildLockedBar(context)
          else
            // Le GestureDetector du bouton micro DOIT rester dans l'arbre
            // pendant tout le geste hold → on superpose l'overlay avec IgnorePointer
            Stack(
              children: [
                _buildComposer(context),
                if (_voiceMode == _VoiceMode.holding)
                  IgnorePointer(child: _buildHoldingOverlay(context)),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _startCall(BuildContext ctx, ChatRoomModel room, String callType) async {
    final other = room.membersPreview.isNotEmpty ? room.membersPreview.first : null;
    final name  = other?.displayName ?? room.displayName;
    try {
      await CallService().initiateCall(
        roomId: room.id,
        callType: callType,
        remoteUserName: name,
        remoteUserAvatarUrl: other?.avatarUrl,
      );
      if (ctx.mounted) {
        Navigator.push(
          ctx,
          MaterialPageRoute(
            builder: (_) => OutgoingCallScreen(
              callType: callType,
              remoteUserName: name,
              remoteUserAvatarUrl: other?.avatarUrl,
            ),
          ),
        );
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text('Impossible de lancer l\'appel : $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  // ── NavBar ────────────────────────────────────────────────────────────────

  Widget _buildNavBar(BuildContext context, ChatRoomModel? room) {
    final name    = room?.displayName ?? 'Conversation';
    final other   = room?.membersPreview.isNotEmpty == true
        ? room!.membersPreview.first
        : null;

    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(Sp.md, 8, Sp.md, 10),
        decoration: BoxDecoration(
          color: context.tpCard,
          border: Border(bottom: BorderSide(color: context.tpHair)),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                child: Icon(PhosphorIcons.caretLeft(), color: context.tpInk, size: 18),
              ),
            ),
            const SizedBox(width: 10),
            TpAvatar(
              name: other?.displayName ?? name,
              imageUrl: other?.avatarUrl,
              size: 40,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900,
                        color: context.tpInk, letterSpacing: -0.3)),
                  if (room?.isEvent == true && room?.eventTitle != null)
                    Text(room!.eventTitle!,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kPrimary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            // Boutons appel (seulement pour DM)
            if (room?.isPrivate == true) ...[
              _CallIconBtn(
                icon: PhosphorIcons.phone(),
                onTap: () => _startCall(context, room!, 'audio'),
              ),
              const SizedBox(width: 4),
              _CallIconBtn(
                icon: PhosphorIcons.videoCamera(),
                onTap: () => _startCall(context, room!, 'video'),
              ),
              const SizedBox(width: 4),
            ],
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
              child: Icon(PhosphorIcons.dotsThreeVertical(), color: context.tpInk, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  // ── Liste ──────────────────────────────────────────────────────────────────

  Widget _buildMessageList(BuildContext context, List<ChatMessage> messages, String? myId) {
    if (messages.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('💬', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text('Commence la conversation !',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.tpInkSub)),
        ]),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.md),
      itemCount: messages.length,
      itemBuilder: (_, i) {
        final msg     = messages[i];
        final isMe    = msg.sender.id == myId;
        final showDay = i == 0 || !_sameDay(messages[i - 1].createdAt, msg.createdAt);
        return Column(children: [
          if (showDay) _buildDaySeparator(context, msg.createdAt),
          _MessageBubble(message: msg, isMe: isMe, roomId: widget.roomId),
        ]);
      },
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildDaySeparator(BuildContext context, DateTime dt) {
    final now = DateTime.now();
    String label;
    if (_sameDay(dt, now)) {
      label = "Aujourd'hui";
    } else if (_sameDay(dt, now.subtract(const Duration(days: 1)))) {
      label = 'Hier';
    } else {
      label = DateFormat('d MMMM', 'fr_FR').format(dt);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Sp.sm),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: context.tpHair, borderRadius: BorderRadius.circular(999)),
          child: Text(label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: context.tpInkSub)),
        ),
      ),
    );
  }

  // ── Composer ──────────────────────────────────────────────────────────────

  Widget _buildComposer(BuildContext context) {
    final hasText = _ctrl.text.isNotEmpty;

    return Container(
      padding: EdgeInsets.fromLTRB(Sp.md, 10, Sp.md,
          10 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: context.tpCard,
        border: Border(top: BorderSide(color: context.tpHair)),
      ),
      child: Row(
        children: [
          // Image picker
          if (!hasText)
            GestureDetector(
              onTap: _pickImage,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: context.tpBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.tpHair),
                  ),
                  child: Icon(PhosphorIcons.image(), color: context.tpInkSub, size: 20),
                ),
              ),
            ),

          // Champ de texte
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: context.tpBg,
                borderRadius: BorderRadius.circular(22),
              ),
              padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 4),
              child: TextField(
                controller: _ctrl,
                maxLines: null,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.tpInk),
                decoration: InputDecoration(
                  hintText: 'Écris un message…',
                  hintStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.tpInkMute),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onSubmitted: (_) => _sendText(),
                textInputAction: TextInputAction.send,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Envoyer ou micro
          hasText
              ? GestureDetector(
                  onTap: _sendText,
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      gradient: trackpartyGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: Shadows.brand,
                    ),
                    child: Icon(PhosphorIcons.paperPlaneTilt(), color: Colors.white, size: 20),
                  ),
                )
              : GestureDetector(
                  onTap:                  _onMicTap,
                  onLongPressStart:       _onHoldStart,
                  onLongPressMoveUpdate:  _onHoldMove,
                  onLongPressEnd:         _onHoldEnd,
                  // onLongPressCancel fire aussi après un tap simple → ne cancel que si
                  // on est vraiment en mode hold (pas en mode locked déclenché par tap)
                  onLongPressCancel: () {
                    if (_voiceMode == _VoiceMode.holding) _cancelVoice();
                  },
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: context.tpBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.tpHair),
                    ),
                    child: Icon(PhosphorIcons.microphone(), color: context.tpInkSub, size: 20),
                  ),
                ),
        ],
      ),
    );
  }

  // ── Indicateur verrouillage (au-dessus, mode hold) ───────────────────────

  Widget _buildLockIndicator(BuildContext context) {
    final nearLock = _holdDragY < -30;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      margin: const EdgeInsets.only(right: Sp.md, bottom: 4),
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: nearLock ? kPrimary : context.tpCard,
          borderRadius: BorderRadius.circular(20),
          boxShadow: Shadows.sm,
          border: Border.all(color: nearLock ? kPrimary : context.tpHair),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              nearLock ? PhosphorIcons.lock(PhosphorIconsStyle.fill) : PhosphorIcons.lock(),
              color: nearLock ? Colors.white : kPrimary,
              size: 18,
            ),
            const SizedBox(height: 2),
            Text(
              '↑',
              style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w900,
                color: nearLock ? Colors.white : kPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Overlay hold (par-dessus le composer, IgnorePointer → gestes passent) ─

  Widget _buildHoldingOverlay(BuildContext context) {
    final cancelHighlight = _holdDragX < -40;

    return Container(
      padding: EdgeInsets.fromLTRB(Sp.md, 10, Sp.md,
          10 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: context.tpCard,
        border: Border(top: BorderSide(color: context.tpHair)),
      ),
      child: Row(
        children: [
          // Bouton micro visuel (rouge, pas de GestureDetector — celui du
          // composer sous-jacent gère les gestes)
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: kError,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: kError.withValues(alpha: 0.3), blurRadius: 12, spreadRadius: 2)],
            ),
            child: Icon(PhosphorIcons.microphone(), color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),

          _RecordingDots(),
          const SizedBox(width: 6),
          Text(
            _fmtDuration(_recordSecs),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kError),
          ),

          Expanded(
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 150),
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: cancelHighlight ? kError : context.tpInkMute,
                ),
                child: const Text('← Glisse pour annuler'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Mode verrouillé / pause (tap ou lock) ─────────────────────────────────

  Widget _buildLockedBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(Sp.md, 10, Sp.md,
          10 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: context.tpCard,
        border: Border(top: BorderSide(color: context.tpHair)),
      ),
      child: Row(
        children: [
          // Supprimer
          Semantics(
            button: true, label: 'Annuler l\'enregistrement',
            child: GestureDetector(
              onTap: _cancelVoice,
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: kError.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(PhosphorIcons.trash(), color: kError, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Durée + animation
          _RecordingDots(),
          const SizedBox(width: 6),
          Text(
            _fmtDuration(_recordSecs),
            style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800,
              color: _recordPaused ? context.tpInkMute : kError,
            ),
          ),
          if (_recordPaused)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text('En pause',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.tpInkMute)),
            ),

          const Spacer(),

          // Pause / Reprendre
          Semantics(
            button: true,
            label: _recordPaused ? 'Reprendre l\'enregistrement' : 'Mettre en pause',
            child: GestureDetector(
              onTap: _togglePause,
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: context.tpBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.tpHair),
                ),
                child: Icon(
                  _recordPaused ? PhosphorIcons.play() : PhosphorIcons.pause(),
                  color: context.tpInk, size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Envoyer
          Semantics(
            button: true, label: 'Envoyer la note vocale',
            child: GestureDetector(
              onTap: _sendVoice,
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: trackpartyGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: Shadows.brand,
                ),
                child: Icon(PhosphorIcons.paperPlaneTilt(), color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _VoiceMode { idle, holding, locked, paused }

// ── Bouton appel (navbar) ─────────────────────────────────────────────────────

class _CallIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CallIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: kPrimary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: kPrimary, size: 18),
      ),
    );
  }
}

// ── Typing indicator ──────────────────────────────────────────────────────────

class _TypingIndicator extends StatelessWidget {
  final String userName;
  const _TypingIndicator({required this.userName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md + 34, 0, Sp.md, 4),
      child: Text(
        '$userName est en train d\'écrire…',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: context.tpInkMute, fontStyle: FontStyle.italic),
      ),
    );
  }
}

// ── Recording dots animation ──────────────────────────────────────────────────

class _RecordingDots extends StatefulWidget {
  @override
  State<_RecordingDots> createState() => _RecordingDotsState();
}

class _RecordingDotsState extends State<_RecordingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i / 3;
            final opacity = ((_ctrl.value - delay) % 1.0).abs();
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 6, height: 6,
              decoration: BoxDecoration(
                color: kError.withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

// ── Bulle de message ──────────────────────────────────────────────────────────

class _MessageBubble extends ConsumerWidget {
  final ChatMessage message;
  final bool isMe;
  final String roomId;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.roomId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final time = DateFormat('HH:mm').format(message.createdAt.toLocal());

    Widget content;
    if (message.isImage) {
      content = _ImageContent(imageUrl: message.imageUrl, isMe: isMe);
    } else if (message.isVoice) {
      content = _VoiceContent(
        voiceUrl: message.voiceUrl,
        duration: message.voiceDuration ?? 0,
        isMe: isMe,
      );
    } else if (message.isEventInvite) {
      content = _EventInviteContent(
        eventId: message.eventInviteId,
        isMe: isMe,
      );
    } else {
      content = _TextContent(text: message.content, isMe: isMe);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            TpAvatar(name: message.sender.displayName, imageUrl: message.sender.avatarUrl, size: 28),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(message.sender.displayName,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.tpInkSub)),
                  ),
                content,
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                  child: Text(time,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: context.tpInkMute)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Contenu texte ─────────────────────────────────────────────────────────────

class _TextContent extends StatelessWidget {
  final String text;
  final bool isMe;
  const _TextContent({required this.text, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.68),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: isMe ? trackpartyGradient : null,
        color: isMe ? null : context.tpCard,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isMe ? 20 : 6),
          bottomRight: Radius.circular(isMe ? 6 : 20),
        ),
        boxShadow: isMe ? Shadows.brand : Shadows.sm,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600,
          color: isMe ? Colors.white : context.tpInk,
          height: 1.4,
        ),
      ),
    );
  }
}

// ── Contenu image ─────────────────────────────────────────────────────────────

class _ImageContent extends StatelessWidget {
  final String? imageUrl;
  final bool isMe;
  const _ImageContent({required this.imageUrl, required this.isMe});

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null) {
      return const SizedBox.shrink();
    }
    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(20),
        topRight: const Radius.circular(20),
        bottomLeft: Radius.circular(isMe ? 20 : 6),
        bottomRight: Radius.circular(isMe ? 6 : 20),
      ),
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: MediaQuery.of(context).size.width * 0.6,
        height: 200,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: MediaQuery.of(context).size.width * 0.6,
          height: 200,
          color: context.tpHair,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (_, __, ___) => Container(
          width: MediaQuery.of(context).size.width * 0.6,
          height: 80,
          color: context.tpHair,
          child: Icon(PhosphorIcons.imageBroken(), color: context.tpInkMute),
        ),
      ),
    );
  }
}

// ── Contenu note vocale ───────────────────────────────────────────────────────

class _VoiceContent extends StatefulWidget {
  final String? voiceUrl;
  final int duration;
  final bool isMe;

  const _VoiceContent({required this.voiceUrl, required this.duration, required this.isMe});

  @override
  State<_VoiceContent> createState() => _VoiceContentState();
}

class _VoiceContentState extends State<_VoiceContent> {
  final _player   = AudioPlayer();
  bool  _playing  = false;
  double _progress = 0;
  int   _current  = 0;
  StreamSubscription? _posSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    _posSub = _player.onPositionChanged.listen((pos) {
      if (!mounted) return;
      final total = widget.duration > 0 ? widget.duration : 1;
      setState(() {
        _current  = pos.inSeconds;
        _progress = pos.inSeconds / total;
      });
    });
    _stateSub = _player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      if (s == PlayerState.completed) {
        setState(() { _playing = false; _progress = 0; _current = 0; });
      }
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (widget.voiceUrl == null) return;
    if (_playing) {
      await _player.pause();
      setState(() => _playing = false);
    } else {
      await _player.play(UrlSource(widget.voiceUrl!));
      setState(() => _playing = true);
    }
  }

  String _fmt(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bg    = widget.isMe ? null : context.tpCard;
    final fg    = widget.isMe ? Colors.white : context.tpInk;
    final track = widget.isMe ? Colors.white38 : context.tpHair;

    return Container(
      width: MediaQuery.of(context).size.width * 0.65,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: widget.isMe ? trackpartyGradient : null,
        color: bg,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(widget.isMe ? 20 : 6),
          bottomRight: Radius.circular(widget.isMe ? 6 : 20),
        ),
        boxShadow: widget.isMe ? Shadows.brand : Shadows.sm,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggle,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: widget.isMe ? Colors.white24 : kPrimary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _playing ? PhosphorIcons.pause() : PhosphorIcons.play(),
                color: widget.isMe ? Colors.white : kPrimary,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: track,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    widget.isMe ? Colors.white : kPrimary,
                  ),
                  minHeight: 3,
                  borderRadius: BorderRadius.circular(2),
                ),
                const SizedBox(height: 4),
                Text(
                  _playing ? _fmt(_current) : _fmt(widget.duration),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fg.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Contenu invitation événement ──────────────────────────────────────────────

class _EventInviteContent extends StatelessWidget {
  final String? eventId;
  final bool isMe;

  const _EventInviteContent({required this.eventId, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.72,
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isMe ? 20 : 6),
          bottomRight: Radius.circular(isMe ? 6 : 20),
        ),
        boxShadow: Shadows.sm,
        border: Border.all(color: kPrimary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [kPrimary.withValues(alpha: 0.12), kAccent.withValues(alpha: 0.08)],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Text('🎉', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text('Invitation à un événement',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kPrimary)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: GestureDetector(
              onTap: eventId != null ? () => context.push('/event/$eventId') : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: trackpartyGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: Shadows.brand,
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(PhosphorIcons.arrowRight(), color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      const Text('Voir l\'événement',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

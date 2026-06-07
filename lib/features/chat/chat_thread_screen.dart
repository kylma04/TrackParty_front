import 'dart:async';

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
import '../../core/services/invitation_service.dart';
import 'room_members_sheet.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_avatar.dart';
import '../../widgets/tp_toast.dart';

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

  // Mode événement (annonce + carte événement) — admin de groupe événement uniquement
  bool _attachEvent = true;

  // Voice recording — style WhatsApp
  _VoiceMode _voiceMode   = _VoiceMode.idle;
  bool       _recordPaused = false;
  int        _recordSecs  = 0;
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
    _scrollCtrl.addListener(_onScroll);

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

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    if (_scrollCtrl.position.pixels <= 80) {
      ref.read(chatThreadProvider(widget.roomId).notifier).loadOlderMessages();
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTextChanged);
    _scrollCtrl.removeListener(_onScroll);
    _ctrl.dispose();
    _scrollCtrl.dispose();
    _typingTimer?.cancel();
    _typingClearTimer?.cancel();
    _typingSub?.cancel();
    _recordTimer?.cancel();
    if (_voiceMode != _VoiceMode.idle) _recorder.stop().catchError((_) => null);
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
    await ref.read(chatThreadProvider(widget.roomId).notifier)
        .sendTextMessage(text, attachEvent: _attachEvent);
    _scrollToBottom();
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    await ref.read(chatThreadProvider(widget.roomId).notifier)
        .sendImageMessage(file, attachEvent: _attachEvent);
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
        if (mounted) {
          TpToast.warning(context, 'Permission micro refusée — autorise le micro dans les réglages.');
        }
        return false;
      }
      final dir  = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      if (mounted) {
        setState(() { _recordSecs = 0; _recordPaused = false; });
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted && !_recordPaused) setState(() => _recordSecs++);
        });
      }
      return true;
    } catch (e) {
      if (mounted) {
        TpToast.error(context, 'Erreur micro : $e');
      }
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
          .sendVoiceMessage(path, secs, attachEvent: _attachEvent);
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
    final messagesAsync    = ref.watch(chatThreadProvider(widget.roomId));
    final room             = ref.watch(chatRoomByIdProvider(widget.roomId));
    final authState        = ref.watch(authNotifierProvider).valueOrNull;
    final me               = authState is AuthAuthenticated ? authState.user : null;
    final partnerReadAt    = room?.isPrivate == true
        ? ref.watch(chatPartnerReadAtProvider(widget.roomId))
        : null;

    final canWrite = room == null ||
        room.isPrivate ||
        room.isAdmin ||
        room.groupMode == 'open';

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
              data: (msgs) => _buildMessageList(context, msgs, me?.id, partnerReadAt, canWrite),
            ),
          ),
          if (_typingUserName != null && _voiceMode == _VoiceMode.idle)
            _TypingIndicator(userName: _typingUserName!),
          if (!canWrite)
            _BroadcastBanner()
          else ...[
            if (_voiceMode == _VoiceMode.holding)
              _buildLockIndicator(context),
            if (_voiceMode == _VoiceMode.locked || _voiceMode == _VoiceMode.paused)
              _buildLockedBar(context)
            else
              Stack(
                children: [
                  _buildComposer(context, isAdmin: room?.isAdmin == true && room?.isEvent == true),
                  if (_voiceMode == _VoiceMode.holding)
                    IgnorePointer(child: _buildHoldingOverlay(context)),
                ],
              ),
          ],
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
        ctx.push('/call/outgoing', extra: {
          'callType': callType,
          'remoteUserName': name,
          'remoteUserAvatarUrl': other?.avatarUrl,
        });
      }
    } catch (e) {
      if (ctx.mounted) {
        TpToast.error(ctx, 'Impossible de lancer l\'appel : $e');
      }
    }
  }

  // ── Membres du groupe ─────────────────────────────────────────────────────

  void _showMembersSheet(BuildContext context, ChatRoomModel room) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => RoomMembersSheet(room: room),
    );
  }

  // ── Mode groupe ───────────────────────────────────────────────────────────

  Future<void> _showGroupModeSheet(ChatRoomModel room) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _GroupModeSheet(
        isBroadcast: room.isBroadcast,
        onToggle: () async {
          final newMode = room.isBroadcast ? 'open' : 'broadcast';
          await ref.read(groupModeUpdateProvider)(room.id, newMode);
          if (!mounted) return;
          await ref.read(chatRoomsProvider.notifier).refresh();
        },
      ),
    );
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
            Semantics(
              button: true, label: 'Retour',
              child: GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(Radii.md)),
                  child: Icon(PhosphorIcons.caretLeft(), color: context.tpInk, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            TpAvatar(
              name: other?.displayName ?? name,
              imageUrl: room?.roomAvatarUrl ?? other?.avatarUrl,
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
                label: 'Appel audio',
                onTap: () => _startCall(context, room!, 'audio'),
              ),
              const SizedBox(width: 4),
              _CallIconBtn(
                icon: PhosphorIcons.videoCamera(),
                label: 'Appel vidéo',
                onTap: () => _startCall(context, room!, 'video'),
              ),
              const SizedBox(width: 4),
            ],
            if (room?.isEvent == true) ...[
              Semantics(
                button: true, label: 'Voir les membres',
                child: GestureDetector(
                  onTap: () => _showMembersSheet(context, room!),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(Radii.md)),
                    child: Icon(PhosphorIcons.usersThree(), color: context.tpInk, size: 20),
                  ),
                ),
              ),
              if (room?.isAdmin == true) ...[
                const SizedBox(width: 4),
                Semantics(
                  button: true, label: 'Paramètres du groupe',
                  child: GestureDetector(
                    onTap: () => _showGroupModeSheet(room!),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(Radii.md)),
                      child: Icon(PhosphorIcons.dotsThreeVertical(), color: context.tpInk, size: 20),
                    ),
                  ),
                ),
              ],
            ] else
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(Radii.md)),
                child: Icon(PhosphorIcons.dotsThreeVertical(), color: context.tpInk, size: 20),
              ),
          ],
        ),
      ),
    );
  }

  // ── Liste ──────────────────────────────────────────────────────────────────

  Widget _buildMessageList(BuildContext context, List<ChatMessage> messages, String? myId, DateTime? partnerReadAt, bool canWrite) {
    final notifier     = ref.read(chatThreadProvider(widget.roomId).notifier);
    final isLoadingOld = notifier.loadingOlder;
    final hasMoreOld   = notifier.hasMoreOlder;

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

    // Index du dernier message envoyé par moi, pour afficher "Vu"
    final lastMyMsgIdx = messages.lastIndexWhere((m) => m.sender.id == myId);

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.md),
      // +1 pour l'indicateur de chargement en tête
      itemCount: messages.length + 1,
      itemBuilder: (_, i) {
        // Slot 0 : indicateur "charger plus" ou "début de conversation"
        if (i == 0) {
          if (isLoadingOld) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: kPrimary))),
            );
          }
          if (!hasMoreOld) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(child: Text('Début de la conversation',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.tpInkMute))),
            );
          }
          return const SizedBox.shrink();
        }

        final idx  = i - 1;
        final msg  = messages[idx];
        final isMe = msg.sender.id == myId;
        final showDay = idx == 0 || !_sameDay(messages[idx - 1].createdAt, msg.createdAt);
        final showRead = isMe && idx == lastMyMsgIdx && partnerReadAt != null
            && !partnerReadAt.isBefore(msg.createdAt);
        return Column(children: [
          if (showDay) _buildDaySeparator(context, msg.createdAt),
          _MessageBubble(message: msg, isMe: isMe, roomId: widget.roomId, showRead: showRead, canReact: canWrite),
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
          decoration: BoxDecoration(color: context.tpHair, borderRadius: BorderRadius.circular(Radii.pill)),
          child: Text(label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: context.tpInkSub)),
        ),
      ),
    );
  }

  // ── Composer ──────────────────────────────────────────────────────────────

  Widget _buildComposer(BuildContext context, {bool isAdmin = false}) {
    final hasText  = _ctrl.text.isNotEmpty;
    final hintText = isAdmin
        ? (_attachEvent ? 'Poster une annonce…' : 'Écris un message…')
        : 'Écris un message…';

    return Container(
      decoration: BoxDecoration(
        color: context.tpCard,
        border: Border(top: BorderSide(color: context.tpHair)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bandeau "Mode événement" (admin d'un groupe événement uniquement)
          if (isAdmin) _buildEventModeBanner(context),
          Padding(
            padding: EdgeInsets.fromLTRB(Sp.md, 10, Sp.md,
                10 + MediaQuery.of(context).padding.bottom),
            child: Row(
        children: [
          // Image picker
          if (!hasText)
            Semantics(
              button: true, label: 'Joindre une image',
              child: GestureDetector(
                onTap: _pickImage,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: context.tpBg,
                      borderRadius: BorderRadius.circular(Radii.button),
                      border: Border.all(color: context.tpHair),
                    ),
                    child: Icon(PhosphorIcons.image(), color: context.tpInkSub, size: 20),
                  ),
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
                  hintText: hintText,
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
              ? Semantics(
                  button: true, label: 'Envoyer le message',
                  child: GestureDetector(
                    onTap: _sendText,
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        gradient: trackpartyGradient,
                        borderRadius: BorderRadius.circular(Radii.button),
                        boxShadow: Shadows.brand,
                      ),
                      child: Icon(PhosphorIcons.paperPlaneTilt(), color: Colors.white, size: 20),
                    ),
                  ),
                )
              : Semantics(
                  button: true, label: 'Enregistrer un message vocal',
                  child: GestureDetector(
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
                      borderRadius: BorderRadius.circular(Radii.button),
                      border: Border.all(color: context.tpHair),
                    ),
                    child: Icon(PhosphorIcons.microphone(), color: context.tpInkSub, size: 20),
                  ),
                ),
                ),
          ],
        ),
        ),
        ],
      ),
    );
  }

  Widget _buildEventModeBanner(BuildContext context) {
    return EventModeBanner(
      attachEvent: _attachEvent,
      onToggle: () => setState(() => _attachEvent = !_attachEvent),
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
          borderRadius: BorderRadius.circular(Radii.card),
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
          _VoiceActionBtn(
            label: 'Annuler l\'enregistrement',
            icon: PhosphorIcons.trash(),
            iconColor: kError,
            onTap: _cancelVoice,
            decoration: BoxDecoration(
              color: kError.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
          ),
          const SizedBox(width: 8),
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
          _VoiceActionBtn(
            label: _recordPaused ? 'Reprendre l\'enregistrement' : 'Mettre en pause',
            icon: _recordPaused ? PhosphorIcons.play() : PhosphorIcons.pause(),
            iconColor: context.tpInk,
            onTap: _togglePause,
            decoration: BoxDecoration(
              color: context.tpBg,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: context.tpHair),
            ),
          ),
          const SizedBox(width: 8),
          _VoiceActionBtn(
            label: 'Envoyer la note vocale',
            icon: PhosphorIcons.paperPlaneTilt(),
            iconColor: Colors.white,
            onTap: _sendVoice,
            decoration: BoxDecoration(
              gradient: trackpartyGradient,
              borderRadius: BorderRadius.circular(Radii.button),
              boxShadow: Shadows.brand,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bouton action vocale (barre verrouillée) ──────────────────────────────────

class _VoiceActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  final BoxDecoration decoration;

  const _VoiceActionBtn({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    required this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: decoration,
          child: Icon(icon, color: iconColor, size: 20),
        ),
      ),
    );
  }
}

enum _VoiceMode { idle, holding, locked, paused }

// ── Bouton appel (navbar) ─────────────────────────────────────────────────────

class _CallIconBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _CallIconBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: kPrimary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Icon(icon, color: kPrimary, size: 18),
      ),
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
      builder: (_, _) {
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
  final bool showRead;
  final bool canReact;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.roomId,
    this.showRead = false,
    this.canReact = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final time = DateFormat('HH:mm').format(message.createdAt.toLocal());

    // Les annonces admin sont affichées pleine largeur
    if (message.isAnnouncement) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _AnnouncementBubble(message: message, roomId: roomId, time: time),
      );
    }

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
      content = message.invitationId != null
          ? _InvitationDmBubble(message: message, roomId: roomId, isMe: isMe)
          : _EventInviteContent(eventId: message.eventInviteId, isMe: isMe);
    } else {
      content = _TextContent(text: message.content, isMe: isMe);
    }

    // Réactions existantes sous la bulle
    final hasReactions = message.reactions.isNotEmpty;

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
                Semantics(
                  label: 'Message de ${message.sender.displayName}',
                  child: GestureDetector(
                  onLongPress: canReact ? () => _showReactionPicker(context, ref, message.id, roomId) : null,
                  child: content,
                  ),
                ),
                if (hasReactions && canReact)
                  _InlineReactionRow(message: message, roomId: roomId, isMe: isMe),
                Row(
                  mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                      child: Text(time,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: context.tpInkMute)),
                    ),
                    if (showRead) ...[
                      const SizedBox(width: 2),
                      Text('Vu',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kInfo)),
                      const SizedBox(width: 2),
                      const Icon(Icons.done_all_rounded, size: 12, color: kInfo),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static void _showReactionPicker(BuildContext context, WidgetRef ref, String messageId, String roomId) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReactionPickerSheet(messageId: messageId, roomId: roomId),
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
          topLeft: const Radius.circular(Radii.card),
          topRight: const Radius.circular(Radii.card),
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
        topLeft: const Radius.circular(Radii.card),
        topRight: const Radius.circular(Radii.card),
        bottomLeft: Radius.circular(isMe ? 20 : 6),
        bottomRight: Radius.circular(isMe ? 6 : 20),
      ),
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: MediaQuery.of(context).size.width * 0.6,
        height: 200,
        fit: BoxFit.cover,
        placeholder: (_, _) => Container(
          width: MediaQuery.of(context).size.width * 0.6,
          height: 200,
          color: context.tpHair,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (_, _, _) => Container(
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
          topLeft: const Radius.circular(Radii.card),
          topRight: const Radius.circular(Radii.card),
          bottomLeft: Radius.circular(widget.isMe ? 20 : 6),
          bottomRight: Radius.circular(widget.isMe ? 6 : 20),
        ),
        boxShadow: widget.isMe ? Shadows.brand : Shadows.sm,
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: _playing ? 'Pause' : 'Lecture',
            child: GestureDetector(
            onTap: _toggle,
            child: Container(
              width: 44, height: 44,
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

// ── Contenu invitation événement (simple lien) ────────────────────────────────

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
          topLeft: const Radius.circular(Radii.card),
          topRight: const Radius.circular(Radii.card),
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.card)),
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
            child: Semantics(
              button: true,
              label: 'Voir l\'événement',
              child: GestureDetector(
              onTap: eventId != null ? () => context.push('/event/$eventId') : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: trackpartyGradient,
                  borderRadius: BorderRadius.circular(Radii.md),
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
          ),
        ],
      ),
    );
  }
}

// ── Carte d'invitation dans un DM (Accept / Refuser) ─────────────────────────

class _InvitationDmBubble extends ConsumerWidget {
  final ChatMessage message;
  final String roomId;
  final bool isMe;

  const _InvitationDmBubble({
    required this.message,
    required this.roomId,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data   = message.eventInviteData;
    final status = message.invitationStatus;
    final isPending = status == 'pending' || status == null;

    final catLabel = data != null ? EventInviteData.categoryLabel(data.category) : 'SOIRÉE';
    final dateStr  = data != null
        ? DateFormat('EEE d MMM · HH\'h\'', 'fr_FR').format(data.startAt.toLocal())
        : '';
    final location = data != null
        ? '${data.addressLabel}${data.quartier.isNotEmpty ? ' · ${data.quartier}' : ''}'
        : '';
    final contrib = data?.contributionItems.isNotEmpty == true
        ? 'Apporte ${data!.contributionItems.first['emoji']} ${data.contributionItems.first['name']}'
        : null;

    return Container(
      width: MediaQuery.of(context).size.width * 0.78,
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: const BorderRadius.all(Radius.circular(Radii.card)),
        boxShadow: Shadows.sm,
        border: Border.all(color: context.tpHair),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header gradient
          Container(
            height: 80,
            decoration: BoxDecoration(gradient: trackpartyGradient),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(Radii.card),
                  ),
                  child: Text(catLabel,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(Radii.card),
                  ),
                  child: Text(
                    'Invitation · ${message.sender.displayName}',
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800,
                      color: kPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Event info
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Text(
              data?.title ?? 'Événement',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: context.tpInk),
            ),
          ),
          if (location.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 2),
              child: Text('📍 $location',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.tpInkSub),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 0),
            child: Row(
              children: [
                Text('🗓 $dateStr',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.tpInkSub)),
                if (contrib != null) ...[
                  const SizedBox(width: 8),
                  Text('·', style: TextStyle(color: context.tpInkMute)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(contrib,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.tpInkSub),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Buttons or status
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: isPending && !isMe
                ? Row(
                    children: [
                      Expanded(
                        child: _InviteActionBtn(
                          label: 'Refuser',
                          isPrimary: false,
                          onTap: () => _respond(context, ref, 'refuse'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _InviteActionBtn(
                          label: '✓  Accepter',
                          isPrimary: true,
                          onTap: () => _respond(context, ref, 'accept'),
                        ),
                      ),
                    ],
                  )
                : _StatusChip(status: status ?? 'pending', isMe: isMe),
          ),
        ],
      ),
    );
  }

  Future<void> _respond(BuildContext context, WidgetRef ref, String action) async {
    if (message.invitationId == null) return;
    try {
      await ref.read(invitationServiceProvider).respondToInvitation(message.invitationId!, action);
      ref.read(chatThreadProvider(roomId).notifier).updateInvitationStatus(message.invitationId!, action == 'accept' ? 'accepted' : 'refused');
    } catch (e) {
      if (context.mounted) {
        TpToast.error(context, 'Erreur : $e');
      }
    }
  }
}

class _InviteActionBtn extends StatelessWidget {
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _InviteActionBtn({required this.label, required this.isPrimary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: isPrimary ? trackpartyGradient : null,
          color: isPrimary ? null : context.tpBg,
          borderRadius: BorderRadius.circular(Radii.md),
          boxShadow: isPrimary ? Shadows.brand : null,
          border: isPrimary ? null : Border.all(color: context.tpHair),
        ),
        child: Center(
          child: Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isPrimary ? Colors.white : context.tpInk,
            )),
        ),
      ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final bool isMe;

  const _StatusChip({required this.status, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final isAccepted = status == 'accepted';
    final label = isAccepted ? '✓ Acceptée' : (status == 'refused' ? '✗ Refusée' : 'En attente…');
    final color = isAccepted ? kSuccess : (status == 'refused' ? kError : context.tpInkMute);

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
      ),
    );
  }
}

// ── Bulle d'annonce admin (texte + carte événement + réactions) ───────────────

class _AnnouncementBubble extends ConsumerWidget {
  final ChatMessage message;
  final String roomId;
  final String time;

  const _AnnouncementBubble({
    required this.message,
    required this.roomId,
    required this.time,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = message.eventInviteData;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: BorderRadius.circular(Radii.card),
        boxShadow: Shadows.sm,
        border: Border.all(color: kPrimary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sender row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                TpAvatar(
                  name: message.sender.displayName,
                  imageUrl: message.sender.avatarUrl,
                  size: 36,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(message.sender.displayName,
                            style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w900, color: context.tpInk)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: kPrimary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('ADMIN',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kPrimary)),
                          ),
                        ],
                      ),
                      Text(time,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: context.tpInkMute)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Message text
          if (message.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Text(message.content,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.tpInk, height: 1.45)),
            ),
          // Image attachée
          if (message.imageUrl != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.button),
                child: CachedNetworkImage(
                  imageUrl: message.imageUrl!,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(height: 200, color: context.tpHair,
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
                  errorWidget: (_, _, _) => Container(height: 80, color: context.tpHair,
                    child: Icon(PhosphorIcons.imageBroken(), color: context.tpInkMute)),
                ),
              ),
            ),
          // Note vocale attachée
          if (message.voiceUrl != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: _VoiceContent(
                voiceUrl: message.voiceUrl,
                duration: message.voiceDuration ?? 0,
                isMe: false,
              ),
            ),
          // Event mini-card
          if (data != null)
            Semantics(
              button: true,
              label: 'Voir l\'événement ${data.title}',
              child: GestureDetector(
              onTap: () => context.push('/event/${data.id}'),
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [kPrimary.withValues(alpha: 0.08), kAccent.withValues(alpha: 0.06)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(Radii.button),
                  border: Border.all(color: kPrimary.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    const Text('📍', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data.title,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: context.tpInk),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(
                            '${data.quartier.isNotEmpty ? data.quartier : data.addressLabel} · ${DateFormat('EEE d MMM', 'fr_FR').format(data.startAt.toLocal())}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.tpInkSub),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(PhosphorIcons.caretRight(), color: context.tpInkMute, size: 14),
                  ],
                ),
              ),
              ),
            ),
          // Réactions
          if (message.reactions.isNotEmpty || true) // toujours montrer pour permettre de réagir
            _ReactionRow(message: message, roomId: roomId),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Ligne de réactions ────────────────────────────────────────────────────────

class _ReactionRow extends ConsumerWidget {
  final ChatMessage message;
  final String roomId;

  const _ReactionRow({required this.message, required this.roomId});

  static const _emojis = ['🔥', '❤️', '🎉'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Row(
        children: [
          // Comptes des réactions existantes
          for (final r in message.reactions)
            _ReactionChip(
              emoji: r.emoji,
              count: r.count,
              onTap: () => ref.read(chatThreadProvider(roomId).notifier)
                  .reactToMessage(message.id, r.emoji),
            ),
          const Spacer(),
          // Boutons pour réagir
          for (final emoji in _emojis)
            Semantics(
              button: true,
              label: 'Réagir avec $emoji',
              child: GestureDetector(
              onTap: () => ref.read(chatThreadProvider(roomId).notifier)
                  .reactToMessage(message.id, emoji),
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(emoji, style: const TextStyle(fontSize: 18)),
              ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  final String emoji;
  final int count;
  final VoidCallback onTap;

  const _ReactionChip({required this.emoji, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true, label: 'Réaction $emoji · $count',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: kPrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: kPrimary.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text('$count',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Picker de réactions (long-press) ─────────────────────────────────────────

class _ReactionPickerSheet extends ConsumerWidget {
  final String messageId;
  final String roomId;

  const _ReactionPickerSheet({required this.messageId, required this.roomId});

  static const _emojis = ['🔥', '❤️', '🎉', '😂', '👏', '😮', '😢', '👍'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, bottom + 12),
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.card)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(color: context.tpHair, borderRadius: BorderRadius.circular(2)),
          ),
          Text('Réagir',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: context.tpInk)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _emojis.map((emoji) => Semantics(
              button: true, label: 'Réagir avec $emoji',
              child: GestureDetector(
                onTap: () {
                  ref.read(chatThreadProvider(roomId).notifier).reactToMessage(messageId, emoji);
                  Navigator.of(context).pop();
                },
                child: Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: context.tpBg,
                    borderRadius: BorderRadius.circular(Radii.lg),
                    border: Border.all(color: context.tpHair),
                  ),
                  alignment: Alignment.center,
                  child: Text(emoji, style: const TextStyle(fontSize: 26)),
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Réactions inline sous une bulle normale ───────────────────────────────────

class _InlineReactionRow extends ConsumerWidget {
  final ChatMessage message;
  final String roomId;
  final bool isMe;

  const _InlineReactionRow({
    required this.message,
    required this.roomId,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
      child: Wrap(
        spacing: 4,
        children: message.reactions.map((r) => Semantics(
          button: true, label: 'Réaction ${r.emoji} · ${r.count}',
          child: GestureDetector(
            onTap: () => ref.read(chatThreadProvider(roomId).notifier)
                .reactToMessage(message.id, r.emoji),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: kPrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(Radii.card),
                border: Border.all(color: kPrimary.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(r.emoji, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 3),
                  Text('${r.count}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kPrimary)),
                ],
              ),
            ),
          ),
        )).toList(),
      ),
    );
  }
}

// ── Bannière mode broadcast ───────────────────────────────────────────────────

class _BroadcastBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        Sp.md, 14, Sp.md, 14 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: context.tpCard,
        border: Border(top: BorderSide(color: context.tpHair)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIcons.megaphone(), color: context.tpInkMute, size: 16),
          const SizedBox(width: 8),
          Text(
            'Seuls les organisateurs peuvent envoyer des messages',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.tpInkMute),
          ),
        ],
      ),
    );
  }
}

// ── Bandeau toggle mode événement ─────────────────────────────────────────────

class EventModeBanner extends StatelessWidget {
  final bool attachEvent;
  final VoidCallback onToggle;

  const EventModeBanner({
    super.key,
    required this.attachEvent,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: attachEvent ? 'Désactiver le mode annonce' : 'Activer le mode annonce',
      toggled: attachEvent,
      child: GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.fromLTRB(Sp.md, 8, Sp.md, 6),
        decoration: BoxDecoration(
          gradient: attachEvent
              ? LinearGradient(
                  colors: [kPrimary.withValues(alpha: 0.12), kAccent.withValues(alpha: 0.08)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: attachEvent ? null : context.tpBg,
          border: Border(bottom: BorderSide(color: context.tpHair)),
        ),
        child: Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              gradient: attachEvent ? trackpartyGradient : null,
              color: attachEvent ? null : context.tpHair,
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Icon(
              attachEvent
                  ? PhosphorIcons.megaphone(PhosphorIconsStyle.fill)
                  : PhosphorIcons.megaphone(),
              color: attachEvent ? Colors.white : context.tpInkMute,
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachEvent ? 'Mode annonce activé' : 'Mode annonce désactivé',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800,
                    color: attachEvent ? kPrimary : context.tpInkMute,
                  ),
                ),
                Text(
                  attachEvent
                      ? 'Les messages seront des annonces officielles'
                      : 'Messages envoyés en mode conversation normale',
                  style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600,
                    color: attachEvent ? kPrimary.withValues(alpha: 0.7) : context.tpInkMute,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            attachEvent ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
            color: attachEvent ? kPrimary : context.tpInkMute,
            size: 28,
          ),
        ]),
      ),
      ),
    );
  }
}

class _GroupModeSheet extends StatelessWidget {
  final bool isBroadcast;
  final Future<void> Function() onToggle;
  const _GroupModeSheet({required this.isBroadcast, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(Sp.md),
      padding: const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, Sp.md),
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: BorderRadius.circular(Radii.cardLg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: context.tpHair, borderRadius: BorderRadius.circular(2)),
          ),
          Row(children: [
            Icon(
              isBroadcast
                ? PhosphorIcons.megaphone(PhosphorIconsStyle.fill)
                : PhosphorIcons.megaphone(),
              color: isBroadcast ? kPrimary : context.tpInkSub,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Paramètres du groupe',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: context.tpInk)),
                  const SizedBox(height: 2),
                  Text(
                    isBroadcast
                      ? 'Mode diffusion — seuls les admins peuvent écrire'
                      : 'Groupe ouvert — tout le monde peut écrire',
                    style: TextStyle(fontSize: 12, color: context.tpInkSub),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Semantics(
            button: true,
            label: isBroadcast ? 'Ouvrir aux participants' : 'Passer en mode diffusion',
            child: GestureDetector(
            onTap: () {
              Navigator.pop(context);
              onToggle();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 14),
              decoration: BoxDecoration(color: context.tpBg, borderRadius: BorderRadius.circular(Radii.lg)),
              child: Row(children: [
                Icon(
                  isBroadcast ? PhosphorIcons.lockKeyOpen() : PhosphorIcons.lock(),
                  color: isBroadcast ? kSuccess : kWarning,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isBroadcast ? 'Ouvrir aux participants' : 'Passer en mode diffusion',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.tpInk),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isBroadcast
                          ? 'Les participants pourront envoyer des messages'
                          : 'Seuls les admins pourront envoyer des messages',
                        style: TextStyle(fontSize: 12, color: context.tpInkSub),
                      ),
                    ],
                  ),
                ),
                Icon(PhosphorIcons.caretRight(), color: context.tpInkSub, size: 16),
              ]),
            ),
            ),
          ),
          const SizedBox(height: Sp.sm),
        ],
      ),
    );
  }
}

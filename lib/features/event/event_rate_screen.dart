import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/event_model.dart';
import '../../core/services/event_service.dart';
import '../../core/api/api_exception.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_button.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class EventRateScreen extends ConsumerStatefulWidget {
  final String eventId;
  const EventRateScreen({super.key, required this.eventId});
  @override
  ConsumerState<EventRateScreen> createState() => _EventRateScreenState();
}

class _EventRateScreenState extends ConsumerState<EventRateScreen> {
  int _rating = 0;
  final Set<int> _tags = {};
  final _ctrl = TextEditingController();
  bool _public = true;
  TpButtonState _btnState = TpButtonState.idle;

  EventModel? _event;
  bool _loadingEvent = true;

  static const _tagLabels = [
    '🎵 Ambiance', '🍾 Boissons', '👥 Monde sympa',
    '📍 Lieu', '⏰ Ponctualité', '🍽 Bouffe',
  ];

  static const _tagKeys = [
    'ambiance', 'boissons', 'monde_sympa', 'lieu', 'ponctualite', 'bouffe',
  ];

  static const _ratingLabels = [
    '', 'Bof 😕', 'Moyen 😐', 'Pas mal 👌', 'Super soirée ✨', 'Incroyable 🔥',
  ];

  @override
  void initState() {
    super.initState();
    _loadEvent();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadEvent() async {
    try {
      final event = await ref.read(eventServiceProvider).getEvent(widget.eventId);
      if (mounted) setState(() { _event = event; _loadingEvent = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingEvent = false);
    }
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisis une note avant d\'envoyer.')));
      return;
    }
    setState(() => _btnState = TpButtonState.loading);
    try {
      await ref.read(eventServiceProvider).submitReview(
        widget.eventId,
        rating: _rating,
        comment: _ctrl.text.trim().isEmpty ? null : _ctrl.text.trim(),
        isPublic: _public,
        tags: _tags.map((i) => _tagKeys[i]).toList(),
      );
      if (!mounted) return;
      setState(() => _btnState = TpButtonState.idle);
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Merci pour ton avis ! 🙏')));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _btnState = TpButtonState.idle);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _btnState = TpButtonState.idle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventTitle = _event?.title ?? '…';
    final eventCity = _event?.city ?? '';
    final organizerName = _event?.organizerName ?? '…';

    return Scaffold(
      backgroundColor: context.tpBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Semantics(
                      button: true, label: 'Retour',
                      child: GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                              color: context.tpCard,
                              borderRadius: BorderRadius.circular(Radii.md),
                              boxShadow: Shadows.sm),
                          child: Icon(PhosphorIcons.caretLeft(), color: context.tpInk, size: 18),
                        ),
                      ),
                    ),
                    Semantics(
                      button: true, label: 'Passer',
                      child: GestureDetector(
                        onTap: () => context.pop(),
                        child: Text('Passer',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: context.tpInkSub)),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.lg, 20, Sp.lg, 0),
                child: Column(
                  children: [
                    Container(
                      width: 88, height: 88,
                      decoration: BoxDecoration(
                        gradient: trackpartyGradient,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: Shadows.brand,
                      ),
                      alignment: Alignment.center,
                      child: const Text('🎉', style: TextStyle(fontSize: 44)),
                    ),
                    const SizedBox(height: 18),
                    Text('Comment c\'était ?',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900,
                          color: context.tpInk, letterSpacing: -0.8, height: 1.15)),
                    const SizedBox(height: 6),
                    if (_loadingEvent)
                      Container(
                        width: 180, height: 14,
                        decoration: BoxDecoration(
                          color: context.tpHair, borderRadius: BorderRadius.circular(Radii.xs)),
                      )
                    else ...[
                      Text('$eventTitle${eventCity.isNotEmpty ? ' · $eventCity' : ''}',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.tpInkSub)),
                      const SizedBox(height: 2),
                      Text('organisé par $organizerName',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.tpInkMute)),
                    ],
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(0, 26, 0, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final filled = i < _rating;
                    return Semantics(
                      button: true,
                      label: '${i + 1} étoile${i > 0 ? 's' : ''}',
                      selected: filled,
                      child: GestureDetector(
                        onTap: () => setState(() => _rating = i + 1),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Icon(
                            PhosphorIcons.star(PhosphorIconsStyle.fill),
                            size: 44,
                            color: filled ? kWarning : kWarning.withValues(alpha: 0.15),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: AnimatedOpacity(
                  opacity: _rating > 0 ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Text(_rating > 0 ? _ratingLabels[_rating] : '',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: context.tpInk)),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.lg, 24, Sp.lg, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Qu'est-ce que tu as aimé ?",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: context.tpInk)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: List.generate(_tagLabels.length, (i) {
                        final active = _tags.contains(i);
                        return Semantics(
                          button: true,
                          label: _tagLabels[i],
                          selected: active,
                          child: GestureDetector(
                          onTap: () => setState(() => active ? _tags.remove(i) : _tags.add(i)),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: active ? kPrimary : context.tpCard,
                              borderRadius: BorderRadius.circular(Radii.md),
                              border: active ? null : Border.all(color: context.tpHair),
                              boxShadow: active
                                  ? [const BoxShadow(color: Color(0x407C3AED), blurRadius: 10, offset: Offset(0, 4))]
                                  : null,
                            ),
                            child: Text(_tagLabels[i],
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                                  color: active ? Colors.white : context.tpInk)),
                          ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.lg, 20, Sp.lg, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(children: [
                        TextSpan(
                          text: 'Un mot pour $organizerName ?',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: context.tpInk)),
                        TextSpan(
                          text: ' (optionnel)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.tpInkMute)),
                      ]),
                    ),
                    const SizedBox(height: 8),
                    AnimatedBuilder(
                      animation: _ctrl,
                      builder: (_, _) => Column(
                        children: [
                          TextField(
                            controller: _ctrl,
                            maxLines: 4, maxLength: 280,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.tpInk, height: 1.45),
                            decoration: InputDecoration(
                              hintText: 'Sunset incroyable, sets afrobeats au top…',
                              hintStyle: TextStyle(fontSize: 14, color: context.tpInkMute),
                              filled: true, fillColor: context.tpCard,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.button),
                                  borderSide: BorderSide(color: context.tpHair, width: 1.5)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.button),
                                  borderSide: BorderSide(color: context.tpHair, width: 1.5)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.button),
                                  borderSide: const BorderSide(color: kPrimary, width: 1.5)),
                              counterText: '',
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text('${_ctrl.text.length} / 280',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.tpInkMute)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.lg, 12, Sp.lg, 0),
                child: Semantics(
                  button: true, toggled: _public,
                  label: 'Publier sur le profil public de $organizerName',
                  child: GestureDetector(
                    onTap: () => setState(() => _public = !_public),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 22, height: 22,
                          decoration: BoxDecoration(
                            gradient: _public ? trackpartyGradient : null,
                            color: _public ? null : context.tpCard,
                            borderRadius: BorderRadius.circular(7),
                            border: _public ? null : Border.all(color: context.tpHair, width: 1.5),
                          ),
                          child: _public
                              ? Icon(PhosphorIcons.check(), color: Colors.white, size: 14)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Publier sur le profil public de $organizerName',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.tpInkSub)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.lg, 20, Sp.lg, 0),
                child: TpButton(
                  label: 'Envoyer mon avis',
                  icon: PhosphorIcons.paperPlaneTilt(),
                  fullWidth: true,
                  state: _btnState,
                  onPressed: _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

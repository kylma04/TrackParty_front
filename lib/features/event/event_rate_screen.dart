import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_button.dart';


class EventRateScreen extends StatefulWidget {
  final String eventId;
  const EventRateScreen({super.key, required this.eventId});
  @override
  State<EventRateScreen> createState() => _EventRateScreenState();
}

class _EventRateScreenState extends State<EventRateScreen> {
  int _rating = 4;
  final Set<int> _tags = {0, 1, 2};
  final _ctrl = TextEditingController();
  bool _public = true;
  TpButtonState _btnState = TpButtonState.idle;

  static const _tagLabels = [
    '🎵 Ambiance', '🍾 Boissons', '👥 Monde sympa',
    '📍 Lieu', '⏰ Ponctualité', '🍽 Bouffe',
  ];

  static const _ratingLabels = [
    '', 'Bof 😕', 'Moyen 😐', 'Pas mal 👌', 'Super soirée ✨', 'Incroyable 🔥',
  ];

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tpBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Semantics(
                      button: true,
                      label: 'Retour',
                      child: GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.chevron_left, color: context.tpInk, size: 18),
                        ),
                      ),
                    ),
                    Text('Passer',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: context.tpInkSub)),
                  ],
                ),
              ),

              // Hero
              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.lg, 4, Sp.lg, 0),
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
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900,
                          color: context.tpInk, letterSpacing: -0.8, height: 1.15)),
                    const SizedBox(height: 6),
                    Text('Afro Sunset Rooftop · Plateau',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.tpInkSub)),
                    const SizedBox(height: 2),
                    Text('organisé par Karim Diallo',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.tpInkMute)),
                  ],
                ),
              ),

              // Stars
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
                            filled ? Icons.star : Icons.star,
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
                child: Text(_rating > 0 ? _ratingLabels[_rating] : '',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: context.tpInk)),
              ),

              // Tags
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
                        return GestureDetector(
                          onTap: () => setState(() => active ? _tags.remove(i) : _tags.add(i)),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: active ? kPrimary : context.tpCard,
                              borderRadius: BorderRadius.circular(12),
                              border: active ? null : Border.all(color: context.tpHair),
                              boxShadow: active
                                  ? [const BoxShadow(color: Color(0x407C3AED), blurRadius: 10, offset: Offset(0, 4))]
                                  : null,
                            ),
                            child: Text(_tagLabels[i],
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                                  color: active ? Colors.white : context.tpInk)),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),

              // Comment
              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.lg, 20, Sp.lg, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(children: [
                        TextSpan(text: 'Un mot pour Karim ?',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: context.tpInk)),
                        TextSpan(text: ' (optionnel)',
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
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: context.tpHair, width: 1.5)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: context.tpHair, width: 1.5)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
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

              // Public toggle
              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.lg, 12, Sp.lg, 0),
                child: Semantics(
                  button: true,
                  toggled: _public,
                  label: 'Publier sur le profil public de Karim',
                  child: GestureDetector(
                    onTap: () => setState(() => _public = !_public),
                    child: Row(
                      children: [
                        Container(
                          width: 22, height: 22,
                          decoration: BoxDecoration(
                            gradient: _public ? trackpartyGradient : null,
                            color: _public ? null : context.tpCard,
                            borderRadius: BorderRadius.circular(7),
                            border: _public ? null : Border.all(color: context.tpHair, width: 1.5),
                          ),
                          child: _public ? Icon(Icons.check, color: Colors.white, size: 14) : null,
                        ),
                        const SizedBox(width: 10),
                        Text('Publier sur le profil public de Karim',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.tpInkSub)),
                      ],
                    ),
                  ),
                ),
              ),

              // Submit
              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.lg, 20, Sp.lg, 0),
                child: TpButton(
                  label: 'Envoyer mon avis',
                  icon: Icons.check,
                  fullWidth: true,
                  state: _btnState,
                  onPressed: () async {
                    setState(() => _btnState = TpButtonState.loading);
                    final nav = Navigator.of(context);
                    await Future.delayed(const Duration(seconds: 1));
                    if (!mounted) return;
                    setState(() => _btnState = TpButtonState.idle);
                    nav.pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

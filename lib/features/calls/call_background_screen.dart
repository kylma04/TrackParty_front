import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/services/call_readiness_service.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';

/// Écran « Appels en arrière-plan » : explique et guide l'utilisateur pour
/// autoriser le réveil du téléphone sur un appel entrant quand l'app est tuée
/// (exemption batterie + démarrage auto OEM). Sert d'onboarding (auto après
/// login) ET de page accessible depuis les Paramètres.
class CallBackgroundScreen extends StatefulWidget {
  const CallBackgroundScreen({super.key});

  @override
  State<CallBackgroundScreen> createState() => _CallBackgroundScreenState();
}

class _CallBackgroundScreenState extends State<CallBackgroundScreen>
    with WidgetsBindingObserver {
  bool _exempted = false;
  bool _reminderOn = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Retour dans l'app après un passage dans les réglages système → réactualiser
    // l'état (le ✅ « autorisé » se met à jour tout seul).
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final exempted = await CallReadinessService.isBatteryExempted();
    final off      = await CallReadinessService.reminderDisabled();
    if (!mounted) return;
    setState(() {
      _exempted   = exempted;
      _reminderOn = !off;
      _loading    = false;
    });
  }

  Future<void> _toggleReminder(bool on) async {
    setState(() => _reminderOn = on);
    await CallReadinessService.setReminderDisabled(!on);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tpBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.md, 8, Sp.md, 0),
              child: Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'Retour',
                    child: GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 44, height: 44,
                        alignment: Alignment.centerLeft,
                        child: Icon(PhosphorIcons.caretLeft(), color: context.tpInk, size: 20),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text('Appels en arrière-plan',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: context.tpInk)),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Sp.md, 16, Sp.md, 24),
                children: [
                  // Illustration + pitch
                  Center(
                    child: Container(
                      width: 88, height: 88,
                      decoration: BoxDecoration(
                        gradient: trackpartyGradient,
                        borderRadius: BorderRadius.circular(Radii.cardLg),
                      ),
                      child: Icon(PhosphorIcons.phoneCall(PhosphorIconsStyle.fill),
                          color: Colors.white, size: 40),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Ne rate plus aucun appel',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                          color: context.tpInk, letterSpacing: -0.4)),
                  const SizedBox(height: 8),
                  Text(
                    'Pour que ton téléphone sonne même quand TrackParty est fermé, '
                    'autorise l\'app à rester active en arrière-plan. Sur certaines '
                    'marques (Xiaomi, Oppo, Vivo, Samsung…), c\'est indispensable.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: context.tpInkSub, height: 1.5),
                  ),
                  const SizedBox(height: 24),

                  if (!Platform.isAndroid)
                    _InfoCard(
                      icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                      color: kSuccess,
                      text: 'Sur iOS, les appels entrants sont gérés nativement — '
                          'aucun réglage supplémentaire n\'est nécessaire.',
                    )
                  else ...[
                    // ── Étape 1 : optimisation batterie ────────────────────────
                    _StepCard(
                      step: '1',
                      title: 'Optimisation de la batterie',
                      subtitle: _loading
                          ? '…'
                          : (_exempted
                              ? 'Autorisé — TrackParty peut se réveiller.'
                              : 'À autoriser pour recevoir les appels app fermée.'),
                      done: _exempted,
                      actionLabel: _exempted ? 'Autorisé' : 'Autoriser',
                      onAction: _exempted
                          ? null
                          : () async {
                              await CallReadinessService.requestBatteryExemption();
                            },
                    ),
                    const SizedBox(height: 12),
                    // ── Étape 2 : démarrage automatique ────────────────────────
                    _StepCard(
                      step: '2',
                      title: 'Démarrage automatique',
                      subtitle: 'Xiaomi / Oppo / Vivo / Huawei : active TrackParty '
                          'dans la liste « Démarrage auto ».',
                      done: false,
                      actionLabel: 'Ouvrir',
                      onAction: () async {
                        await CallReadinessService.openAutoStartSettings();
                      },
                    ),
                    const SizedBox(height: 20),

                    // ── Rappel activable / désactivable ────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: context.tpCard,
                        borderRadius: BorderRadius.circular(Radii.lg),
                        border: Border.all(color: context.tpHair),
                      ),
                      child: Row(children: [
                        Icon(PhosphorIcons.bellRinging(), color: context.tpInkSub, size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Me le rappeler au démarrage',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.tpInk)),
                            Text('Désactive pour ne plus voir cet écran automatiquement.',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.tpInkSub)),
                          ]),
                        ),
                        _Switch(value: _reminderOn, onChanged: _toggleReminder),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 28),
                  Semantics(
                    button: true,
                    label: 'Terminé',
                    child: GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: trackpartyGradient,
                          borderRadius: BorderRadius.circular(Radii.button),
                        ),
                        child: const Text('Terminé',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets locaux ────────────────────────────────────────────────────────────

class _StepCard extends StatelessWidget {
  final String step;
  final String title;
  final String subtitle;
  final bool done;
  final String actionLabel;
  final VoidCallback? onAction;

  const _StepCard({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.done,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: done ? kSuccess.withValues(alpha: 0.4) : context.tpHair),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: (done ? kSuccess : kPrimary).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(Radii.tag),
          ),
          child: done
              ? Icon(PhosphorIcons.check(PhosphorIconsStyle.bold), color: kSuccess, size: 18)
              : Text(step,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: kPrimary)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.tpInk)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.tpInkSub)),
          ]),
        ),
        const SizedBox(width: 10),
        Semantics(
          button: onAction != null,
          label: actionLabel,
          child: GestureDetector(
            onTap: onAction,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: onAction == null ? kSuccess.withValues(alpha: 0.12) : kPrimary,
                borderRadius: BorderRadius.circular(Radii.button),
              ),
              child: Text(actionLabel,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800,
                      color: onAction == null ? kSuccess : Colors.white)),
            ),
          ),
        ),
      ]),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _InfoCard({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.tpInk, height: 1.4)),
        ),
      ]),
    );
  }
}

class _Switch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Switch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: value,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44, height: 26,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: value ? kPrimary : context.tpHair,
            borderRadius: BorderRadius.circular(13),
          ),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22, height: 22,
            decoration: const BoxDecoration(
              color: Colors.white, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 3)],
            ),
          ),
        ),
      ),
    );
  }
}

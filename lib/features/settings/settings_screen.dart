import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/biometric_service.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_confirm_sheet.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _biometricAvailable = false;
  bool _biometricEnabled   = false;
  bool _notifPush          = true;
  bool _notifEmail         = true;
  bool _notifSms           = false;

  @override
  void initState() {
    super.initState();
    _loadBiometric();
  }

  Future<void> _loadBiometric() async {
    final svc       = ref.read(biometricServiceProvider);
    final available = await svc.canAuthenticate();
    final enabled   = await svc.isEnabled();
    if (mounted) setState(() { _biometricAvailable = available; _biometricEnabled = enabled; });
  }

  Future<void> _toggleBiometric(bool val) async {
    final svc = ref.read(biometricServiceProvider);
    if (val) {
      final ok = await svc.authenticate();
      if (!ok) return;
      await svc.setEnabled(true);
    } else {
      await svc.setEnabled(false);
    }
    if (mounted) setState(() => _biometricEnabled = val);
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await TpConfirmSheet.show(
      context,
      title: 'Supprimer mon compte ?',
      body: 'Cette action est irréversible. Toutes tes données (événements, billets, messages) seront définitivement supprimées.',
      confirmLabel: 'Supprimer',
    );
    if (confirmed) await ref.read(authNotifierProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: context.tpBg,
      body: CustomScrollView(
        slivers: [
          // ── AppBar ──────────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: context.tpCard,
            surfaceTintColor: Colors.transparent,
            leading: Semantics(
              button: true,
              label: 'Retour',
              child: GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.tpBg,
                    borderRadius: BorderRadius.circular(Radii.tag),
                  ),
                  child: Icon(PhosphorIcons.caretLeft(), color: context.tpInk, size: 18),
                ),
              ),
            ),
            title: Text('Paramètres',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: context.tpInk)),
            centerTitle: true,
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Sp.md, 20, Sp.md, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Apparence ─────────────────────────────────────────────────
                _SectionHeader(label: 'APPARENCE'),
                const SizedBox(height: 8),
                _SettingsCard(children: [
                  _SettingRow(
                    icon: PhosphorIcons.sun(),
                    iconColor: kWarning,
                    label: 'Thème',
                    sub: switch (themeMode) {
                      ThemeMode.light  => 'Clair',
                      ThemeMode.dark   => 'Sombre',
                      ThemeMode.system => 'Auto (système)',
                    },
                    isLast: true,
                    onTap: () => _showThemePicker(context, themeMode),
                  ),
                ]),
                const SizedBox(height: 20),

                // ── Notifications ──────────────────────────────────────────────
                _SectionHeader(label: 'NOTIFICATIONS'),
                const SizedBox(height: 8),
                _SettingsCard(children: [
                  _SettingRow(
                    icon: PhosphorIcons.bellRinging(),
                    iconColor: kAccent,
                    label: 'Notifications push',
                    sub: 'Événements, invitations, messages',
                    isLast: false,
                    toggle: true,
                    toggleValue: _notifPush,
                    onToggle: (v) => setState(() => _notifPush = v),
                  ),
                  _SettingRow(
                    icon: PhosphorIcons.envelope(),
                    iconColor: kPrimary,
                    label: 'Notifications email',
                    sub: 'Résumés et rappels',
                    isLast: false,
                    toggle: true,
                    toggleValue: _notifEmail,
                    onToggle: (v) => setState(() => _notifEmail = v),
                  ),
                  _SettingRow(
                    icon: PhosphorIcons.chatTeardrop(),
                    iconColor: kSuccess,
                    label: 'Notifications SMS',
                    sub: 'Rappels importants uniquement',
                    isLast: true,
                    toggle: true,
                    toggleValue: _notifSms,
                    onToggle: (v) => setState(() => _notifSms = v),
                  ),
                ]),
                const SizedBox(height: 20),

                // ── Sécurité ───────────────────────────────────────────────────
                _SectionHeader(label: 'SÉCURITÉ'),
                const SizedBox(height: 8),
                _SettingsCard(children: [
                  if (_biometricAvailable)
                    _SettingRow(
                      icon: PhosphorIcons.fingerprint(),
                      iconColor: kSecondary,
                      label: 'Connexion biométrique',
                      sub: 'Face ID / Empreinte digitale',
                      isLast: false,
                      toggle: true,
                      toggleValue: _biometricEnabled,
                      onToggle: _toggleBiometric,
                    ),
                  _SettingRow(
                    icon: PhosphorIcons.lock(),
                    iconColor: kViolet,
                    label: 'Changer le mot de passe',
                    sub: '',
                    isLast: true,
                    onTap: () => context.push('/forgot'),
                  ),
                ]),
                const SizedBox(height: 20),

                // ── Confidentialité ────────────────────────────────────────────
                _SectionHeader(label: 'CONFIDENTIALITÉ'),
                const SizedBox(height: 8),
                _SettingsCard(children: [
                  _SettingRow(
                    icon: PhosphorIcons.mapPin(),
                    iconColor: kInfo,
                    label: 'Localisation',
                    sub: 'Utilisée pour afficher les events proches',
                    isLast: false,
                  ),
                  _SettingRow(
                    icon: PhosphorIcons.prohibit(),
                    iconColor: kError,
                    label: 'Utilisateurs bloqués',
                    sub: 'Gérer les blocages',
                    isLast: true,
                    onTap: () {},
                  ),
                ]),
                const SizedBox(height: 20),

                // ── À propos ───────────────────────────────────────────────────
                _SectionHeader(label: 'À PROPOS'),
                const SizedBox(height: 8),
                _SettingsCard(children: [
                  _SettingRow(
                    icon: PhosphorIcons.question(),
                    iconColor: kTertiary,
                    label: 'Aide & support',
                    sub: 'FAQ, contact',
                    isLast: false,
                    onTap: () {},
                  ),
                  _SettingRow(
                    icon: PhosphorIcons.shieldCheck(),
                    iconColor: kSuccess,
                    label: 'Politique de confidentialité',
                    sub: '',
                    isLast: false,
                    onTap: () {},
                  ),
                  _SettingRow(
                    icon: PhosphorIcons.info(),
                    iconColor: context.tpInkMute,
                    label: 'Version',
                    sub: 'TrackParty v1.0.0 · 🇨🇮',
                    isLast: true,
                  ),
                ]),
                const SizedBox(height: 20),

                // ── Zone dangereuse ────────────────────────────────────────────
                _SectionHeader(label: 'ZONE DANGEREUSE'),
                const SizedBox(height: 8),
                Semantics(
                  button: true,
                  label: 'Supprimer mon compte',
                  child: GestureDetector(
                  onTap: () => _confirmDeleteAccount(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: kError.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(Radii.lg),
                      border: Border.all(color: kError.withValues(alpha: 0.20)),
                    ),
                    child: Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                            color: kError.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(Radii.tag)),
                        child: Icon(PhosphorIcons.trash(), color: kError, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Supprimer mon compte',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kError)),
                          Text('Action irréversible',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                  color: kError.withValues(alpha: 0.65))),
                        ]),
                      ),
                      Icon(PhosphorIcons.caretRight(), color: kError.withValues(alpha: 0.5), size: 16),
                    ]),
                  ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showThemePicker(BuildContext context, ThemeMode current) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: context.tpBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.cardLg)),
        ),
        padding: const EdgeInsets.fromLTRB(Sp.md, 20, Sp.md, 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: context.tpHair, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(gradient: trackpartyGradient, borderRadius: BorderRadius.circular(Radii.md)),
              child: Icon(PhosphorIcons.sun(), color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Text('Thème de l\'application',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: context.tpInk)),
          ]),
          const SizedBox(height: 20),
          for (final rec in <(ThemeMode, String, IconData, Color)>[
            (ThemeMode.system, 'Auto (système)',   PhosphorIcons.deviceMobile(), context.tpInkSub),
            (ThemeMode.light,  'Clair',            PhosphorIcons.sun(),          kWarning),
            (ThemeMode.dark,   'Sombre',           PhosphorIcons.moon(),         kPrimary),
          ]) ...[
            Semantics(
              button: true,
              label: rec.$2,
              selected: current == rec.$1,
              child: GestureDetector(
              onTap: () {
                ref.read(themeModeProvider.notifier).set(rec.$1);
                Navigator.pop(context);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: current == rec.$1 ? kPrimary.withValues(alpha: 0.08) : context.tpCard,
                  borderRadius: BorderRadius.circular(Radii.button),
                  border: Border.all(
                    color: current == rec.$1 ? kPrimary.withValues(alpha: 0.3) : context.tpHair,
                    width: current == rec.$1 ? 1.5 : 1,
                  ),
                ),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                        color: rec.$4.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(Radii.tag)),
                    child: Icon(rec.$3, color: rec.$4, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(rec.$2,
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800,
                            color: current == rec.$1 ? kPrimary : context.tpInk)),
                  ),
                  if (current == rec.$1)
                    Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), color: kPrimary, size: 20),
                ]),
              ),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Widgets locaux ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) => Text(label,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900,
          color: context.tpInkSub, letterSpacing: 0.4));
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: context.tpCard,
          borderRadius: BorderRadius.circular(Radii.lg),
          boxShadow: const [BoxShadow(color: Color(0x0D1B1A2E), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Column(children: children),
      );
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String sub;
  final bool isLast;
  final bool toggle;
  final bool? toggleValue;
  final void Function(bool)? onToggle;
  final VoidCallback? onTap;

  const _SettingRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.sub,
    required this.isLast,
    this.toggle = false,
    this.toggleValue,
    this.onToggle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
        button: !toggle,
        label: label,
        toggled: toggle ? (toggleValue ?? false) : null,
        child: GestureDetector(
        onTap: toggle ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
              border: isLast ? null : Border(bottom: BorderSide(color: context.tpHair))),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Radii.tag)),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.tpInk)),
              if (sub.isNotEmpty)
                Text(sub, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.tpInkSub)),
            ])),
            if (toggle)
              Semantics(
                label: label,
                toggled: toggleValue ?? false,
                button: true,
                child: GestureDetector(
                onTap: () => onToggle?.call(!(toggleValue ?? false)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44, height: 26,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: (toggleValue ?? false) ? kPrimary : context.tpHair,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  alignment: (toggleValue ?? false) ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 22, height: 22,
                    decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 3)],
                    ),
                  ),
                ),
              ),
            )
            else if (onTap != null)
              Icon(PhosphorIcons.caretRight(), color: context.tpInkMute, size: 16),
          ]),
        ),
      ),
    );
}

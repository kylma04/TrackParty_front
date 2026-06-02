import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/user_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_avatar.dart';


class MyProfileScreen extends ConsumerStatefulWidget {
  const MyProfileScreen({super.key});

  @override
  ConsumerState<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends ConsumerState<MyProfileScreen> {
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider).valueOrNull;
    final user = authState is AuthAuthenticated ? authState.user : null;

    return Scaffold(
      backgroundColor: context.tpBg,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context, user),
            _buildMiniStats(context, user),
            _buildMyEvents(context),
            _buildSettings(context),
            _buildLogout(context),
            const SizedBox(height: 12),
            Text('TrackParty · v1.0.0 · 🇨🇮',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: context.tpInkMute)),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, UserModel? user) {
    final name = user?.displayName ?? '—';
    final avatarUrl = user?.avatarUrl;
    final location = [user?.quartier, user?.city].where((s) => s != null && s.isNotEmpty).join(', ');
    final memberYear = user?.createdAt.year.toString() ?? '—';

    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          Container(
            height: 220,
            decoration: const BoxDecoration(
              gradient: trackpartyGradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: Stack(children: [
              Positioned(
                top: -60, right: -40,
                child: Container(
                  width: 180, height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [Colors.white.withValues(alpha: 0.18), Colors.transparent])),
                ),
              ),
              Positioned(
                bottom: -40, left: -40,
                child: Container(
                  width: 200, height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [kAccent.withValues(alpha: 0.32), Colors.transparent])),
                ),
              ),
            ]),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.md),
              child: Row(children: [
                const Text('Mon profil',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.6)),
                const Spacer(),
                Semantics(
                  button: true,
                  label: 'Paramètres',
                  child: _ProfileGlassBtn(icon: Icons.settings_outlined, onTap: () {}),
                ),
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: 'Modifier le profil',
                  child: _ProfileGlassBtn(icon: Icons.edit_outlined, onTap: () => context.push('/me/edit')),
                ),
              ]),
            ),
          ),
          Positioned(
            top: 90, left: Sp.md, right: Sp.md,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.3)),
                  child: Stack(children: [
                    TpAvatar(name: name, imageUrl: avatarUrl, size: 70, ringColor: Colors.white),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        width: 26, height: 26,
                        decoration: BoxDecoration(
                            color: kAccent, shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5)),
                        child: Icon(Icons.camera_alt_outlined, color: Colors.white, size: 14)),
                    ),
                  ]),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.4)),
                    const SizedBox(height: 2),
                    Text(
                      location.isNotEmpty ? location : 'Abidjan, Côte d\'Ivoire',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.85)),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('🎉 Membre depuis $memberYear',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Mini stats ──────────────────────────────────────────────────────────────
  Widget _buildMiniStats(BuildContext context, UserModel? user) {
    final profile = user?.promoterProfile;
    final events = profile?.totalEvents.toString() ?? '0';
    final rating = profile?.avgRating.toStringAsFixed(1) ?? '—';

    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 14, Sp.md, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: context.tpCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x0D1B1A2E), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _StatPill(icon: '🎟️', n: '0', l: 'Participations'),
            _Divider(),
            _StatPill(icon: '🤝', n: events, l: 'Organisés'),
            _Divider(),
            _StatPill(icon: '⭐', n: rating, l: 'Note'),
          ],
        ),
      ),
    );
  }

  // ── My events ───────────────────────────────────────────────────────────────
  Widget _buildMyEvents(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 18, Sp.md, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('MES EVENTS',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: context.tpInkSub, letterSpacing: 0.3)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _ActionTile(icon: '📅', label: 'À venir', count: '—', color: kPrimary, active: true)),
          const SizedBox(width: 8),
          Expanded(child: _ActionTile(icon: '✅', label: 'Confirmés', count: '—', color: kSecondary, active: false)),
          const SizedBox(width: 8),
          Expanded(child: _ActionTile(icon: '📜', label: 'Historique', count: '—', color: kAccent, active: false)),
        ]),
      ]),
    );
  }

  // ── Settings ────────────────────────────────────────────────────────────────
  Widget _buildSettings(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 18, Sp.md, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('COMPTE & CONFIDENTIALITÉ',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: context.tpInkSub, letterSpacing: 0.3)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: context.tpCard,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [BoxShadow(color: Color(0x0D1B1A2E), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Column(children: [
            _SettingRow(
              icon: '🔔', color: kAccent,
              label: 'Notifications', sub: 'Push, email, SMS',
              toggle: true,
              toggleValue: _notificationsEnabled,
              onToggle: (v) => setState(() => _notificationsEnabled = v),
              isLast: false,
            ),
            _SettingRow(icon: '🛡', color: kSecondary, label: 'Confidentialité', sub: 'Localisation, profil', isLast: false),
            _SettingRow(icon: '🚫', color: kError, label: 'Utilisateurs bloqués', sub: '0 personne', isLast: false),
            _SettingRow(icon: '🌙', color: kInfo, label: 'Apparence', sub: 'Light · Auto · Dark', isLast: false),
            _SettingRow(icon: '💳', color: kSuccess, label: 'Méthodes de paiement', sub: 'Bientôt', disabled: true, isLast: false),
            _SettingRow(icon: '❓', color: kTertiary, label: 'Aide & support', sub: '', isLast: true),
          ]),
        ),
      ]),
    );
  }

  // ── Logout ──────────────────────────────────────────────────────────────────
  Widget _buildLogout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 14, Sp.md, 0),
      child: Semantics(
        button: true,
        label: 'Se déconnecter',
        child: GestureDetector(
          onTap: () => _confirmLogout(context),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: context.tpCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.tpHair),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.logout, color: kError, size: 18),
              SizedBox(width: 8),
              Text('Se déconnecter',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kError)),
            ]),
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.tpCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Se déconnecter ?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: context.tpInk)),
        content: Text('Tu devras te reconnecter pour accéder à ton compte.',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.tpInkSub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.tpInkSub)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authNotifierProvider.notifier).logout();
            },
            child: const Text('Déconnecter',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kError)),
          ),
        ],
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _ProfileGlassBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ProfileGlassBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      );
}

class _StatPill extends StatelessWidget {
  final String icon, n, l;
  const _StatPill({required this.icon, required this.n, required this.l});

  @override
  Widget build(BuildContext context) => Column(children: [
        RichText(
          text: TextSpan(children: [
            TextSpan(text: icon, style: const TextStyle(fontSize: 14)),
            TextSpan(text: '  $n', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: context.tpInk, letterSpacing: -0.4)),
          ]),
        ),
        const SizedBox(height: 2),
        Text(l, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.tpInkSub)),
      ]);
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 32, color: context.tpHair);
}

class _ActionTile extends StatelessWidget {
  final String icon, label, count;
  final Color color;
  final bool active;
  const _ActionTile({required this.icon, required this.label, required this.count, required this.color, required this.active});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
        decoration: BoxDecoration(
          color: active ? color : context.tpCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: active
              ? [BoxShadow(color: color.withValues(alpha: 0.32), blurRadius: 14, offset: const Offset(0, 6))]
              : const [BoxShadow(color: Color(0x0D1B1A2E), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(count, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: active ? Colors.white : context.tpInk, letterSpacing: -0.4)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: active ? Colors.white.withValues(alpha: 0.85) : context.tpInkSub)),
        ]),
      );
}

class _SettingRow extends StatelessWidget {
  final String icon, label, sub;
  final Color color;
  final bool toggle, disabled, isLast;
  final bool? toggleValue;
  final void Function(bool)? onToggle;

  const _SettingRow({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.isLast,
    this.toggle = false,
    this.toggleValue,
    this.onToggle,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: disabled ? 0.5 : 1,
        child: Semantics(
          button: !toggle,
          toggled: toggle ? toggleValue : null,
          label: label,
          enabled: !disabled,
          child: GestureDetector(
            onTap: disabled ? null : (toggle ? () => onToggle?.call(!(toggleValue ?? false)) : () {}),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                  border: isLast ? null : Border(bottom: BorderSide(color: context.tpHair))),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
                  alignment: Alignment.center,
                  child: Text(icon, style: const TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.tpInk)),
                  if (sub.isNotEmpty) Text(sub, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.tpInkSub)),
                ])),
                if (toggle)
                  GestureDetector(
                    onTap: disabled ? null : () => onToggle?.call(!(toggleValue ?? false)),
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
                  )
                else
                  Icon(Icons.chevron_right, color: context.tpInkMute, size: 20),
              ]),
            ),
          ),
        ),
      );
}

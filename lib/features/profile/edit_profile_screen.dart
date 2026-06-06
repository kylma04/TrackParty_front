import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/models/user_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/cloudinary_service.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_avatar.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _quartierCtrl;

  bool _loading       = false;
  bool _avatarLoading = false;

  @override
  void initState() {
    super.initState();
    final user = _currentUser;
    _nameCtrl     = TextEditingController(text: user?.displayName ?? '');
    _phoneCtrl    = TextEditingController(text: user?.phone ?? '');
    _bioCtrl      = TextEditingController(text: user?.bio ?? '');
    _cityCtrl     = TextEditingController(text: user?.city ?? '');
    _quartierCtrl = TextEditingController(text: user?.quartier ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _bioCtrl.dispose();
    _cityCtrl.dispose();
    _quartierCtrl.dispose();
    super.dispose();
  }

  UserModel? get _currentUser {
    final auth = ref.read(authNotifierProvider).valueOrNull;
    return auth is AuthAuthenticated ? auth.user : null;
  }

  Future<void> _pickAvatar() async {
    if (_avatarLoading) return;
    setState(() => _avatarLoading = true);
    try {
      final url = await ref.read(cloudinaryServiceProvider).pickAndUpload(folder: 'avatars');
      if (url != null && mounted) {
        await ref.read(authNotifierProvider.notifier).updateProfile({'avatar_cloud_url': url});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur photo : ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _avatarLoading = false);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      await ref.read(authNotifierProvider.notifier).updateProfile({
        'display_name': _nameCtrl.text.trim(),
        'phone':        _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'bio':          _bioCtrl.text.trim(),
        'city':         _cityCtrl.text.trim(),
        'quartier':     _quartierCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil mis à jour !')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final me = user is AuthAuthenticated ? user.user : null;

    return Scaffold(
      backgroundColor: context.tpBg,
      body: Column(
        children: [
          _buildNavBar(context),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  Sp.md, Sp.md, Sp.md, MediaQuery.of(context).padding.bottom + 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAvatarSection(context, me),
                    const SizedBox(height: 24),
                    _buildSection(context, 'INFORMATIONS', [
                      _field(context, controller: _nameCtrl, label: 'Nom affiché',
                          icon: PhosphorIcons.user(),
                          validator: (v) => (v?.trim().isEmpty ?? true) ? 'Requis' : null),
                      _field(context, controller: _phoneCtrl, label: 'Téléphone (optionnel)',
                          icon: PhosphorIcons.phone(),
                          keyboardType: TextInputType.phone),
                      _field(context, controller: _bioCtrl, label: 'Bio',
                          icon: PhosphorIcons.textAlignLeft(),
                          maxLines: 3),
                    ]),
                    const SizedBox(height: 16),
                    _buildSection(context, 'LOCALISATION', [
                      _field(context, controller: _cityCtrl, label: 'Ville',
                          icon: PhosphorIcons.city()),
                      _field(context, controller: _quartierCtrl, label: 'Quartier',
                          icon: PhosphorIcons.mapPin()),
                    ]),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavBar(BuildContext context) {
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
            const SizedBox(width: 8),
            Text('Modifier le profil',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900,
                  color: context.tpInk, letterSpacing: -0.3)),
            const Spacer(),
            if (_loading)
              const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2))
            else
              Semantics(
                button: true, label: 'Sauvegarder le profil',
                child: GestureDetector(
                onTap: _save,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                      gradient: trackpartyGradient, borderRadius: BorderRadius.circular(Radii.tag)),
                  child: const Text('Sauvegarder',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarSection(BuildContext context, UserModel? me) {
    return Center(
      child: Semantics(
        button: true,
        label: 'Changer la photo de profil',
        child: GestureDetector(
          onTap: _avatarLoading ? null : _pickAvatar,
          child: Stack(
            children: [
              TpAvatar(name: me?.displayName ?? '?', imageUrl: me?.avatarUrl, size: 80),
              if (_avatarLoading)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.35),
                    ),
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    ),
                  ),
                ),
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                      gradient: trackpartyGradient,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.tpBg, width: 2)),
                  child: Icon(PhosphorIcons.camera(), color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> fields) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900,
              color: context.tpInkSub, letterSpacing: 0.5)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
              color: context.tpCard, borderRadius: BorderRadius.circular(Radii.lg)),
          child: Column(children: fields),
        ),
      ],
    );
  }

  Widget _field(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.tpInk),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 13, color: context.tpInkSub),
          prefixIcon: Icon(icon, color: context.tpInkMute, size: 18),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

}

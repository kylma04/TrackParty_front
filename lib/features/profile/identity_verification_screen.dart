import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/cloudinary_service.dart';

class IdentityVerificationScreen extends ConsumerStatefulWidget {
  const IdentityVerificationScreen({super.key});

  @override
  ConsumerState<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends ConsumerState<IdentityVerificationScreen> {
  String _documentType = 'cni';
  String? _frontUrl;
  String? _backUrl;
  String? _selfieUrl;
  bool _loading = false;

  Future<void> _pickFront() async {
    final url = await ref.read(cloudinaryServiceProvider).pickAndUpload(
          source: ImageSource.camera,
          folder: 'identity_verifications',
        );
    if (url != null && mounted) setState(() => _frontUrl = url);
  }

  Future<void> _pickBack() async {
    final url = await ref.read(cloudinaryServiceProvider).pickAndUpload(
          source: ImageSource.camera,
          folder: 'identity_verifications',
        );
    if (url != null && mounted) setState(() => _backUrl = url);
  }

  Future<void> _pickSelfie() async {
    final url = await ref.read(cloudinaryServiceProvider).pickAndUpload(
          source: ImageSource.camera,
          folder: 'identity_verifications',
        );
    if (url != null && mounted) setState(() => _selfieUrl = url);
  }

  Future<void> _submit() async {
    if (_frontUrl == null || _selfieUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ajoute au moins le recto de la pièce et un selfie.'),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await ref.read(authServiceProvider).submitIdentityVerification(
            documentType: _documentType,
            frontImageUrl: _frontUrl!,
            backImageUrl: _backUrl,
            selfieImageUrl: _selfieUrl!,
          );

      await ref.read(authNotifierProvider.notifier).refreshUser();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vérification envoyée.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider).valueOrNull;
    final user = auth is AuthAuthenticated ? auth.user : null;
    final status = user?.identityVerificationStatus;

    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _statusText(status),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            initialValue: _documentType,
            decoration: const InputDecoration(
              labelText: 'Type de document',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'cni', child: Text('Carte d’identité')),
              DropdownMenuItem(value: 'passport', child: Text('Passeport')),
              DropdownMenuItem(
                value: 'driver_license',
                child: Text('Permis de conduire'),
              ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _documentType = v);
            },
          ),

          const SizedBox(height: 16),
          _DocButton(
            label: 'Photo recto',
            done: _frontUrl != null,
            onPressed: _loading ? null : _pickFront,
          ),
          const SizedBox(height: 10),
          _DocButton(
            label: 'Photo verso',
            done: _backUrl != null,
            onPressed: _loading ? null : _pickBack,
          ),
          const SizedBox(height: 10),
          _DocButton(
            label: 'Selfie',
            done: _selfieUrl != null,
            onPressed: _loading ? null : _pickSelfie,
          ),

          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: Text(_loading ? 'Envoi...' : 'Soumettre la vérification'),
          ),
        ],
      ),
    );
  }

  String _statusText(String? status) {
    switch (status) {
      case 'pending':
        return 'Statut : en attente de validation';
      case 'approved':
        return 'Statut : identité vérifiée';
      case 'rejected':
        return 'Statut : vérification refusée';
      case 'manual_review':
        return 'Statut : vérification manuelle requise';
      default:
        return 'Statut : aucune vérification soumise';
    }
  }
}

class _DocButton extends StatelessWidget {
  final String label;
  final bool done;
  final VoidCallback? onPressed;

  const _DocButton({
    required this.label,
    required this.done,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(done ? Icons.check_circle : Icons.camera_alt_outlined),
      label: Text(done ? '$label ajoutée' : label),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/models/content_model.dart';
import '../../core/services/content_service.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/markdown_lite.dart';

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doc = ref.watch(legalDocumentProvider('privacy'));

    return Scaffold(
      backgroundColor: context.tpBg,
      appBar: AppBar(
        backgroundColor: context.tpCard,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(PhosphorIcons.caretLeft(), color: context.tpInk, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text('Confidentialité',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w900, color: context.tpInk)),
        centerTitle: true,
      ),
      body: doc.when(
        loading: () => const Center(child: CircularProgressIndicator(color: kPrimary)),
        error: (_, _) => _ErrorView(onRetry: () => ref.invalidate(legalDocumentProvider('privacy'))),
        data: (d) => _DocumentBody(doc: d),
      ),
    );
  }
}

class _DocumentBody extends StatelessWidget {
  final LegalDocument doc;
  const _DocumentBody({required this.doc});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Sp.md, 24, Sp.md, 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: kSuccess.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(Radii.lg),
            ),
            child: Icon(PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill),
                color: kSuccess, size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            doc.title,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
              color: context.tpInk,
              height: 1.15,
            ),
          ),
          if (doc.updatedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Mis à jour le ${_fmtDate(doc.updatedAt!)}',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: context.tpInkMute),
            ),
          ],
          const SizedBox(height: 24),
          MarkdownLite(doc.body),
        ],
      ),
    );
  }
}

const _months = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

String _fmtDate(DateTime d) {
  final local = d.toLocal();
  return '${local.day} ${_months[local.month - 1]} ${local.year}';
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Sp.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorIcons.cloudSlash(), color: context.tpInkMute, size: 48),
              const SizedBox(height: 16),
              Text('Impossible de charger le document.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.tpInkSub)),
              const SizedBox(height: 16),
              TextButton(
                onPressed: onRetry,
                child: const Text('Réessayer',
                    style: TextStyle(
                        color: kPrimary, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      );
}

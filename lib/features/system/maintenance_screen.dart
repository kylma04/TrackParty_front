import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/api/api_client.dart';
import '../../core/providers/maintenance_provider.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_button.dart';

/// Écran affiché pendant une fenêtre de maintenance globale.
/// L'utilisateur y est confiné tant que le backend signale `maintenance:true`.
class MaintenanceScreen extends ConsumerStatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  ConsumerState<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen> {
  bool _checking = false;

  /// Re-interroge `/api/status/` (endpoint exempté). Si la maintenance est
  /// levée, on vide le provider → le router renvoie vers l'accueil.
  Future<void> _retry() async {
    setState(() => _checking = true);
    try {
      final dio = ref.read(dioProvider);
      final resp = await dio.get('status/');
      final data = resp.data as Map<String, dynamic>?;
      final active = data?['maintenance'] == true;
      if (!active) {
        ref.read(maintenanceProvider.notifier).state = null;
      } else {
        final endRaw = data?['estimated_end'] as String?;
        ref.read(maintenanceProvider.notifier).state = MaintenanceInfo(
          message: (data?['message'] as String?) ??
              'TrackParty est en maintenance.',
          estimatedEnd: endRaw != null ? DateTime.tryParse(endRaw) : null,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Toujours en maintenance, encore un instant…')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service indisponible, réessaie dans un instant.')),
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = ref.watch(maintenanceProvider);
    final message = info?.message ??
        'TrackParty est en maintenance. Nous revenons très vite — '
            'merci de patienter quelques instants.';
    final end = info?.estimatedEnd;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: context.tpBg,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Sp.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    decoration: const BoxDecoration(
                      gradient: trackpartyGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x554F46E5),
                          blurRadius: 32,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Icon(
                      PhosphorIcons.wrench(PhosphorIconsStyle.fill),
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                  const SizedBox(height: Sp.xl),
                  Text(
                    'Maintenance en cours',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: context.tpInk,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                      color: context.tpInkSub,
                    ),
                  ),
                  if (end != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: context.tpCardAlt,
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(PhosphorIcons.clock(), size: 16, color: kPrimary),
                          const SizedBox(width: 8),
                          Text(
                            'Retour estimé : ${_formatEnd(end)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: context.tpInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: Sp.xl),
                  TpButton(
                    label: 'Réessayer',
                    icon: PhosphorIcons.arrowClockwise(),
                    fullWidth: true,
                    state: _checking
                        ? TpButtonState.loading
                        : TpButtonState.idle,
                    onPressed: _retry,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatEnd(DateTime end) {
    final local = end.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$d/$m à ${h}h$min';
  }
}

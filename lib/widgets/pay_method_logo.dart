import 'package:flutter/material.dart';

import '../core/services/payment_service.dart';

/// Logo officiel d'un moyen de paiement GeniusPay
/// (`assets/icons/payments/[methode].png`). Tant que le fichier n'est pas
/// fourni, on retombe sur l'emoji du moyen de paiement (aucun crash).
class PayMethodLogo extends StatelessWidget {
  final PayMethod method;
  final double size;
  const PayMethodLogo({super.key, required this.method, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        method.logoAsset,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Center(
          child: Text(method.emoji, style: TextStyle(fontSize: size * 0.72)),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/services/payment_service.dart';

/// Logo officiel d'un moyen de paiement Jeko (`assets/icons/payments/`).
/// Tant qu'un visuel n'est pas fourni pour une méthode donnée
/// ([PayMethodX.logoAsset] vaut `null`), on retombe sur l'emoji (aucun
/// crash).
class PayMethodLogo extends StatelessWidget {
  final PayMethod method;
  final double size;
  const PayMethodLogo({super.key, required this.method, this.size = 28});

  @override
  Widget build(BuildContext context) {
    final asset = method.logoAsset;
    if (asset == null) {
      return SizedBox(width: size, height: size, child: _emojiFallback());
    }

    final logo = asset.endsWith('.svg')
        ? SvgPicture.asset(
            asset,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _emojiFallback(),
          )
        : Image.asset(
            asset,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _emojiFallback(),
          );

    if (!method.logoNeedsLightBackdrop) {
      return SizedBox(width: size, height: size, child: logo);
    }

    // Logo noir (ex. Djamo) : fond clair fixe pour rester lisible même sur
    // les surfaces sombres du thème par défaut de l'app.
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: logo,
    );
  }

  Widget _emojiFallback() => Center(
        child: Text(method.emoji, style: TextStyle(fontSize: size * 0.72)),
      );
}

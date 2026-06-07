import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/colors.dart';

enum TpToastType { success, error, warning, info }

abstract final class TpToast {
  static void show(
    BuildContext context,
    String message, {
    TpToastType type = TpToastType.info,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: _ToastContent(message: message, type: type),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
          16, 0, 16,
          16 + MediaQuery.of(context).padding.bottom,
        ),
        duration: Duration(seconds: type == TpToastType.error ? 4 : 3),
        padding: EdgeInsets.zero,
      ));
  }

  static void success(BuildContext context, String message) =>
      show(context, message, type: TpToastType.success);

  static void error(BuildContext context, String message) =>
      show(context, message, type: TpToastType.error);

  static void warning(BuildContext context, String message) =>
      show(context, message, type: TpToastType.warning);

  static void info(BuildContext context, String message) =>
      show(context, message, type: TpToastType.info);
}

class _ToastContent extends StatelessWidget {
  final String message;
  final TpToastType type;

  const _ToastContent({required this.message, required this.type});

  (Color, IconData) get _style => switch (type) {
        TpToastType.success => (kSuccess, PhosphorIcons.checkCircle()),
        TpToastType.error   => (kError,   PhosphorIcons.xCircle()),
        TpToastType.warning => (kWarning, PhosphorIcons.warning()),
        TpToastType.info    => (kPrimary, PhosphorIcons.info()),
      };

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _style;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1F35),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x40000000), blurRadius: 20, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

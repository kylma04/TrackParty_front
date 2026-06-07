import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/gradients.dart';
import '../theme/haptics.dart';
import '../theme/shadows.dart';
import '../theme/spacing.dart';
import '../theme/theme_ext.dart';

enum TpButtonVariant { gradient, outline, ghost, danger, coral }

enum TpButtonSize { sm, md, lg }

enum TpButtonState { idle, loading, disabled }

class TpButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final TpButtonVariant variant;
  final TpButtonSize size;
  final TpButtonState state;
  final VoidCallback? onPressed;
  final bool fullWidth;

  const TpButton({
    super.key,
    required this.label,
    this.icon,
    this.variant = TpButtonVariant.gradient,
    this.size = TpButtonSize.lg,
    this.state = TpButtonState.idle,
    this.onPressed,
    this.fullWidth = false,
  });

  @override
  State<TpButton> createState() => _TpButtonState();
}

class _TpButtonState extends State<TpButton> {
  bool _pressed = false;

  double get _height => switch (widget.size) {
        TpButtonSize.sm => 40,
        TpButtonSize.md => 48,
        TpButtonSize.lg => 56,
      };

  double get _fontSize => switch (widget.size) {
        TpButtonSize.sm => 13,
        TpButtonSize.md => 15,
        TpButtonSize.lg => 16,
      };

  bool get _isDisabled => widget.state == TpButtonState.disabled;
  bool get _isLoading => widget.state == TpButtonState.loading;

  Decoration _decoration(BuildContext context) {
    if (_isDisabled) {
      return BoxDecoration(
        color: context.tpHair,
        borderRadius: BorderRadius.circular(Radii.button),
      );
    }
    return switch (widget.variant) {
      TpButtonVariant.gradient => BoxDecoration(
          gradient: trackpartyGradient,
          borderRadius: BorderRadius.circular(Radii.button),
          boxShadow: _pressed ? [] : Shadows.brand,
        ),
      TpButtonVariant.coral => BoxDecoration(
          gradient: coralGradient,
          borderRadius: BorderRadius.circular(Radii.button),
          boxShadow: _pressed ? [] : Shadows.coral,
        ),
      TpButtonVariant.outline => BoxDecoration(
          border: Border.all(color: kPrimary, width: 1.5),
          borderRadius: BorderRadius.circular(Radii.button),
        ),
      TpButtonVariant.ghost => const BoxDecoration(),
      TpButtonVariant.danger => BoxDecoration(
          color: kError,
          borderRadius: BorderRadius.circular(Radii.button),
        ),
    };
  }

  Color _textColor(BuildContext context) {
    if (_isDisabled) return context.tpInkMute;
    return switch (widget.variant) {
      TpButtonVariant.gradient || TpButtonVariant.coral || TpButtonVariant.danger => Colors.white,
      TpButtonVariant.outline || TpButtonVariant.ghost => kPrimary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final textColor = _textColor(context);
    return Semantics(
      button: true,
      label: widget.label,
      enabled: !_isDisabled,
      child: GestureDetector(
      onTapDown: _isDisabled || _isLoading
          ? null
          : (_) {
              setState(() => _pressed = true);
              switch (widget.variant) {
                case TpButtonVariant.gradient:
                case TpButtonVariant.coral:
                  Haptics.medium();
                case TpButtonVariant.danger:
                  Haptics.heavy();
                default:
                  Haptics.light();
              }
            },
      onTapUp: _isDisabled || _isLoading
          ? null
          : (_) {
              setState(() => _pressed = false);
              widget.onPressed?.call();
            },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: _height,
          width: widget.fullWidth ? double.infinity : null,
          padding: EdgeInsets.symmetric(horizontal: widget.size == TpButtonSize.sm ? 16 : 24),
          decoration: _decoration(context),
          alignment: Alignment.center,
          child: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: textColor,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: textColor, size: _fontSize + 2),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.label,
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        fontSize: _fontSize,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
        ),
      ),
      ),
    );
  }
}

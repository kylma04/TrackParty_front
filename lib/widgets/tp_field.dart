import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';

class TpField extends StatefulWidget {
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final int maxLines;
  final int? maxLength;
  final void Function(String)? onChanged;
  final String? errorText;

  const TpField({
    super.key,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.controller,
    this.validator,
    this.maxLines = 1,
    this.maxLength,
    this.onChanged,
    this.errorText,
  });

  @override
  State<TpField> createState() => _TpFieldState();
}

class _TpFieldState extends State<TpField> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: isDark ? kInkSubDark : kInkSubLight,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        Semantics(
          label: widget.label,
          textField: true,
          child: TextFormField(
          focusNode: _focus,
          controller: widget.controller,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          maxLines: widget.obscureText ? 1 : widget.maxLines,
          maxLength: widget.maxLength,
          validator: widget.validator,
          onChanged: widget.onChanged,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDark ? kInkDark : kInkLight,
          ),
          decoration: InputDecoration(
            errorText: widget.errorText,
            hintText: widget.hint,
            hintStyle: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? kInkMuteDark : kInkMuteLight,
            ),
            prefixIcon: widget.prefixIcon != null
                ? Icon(widget.prefixIcon, color: _focused ? kPrimary : (isDark ? kInkMuteDark : kInkMuteLight), size: 20)
                : null,
            suffixIcon: widget.suffixIcon,
            filled: true,
            fillColor: isDark ? kCardDark : kCardLight,
            contentPadding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.button),
              borderSide: BorderSide(color: isDark ? kHairDark : kHairLight, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.button),
              borderSide: BorderSide(color: isDark ? kHairDark : kHairLight, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.button),
              borderSide: const BorderSide(color: kPrimary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.button),
              borderSide: const BorderSide(color: kError, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.button),
              borderSide: const BorderSide(color: kError, width: 1.5),
            ),
            errorStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: kError,
            ),
          ),
        ),
        ),
      ],
    );
  }
}

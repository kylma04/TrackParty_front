import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/colors.dart';
import '../theme/theme_ext.dart';

class TpAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double size;
  final Color? ringColor;
  final bool showOnline;

  const TpAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 40,
    this.ringColor,
    this.showOnline = false,
  });

  static const _gradients = [
    [kPrimary, kTertiary],
    [kAccent, kTertiary],
    [kInfo, kSecondary],
    [kCategoryArt, kInfo],
    [kWarning, kAccent],
    [kSecondary, kInfo],
    [kTertiary, kWarning],
  ];

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  List<Color> get _colors => _gradients[name.hashCode.abs() % _gradients.length];

  @override
  Widget build(BuildContext context) {
    final effectiveRingColor = ringColor ?? kPrimary;
    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: effectiveRingColor.withValues(alpha: 0.35), blurRadius: 0, spreadRadius: 2.5),
              BoxShadow(color: context.tpBg, blurRadius: 0, spreadRadius: 4.5),
            ],
          ),
          child: ClipOval(
            child: imageUrl != null && imageUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, _) => _gradientFallback(),
                    errorWidget: (context, url, error) => _gradientFallback(),
                  )
                : _gradientFallback(),
          ),
        ),
        if (showOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.27,
              height: size * 0.27,
              decoration: BoxDecoration(
                color: kSuccess,
                shape: BoxShape.circle,
                border: Border.all(color: context.tpBg, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }

  Widget _gradientFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

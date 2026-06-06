import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/colors.dart';

class TpPhoto extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxFit fit;

  const TpPhoto({
    super.key,
    this.url,
    this.width,
    this.height,
    this.borderRadius,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: kPrimary,
        borderRadius: borderRadius,
      ),
    );

    if (url == null || url!.isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: CachedNetworkImage(
        imageUrl: url!,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, _) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Shimmer.fromColors(
            baseColor: isDark ? const Color(0xFF1A1633) : kHairLight,
            highlightColor: isDark ? const Color(0xFF241E40) : kBgLight,
            child: Container(
              width: width,
              height: height,
              color: isDark ? const Color(0xFF1A1633) : Colors.white,
            ),
          );
        },
        errorWidget: (context, url, error) => placeholder,
      ),
    );
  }
}

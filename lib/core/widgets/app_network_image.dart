import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// A remote image that is cached on the device, with a placeholder while it
/// loads or if it is missing or fails.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    required this.url,
    this.displayWidth,
    this.semanticLabel,
    super.key,
  });

  /// Lets tests show images without network or device storage.
  @visibleForTesting
  static Widget Function(String url)? debugBuilder;

  final String? url;

  /// Decodes a smaller copy for thumbnails, which saves a lot of memory.
  final double? displayWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    if (url == null) {
      return const _Placeholder(icon: Icons.image_outlined);
    }
    final debug = debugBuilder;
    if (debug != null) return debug(url);
    final displayWidth = this.displayWidth;
    return Semantics(
      image: true,
      label: semanticLabel,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        memCacheWidth: displayWidth == null
            ? null
            : (displayWidth * MediaQuery.devicePixelRatioOf(context)).round(),
        fadeInDuration: const Duration(milliseconds: 150),
        placeholder: (context, url) =>
            const _Placeholder(icon: Icons.image_outlined),
        errorWidget: (context, url, error) =>
            const _Placeholder(icon: Icons.broken_image_outlined),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.primarySoft,
      child: Center(child: Icon(icon, color: AppColors.primary, size: 32)),
    );
  }
}

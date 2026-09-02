import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:spicy/core/theme/app_theme.dart';

/// The shared network-image boundary for the app.
///
/// On mobile, [CachedNetworkImage] keeps downloaded files in the device cache.
/// On web, the browser's HTTP cache is used. Supplying cache dimensions also
/// avoids decoding menu photography at a much larger size than the UI needs.
class AppNetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? cacheWidth;
  final int? cacheHeight;
  final Alignment alignment;
  final String? semanticLabel;

  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.cacheWidth,
    this.cacheHeight,
    this.alignment = Alignment.center,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.trim().isEmpty) {
      return _ImageFallback(width: width, height: height);
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      memCacheWidth: cacheWidth,
      memCacheHeight: cacheHeight,
      maxWidthDiskCache: cacheWidth,
      maxHeightDiskCache: cacheHeight,
      fadeInDuration: const Duration(milliseconds: 180),
      fadeOutDuration: const Duration(milliseconds: 100),
      placeholder: (_, _) => _ImagePlaceholder(width: width, height: height),
      errorWidget: (_, _, _) => _ImageFallback(width: width, height: height),
      imageBuilder: semanticLabel == null
          ? null
          : (context, provider) => Semantics(
              image: true,
              label: semanticLabel,
              child: Image(
                image: provider,
                width: width,
                height: height,
                fit: fit,
                alignment: alignment,
                excludeFromSemantics: true,
              ),
            ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final double? width;
  final double? height;

  const _ImagePlaceholder({this.width, this.height});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.surfaceDim,
      child: SizedBox(
        width: width,
        height: height,
        child: Center(
          child: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primary.withValues(alpha: 0.65),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  final double? width;
  final double? height;

  const _ImageFallback({this.width, this.height});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.surfaceDim,
      child: SizedBox(
        width: width,
        height: height,
        child: Center(
          child: Icon(
            Icons.restaurant_outlined,
            size: 40,
            color: AppTheme.outline,
          ),
        ),
      ),
    );
  }
}

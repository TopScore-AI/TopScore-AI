import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';
import 'shimmer_loading.dart';
import '../utils/image_cache_manager.dart';

/// Optimized network image widget with:
/// - Memory-efficient caching (resizes in memory)
/// - Shimmer loading placeholder
/// - Smooth fade-in animation
/// - Error handling with fallback
class OptimizedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? errorWidget;
  final bool showShimmer;

  const OptimizedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.errorWidget,
    this.showShimmer = true,
  });

  /// Checks if the URL is from an external domain that might have CORS issues
  bool _isExternalUrl(String url) {
    if (!url.startsWith('http')) return false;
    
    final safeDomains = [
      'localhost',
      '127.0.0.1',
      'firebasestorage.googleapis.com',
      'storage.googleapis.com',
    ];
    
    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();
      
      for (final domain in safeDomains) {
        if (host.contains(domain)) {
          return false;
        }
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Converts external URL to use a CORS proxy on web
  String _getCorsProxyUrl(String url) {
    if (!kIsWeb || !_isExternalUrl(url)) {
      return url;
    }
    
    // Use allOrigins proxy for external images on web
    return 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}';
  }

  @override
  Widget build(BuildContext context) {
    final proxiedUrl = _getCorsProxyUrl(imageUrl);
    
    Widget image = CachedNetworkImage(
      imageUrl: proxiedUrl,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 200),
      
      // Use cache manager
      cacheManager: AppImageCacheManager(),
      
      // Resize in memory to reduce RAM usage
      memCacheWidth: width != null ? (width! * 2).toInt() : 600,
      memCacheHeight: height != null ? (height! * 2).toInt() : null,
      
      // Add headers to help with CORS
      httpHeaders: const {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      },
      
      placeholder: (context, url) => showShimmer
          ? ShimmerLoading(
              width: width ?? double.infinity,
              height: height ?? 100,
              borderRadius: borderRadius?.topLeft.x ?? 8,
            )
          : Container(
              width: width,
              height: height,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[800]
                  : Colors.grey[200],
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
      errorWidget: (context, url, error) =>
          errorWidget ??
          Container(
            width: width,
            height: height,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[800]
                : Colors.grey[200],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.broken_image_outlined,
                  color: Colors.grey[400],
                  size: 32,
                ),
                if (kIsWeb && _isExternalUrl(imageUrl)) ...[
                  const SizedBox(height: 4),
                  Text(
                    'CORS blocked',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }
}

/// Avatar image optimized for profile pictures
class OptimizedAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final String? fallbackText;
  final Color? backgroundColor;

  const OptimizedAvatar({
    super.key,
    this.imageUrl,
    this.radius = 24,
    this.fallbackText,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor:
            backgroundColor ?? Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          (fallbackText?.isNotEmpty == true ? fallbackText![0] : '?')
              .toUpperCase(),
          style: TextStyle(
            fontSize: radius * 0.8,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl!,
      imageBuilder: (context, imageProvider) => CircleAvatar(
        radius: radius,
        backgroundImage: imageProvider,
        backgroundColor: backgroundColor,
      ),
      placeholder: (context, url) => CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[300],
        child: const CircularProgressIndicator(strokeWidth: 2),
      ),
      errorWidget: (context, url, error) => CircleAvatar(
        radius: radius,
        backgroundColor:
            backgroundColor ?? Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          (fallbackText?.isNotEmpty == true ? fallbackText![0] : '?')
              .toUpperCase(),
          style: TextStyle(
            fontSize: radius * 0.8,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ),
      memCacheWidth: (radius * 4).toInt(),
      memCacheHeight: (radius * 4).toInt(),
    );
  }
}

/// Thumbnail image for list items, cards, etc.
class OptimizedThumbnail extends StatelessWidget {
  final String imageUrl;
  final double size;
  final double borderRadius;
  final IconData? placeholderIcon;

  const OptimizedThumbnail({
    super.key,
    required this.imageUrl,
    this.size = 56,
    this.borderRadius = 8,
    this.placeholderIcon,
  });

  @override
  Widget build(BuildContext context) {
    return OptimizedImage(
      imageUrl: imageUrl,
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(borderRadius),
      errorWidget: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[800]
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Icon(
          placeholderIcon ?? Icons.image_outlined,
          color: Colors.grey[400],
          size: size * 0.5,
        ),
      ),
    );
  }
}

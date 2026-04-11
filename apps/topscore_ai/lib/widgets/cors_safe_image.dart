import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/image_cache_manager.dart';
import 'shimmer_loading.dart';

/// A CORS-safe image widget that handles external images properly on web
/// by using a proxy service when needed.
class CorsSafeImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? errorWidget;
  final Widget? placeholder;
  final bool showShimmer;

  const CorsSafeImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.errorWidget,
    this.placeholder,
    this.showShimmer = true,
  });

  /// Checks if the URL is from an external domain that might have CORS issues
  bool _isExternalUrl(String url) {
    if (!url.startsWith('http')) return false;
    
    // List of known safe domains (your own domains)
    final safeDomains = [
      'localhost',
      '127.0.0.1',
      'firebasestorage.googleapis.com',
      'storage.googleapis.com',
      // Add your backend domain here
    ];
    
    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();
      
      // Check if it's a safe domain
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
    
    // Use a CORS proxy service for external images on web
    // Option 1: Use allOrigins proxy (free, no API key needed)
    return 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}';
    
    // Option 2: Use cors-anywhere (requires your own deployment)
    // return 'https://cors-anywhere.herokuapp.com/$url';
    
    // Option 3: Use your own backend proxy endpoint
    // return 'https://your-backend.com/api/proxy?url=${Uri.encodeComponent(url)}';
  }

  Widget _buildPlaceholder(BuildContext context) {
    if (placeholder != null) return placeholder!;
    
    if (showShimmer) {
      return ShimmerLoading(
        width: width ?? double.infinity,
        height: height ?? 100,
        borderRadius: borderRadius?.topLeft.x ?? 8,
      );
    }
    
    return Container(
      width: width,
      height: height,
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[800]
          : Colors.grey[200],
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context) {
    if (errorWidget != null) return errorWidget!;
    
    return Container(
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
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Image blocked by CORS',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
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
      
      // Use appropriate cache manager
      cacheManager: AppImageCacheManager(),
      
      // Resize in memory to reduce RAM usage
      memCacheWidth: width != null ? (width! * 2).toInt() : 600,
      memCacheHeight: height != null ? (height! * 2).toInt() : null,
      
      placeholder: (context, url) => _buildPlaceholder(context),
      errorWidget: (context, url, error) => _buildErrorWidget(context),
      
      // Add headers to help with CORS (though proxy should handle it)
      httpHeaders: const {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      },
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

/// Extension to easily replace Image.network with CORS-safe version
extension CorsSafeImageExtension on Image {
  static Widget network(
    String url, {
    double? width,
    double? height,
    BoxFit? fit,
    Widget? errorBuilder,
    Widget? loadingBuilder,
  }) {
    return CorsSafeImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit ?? BoxFit.cover,
      errorWidget: errorBuilder,
      placeholder: loadingBuilder,
    );
  }
}

// Made with Bob

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/image_cache_manager.dart';

class NetworkAwareImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool isProfilePicture;

  const NetworkAwareImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.placeholder,
    this.errorWidget,
    this.isProfilePicture = false,
  });

  /// Checks if the URL is from an external domain that might have CORS issues
  bool _isExternalUrl(String url) {
    if (!url.startsWith('http')) return false;
    
    final safeDomains = [
      'localhost',
      '127.0.0.1',
      'firebasestorage.googleapis.com',
      'storage.googleapis.com',
      'googleusercontent.com', // For Google profile pictures
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
    // 1. Validation: Check for null, empty, or invalid URLs
    if (imageUrl == null ||
        imageUrl!.isEmpty ||
        imageUrl!.contains('profile/picture/0')) {
      // Filter out the bad URL
      return _buildErrorWidget(context);
    }

    final proxiedUrl = _getCorsProxyUrl(imageUrl!);

    return CachedNetworkImage(
      imageUrl: proxiedUrl,
      width: width,
      height: height,
      fit: fit ?? BoxFit.cover,

      // Use custom cache manager for profile pictures to prevent 429 errors
      cacheManager: isProfilePicture
          ? ProfileImageCacheManager()
          : AppImageCacheManager(),

      // Smooth Fade-In Animation
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 100),

      // 2. Optimization: Resize image in memory to save RAM
      memCacheWidth: width != null ? (width! * 2).toInt() : null,

      // Aggressive caching to prevent 429 errors
      maxWidthDiskCache: width != null ? (width! * 3).toInt() : 1000,
      maxHeightDiskCache: height != null ? (height! * 3).toInt() : 1000,

      // Use cached image even if stale (for profile pictures)
      cacheKey: isProfilePicture ? imageUrl : null,

      // Add headers to help with CORS
      httpHeaders: const {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      },

      // 3. Loading State
      placeholder: (context, url) =>
          placeholder ??
          Container(
            width: width,
            height: height,
            color: Colors.grey.withValues(alpha: 0.1),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),

      // 4. Error State (429s, 404s, etc.)
      errorWidget: (context, url, error) => _buildErrorWidget(context),
    );
  }

  Widget _buildErrorWidget(BuildContext context) {
    return errorWidget ??
        Container(
          width: width,
          height: height,
          color: Colors.grey.withValues(alpha: 0.2),
          child: Icon(
            isProfilePicture ? Icons.person : Icons.broken_image,
            color: Colors.grey,
            size: (width != null) ? width! * 0.5 : 24,
          ),
        );
  }
}

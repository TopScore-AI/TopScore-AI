import 'package:flutter/material.dart';
import '../utils/cors_proxy_helper.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

// Import removed to fix error - we will fallback to launching URL
// import 'package:youtube_player_flutter/youtube_player_flutter.dart';


/// Extracts YouTube video information from a URL
class YouTubeVideoInfo {
  final String videoId;
  final String url;
  final String? title;

  const YouTubeVideoInfo({
    required this.videoId,
    required this.url,
    this.title,
  });

  String get thumbnailUrl =>
      'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
  String get embedUrl => 'https://www.youtube.com/embed/$videoId';
}

/// Reusable single YouTube video card for inline display
class SingleYouTubeCard extends StatelessWidget {
  final String videoId;
  final String url;
  final String? title;
  final bool isDark;

  const SingleYouTubeCard({
    super.key,
    required this.videoId,
    required this.url,
    this.title,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final videoInfo =
        YouTubeVideoInfo(videoId: videoId, url: url, title: title);

    return Container(
      width: double.infinity,
      // IMPROVEMENT: Use AspectRatio instead of fixed height for 16:9 consistency
      margin: const EdgeInsets.only(top: 12, bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail
              CachedNetworkImage(
                imageUrl: CorsProxyHelper.getCorsProxyUrl(videoInfo.thumbnailUrl),
                fit: BoxFit.cover,
                httpHeaders: CorsProxyHelper.standardHeaders,
                // IMPROVEMENT: Cache resized image to save memory
                memCacheHeight: 400,
                placeholder: (context, url) => Container(
                  color: isDark ? Colors.grey[900] : Colors.grey[200],
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: isDark ? Colors.grey[900] : Colors.grey[200],
                  child: const Icon(Icons.error_outline, color: Colors.grey),
                ),
              ),

              // Gradient Overlay (Better text readability)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.1),
                      Colors.black.withValues(alpha: 0.6),
                    ],
                  ),
                ),
              ),

              // Play Button
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.red[600],
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.play_arrow,
                      color: Colors.white, size: 36),
                ),
              ),

              // Video Title
              if (title != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      title!,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

              // YouTube Badge
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_circle_fill,
                          size: 12, color: Colors.red[400]),
                      const SizedBox(width: 4),
                      Text(
                        'YouTube',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Tap Handler
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    // Fallback to launching URL since youtube_player_flutter is not available
                    launchUrl(Uri.parse(url),
                        mode: LaunchMode.externalApplication);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


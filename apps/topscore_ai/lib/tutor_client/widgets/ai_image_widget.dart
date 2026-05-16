import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_config.dart';
import '../../utils/cors_proxy_helper.dart';
import 'chat_media_viewers.dart';
import '../../widgets/app_spinner.dart';

class AiImageWidget extends StatelessWidget {
  final String title;
  final String url;

  const AiImageWidget({
    super.key,
    required this.title,
    required this.url,
  });

  String _resolveUrl(String rawUrl) {
    var imageUrl = rawUrl;
    // Resolve relative URLs from backend
    if (!imageUrl.startsWith('http') && !imageUrl.startsWith('data:')) {
      final base = AppConfig.backendBaseUrl;
      imageUrl = base + (imageUrl.startsWith('/') ? '' : '/') + imageUrl;
    }
    return CorsProxyHelper.getCorsProxyUrl(imageUrl);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isBase64 = url.startsWith('data:');
    final sanitizedUrl = isBase64 ? url : _resolveUrl(url);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Row(
              children: [
                Icon(
                  Icons.image_search_rounded,
                  size: 18,
                  color: theme.primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color:
                          isDark ? Colors.white : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Image Container
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FullScreenImageViewer(
                    imageUrl: sanitizedUrl,
                    heroTag: 'ai_tool_img_${isBase64 ? sanitizedUrl.hashCode : sanitizedUrl}',
                    isBase64: isBase64,
                  ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.primaryColor.withValues(alpha: 0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Hero(
                  tag: 'ai_tool_img_${isBase64 ? sanitizedUrl.hashCode : sanitizedUrl}',
                  child: isBase64
                      ? Image.memory(
                          base64Decode(sanitizedUrl.split(',').last),
                          fit: BoxFit.cover,
                          height: 200,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            height: 150,
                            color: isDark ? Colors.grey[900] : Colors.grey[200],
                            child: const Center(child: Icon(Icons.broken_image)),
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: sanitizedUrl,
                          httpHeaders: CorsProxyHelper.standardHeaders,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 200,
                            width: double.infinity,
                            color: isDark ? Colors.grey[900] : Colors.grey[200],
                            child: AppSpinner.center(),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 150,
                            width: double.infinity,
                            color: isDark ? Colors.grey[900] : Colors.grey[200],
                            child: const Center(
                              child: Icon(Icons.broken_image,
                                  size: 40, color: Colors.grey),
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

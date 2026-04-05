import 'dart:io';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Cache manager for chat images (textbook photos, homework scans).
/// Enforces strict quotas to protect low-end devices and prepaid data bundles.
class ChatImageCacheManager extends CacheManager {
  static const key = 'chatImageCache';

  static final ChatImageCacheManager _instance = ChatImageCacheManager._();
  factory ChatImageCacheManager() => _instance;

  ChatImageCacheManager._()
      : super(
          Config(
            key,
            maxNrOfCacheObjects: 100,
            stalePeriod: const Duration(days: 7),
            repo: JsonCacheInfoRepository(databaseName: key),
            fileService: HttpFileService(),
          ),
        );

  /// Pre-warms the cache with a local file so the image is never re-downloaded
  /// after an upload. Call this after receiving the remote URL from the backend.
  Future<void> prewarmFromFile(String url, File file) async {
    await putFile(
      url,
      await file.readAsBytes(),
      fileExtension: url.split('.').last.split('?').first,
    );
  }
}

/// Custom cache manager for profile images with aggressive caching
/// to prevent 429 (Too Many Requests) errors from Google's servers
class ProfileImageCacheManager extends CacheManager {
  static const key = 'profileImageCache';

  static final ProfileImageCacheManager _instance =
      ProfileImageCacheManager._();
  factory ProfileImageCacheManager() => _instance;

  ProfileImageCacheManager._()
      : super(
          Config(
            key,
            stalePeriod: const Duration(days: 30),
            maxNrOfCacheObjects: 200,
            repo: JsonCacheInfoRepository(databaseName: key),
            fileService: HttpFileService(),
          ),
        );

  /// Pre-warms the cache with a local file so the image is never re-downloaded
  /// after an upload. Call this after receiving the remote URL from the backend.
  Future<void> prewarmFromFile(String url, File file) async {
    await putFile(
      url,
      await file.readAsBytes(),
      fileExtension: 'jpg',
    );
  }
}

/// Custom cache manager for AI avatar and app images with aggressive caching
class AppImageCacheManager extends CacheManager {
  static const key = 'appImageCache';

  static final AppImageCacheManager _instance = AppImageCacheManager._();
  factory AppImageCacheManager() => _instance;

  AppImageCacheManager._()
      : super(
          Config(
            key,
            // Cache for 90 days (very long for static app assets)
            stalePeriod: const Duration(days: 90),
            // Keep up to 100 cached images
            maxNrOfCacheObjects: 100,
            repo: JsonCacheInfoRepository(databaseName: key),
            fileService: HttpFileService(),
          ),
        );
}

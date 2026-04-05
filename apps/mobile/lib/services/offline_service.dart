import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/resource_model.dart';

class OfflineService {
  // Singleton Pattern
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  static const String _resourceBoxName = 'offline_resources';
  static const String _settingsBoxName = 'app_settings';
  static const String _progressBoxName = 'user_progress';

  late Box _resourceBox;
  late Box _settingsBox;
  late Box _progressBox;
  late SharedPreferences _prefs;

  bool _isInitialized = false;

  /// Initialize Hive and open boxes.
  /// Safe to call multiple times (checks initialization state).
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // 1. Initialize SharedPreferences (Works on ALL platforms, including Web)
      _prefs = await SharedPreferences.getInstance();
      if (kDebugMode) debugPrint('SharedPreferences Initialized');

      // 2. Initialize Hive (Only on non-web to avoid hangs/issues)
      if (!kIsWeb) {
        await Hive.initFlutter();
        _resourceBox = await Hive.openBox(_resourceBoxName);
        _settingsBox = await Hive.openBox(_settingsBoxName);
        _progressBox = await Hive.openBox(_progressBoxName);
        if (kDebugMode) debugPrint('Hive Storage Initialized');
      }

      _isInitialized = true;
      if (kDebugMode) debugPrint('OfflineService Fully Initialized');
    } catch (e) {
      if (kDebugMode) debugPrint('Error initializing OfflineService: $e');
    }
  }

  // ==========================================
  // RESOURCE CACHING
  // ==========================================

  /// Cache a list of resources for a specific path (e.g., folder structure)
  Future<void> cacheResources(
    String path,
    List<ResourceModel> resources,
  ) async {
    if (kIsWeb) return; // Skip Hive caching on web
    try {
      final List<Map<String, dynamic>> serialized =
          resources.map((r) => r.toMap()).toList();
      await _resourceBox.put(path, serialized);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error caching resources for path $path: $e');
      }
    }
  }

  /// Retrieve cached resources. Returns empty list on error or empty cache.
  List<ResourceModel> getCachedResources(String path) {
    if (!_isInitialized || kIsWeb) return [];
    try {
      final data = _resourceBox.get(path);

      if (data != null && data is List) {
        return data.map((item) {
          // Hive returns LinkedMap, explicitly cast to Map<String, dynamic>
          final map = Map<String, dynamic>.from(item as Map);
          return ResourceModel.fromMap(map, map['id'] ?? 'unknown');
        }).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error retrieving cached resources for $path: $e');
      }
    }
    return [];
  }

  /// Cache a single individual resource (e.g., for Recently Opened)
  Future<void> cacheSingleResource(ResourceModel resource) async {
    if (kIsWeb) return;
    try {
      await _resourceBox.put('resource_${resource.id}', resource.toMap());
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error caching resource ${resource.id}: $e');
      }
    }
  }

  /// Retrieve a single resource
  ResourceModel? getCachedResource(String id) {
    if (kIsWeb) return null;
    try {
      final data = _resourceBox.get('resource_$id');
      if (data != null && data is Map) {
        final map = Map<String, dynamic>.from(data);
        return ResourceModel.fromMap(map, id);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error retrieving resource $id: $e');
    }
    return null;
  }

  /// Clear all cached resources (useful for Pull-to-Refresh or Logout)
  Future<void> clearAllResources() async {
    if (kIsWeb) return;
    await _resourceBox.clear();
  }

  // ==========================================
  // SETTINGS & PREFERENCES
  // ==========================================

  Future<void> saveLiteMode(bool isEnabled) async {
    if (!_isInitialized) return;
    if (kIsWeb) {
      await _prefs.setBool('lite_mode', isEnabled);
    } else {
      await _settingsBox.put('lite_mode', isEnabled);
    }
  }

  bool getLiteMode() {
    if (!_isInitialized) return false;
    if (kIsWeb) {
      return _prefs.getBool('lite_mode') ?? false;
    }
    return _settingsBox.get('lite_mode', defaultValue: false);
  }

  /// Generic String List Getter (SharedPreferences style)
  /// Uses SharedPreferences as the primary storage for better cross-platform reliability.
  List<String> getStringList(String key) {
    if (!_isInitialized) {
      return [];
    }
    try {
      // Prefer SharedPreferences for simple flag lists (onboarding, etc.)
      return _prefs.getStringList(key) ?? [];
    } catch (e) {
      if (kDebugMode) debugPrint('Error getting string list for $key: $e');
    }
    return [];
  }

  /// Generic String List Setter
  Future<void> setStringList(String key, List<String> value) async {
    if (!_isInitialized) return;
    await _prefs.setStringList(key, value);
  }

  /// Remove a key from SharedPreferences
  Future<void> remove(String key) async {
    if (!_isInitialized) return;
    await _prefs.remove(key);
  }

  /// Clear all settings
  Future<void> clearSettings() async {
    if (!_isInitialized) return;
    await _prefs.clear();
    if (!kIsWeb) {
      await _settingsBox.clear();
    }
  }

  // ==========================================
  // DEVICE & GUEST TRACKING
  // ==========================================

  /// Get or generate a persistent device-specific identifier.
  String getDeviceId() {
    if (!_isInitialized) return 'unknown';
    String? id = _prefs.getString('device_id');
    if (id == null) {
      id = const Uuid().v4();
      _prefs.setString('device_id', id);
    }
    return id;
  }

  /// Get current guest message count for this device.
  int getGuestMessageCount() {
    if (!_isInitialized) return 0;
    return _prefs.getInt('guest_message_count') ?? 0;
  }

  /// Increment the guest message count for this device.
  Future<void> incrementGuestMessageCount() async {
    if (!_isInitialized) return;
    final current = getGuestMessageCount();
    await _prefs.setInt('guest_message_count', current + 1);
  }

  /// Mark the guest trial as completed manually for this device.
  Future<void> setGuestLimitReached(bool reached) async {
    if (!_isInitialized) return;
    // For compatibility, setting reached=true sets count to 3
    if (reached) {
      await _prefs.setInt('guest_message_count', 3);
    } else {
      await _prefs.setInt('guest_message_count', 0);
    }
  }

  /// Check if this device has reached its guest message limit (3).
  bool isGuestLimitReached() {
    if (!_isInitialized) return false;
    return getGuestMessageCount() >= 3;
  }

  // ── App-visit XP debounce ────────────────────────────────────────────────────

  /// Returns the epoch-ms timestamp of the last recorded appVisit XP award,
  /// or null if it has never been recorded.
  int? getLastAppVisitMs() {
    if (!_isInitialized) return null;
    return _prefs.getInt('last_app_visit_xp_ms');
  }

  /// Persist the timestamp of the most recent appVisit XP award.
  Future<void> setLastAppVisitMs(int ms) async {
    if (!_isInitialized) return;
    await _prefs.setInt('last_app_visit_xp_ms', ms);
  }

  // ==========================================
  // PROGRESS & ACTIVITY CACHING
  // ==========================================

  /// Cache user progress data (streak, topics covered, etc.)
  Future<void> cacheUserProgress(String uid, Map<String, dynamic> data) async {
    if (!_isInitialized || kIsWeb) return;
    try {
      await _progressBox.put('progress_$uid', data);
    } catch (e) {
      if (kDebugMode) debugPrint('Error caching progress for $uid: $e');
    }
  }

  /// Retrieve cached user progress
  Map<String, dynamic>? getCachedUserProgress(String uid) {
    if (!_isInitialized || kIsWeb) return null;
    try {
      final data = _progressBox.get('progress_$uid');
      if (data != null && data is Map) {
        return Map<String, dynamic>.from(data);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error retrieving progress for $uid: $e');
    }
    return null;
  }

  /// Cache recent activity summary (for offline display)
  Future<void> cacheActivitySummary(
      String uid, Map<String, dynamic> summary) async {
    if (!_isInitialized || kIsWeb) return;
    try {
      await _progressBox.put('activity_$uid', summary);
    } catch (e) {
      if (kDebugMode) debugPrint('Error caching activity for $uid: $e');
    }
  }

  /// Retrieve cached activity summary
  Map<String, dynamic>? getCachedActivitySummary(String uid) {
    if (!_isInitialized || kIsWeb) return null;
    try {
      final data = _progressBox.get('activity_$uid');
      if (data != null && data is Map) {
        return Map<String, dynamic>.from(data);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error retrieving activity for $uid: $e');
    }
    return null;
  }

  /// Cache current streak count for offline display.
  Future<void> cacheStreak(String uid, int streak) async {
    if (!_isInitialized || kIsWeb) return;
    await _progressBox.put('streak_$uid', streak);
  }

  int getCachedStreak(String uid) {
    if (!_isInitialized || kIsWeb) return 0;
    return _progressBox.get('streak_$uid', defaultValue: 0) as int;
  }
}

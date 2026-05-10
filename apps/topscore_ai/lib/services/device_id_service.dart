import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

class DeviceIdService {
  static const _key = 'topscore_device_id';
  static const _oldKey = 'device_id'; // Key used in SharedPreferences previously
  static String? _cached;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Get the persistent device ID.
  /// 
  /// Strategy:
  /// 1. Check in-memory cache.
  /// 2. Check FlutterSecureStorage.
  /// 3. Check SharedPreferences (Migration path).
  /// 4. Generate new UUID.
  static Future<String> get() async {
    if (_cached != null) return _cached!;

    try {
      // 1. Try secure storage
      String? secureId = await _storage.read(key: _key);
      if (secureId != null && secureId.isNotEmpty) {
        _cached = secureId;
        return _cached!;
      }

      // 2. Migration path: check SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      String? oldId = prefs.getString(_oldKey);
      
      if (oldId != null && oldId.isNotEmpty) {
        _cached = oldId;
        // Persist to secure storage for future proofing
        await _storage.write(key: _key, value: _cached!);
        // We keep it in SharedPreferences for a while just in case, or we could remove it.
        // For now, let's just ensure it's in the secure one.
        if (kDebugMode) print('Migrated Device ID from SharedPreferences: $_cached');
        return _cached!;
      }

      // 3. Generate new ID
      _cached = const Uuid().v4();
      await _storage.write(key: _key, value: _cached!);
      if (kDebugMode) print('Generated new Device ID: $_cached');
      
    } catch (e) {
      if (kDebugMode) print('Error in DeviceIdService: $e');
      // Extreme fallback
      _cached ??= const Uuid().v4();
    }

    return _cached!;
  }
}

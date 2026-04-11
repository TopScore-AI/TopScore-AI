import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

class RecoveryService {
  static const String _keyIsPickingFile = 'is_picking_file';
  static const String _keyActiveChatId = 'active_chat_id';
  static const String _keyRecoveryPath = 'recovery_path';

  static Future<void> saveNavigationState(String path, {String? threadId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsPickingFile, true);
      await prefs.setString(_keyRecoveryPath, path);
      if (threadId != null) {
        await prefs.setString(_keyActiveChatId, threadId);
      }
      developer.log('Recovery State Saved: $path ($threadId)', name: 'RecoveryService');
    } catch (e) {
      developer.log('Error saving recovery state: $e', name: 'RecoveryService');
    }
  }

  static Future<Map<String, String?>?> getRecoveryState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isPicking = prefs.getBool(_keyIsPickingFile) ?? false;
      
      if (!isPicking) return null;

      final path = prefs.getString(_keyRecoveryPath);
      final threadId = prefs.getString(_keyActiveChatId);
      
      return {
        'path': path,
        'threadId': threadId,
      };
    } catch (e) {
      developer.log('Error getting recovery state: $e', name: 'RecoveryService');
      return null;
    }
  }

  static Future<void> clearRecoveryState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyIsPickingFile);
      await prefs.remove(_keyRecoveryPath);
      await prefs.remove(_keyActiveChatId);
      developer.log('Recovery State Cleared', name: 'RecoveryService');
    } catch (e) {
      developer.log('Error clearing recovery state: $e', name: 'RecoveryService');
    }
  }
}

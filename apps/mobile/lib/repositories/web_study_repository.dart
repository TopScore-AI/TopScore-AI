import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'study_repository.dart';

class WebStudyRepository implements StudyRepository {
  final SharedPreferences _prefs;
  final String _storageKey = 'topscore_study_materials';

  WebStudyRepository(this._prefs);
  
  @override
  dynamic get isar => null; // Isar not used on web-only implementation

  List<Map<String, dynamic>> _getAll() {
    final existingJson = _prefs.getString(_storageKey);
    if (existingJson == null) return [];
    final List<dynamic> decodedList = jsonDecode(existingJson);
    return decodedList.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  Future<void> saveMaterial({
    required String type,
    required String topic,
    required String curriculum,
    required String grade,
    required String jsonData,
  }) async {
    final materials = _getAll();
    
    // Generate a pseudo-ID using timestamp
    final id = DateTime.now().millisecondsSinceEpoch;

    materials.add({
      'id': id,
      'type': type,
      'topic': topic,
      'curriculum': curriculum,
      'grade': grade,
      'jsonData': jsonData,
      'createdAt': DateTime.now().toIso8601String(),
    });

    await _prefs.setString(_storageKey, jsonEncode(materials));
  }

  @override
  Future<List<Map<String, dynamic>>> getMaterialsByType(String type) async {
    final all = _getAll();
    // Filter and sort newest first
    var filtered = all.where((m) => m['type'] == type).toList();
    filtered.sort((a, b) => b['createdAt'].compareTo(a['createdAt']));
    return filtered;
  }

  @override
  Future<Map<String, dynamic>?> getMaterialByTopic(String type, String topic) async {
    final all = _getAll();
    try {
      return all.firstWhere((m) => m['type'] == type && m['topic'] == topic);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<int> deleteMaterial(int id) async {
    final materials = _getAll();
    materials.removeWhere((m) => m['id'] == id);
    await _prefs.setString(_storageKey, jsonEncode(materials));
    return 1;
  }
}

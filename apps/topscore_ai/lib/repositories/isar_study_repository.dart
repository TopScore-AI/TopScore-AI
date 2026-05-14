import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/study_material.dart';
import '../config/database_schemas.dart';
import 'study_repository.dart';

class IsarStudyRepository implements StudyRepository {
  late Isar _isar;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    // Open the DB if it isn't already open
    if (Isar.instanceNames.isEmpty) {
      _isar = await Isar.open(appSchemas.cast<CollectionSchema<dynamic>>(),
          directory: dir.path);
    } else {
      _isar = Isar.getInstance()!;
    }
  }

  @override
  Future<void> saveMaterial({
    required String type,
    required String topic,
    required String curriculum,
    required String grade,
    required String jsonData,
  }) async {
    final material = SavedStudyMaterial()
      ..type = type
      ..topic = topic
      ..curriculum = curriculum
      ..grade = grade
      ..jsonData = jsonData
      ..createdAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.savedStudyMaterials.put(material);
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getMaterialsByType(String type) async {
    final results = await _isar.savedStudyMaterials
        .filter()
        .typeEqualTo(type)
        .sortByCreatedAtDesc()
        .findAll();

    // Convert to standard Maps so the UI doesn't know we are using Isar
    return results
        .map((e) => {
              'id': e.id,
              'topic': e.topic,
              'curriculum': e.curriculum,
              'grade': e.grade,
              'jsonData': e.jsonData,
              'createdAt': e.createdAt.toIso8601String(),
            })
        .toList();
  }

  @override
  Future<Map<String, dynamic>?> getMaterialByTopic(
      String type, String topic) async {
    final result = await _isar.savedStudyMaterials
        .filter()
        .typeEqualTo(type)
        .topicEqualTo(topic)
        .findFirst();

    if (result == null) return null;

    return {
      'id': result.id,
      'topic': result.topic,
      'curriculum': result.curriculum,
      'grade': result.grade,
      'jsonData': result.jsonData,
      'createdAt': result.createdAt.toIso8601String(),
    };
  }

  @override
  Future<int> deleteMaterial(int id) async {
    return await _isar.writeTxn(() async {
      final success = await _isar.savedStudyMaterials.delete(id);
      return success ? 1 : 0;
    });
  }

  @override
  Isar get isar => _isar;
}

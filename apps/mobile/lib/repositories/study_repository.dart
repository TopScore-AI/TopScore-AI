abstract class StudyRepository {
  Future<void> saveMaterial({
    required String type,
    required String topic,
    required String curriculum,
    required String grade,
    required String jsonData,
  });

  Future<List<Map<String, dynamic>>> getMaterialsByType(String type);
  Future<Map<String, dynamic>?> getMaterialByTopic(String type, String topic);
  Future<int> deleteMaterial(int id);
  
  dynamic get isar;
}

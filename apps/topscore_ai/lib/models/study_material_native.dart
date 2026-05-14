import 'package:isar_community/isar.dart';

part 'study_material_native.g.dart';

@collection
class SavedStudyMaterial {
  Id id = Isar.autoIncrement;

  @Index()
  late String type; 

  @Index(caseSensitive: false)
  late String topic;

  late String curriculum;
  late String grade;
  
  late String jsonData; 
  
  late DateTime createdAt;
}

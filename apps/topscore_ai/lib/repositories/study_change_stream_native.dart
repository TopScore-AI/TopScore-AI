import '../models/study_material.dart';
import 'study_repository.dart';

Stream<void> watchStudyChanges(StudyRepository repo) {
  return repo.isar.savedStudyMaterials.watchLazy(fireImmediately: false);
}

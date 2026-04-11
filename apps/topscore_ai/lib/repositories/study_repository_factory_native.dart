import 'study_repository.dart';
import 'isar_study_repository.dart';

Future<StudyRepository> createStudyRepository() async {
  final repo = IsarStudyRepository();
  await repo.init();
  return repo;
}

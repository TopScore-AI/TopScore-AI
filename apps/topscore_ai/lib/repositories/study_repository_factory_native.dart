import '../services/firestore_artifact_service.dart';
import 'isar_study_repository.dart';
import 'study_repository.dart';
import 'synced_study_repository.dart';

Future<StudyRepository> createStudyRepository() async {
  final repo = IsarStudyRepository();
  await repo.init();
  return SyncedStudyRepository(
    inner: repo,
    firestore: FirestoreArtifactService(),
  );
}

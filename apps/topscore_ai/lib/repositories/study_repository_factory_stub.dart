import 'package:shared_preferences/shared_preferences.dart';

import '../services/firestore_artifact_service.dart';
import 'study_repository.dart';
import 'synced_study_repository.dart';
import 'web_study_repository.dart';

Future<StudyRepository> createStudyRepository() async {
  final prefs = await SharedPreferences.getInstance();
  final repo = WebStudyRepository(prefs);
  return SyncedStudyRepository(
    inner: repo,
    firestore: FirestoreArtifactService(),
  );
}

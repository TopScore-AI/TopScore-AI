import '../firestore_artifact_service.dart';
import '../isar_service.dart';

class ChatMigrationRunner {
  ChatMigrationRunner({
    required IsarService isar,
    required FirestoreArtifactService firestore,
  });

  Future<void> run({required String uid}) async {
    // No-op on web as Isar is not used for chat history.
    return;
  }
}

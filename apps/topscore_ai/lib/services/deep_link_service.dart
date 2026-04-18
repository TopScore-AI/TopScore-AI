import '../router.dart' as app_router;
import 'firestore_service.dart';
import 'isar_service.dart';
import '../models/study_material.dart';
import 'dart:developer' as developer;

class DeepLinkService {
  static final FirestoreService _firestore = FirestoreService();

  static void handleUri(Uri uri) async {
    developer.log('DeepLinkService: Handling URI $uri', name: 'DeepLink');

    // Handle topscoreapp.ai or topscore://app links
    final path = uri.path;
    final segments = uri.pathSegments;

    if (segments.isEmpty) return;

    final command = segments.first;

    switch (command) {
      case 'deck':
        if (segments.length > 1) {
          final deckId = segments[1];
          _handleSharedDeck(deckId);
        }
        break;
      
      case 'play':
        if (segments.length > 1) {
          final roomCode = segments[1];
          _handleMultiplayerJoin(roomCode);
        }
        break;

      default:
        // Fallback for standard routes
        Future.delayed(const Duration(milliseconds: 100), () {
          app_router.router.go(path);
        });
    }
  }

  static Future<void> _handleSharedDeck(String deckId) async {
    try {
      // 1. Check if we already have it locally is not feasible without fetching its remote ID
      // So we fetch metadata/content from Firestore shared_artifacts
      final artifact = await _firestore.getSharedArtifact(deckId);
      if (artifact == null) {
        developer.log('Shared deck not found: $deckId', name: 'DeepLink');
        return;
      }

      final type = artifact['type'];
      final jsonData = artifact['jsonData'];
      final topic = artifact['topic'] ?? 'Shared Deck';

      // 2. Automatically cache it into Isar so the user can keep it
      final isar = await IsarService().db;
      final material = SavedStudyMaterial()
        ..type = type
        ..topic = topic
        ..curriculum = artifact['curriculum'] ?? 'Unknown'
        ..grade = artifact['grade'] ?? 'Unknown'
        ..jsonData = jsonData
        ..createdAt = DateTime.now();

      await isar?.writeTxn(() async {
        await isar.savedStudyMaterials.put(material);
      });

      // 3. Navigate to the appropriate viewer
      if (type == 'flashcards') {
        app_router.router.go('/tools/flashcards/study', extra: material);
      } else if (type == 'quiz') {
        app_router.router.go('/tools/quiz/study', extra: material);
      }

    } catch (e) {
      developer.log('Error handling shared deck: $e', name: 'DeepLink');
    }
  }

  static void _handleMultiplayerJoin(String roomCode) {
    // Navigate to multiplayer join screen with the PIN pre-filled
    app_router.router.go('/play/$roomCode');
  }
}

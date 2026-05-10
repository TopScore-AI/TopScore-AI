import '../models/user_model.dart';

/// Service to check if a user has access to premium features
class FeatureGateService {
  /// Check if user has an active subscription
  static bool hasActiveSubscription(UserModel? user) {
    if (user == null) return false;
    if (!user.isSubscribed) return false;

    final expiry = user.subscriptionExpiry;
    if (expiry == null) return true; // Legacy subscriptions
    return expiry.isAfter(DateTime.now());
  }

  /// Features that require premium subscription
  static const List<String> premiumFeatures = [
    'flashcards',
    'quiz_generation',
    'multiplayer_quiz',
    'pdf_ai_chat',
    'pdf_download',
    'pdf_share',
    'pdf_summarizer',
    'document_scanner',
  ];

  /// Check if user can access a specific feature
  static bool canAccessFeature(UserModel? user, String feature) {
    if (!premiumFeatures.contains(feature)) {
      return true; // Free feature
    }
    return hasActiveSubscription(user);
  }

  /// Check if user can generate flashcards
  static bool canGenerateFlashcards(UserModel? user) {
    return canAccessFeature(user, 'flashcards');
  }

  /// Check if user can generate quizzes
  static bool canGenerateQuiz(UserModel? user) {
    return canAccessFeature(user, 'quiz_generation');
  }

  /// Check if user can play multiplayer quiz
  static bool canPlayMultiplayerQuiz(UserModel? user) {
    return canAccessFeature(user, 'multiplayer_quiz');
  }

  /// Check if user can use AI in PDF viewer
  static bool canUsePdfAiChat(UserModel? user) {
    return canAccessFeature(user, 'pdf_ai_chat');
  }

  /// Check if user can download PDFs
  static bool canDownloadPdf(UserModel? user) {
    return canAccessFeature(user, 'pdf_download');
  }

  /// Check if user can share PDFs
  static bool canSharePdf(UserModel? user) {
    return canAccessFeature(user, 'pdf_share');
  }


  /// Check if user can use PDF summarizer
  static bool canUsePdfSummarizer(UserModel? user) {
    return canAccessFeature(user, 'pdf_summarizer');
  }

  /// Check if user can use document scanner
  static bool canUseDocumentScanner(UserModel? user) {
    return canAccessFeature(user, 'document_scanner');
  }

  /// Get user-friendly feature name
  static String getFeatureName(String feature) {
    switch (feature) {
      case 'flashcards':
        return 'AI Flashcards';
      case 'quiz_generation':
        return 'Quiz Generation';
      case 'multiplayer_quiz':
        return 'Multiplayer Quiz';
      case 'pdf_ai_chat':
        return 'AI Chat in PDF Viewer';
      case 'pdf_download':
        return 'PDF Download';
      case 'pdf_share':
        return 'PDF Sharing';
      case 'pdf_summarizer':
        return 'PDF Summarizer';
      case 'document_scanner':
        return 'Document Scanner';
      default:
        return feature;
    }
  }

  /// Get upgrade message for a feature
  static String getUpgradeMessage(String feature) {
    final featureName = getFeatureName(feature);
    return '$featureName is a premium feature. Upgrade to TopScore Pro to unlock unlimited access!';
  }
}

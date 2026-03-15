import 'package:cloud_firestore/cloud_firestore.dart';

class SurveyResponse {
  final String id;
  final String userId;
  final String userName;
  final double rating;
  final String favoriteFeature;
  final String improvementSuggestions;
  final String testimonial;
  final bool consentToPublicity;
  final DateTime createdAt;

  SurveyResponse({
    required this.id,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.favoriteFeature,
    required this.improvementSuggestions,
    required this.testimonial,
    required this.consentToPublicity,
    required this.createdAt,
  });

  factory SurveyResponse.fromMap(Map<String, dynamic> data, String id) {
    return SurveyResponse(
      id: id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anonymous',
      rating: (data['rating'] ?? 0.0).toDouble(),
      favoriteFeature: data['favoriteFeature'] ?? '',
      improvementSuggestions: data['improvementSuggestions'] ?? '',
      testimonial: data['testimonial'] ?? '',
      consentToPublicity: data['consentToPublicity'] ?? false,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'rating': rating,
      'favoriteFeature': favoriteFeature,
      'improvementSuggestions': improvementSuggestions,
      'testimonial': testimonial,
      'consentToPublicity': consentToPublicity,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

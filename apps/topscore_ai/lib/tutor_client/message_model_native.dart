import 'dart:convert';
import 'package:isar/isar.dart';

part 'message_model_native.g.dart';

enum MessageStatus { pending, sent, error }

@embedded
class SourceMetadata {
  final String title;
  final String? url;
  final String? author;
  final String type; // 'url', 'book', 'paper'

  SourceMetadata({
    this.title = '',
    this.url,
    this.author,
    this.type = 'url',
  });

  factory SourceMetadata.fromJson(Map<String, dynamic> json) {
    return SourceMetadata(
      title: json['title'] ?? 'Unknown Source',
      url: json['url'],
      author: json['author'],
      type: json['type'] ?? 'url',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'url': url,
      'author': author,
      'type': type,
    };
  }
}

@embedded
class ChatAttachmentMetadata {
  final String? id;
  final String? url;
  final String? name;
  final String? type;

  ChatAttachmentMetadata({
    this.id,
    this.url,
    this.name,
    this.type,
  });

  factory ChatAttachmentMetadata.fromJson(Map<String, dynamic> json) {
    return ChatAttachmentMetadata(
      id: json['id'],
      url: json['url'],
      name: json['name'],
      type: json['type'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'name': name,
      'type': type,
    };
  }
}

@embedded
class UiWidgetData {
  final String? id;
  final String? type;
  final String? title;
  final String? configJson;

  UiWidgetData({
    this.id,
    this.type,
    this.title,
    this.configJson,
  });

  factory UiWidgetData.fromJson(Map<String, dynamic> json) {
    return UiWidgetData(
      id: json['id'],
      type: json['type'] ?? json['type_name'] ?? 'unknown',
      title: json['title'],
      configJson: json['config'] != null ? jsonEncode(json['config']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'config': configJson != null ? jsonDecode(configJson!) : null,
    };
  }
}

@collection
class ChatMessage {
  Id get isarId => _fastHash(id);

  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? audioUrl;
  final String? imageUrl;
  final List<ChatAttachmentMetadata>? attachments; // Multiple attachments support
  final int? feedback; // 1 for thumbs up, -1 for thumbs down, null for no feedback
  final List<SourceMetadata>? sources; // Sources for verification
  final String? reasoning; // Chain-of-thought reasoning
  final String? quizDataJson; // Map stored as JSON for Isar
  final String? flashcardDataJson; // Flashcards stored as JSON for Isar
  final List<String>? mathSteps;
  final String? mathAnswer;
  final bool isBookmarked;
  final List<VideoResult>? videos; // <--- NEW: Video Results
  final String? mnemonicDataJson; // Mnemonics stored as JSON for Isar
  final String? punnettDataJson; // Genetic cross data stored as JSON for Isar
  final List<String>? uiWidgetsJson; // Dynamic UI widgets stored as JSON strings
  final List<UiWidgetData>? uiWidgets; // Side-channel widgets synced by ID

  // Hybrid Streaming Architecture flags
  final bool isTemporary; // true when from WebSocket (temporary), false when from Firebase (final)
  final bool isComplete; // true when streaming is done
  final String? replyToId;
  final String? replyToText;
  final bool isThought; // For TopScore AI Live native thought/reasoning
  final bool isThinking; // UI flag for "Optimistic Thinking" shimmer
  final bool isKicdCertified; // Flag for official KICD-approved content
  
  @enumerated
  final MessageStatus status;
  
  @Index()
  final String? threadId; // For easy querying
  final String? fileId;   // Unique ID for the attachment
  final String? fileName; // Display name for the attachment
  final String? fileType; // Type of attachment ('image', 'pdf', 'docx', etc.)

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.audioUrl,
    this.imageUrl,
    this.feedback,
    this.sources,
    this.reasoning,
    this.quizDataJson,
    this.flashcardDataJson,
    this.mathSteps,
    this.mathAnswer,
    this.isBookmarked = false,
    this.videos,
    this.mnemonicDataJson,
    this.isTemporary = false, // Default: final Firebase message
    this.isComplete = true, // Default: complete message
    this.replyToId,
    this.replyToText,
    this.isThought = false,
    this.isThinking = false,
    this.isKicdCertified = false,
    this.status = MessageStatus.sent,
    this.threadId,
    this.punnettDataJson,
    this.fileId,
    this.fileName,
    this.fileType,
    this.attachments,
    this.uiWidgetsJson,
    this.uiWidgets,
  });

  ChatMessage copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    String? audioUrl,
    String? imageUrl,
    int? feedback,
    List<SourceMetadata>? sources,
    String? reasoning,
    Map<String, dynamic>? quizData,
    String? quizDataJson,
    Map<String, dynamic>? flashcardData,
    String? flashcardDataJson,
    List<String>? mathSteps,
    String? mathAnswer,
    bool? isBookmarked,
    List<VideoResult>? videos,
    bool? isTemporary,
    bool? isComplete,
    String? replyToId,
    String? replyToText,
    bool? isThought,
    bool? isThinking,
    bool? isKicdCertified,
    MessageStatus? status,
    String? threadId,
    String? mnemonicDataJson,
    String? punnettDataJson,
    String? fileId,
    String? fileName,
    String? fileType,
    List<ChatAttachmentMetadata>? attachments,
    List<String>? uiWidgetsJson,
    List<UiWidgetData>? uiWidgets,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      audioUrl: audioUrl ?? this.audioUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      feedback: feedback ?? this.feedback,
      sources: sources ?? this.sources,
      reasoning: reasoning ?? this.reasoning,
      quizDataJson: quizData != null ? jsonEncode(quizData) : (quizDataJson ?? this.quizDataJson),
      flashcardDataJson: flashcardData != null ? jsonEncode(flashcardData) : (flashcardDataJson ?? this.flashcardDataJson),
      mathSteps: mathSteps ?? this.mathSteps,
      mathAnswer: mathAnswer ?? this.mathAnswer,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      videos: videos ?? this.videos,
      isTemporary: isTemporary ?? this.isTemporary,
      isComplete: isComplete ?? this.isComplete,
      replyToId: replyToId ?? this.replyToId,
      replyToText: replyToText ?? this.replyToText,
      isThought: isThought ?? this.isThought,
      isThinking: isThinking ?? this.isThinking,
      isKicdCertified: isKicdCertified ?? this.isKicdCertified,
      status: status ?? this.status,
      threadId: threadId ?? this.threadId,
      mnemonicDataJson: mnemonicDataJson ?? this.mnemonicDataJson,
      punnettDataJson: punnettDataJson ?? this.punnettDataJson,
      fileId: fileId ?? this.fileId,
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      attachments: attachments ?? this.attachments,
      uiWidgetsJson: uiWidgetsJson ?? this.uiWidgetsJson,
      uiWidgets: uiWidgets ?? this.uiWidgets,
    );
  }
}

@embedded
class VideoResult {
  final String id;
  final String title;
  final String thumbnailUrl;
  final String videoUrl;
  final String duration;
  final String source; // e.g., "YouTube", "Khan Academy"

  VideoResult({
    this.id = '',
    this.title = '',
    this.thumbnailUrl = '',
    this.videoUrl = '',
    this.duration = '',
    this.source = '',
  });

  factory VideoResult.fromJson(Map<String, dynamic> json) {
    return VideoResult(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      thumbnailUrl: json['thumbnailUrl'] ?? '',
      videoUrl: json['videoUrl'] ?? '',
      duration: json['duration'] ?? '',
      source: json['source'] ?? 'Unknown',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'thumbnailUrl': thumbnailUrl,
      'videoUrl': videoUrl,
      'duration': duration,
      'source': source,
    };
  }
}

int _fastHash(String string) {
  // JS-safe 32-bit FNV-1a hash (avoids 64-bit integer literals)
  var hash = 0x811c9dc5;
  for (var i = 0; i < string.length; i++) {
    hash ^= string.codeUnitAt(i);
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  // Map to signed 32-bit range so Isar Id (int) stays valid
  return hash > 0x7FFFFFFF ? hash - 0x100000000 : hash;
}
